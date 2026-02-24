"""Genomics service for parsing 23andMe files and generating risk profiles."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

import asyncpg

from app.models.database import get_pool

logger = logging.getLogger(__name__)

# Known health-related SNPs with risk interpretations
# Format: rsid -> {risk_category, risk_allele, risk_level, summary}
HEALTH_SNPS: dict[str, dict[str, Any]] = {
    # Cardiovascular
    "rs1333049": {
        "risk_category": "cardiovascular",
        "risk_alleles": ["C"],
        "summary": "Associated with coronary artery disease risk (9p21 region)",
    },
    "rs10757274": {
        "risk_category": "cardiovascular",
        "risk_alleles": ["G"],
        "summary": "Associated with myocardial infarction risk",
    },
    "rs6025": {
        "risk_category": "cardiovascular",
        "risk_alleles": ["A"],
        "summary": "Factor V Leiden - increased blood clotting risk",
    },
    # Metabolic / Diabetes
    "rs7903146": {
        "risk_category": "metabolic",
        "risk_alleles": ["T"],
        "summary": "TCF7L2 variant - strongest known genetic risk factor for type 2 diabetes",
    },
    "rs1801282": {
        "risk_category": "metabolic",
        "risk_alleles": ["C"],
        "summary": "PPARG variant - associated with insulin sensitivity",
    },
    # Alzheimer's / Neurodegeneration
    "rs429358": {
        "risk_category": "neurodegenerative",
        "risk_alleles": ["C"],
        "summary": "APOE e4 variant - major genetic risk factor for Alzheimer's disease",
    },
    "rs7412": {
        "risk_category": "neurodegenerative",
        "risk_alleles": ["C"],
        "summary": "APOE variant - affects Alzheimer's risk profile",
    },
    # Cancer risk
    "rs1042522": {
        "risk_category": "cancer",
        "risk_alleles": ["C"],
        "summary": "TP53 variant - associated with various cancer risks",
    },
    # Inflammation
    "rs1800795": {
        "risk_category": "inflammation",
        "risk_alleles": ["C"],
        "summary": "IL-6 variant - associated with inflammatory response",
    },
    # Methylation / MTHFR
    "rs1801133": {
        "risk_category": "methylation",
        "risk_alleles": ["A"],
        "summary": "MTHFR C677T - affects folate metabolism and homocysteine levels",
    },
    "rs1801131": {
        "risk_category": "methylation",
        "risk_alleles": ["G"],
        "summary": "MTHFR A1298C - affects folate metabolism",
    },
    # Longevity
    "rs2802292": {
        "risk_category": "longevity",
        "risk_alleles": ["G"],
        "summary": "FOXO3 variant - associated with exceptional longevity",
    },
    # Caffeine metabolism
    "rs762551": {
        "risk_category": "caffeine_metabolism",
        "risk_alleles": ["C"],
        "summary": "CYP1A2 - slow caffeine metabolizer",
    },
    # Vitamin D
    "rs2282679": {
        "risk_category": "vitamin_d",
        "risk_alleles": ["C"],
        "summary": "GC gene - affects vitamin D binding protein levels",
    },
}


def parse_23andme_file(file_content: str) -> list[dict[str, Any]]:
    """Parse a 23andMe raw data file.

    Returns a list of variants: [{rsid, chromosome, position, genotype}, ...]
    """
    variants = []

    for line in file_content.splitlines():
        line = line.strip()

        # Skip comments and empty lines
        if not line or line.startswith("#"):
            continue

        parts = line.split("\t")
        if len(parts) < 4:
            continue

        rsid, chromosome, position, genotype = parts[:4]

        # Skip invalid entries
        if not rsid.startswith("rs") and not rsid.startswith("i"):
            continue
        if genotype in ("--", "DD", "II", "DI", "ID"):
            # No call or indel - skip for now
            continue

        try:
            pos = int(position)
        except ValueError:
            continue

        variants.append({
            "rsid": rsid,
            "chromosome": chromosome,
            "position": pos,
            "genotype": genotype,
        })

    return variants


async def store_variants(
    user_id: UUID,
    variants: list[dict[str, Any]],
    source: str = "23andme",
) -> int:
    """Store parsed variants in the database.

    Returns the number of variants stored.
    """
    pool = get_pool()

    # Batch insert with ON CONFLICT DO UPDATE
    async with pool.acquire() as conn:
        # Use COPY for bulk insert performance
        stored = 0

        # Process in batches of 5000
        batch_size = 5000
        for i in range(0, len(variants), batch_size):
            batch = variants[i : i + batch_size]

            # Prepare batch values
            values = [
                (user_id, v["rsid"], v["chromosome"], v["position"], v["genotype"], source)
                for v in batch
            ]

            # Execute batch insert
            await conn.executemany(
                """
                INSERT INTO genomic_variants (user_id, rsid, chromosome, position, genotype, source)
                VALUES ($1, $2, $3, $4, $5, $6)
                ON CONFLICT (user_id, rsid, source) DO UPDATE SET
                    chromosome = EXCLUDED.chromosome,
                    position = EXCLUDED.position,
                    genotype = EXCLUDED.genotype
                """,
                values,
            )
            stored += len(batch)

    return stored


async def analyze_health_risks(user_id: UUID) -> list[dict[str, Any]]:
    """Analyze stored variants against known health SNPs.

    Returns a list of risk assessments to be stored in genomic_profiles.
    """
    pool = get_pool()

    # Get user's variants for known health SNPs
    rsids = list(HEALTH_SNPS.keys())
    rows = await pool.fetch(
        """
        SELECT rsid, genotype FROM genomic_variants
        WHERE user_id = $1 AND rsid = ANY($2)
        """,
        user_id,
        rsids,
    )

    user_variants = {r["rsid"]: r["genotype"] for r in rows}

    # Aggregate risks by category
    category_risks: dict[str, dict[str, Any]] = {}

    for rsid, info in HEALTH_SNPS.items():
        if rsid not in user_variants:
            continue

        genotype = user_variants[rsid]
        risk_alleles = info["risk_alleles"]
        category = info["risk_category"]

        # Count risk alleles in genotype
        risk_count = sum(1 for allele in genotype if allele in risk_alleles)

        if category not in category_risks:
            category_risks[category] = {
                "variants": [],
                "total_risk_score": 0,
            }

        category_risks[category]["variants"].append({
            "rsid": rsid,
            "genotype": genotype,
            "risk_alleles": risk_count,
            "summary": info["summary"],
        })
        category_risks[category]["total_risk_score"] += risk_count

    # Convert to risk profiles
    risk_profiles = []
    for category, data in category_risks.items():
        # Determine risk level based on total risk alleles
        score = data["total_risk_score"]
        num_variants = len(data["variants"])

        if num_variants == 0:
            continue

        avg_risk = score / (num_variants * 2)  # Max 2 alleles per variant

        if avg_risk >= 0.75:
            risk_level = "elevated"
        elif avg_risk >= 0.5:
            risk_level = "moderate"
        elif avg_risk >= 0.25:
            risk_level = "normal"
        else:
            risk_level = "reduced"

        # Build summary
        variant_summaries = [v["summary"] for v in data["variants"]]
        summary = " | ".join(variant_summaries[:3])  # Limit to 3 summaries
        if len(variant_summaries) > 3:
            summary += f" (+{len(variant_summaries) - 3} more)"

        risk_profiles.append({
            "risk_category": category,
            "risk_level": risk_level,
            "summary": summary,
            "metadata": {
                "variants_analyzed": num_variants,
                "risk_score": score,
                "max_possible": num_variants * 2,
                "variant_details": data["variants"],
            },
        })

    return risk_profiles


async def create_genome_upload(
    user_id: UUID,
    source: str,
    filename: str | None,
) -> UUID:
    """Create a genome upload record and return its ID."""
    pool = get_pool()
    row = await pool.fetchrow(
        """
        INSERT INTO genome_uploads (user_id, source, filename, status)
        VALUES ($1, $2, $3, 'processing')
        RETURNING id
        """,
        user_id,
        source,
        filename,
    )
    return row["id"]


async def update_genome_upload(
    upload_id: UUID,
    variant_count: int | None = None,
    status: str | None = None,
    error_message: str | None = None,
) -> None:
    """Update a genome upload record."""
    pool = get_pool()

    updates = []
    params: list[Any] = []
    idx = 1

    if variant_count is not None:
        updates.append(f"variant_count = ${idx}")
        params.append(variant_count)
        idx += 1

    if status is not None:
        updates.append(f"status = ${idx}")
        params.append(status)
        idx += 1
        if status == "completed":
            updates.append(f"completed_at = ${idx}")
            params.append(datetime.now(timezone.utc))
            idx += 1

    if error_message is not None:
        updates.append(f"error_message = ${idx}")
        params.append(error_message)
        idx += 1

    if not updates:
        return

    params.append(upload_id)
    await pool.execute(
        f"UPDATE genome_uploads SET {', '.join(updates)} WHERE id = ${idx}",
        *params,
    )


async def get_genome_uploads(user_id: UUID) -> list[dict[str, Any]]:
    """Get all genome uploads for a user."""
    pool = get_pool()
    rows = await pool.fetch(
        """
        SELECT id, user_id, source, filename, variant_count, status, error_message, created_at, completed_at
        FROM genome_uploads WHERE user_id = $1 ORDER BY created_at DESC
        """,
        user_id,
    )
    return [dict(r) for r in rows]
