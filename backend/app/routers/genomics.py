"""Genomic risk category routes -- never exposes raw SNP data."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.config import get_settings
from app.models.database import get_pool
from app.models.schemas import GenomicRiskResponse, GenomicRiskUpdate
from app.security.auth import get_current_user
from app.security.encryption import decrypt_field, derive_key, encrypt_field

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
