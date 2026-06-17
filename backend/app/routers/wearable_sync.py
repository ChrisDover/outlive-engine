"""Wearable Sync Router - Manual sync triggers and status endpoints.

Provides endpoints for syncing wearable data and checking sync status.
"""

from __future__ import annotations

import logging
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.security.auth import get_current_user
from app.services.oura_service import sync_oura_data, get_oura_today
from app.services.wearable_connection_service import (
    get_sync_status,
    get_all_connections,
    delete_connection,
    WearableProvider,
)
from app.services.withings_service import (
    sync_withings_data,
    get_withings_latest,
    get_body_composition_trend,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/wearables", tags=["wearables"])


# Request/Response Models


class SyncRequest(BaseModel):
    """Sync request with optional day range."""
    days: int = 7


class SyncResponse(BaseModel):
    """Sync operation response."""
    success: bool
    days_synced: int | None = None
    date_range: dict[str, str] | None = None
    error: str | None = None
    errors: list[str] | None = None


class ConnectionStatus(BaseModel):
    """Individual connection status."""
    provider: str
    connected: bool
    last_sync: str | None = None
    token_expired: bool = False


class SyncStatusResponse(BaseModel):
    """All connections sync status."""
    connections: dict[str, ConnectionStatus]


class WearableDataResponse(BaseModel):
    """Wearable data response."""
    success: bool
    data: dict[str, Any] | None = None
    error: str | None = None


class TrendResponse(BaseModel):
    """Body composition trend response."""
    success: bool
    data: list[dict[str, Any]] | None = None
    error: str | None = None


# Sync Endpoints


@router.post("/sync/oura", response_model=SyncResponse)
async def sync_oura(
    request: SyncRequest = SyncRequest(),
    current_user: dict = Depends(get_current_user),
) -> SyncResponse:
    """
    Manually trigger Oura data sync.

    Fetches sleep, readiness, and activity data for the specified number of days.
    """
    user_id = UUID(current_user["sub"])

    try:
        result = await sync_oura_data(user_id, days=request.days)
        return SyncResponse(
            success=result["success"],
            days_synced=result.get("days_synced"),
            date_range=result.get("date_range"),
            error=result.get("error"),
            errors=result.get("errors"),
        )
    except Exception as e:
        logger.exception(f"Oura sync error for user {user_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Sync failed: {str(e)}",
        )


@router.post("/sync/withings", response_model=SyncResponse)
async def sync_withings(
    request: SyncRequest = SyncRequest(days=30),
    current_user: dict = Depends(get_current_user),
) -> SyncResponse:
    """
    Manually trigger Withings data sync.

    Fetches body composition, weight, and health metrics.
    """
    user_id = UUID(current_user["sub"])

    try:
        result = await sync_withings_data(user_id, days=request.days)
        return SyncResponse(
            success=result["success"],
            days_synced=result.get("days_synced"),
            date_range=result.get("date_range"),
            error=result.get("error"),
            errors=result.get("errors"),
        )
    except Exception as e:
        logger.exception(f"Withings sync error for user {user_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Sync failed: {str(e)}",
        )


@router.post("/sync/all", response_model=dict[str, SyncResponse])
async def sync_all_wearables(
    request: SyncRequest = SyncRequest(),
    current_user: dict = Depends(get_current_user),
) -> dict[str, SyncResponse]:
    """
    Sync all connected wearables.

    Returns sync results for each connected provider.
    """
    user_id = UUID(current_user["sub"])
    results = {}

    # Get all connections
    connections = await get_all_connections(user_id)
    connected_providers = {conn["provider"] for conn in connections}

    # Sync each connected provider
    if WearableProvider.OURA in connected_providers:
        try:
            oura_result = await sync_oura_data(user_id, days=request.days)
            results["oura"] = SyncResponse(
                success=oura_result["success"],
                days_synced=oura_result.get("days_synced"),
                date_range=oura_result.get("date_range"),
                error=oura_result.get("error"),
            )
        except Exception as e:
            results["oura"] = SyncResponse(success=False, error=str(e))

    if WearableProvider.WITHINGS in connected_providers:
        try:
            withings_result = await sync_withings_data(user_id, days=request.days)
            results["withings"] = SyncResponse(
                success=withings_result["success"],
                days_synced=withings_result.get("days_synced"),
                date_range=withings_result.get("date_range"),
                error=withings_result.get("error"),
            )
        except Exception as e:
            results["withings"] = SyncResponse(success=False, error=str(e))

    return results


# Status Endpoints


@router.get("/sync/status", response_model=SyncStatusResponse)
async def get_wearable_sync_status(
    current_user: dict = Depends(get_current_user),
) -> SyncStatusResponse:
    """
    Get sync status for all wearable connections.

    Returns connection status, last sync time, and token validity for each provider.
    """
    user_id = UUID(current_user["sub"])
    status_data = await get_sync_status(user_id)

    connections = {}
    for provider, info in status_data.items():
        connections[provider] = ConnectionStatus(
            provider=provider,
            connected=info["connected"],
            last_sync=info["last_sync"],
            token_expired=info["token_expired"],
        )

    return SyncStatusResponse(connections=connections)


@router.get("/connections")
async def list_connections(
    current_user: dict = Depends(get_current_user),
) -> list[dict[str, Any]]:
    """
    List all wearable connections for the current user.

    Returns connection details without sensitive token data.
    """
    user_id = UUID(current_user["sub"])
    return await get_all_connections(user_id)


@router.delete("/connections/{provider}")
async def disconnect_wearable(
    provider: str,
    current_user: dict = Depends(get_current_user),
) -> dict[str, bool]:
    """
    Disconnect a wearable provider.

    Removes OAuth tokens and connection record.
    """
    user_id = UUID(current_user["sub"])

    # Validate provider
    valid_providers = [
        WearableProvider.OURA,
        WearableProvider.WITHINGS,
        WearableProvider.WHOOP,
    ]
    if provider not in valid_providers:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid provider. Must be one of: {valid_providers}",
        )

    success = await delete_connection(user_id, provider)
    return {"success": success}


# Data Endpoints


@router.get("/data/oura/today", response_model=WearableDataResponse)
async def get_oura_today_data(
    current_user: dict = Depends(get_current_user),
) -> WearableDataResponse:
    """
    Get today's Oura data.

    Returns cached data if fresh, otherwise fetches from API.
    """
    user_id = UUID(current_user["sub"])

    try:
        data = await get_oura_today(user_id)
        if data:
            return WearableDataResponse(success=True, data=data)
        return WearableDataResponse(success=False, error="No data available")
    except Exception as e:
        logger.exception(f"Error getting Oura data for user {user_id}: {e}")
        return WearableDataResponse(success=False, error=str(e))


@router.get("/data/withings/latest", response_model=WearableDataResponse)
async def get_withings_latest_data(
    current_user: dict = Depends(get_current_user),
) -> WearableDataResponse:
    """
    Get latest Withings data.

    Returns most recent body composition and health metrics.
    """
    user_id = UUID(current_user["sub"])

    try:
        data = await get_withings_latest(user_id)
        if data:
            return WearableDataResponse(success=True, data=data)
        return WearableDataResponse(success=False, error="No data available")
    except Exception as e:
        logger.exception(f"Error getting Withings data for user {user_id}: {e}")
        return WearableDataResponse(success=False, error=str(e))


@router.get("/data/withings/trend", response_model=TrendResponse)
async def get_withings_body_composition_trend(
    days: int = 30,
    current_user: dict = Depends(get_current_user),
) -> TrendResponse:
    """
    Get body composition trend over time.

    Returns weight, body fat, and muscle mass trends.
    """
    user_id = UUID(current_user["sub"])

    try:
        data = await get_body_composition_trend(user_id, days=days)
        return TrendResponse(success=True, data=data)
    except Exception as e:
        logger.exception(f"Error getting Withings trend for user {user_id}: {e}")
        return TrendResponse(success=False, error=str(e))


# Combined Data Endpoint


@router.get("/data/combined")
async def get_combined_wearable_data(
    current_user: dict = Depends(get_current_user),
) -> dict[str, Any]:
    """
    Get combined wearable data from all connected sources.

    Merges Oura (sleep, recovery) and Withings (body composition) data.
    """
    user_id = UUID(current_user["sub"])
    combined = {}

    # Get Oura data
    try:
        oura_data = await get_oura_today(user_id)
        if oura_data:
            combined["oura"] = oura_data
            combined["sleep_score"] = oura_data.get("sleep_score")
            combined["readiness_score"] = oura_data.get("readiness_score")
            combined["recovery_score"] = oura_data.get("recovery_score")
            combined["hrv"] = oura_data.get("hrv")
            combined["resting_hr"] = oura_data.get("resting_hr")
    except Exception as e:
        logger.warning(f"Could not get Oura data: {e}")

    # Get Withings data
    try:
        withings_data = await get_withings_latest(user_id)
        if withings_data:
            combined["withings"] = withings_data
            combined["weight_kg"] = withings_data.get("weight_kg")
            combined["body_fat_percent"] = withings_data.get("body_fat_percent")
            combined["muscle_mass_kg"] = withings_data.get("muscle_mass_kg")
    except Exception as e:
        logger.warning(f"Could not get Withings data: {e}")

    return {
        "success": True,
        "data": combined,
        "sources": list(combined.keys()),
    }
