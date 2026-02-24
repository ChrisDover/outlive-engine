"""Body composition CRUD routes."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.config import get_settings
from app.models.database import get_pool
from app.models.schemas import BodyCompositionCreate, BodyCompositionResponse
from app.security.auth import get_current_user
from app.security.encryption import decrypt_field, derive_key, encrypt_field

router = APIRouter(prefix="/body-composition", tags=["body-composition"])


def _enc_key() -> bytes:
    return derive_key(get_settings().FIELD_ENCRYPTION_KEY)


def _row_to_response(row: Any, key: bytes) -> BodyCompositionResponse:
    metrics = json.loads(decrypt_field(row["metrics_json"], key))
    return BodyCompositionResponse(
        id=row["id"],
        user_id=row["user_id"],
        date=row["date"],
        metrics=metrics,
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


@router.get("", response_model=list[BodyCompositionResponse])
async def list_entries(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[BodyCompositionResponse]:
    """List body composition entries for the current user, newest first."""
    pool = get_pool()
    key = _enc_key()

    rows = await pool.fetch(
        "SELECT id, user_id, date, metrics_json, created_at, updated_at "
        "FROM body_composition WHERE user_id = $1 "
        "ORDER BY date DESC LIMIT $2 OFFSET $3",
        current_user["id"],
        limit,
        offset,
    )
    return [_row_to_response(r, key) for r in rows]


@router.post("", response_model=BodyCompositionResponse, status_code=status.HTTP_201_CREATED)
async def upsert_entry(
    body: BodyCompositionCreate,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> BodyCompositionResponse:
    """Create or update a body composition entry (upsert by date)."""
    pool = get_pool()
    key = _enc_key()
    now = datetime.now(timezone.utc)

    enc_metrics = encrypt_field(json.dumps(body.metrics), key)

    row = await pool.fetchrow(
        """
        INSERT INTO body_composition (user_id, date, metrics_json, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $4)
        ON CONFLICT (user_id, date) DO UPDATE
            SET metrics_json = EXCLUDED.metrics_json,
                updated_at   = EXCLUDED.updated_at
        RETURNING id, user_id, date, metrics_json, created_at, updated_at
        """,
        current_user["id"],
        body.date,
        enc_metrics,
        now,
    )
    return _row_to_response(row, key)


@router.get("/{entry_id}", response_model=BodyCompositionResponse)
async def get_entry(
    entry_id: UUID,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> BodyCompositionResponse:
    """Get a single body composition entry by ID."""
    pool = get_pool()
    key = _enc_key()

    row = await pool.fetchrow(
        "SELECT id, user_id, date, metrics_json, created_at, updated_at "
        "FROM body_composition WHERE id = $1 AND user_id = $2",
        entry_id,
        current_user["id"],
    )
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Entry not found")

    return _row_to_response(row, key)


@router.delete("/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_entry(
    entry_id: UUID,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> None:
    """Hard-delete a body composition entry."""
    pool = get_pool()
    result = await pool.execute(
        "DELETE FROM body_composition WHERE id = $1 AND user_id = $2",
        entry_id,
        current_user["id"],
    )
    if result == "DELETE 0":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Entry not found")
