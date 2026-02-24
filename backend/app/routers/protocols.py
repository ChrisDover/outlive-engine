"""Protocol routes: daily protocol view and source management."""

from __future__ import annotations

import json
from datetime import date, datetime, timezone
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.config import get_settings
from app.models.database import get_pool
from app.models.schemas import DailyProtocolResponse, ProtocolSourceResponse, ProtocolSourceUpdate
from app.security.auth import get_current_user
from app.security.encryption import decrypt_field, derive_key, encrypt_field

router = APIRouter(prefix="/protocols", tags=["protocols"])


def _enc_key() -> bytes:
    return derive_key(get_settings().FIELD_ENCRYPTION_KEY)


@router.get("/daily", response_model=DailyProtocolResponse | None)
async def get_daily_protocol(
    target_date: date = Query(default_factory=date.today),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> DailyProtocolResponse | None:
    """Get the daily protocol for a given date (defaults to today)."""
    pool = get_pool()
    key = _enc_key()

    row = await pool.fetchrow(
        "SELECT id, user_id, date, protocol_json, created_at, updated_at "
        "FROM daily_protocols WHERE user_id = $1 AND date = $2",
        current_user["id"],
        target_date,
    )

    if row is None:
        return None

    protocol = json.loads(decrypt_field(row["protocol_json"], key))
    return DailyProtocolResponse(
        id=row["id"],
        user_id=row["user_id"],
        date=row["date"],
        protocol=protocol,
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


@router.get("/library", response_model=list[ProtocolSourceResponse])
async def list_protocol_sources(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[ProtocolSourceResponse]:
    """List protocol sources for the current user."""
    pool = get_pool()
    key = _enc_key()

    rows = await pool.fetch(
        "SELECT id, user_id, source_name, enabled, priority, config_json, updated_at "
        "FROM protocol_sources WHERE user_id = $1 ORDER BY priority DESC LIMIT $2 OFFSET $3",
        current_user["id"],
        limit,
        offset,
    )

    results: list[ProtocolSourceResponse] = []
    for r in rows:
        config = (
            json.loads(decrypt_field(r["config_json"], key))
            if r["config_json"]
            else None
        )
        results.append(
            ProtocolSourceResponse(
                id=r["id"],
                user_id=r["user_id"],
                source_name=r["source_name"],
                enabled=r["enabled"],
                priority=r["priority"],
                config=config,
                updated_at=r["updated_at"],
            )
        )
    return results


@router.put("/sources/{source_id}", response_model=ProtocolSourceResponse)
async def update_protocol_source(
    source_id: UUID,
    body: ProtocolSourceUpdate,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> ProtocolSourceResponse:
    """Update a protocol source's settings."""
    pool = get_pool()
    key = _enc_key()
    now = datetime.now(timezone.utc)

    updates: dict[str, Any] = {}
    if body.enabled is not None:
        updates["enabled"] = body.enabled
    if body.priority is not None:
        updates["priority"] = body.priority
    if body.config is not None:
        updates["config_json"] = encrypt_field(json.dumps(body.config), key)

    if not updates:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No fields to update",
        )

    set_clauses = ", ".join(f"{k} = ${i+3}" for i, k in enumerate(updates))
    values = list(updates.values())

    row = await pool.fetchrow(
        f"UPDATE protocol_sources SET {set_clauses}, updated_at = ${len(values)+3} "
        f"WHERE id = $1 AND user_id = $2 "
        f"RETURNING id, user_id, source_name, enabled, priority, config_json, updated_at",
        source_id,
        current_user["id"],
        *values,
        now,
    )

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Protocol source not found")

    config = (
        json.loads(decrypt_field(row["config_json"], key))
        if row["config_json"]
        else None
    )
    return ProtocolSourceResponse(
        id=row["id"],
        user_id=row["user_id"],
        source_name=row["source_name"],
        enabled=row["enabled"],
        priority=row["priority"],
        config=config,
        updated_at=row["updated_at"],
    )
