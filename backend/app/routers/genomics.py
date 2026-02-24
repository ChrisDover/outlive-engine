"""Genomic risk category routes and 23andMe upload."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, Query, Request, UploadFile, status
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.config import get_settings
from app.models.database import get_pool
from app.models.schemas import GenomeUploadResponse, GenomicRiskResponse, GenomicRiskUpdate
from app.security.auth import get_current_user
from app.security.encryption import decrypt_field, derive_key, encrypt_field
from app.services.genomics_service import (
    analyze_health_risks,
    create_genome_upload,
    get_genome_uploads,
    parse_23andme_file,
    store_variants,
    update_genome_upload,
)

router = APIRouter(prefix="/genomics", tags=["genomics"])
limiter = Limiter(key_func=get_remote_address)


def _enc_key() -> bytes:
    return derive_key(get_settings().FIELD_ENCRYPTION_KEY)


@router.get("/risks", response_model=list[GenomicRiskResponse])
async def get_risk_categories(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[GenomicRiskResponse]:
    """Return genomic risk categories for the current user."""
    pool = get_pool()
    key = _enc_key()

    rows = await pool.fetch(
        "SELECT id, user_id, risk_category, risk_level, summary, metadata_json, updated_at "
        "FROM genomic_profiles WHERE user_id = $1 LIMIT $2 OFFSET $3",
        current_user["id"],
        limit,
        offset,
    )

    results: list[GenomicRiskResponse] = []
    for r in rows:
        summary = decrypt_field(r["summary"], key) if r["summary"] else None
        metadata = (
            json.loads(decrypt_field(r["metadata_json"], key))
            if r["metadata_json"]
            else None
        )
        results.append(
            GenomicRiskResponse(
                id=r["id"],
                user_id=r["user_id"],
                risk_category=r["risk_category"],
                risk_level=r["risk_level"],
                summary=summary,
                metadata=metadata,
                updated_at=r["updated_at"],
            )
        )
    return results


@router.put("/risks", response_model=list[GenomicRiskResponse], status_code=status.HTTP_200_OK)
@limiter.limit("60/minute")
async def update_risk_categories(
    request: Request,
    body: GenomicRiskUpdate,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[GenomicRiskResponse]:
    """Upsert genomic risk categories."""
    pool = get_pool()
    key = _enc_key()
    user_id: UUID = current_user["id"]
    now = datetime.now(timezone.utc)

    results: list[GenomicRiskResponse] = []
    for risk in body.risks:
        enc_summary = encrypt_field(risk.summary, key) if risk.summary else None
        enc_metadata = (
            encrypt_field(json.dumps(risk.metadata), key) if risk.metadata else None
        )

        row = await pool.fetchrow(
            """
            INSERT INTO genomic_profiles (user_id, risk_category, risk_level, summary, metadata_json, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (user_id, risk_category)
            DO UPDATE SET risk_level = $3, summary = $4, metadata_json = $5, updated_at = $6
            RETURNING id, user_id, risk_category, risk_level, summary, metadata_json, updated_at
            """,
            user_id,
            risk.risk_category,
            risk.risk_level.value,
            enc_summary,
            enc_metadata,
            now,
        )

        results.append(
            GenomicRiskResponse(
                id=row["id"],
                user_id=row["user_id"],
                risk_category=row["risk_category"],
                risk_level=row["risk_level"],
                summary=risk.summary,
                metadata=risk.metadata,
                updated_at=row["updated_at"],
            )
        )

    return results


@router.post("/upload", response_model=GenomeUploadResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/hour")
async def upload_genome_file(
    request: Request,
    file: UploadFile = File(...),
    source: str = Form(default="23andme"),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> GenomeUploadResponse:
    """Upload a 23andMe (or compatible) raw genome data file.

    The file should be a text file in 23andMe format:
    - Tab-separated values
    - Columns: rsid, chromosome, position, genotype
    - Comments start with #

    After upload, health-related SNPs are automatically analyzed and
    genomic risk profiles are generated.
    """
    user_id: UUID = current_user["id"]
    key = _enc_key()

    # Create upload record
    upload_id = await create_genome_upload(user_id, source, file.filename)

    try:
        # Read and parse file
        content = await file.read()
        text_content = content.decode("utf-8")
        variants = parse_23andme_file(text_content)

        if not variants:
            await update_genome_upload(
                upload_id, status="failed", error_message="No valid variants found in file"
            )
            uploads = await get_genome_uploads(user_id)
            return GenomeUploadResponse(**uploads[0])

        # Store variants
        variant_count = await store_variants(user_id, variants, source)
        await update_genome_upload(upload_id, variant_count=variant_count)

        # Analyze health risks and update profiles
        risk_profiles = await analyze_health_risks(user_id)

        # Store risk profiles
        pool = get_pool()
        now = datetime.now(timezone.utc)

        for risk in risk_profiles:
            enc_summary = encrypt_field(risk["summary"], key) if risk["summary"] else None
            enc_metadata = encrypt_field(json.dumps(risk["metadata"]), key)

            await pool.execute(
                """
                INSERT INTO genomic_profiles (user_id, risk_category, risk_level, summary, metadata_json, updated_at)
                VALUES ($1, $2, $3, $4, $5, $6)
                ON CONFLICT (user_id, risk_category)
                DO UPDATE SET risk_level = $3, summary = $4, metadata_json = $5, updated_at = $6
                """,
                user_id,
                risk["risk_category"],
                risk["risk_level"],
                enc_summary,
                enc_metadata,
                now,
            )

        # Mark upload as completed
        await update_genome_upload(upload_id, status="completed")

    except Exception as e:
        await update_genome_upload(upload_id, status="failed", error_message=str(e))
        raise

    uploads = await get_genome_uploads(user_id)
    return GenomeUploadResponse(**uploads[0])


@router.get("/uploads", response_model=list[GenomeUploadResponse])
async def list_genome_uploads(
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[GenomeUploadResponse]:
    """List all genome uploads for the current user."""
    uploads = await get_genome_uploads(current_user["id"])
    return [GenomeUploadResponse(**u) for u in uploads]
