"""Bloodwork panel CRUD routes."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.config import get_settings
from app.models.database import get_pool
from app.models.schemas import BloodworkPanelCreate, BloodworkPanelResponse
from app.security.auth import get_current_user
from app.security.encryption import decrypt_field, derive_key, encrypt_field

router = APIRouter(prefix="/bloodwork", tags=["bloodwork"])
limiter = Limiter(key_func=get_remote_address)


def _enc_key() -> bytes:
    return derive_key(get_settings().FIELD_ENCRYPTION_KEY)


def _row_to_response(row: Any, key: bytes) -> BloodworkPanelResponse:
    markers = json.loads(decrypt_field(row["markers_json"], key))
    notes = decrypt_field(row["notes"], key) if row["notes"] else None
    return BloodworkPanelResponse(
        id=row["id"],
        user_id=row["user_id"],
        panel_date=row["panel_date"],
        lab_name=row["lab_name"],
        markers=markers,
        notes=notes,
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


@router.get("", response_model=list[BloodworkPanelResponse])
async def list_panels(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[BloodworkPanelResponse]:
    """List bloodwork panels for the current user, newest first."""
    pool = get_pool()
    key = _enc_key()

    rows = await pool.fetch(
        "SELECT id, user_id, panel_date, lab_name, markers_json, notes, created_at, updated_at "
        "FROM bloodwork_panels WHERE user_id = $1 AND deleted_at IS NULL "
        "ORDER BY panel_date DESC LIMIT $2 OFFSET $3",
        current_user["id"],
        limit,
        offset,
    )
    return [_row_to_response(r, key) for r in rows]


@router.post("", response_model=BloodworkPanelResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("60/minute")
async def create_panel(
    request: Request,
    body: BloodworkPanelCreate,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> BloodworkPanelResponse:
    """Create a new bloodwork panel."""
    pool = get_pool()
    key = _enc_key()
    now = datetime.now(timezone.utc)

    enc_markers = encrypt_field(
        json.dumps([m.model_dump() for m in body.markers]), key
    )
    enc_notes = encrypt_field(body.notes, key) if body.notes else None

    row = await pool.fetchrow(
        """
        INSERT INTO bloodwork_panels (user_id, panel_date, lab_name, markers_json, notes, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $6)
        RETURNING id, user_id, panel_date, lab_name, markers_json, notes, created_at, updated_at
        """,
        current_user["id"],
        body.panel_date,
        body.lab_name,
        enc_markers,
        enc_notes,
        now,
    )
    return _row_to_response(row, key)


@router.get("/{panel_id}", response_model=BloodworkPanelResponse)
async def get_panel(
    panel_id: UUID,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> BloodworkPanelResponse:
    """Get a single bloodwork panel by ID."""
    pool = get_pool()
    key = _enc_key()

    row = await pool.fetchrow(
        "SELECT id, user_id, panel_date, lab_name, markers_json, notes, created_at, updated_at "
        "FROM bloodwork_panels WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL",
        panel_id,
        current_user["id"],
    )
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Panel not found")

    return _row_to_response(row, key)


@router.delete("/{panel_id}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("60/minute")
async def delete_panel(
    request: Request,
    panel_id: UUID,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> None:
    """Soft-delete a bloodwork panel."""
    pool = get_pool()
    result = await pool.execute(
        "UPDATE bloodwork_panels SET deleted_at = $1 WHERE id = $2 AND user_id = $3 AND deleted_at IS NULL",
        datetime.now(timezone.utc),
        panel_id,
        current_user["id"],
    )
    if result == "UPDATE 0":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Panel not found")
