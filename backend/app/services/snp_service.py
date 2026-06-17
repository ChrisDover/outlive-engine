"""SNP Knowledge Service - Direct genome-to-protocol matching without external AI."""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any
from uuid import UUID

from app.models.database import get_pool

logger = logging.getLogger(__name__)


async def seed_snp_knowledge() -> dict[str, int]:
    """Load SNP knowledge from JSON file into database."""
    pool = get_pool()
    data_path = Path(__file__).parent.parent.parent / "data" / "snp_knowledge.json"

    if not data_path.exists():
        logger.warning(f"SNP knowledge file not found: {data_path}")
        return {"inserted": 0, "updated": 0}

    with open(data_path) as f:
        data = json.load(f)

    inserted = 0
    updated = 0

    for snp in data.get("snp_knowledge", []):
        result = await pool.execute(
            """
            INSERT INTO snp_knowledge (
                rsid, gene, risk_allele, normal_allele, category, condition,
                risk_level, description, supplements, avoid, interventions,
                tests_recommended, drug_interactions, expert_source, pubmed_ids, evidence_level
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15::text[], $16)
            ON CONFLICT (rsid, risk_allele) DO UPDATE SET
                gene = EXCLUDED.gene,
                normal_allele = EXCLUDED.normal_allele,
                category = EXCLUDED.category,
                condition = EXCLUDED.condition,
                risk_level = EXCLUDED.risk_level,
                description = EXCLUDED.description,
                supplements = EXCLUDED.supplements,
                avoid = EXCLUDED.avoid,
                interventions = EXCLUDED.interventions,
                tests_recommended = EXCLUDED.tests_recommended,
                drug_interactions = EXCLUDED.drug_interactions,
                expert_source = EXCLUDED.expert_source,
                pubmed_ids = EXCLUDED.pubmed_ids,
                evidence_level = EXCLUDED.evidence_level,
                updated_at = NOW()
            """,
            snp["rsid"],
            snp.get("gene"),
            snp.get("risk_allele"),
            snp.get("normal_allele"),
            snp["category"],
            snp["condition"],
            snp.get("risk_level"),
            snp["description"],
            json.dumps(snp.get("supplements", [])),
            json.dumps(snp.get("avoid", [])),
            json.dumps(snp.get("interventions", [])),
            json.dumps(snp.get("tests_recommended", [])),
            json.dumps(snp.get("drug_interactions", [])),
            snp.get("expert_source"),
            snp.get("pubmed_ids", []),
            snp.get("evidence_level"),
        )
        # Check if inserted or updated
        if "INSERT" in result:
            inserted += 1
        else:
            updated += 1

    logger.info(f"SNP knowledge seeded: {inserted} inserted, {updated} updated")
    return {"inserted": inserted, "updated": updated}


async def analyze_genome_with_knowledge(user_id: UUID) -> dict[str, Any]:
    """
    Match user's genome variants against the SNP knowledge base.
    Returns actionable findings without needing external AI.
    """
    pool = get_pool()

    # Get all user's genomic variants
    variants = await pool.fetch(
        """
        SELECT rsid, genotype
        FROM genomic_variants
        WHERE user_id = $1
        """,
        user_id,
    )

    if not variants:
        return {
            "status": "no_genome",
            "message": "No genomic data found. Upload your 23andMe data first.",
            "findings": [],
        }

    # Build a map of rsid -> genotype
    user_genotypes = {v["rsid"]: v["genotype"] for v in variants}

    # Get all SNP knowledge
    knowledge = await pool.fetch(
        """
        SELECT * FROM snp_knowledge
        """
    )

    findings = []

    for snp in knowledge:
        rsid = snp["rsid"]
        if rsid not in user_genotypes:
            continue

        genotype = user_genotypes[rsid]
        risk_allele = snp["risk_allele"]
        normal_allele = snp["normal_allele"]

        # Count risk alleles in genotype
        risk_count = genotype.count(risk_allele) if risk_allele else 0

        # Determine status
        if risk_count == 2:
            status = "homozygous_risk"
            status_label = f"Homozygous ({risk_allele}/{risk_allele})"
            impact = "high"
        elif risk_count == 1:
            status = "heterozygous"
            status_label = f"Heterozygous ({genotype})"
            impact = "moderate"
        else:
            status = "normal"
            status_label = f"Normal ({genotype})"
            impact = "none"
            # Only include if it's protective (like FOXO3)
            if snp["risk_level"] != "protective":
                continue

        findings.append({
            "rsid": rsid,
            "gene": snp["gene"],
            "genotype": genotype,
            "status": status,
            "status_label": status_label,
            "impact": impact,
            "category": snp["category"],
            "condition": snp["condition"],
            "risk_level": snp["risk_level"],
            "description": snp["description"],
            "supplements": json.loads(snp["supplements"]) if snp["supplements"] else [],
            "avoid": json.loads(snp["avoid"]) if snp["avoid"] else [],
            "interventions": json.loads(snp["interventions"]) if snp["interventions"] else [],
            "tests_recommended": json.loads(snp["tests_recommended"]) if snp["tests_recommended"] else [],
            "drug_interactions": json.loads(snp["drug_interactions"]) if snp["drug_interactions"] else [],
            "expert_source": snp["expert_source"],
            "evidence_level": snp["evidence_level"],
        })

    # Sort by impact (high first)
    impact_order = {"high": 0, "moderate": 1, "none": 2}
    findings.sort(key=lambda x: impact_order.get(x["impact"], 99))

    # Aggregate recommendations
    all_supplements = {}
    all_avoid = {}
    all_interventions = []
    all_tests = set()

    for finding in findings:
        if finding["impact"] == "none":
            continue

        for supp in finding.get("supplements", []):
            name = supp.get("name")
            if name:
                if name not in all_supplements:
                    all_supplements[name] = {
                        **supp,
                        "reasons": [finding["condition"]],
                    }
                else:
                    all_supplements[name]["reasons"].append(finding["condition"])

        for avoid in finding.get("avoid", []):
            item = avoid.get("item")
            if item:
                if item not in all_avoid:
                    all_avoid[item] = {
                        **avoid,
                        "reasons": [finding["condition"]],
                    }
                else:
                    all_avoid[item]["reasons"].append(finding["condition"])

        for intervention in finding.get("interventions", []):
            all_interventions.append({
                **intervention,
                "for": finding["condition"],
            })

        for test in finding.get("tests_recommended", []):
            all_tests.add(test)

    return {
        "status": "analyzed",
        "total_variants_checked": len(variants),
        "findings_count": len(findings),
        "findings": findings,
        "summary": {
            "high_impact": len([f for f in findings if f["impact"] == "high"]),
            "moderate_impact": len([f for f in findings if f["impact"] == "moderate"]),
            "protective": len([f for f in findings if f["risk_level"] == "protective"]),
        },
        "aggregated_recommendations": {
            "supplements": list(all_supplements.values()),
            "avoid": list(all_avoid.values()),
            "interventions": all_interventions,
            "tests": list(all_tests),
        },
    }


async def get_snp_categories() -> list[dict[str, Any]]:
    """Get all SNP categories with counts."""
    pool = get_pool()

    rows = await pool.fetch(
        """
        SELECT category, COUNT(*) as count
        FROM snp_knowledge
        GROUP BY category
        ORDER BY count DESC
        """
    )

    return [{"category": r["category"], "count": r["count"]} for r in rows]
