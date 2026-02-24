"""Wearable data routes: batch upsert and date-range queries."""

from __future__ import annotations

import json
from datetime import date, datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, Query, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.config import get_settings
from app.models.database import get_pool
from app.models.schemas import (
    WearableDataBatchCreate,
    WearableDataResponse,
)
from app.security.auth import get_current_user
from app.security.encryption import decrypt_field, derive_key, encrypt_field

router = APIRouter(prefix="/wearables", tags=["wearables"])
limiter = Limiter(key_func=get_remote_address)


def _enc_key() -> bytes:
    return derive_key(get_settings().FIELD_ENCRYPTION_KEY)


@router.post("/batch", response_model=list[WearableDataResponse], status_code=status.HTTP_200_OK)
@limiter.limit("60/minute")
async def batch_upsert(
    request: Request,
    body: WearableDataBatchCreate,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[WearableDataResponse]:
    """Batch upsert daily wearable data entries."""
    pool = get_pool()
    key = _enc_key()
    user_id = current_user["id"]
    now = datetime.now(timezone.utc)

    results: list[WearableDataResponse] = []

    async with pool.acquire() as conn:
        async with conn.transaction():
            for entry in body.entries:
                enc_metrics = encrypt_field(json.dumps(entry.metrics), key)

                row = await conn.fetchrow(
                    """
                    INSERT INTO daily_wearable_data (user_id, date, source, metrics_json, created_at, updated_at)
                    VALUES ($1, $2, $3, $4, $5, $5)
                    ON CONFLICT (user_id, date, source)
                    DO UPDATE SET metrics_json = $4, updated_at = $5
                    RETURNING id, user_id, date, source, metrics_json, created_at, updated_at
                    """,
                    user_id,
                    entry.date,
                    entry.source,
                    enc_metrics,
                    now,
                )

                results.append(
                    WearableDataResponse(
                        id=row["id"],
                        user_id=row["user_id"],
                        date=row["date"],
                        source=row["source"],
                        metrics=entry.metrics,
                        created_at=row["created_at"],
                        updated_at=row["updated_at"],
                    )
                )

    return results


@router.get("", response_model=list[WearableDataResponse])
async def list_wearable_data(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    source: str | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[WearableDataResponse]:
    """List wearable data with optional date range and source filters."""
    pool = get_pool()
    key = _enc_key()

    query = (
        "SELECT id, user_id, date, source, metrics_json, created_at, updated_at "
        "FROM daily_wearable_data WHERE user_id = $1"
    )
    params: list[Any] = [current_user["id"]]
    idx = 2

    if start_date is not None:
        query += f" AND date >= ${idx}"
        params.append(start_date)
        idx += 1

    if end_date is not None:
        query += f" AND date <= ${idx}"
        params.append(end_date)
        idx += 1

    if source is not None:
        query += f" AND source = ${idx}"
        params.append(source.strip().lower())
        idx += 1

    query += f" ORDER BY date DESC LIMIT ${idx} OFFSET ${idx+1}"
    params.append(limit)
    params.append(offset)

    rows = await pool.fetch(query, *params)

    results: list[WearableDataResponse] = []
    for r in rows:
        metrics = json.loads(decrypt_field(r["metrics_json"], key))
        results.append(
            WearableDataResponse(
                id=r["id"],
                user_id=r["user_id"],
                date=r["date"],
                source=r["source"],
                metrics=metrics,
                created_at=r["created_at"],
                updated_at=r["updated_at"],
            )
        )
    return results
