"""Bidirectional sync routes using vector clocks."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, status

from app.models.schemas import SyncRequest, SyncResponse
from app.security.auth import get_current_user
from app.services.sync_service import pull_changes, push_changes

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("/push", response_model=SyncResponse)
async def sync_push(
    body: SyncRequest,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> SyncResponse:
    """Client pushes local changes to the server."""
    return await push_changes(
        user_id=current_user["id"],
        request=body,
    )


@router.post("/pull", response_model=SyncResponse)
async def sync_pull(
    body: SyncRequest,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> SyncResponse:
    """Client pulls server changes since last sync."""
    return await pull_changes(
        user_id=current_user["id"],
        request=body,
    )
