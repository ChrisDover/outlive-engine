"""Oura Ring Sync Service - Fetch and store data from Oura API.

Syncs sleep, readiness, activity, and heart rate data from Oura Ring.
"""

from __future__ import annotations

import json
import logging
from datetime import date, datetime, timedelta, timezone
from typing import Any
from uuid import UUID

import httpx

from app.config import get_settings
from app.models.database import get_pool
from app.security.encryption import derive_key, encrypt_field
from app.services.wearable_connection_service import (
    get_connection,
    update_last_sync,
    update_tokens,
    WearableProvider,
)

logger = logging.getLogger(__name__)

OURA_API_BASE = "https://api.ouraring.com/v2/usercollection"
OURA_TOKEN_URL = "https://api.ouraring.com/oauth/token"


async def refresh_oura_token(user_id: UUID, refresh_token: str) -> dict[str, Any] | None:
    """
    Refresh Oura OAuth tokens.

    Returns new tokens on success, None on failure.
    """
    settings = get_settings()

    async with httpx.AsyncClient() as client:
        try:
            resp = await client.post(
                OURA_TOKEN_URL,
                data={
                    "grant_type": "refresh_token",
                    "refresh_token": refresh_token,
                    "client_id": settings.OURA_CLIENT_ID or "",
                    "client_secret": settings.OURA_CLIENT_SECRET or "",
                },
            )

            if resp.status_code != 200:
                logger.error(f"Oura token refresh failed: {resp.status_code}")
                return None

            tokens = resp.json()

            # Calculate expiry
            expires_in = tokens.get("expires_in", 86400)
            expires_at = datetime.now(timezone.utc) + timedelta(seconds=expires_in)

            # Update stored tokens
            await update_tokens(
                user_id=user_id,
                provider=WearableProvider.OURA,
                access_token=tokens["access_token"],
                refresh_token=tokens.get("refresh_token"),
                expires_at=expires_at,
            )

            return {
                "access_token": tokens["access_token"],
                "refresh_token": tokens.get("refresh_token", refresh_token),
                "expires_at": expires_at,
            }

        except Exception as e:
            logger.exception(f"Oura token refresh error: {e}")
            return None


async def _oura_api_call(
    user_id: UUID,
    access_token: str,
    refresh_token: str,
    endpoint: str,
    params: dict[str, str],
) -> dict[str, Any] | None:
    """Make an authenticated call to Oura API with automatic token refresh."""
    url = f"{OURA_API_BASE}/{endpoint}"

    async with httpx.AsyncClient() as client:
        # First attempt
        resp = await client.get(
            url,
            params=params,
            headers={"Authorization": f"Bearer {access_token}"},
        )

        # Token expired - refresh and retry
        if resp.status_code == 401 and refresh_token:
            new_tokens = await refresh_oura_token(user_id, refresh_token)
            if not new_tokens:
                return None

            resp = await client.get(
                url,
                params=params,
                headers={"Authorization": f"Bearer {new_tokens['access_token']}"},
            )

        if resp.status_code != 200:
            logger.error(f"Oura API error {endpoint}: {resp.status_code}")
            return None

        return resp.json()


async def sync_oura_data(user_id: UUID, days: int = 7) -> dict[str, Any]:
    """
    Sync Oura data for the specified number of days.

    Fetches sleep, readiness, and activity data and stores in daily_wearable_data.

    Args:
        user_id: User's UUID
        days: Number of days to sync (default 7)

    Returns:
        Sync result summary
    """
    # Get connection details
    connection = await get_connection(user_id, WearableProvider.OURA)
    if not connection:
        return {"success": False, "error": "Not connected to Oura"}

    access_token = connection["access_token"]
    refresh_token = connection["refresh_token"]

    if not access_token:
        return {"success": False, "error": "No access token"}

    # Calculate date range
    end_date = date.today()
    start_date = end_date - timedelta(days=days - 1)

    params = {
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
    }

    # Fetch data from all endpoints
    results = {
        "sleep": await _oura_api_call(user_id, access_token, refresh_token, "daily_sleep", params),
        "readiness": await _oura_api_call(user_id, access_token, refresh_token, "daily_readiness", params),
        "activity": await _oura_api_call(user_id, access_token, refresh_token, "daily_activity", params),
    }

    # Process and store data
    pool = get_pool()
    settings = get_settings()
    key = derive_key(settings.FIELD_ENCRYPTION_KEY)
    now = datetime.now(timezone.utc)

    days_synced = 0
    errors = []

    # Combine data by date
    data_by_date: dict[str, dict[str, Any]] = {}

    # Process sleep data
    if results["sleep"] and "data" in results["sleep"]:
        for item in results["sleep"]["data"]:
            day = item.get("day")
            if day:
                if day not in data_by_date:
                    data_by_date[day] = {}
                data_by_date[day]["sleep_score"] = item.get("score")
                data_by_date[day]["total_sleep_duration"] = item.get("contributors", {}).get("total_sleep")
                data_by_date[day]["rem_sleep_duration"] = item.get("contributors", {}).get("rem_sleep")
                data_by_date[day]["deep_sleep_duration"] = item.get("contributors", {}).get("deep_sleep")
                data_by_date[day]["sleep_efficiency"] = item.get("contributors", {}).get("efficiency")

    # Process readiness data
    if results["readiness"] and "data" in results["readiness"]:
        for item in results["readiness"]["data"]:
            day = item.get("day")
            if day:
                if day not in data_by_date:
                    data_by_date[day] = {}
                data_by_date[day]["readiness_score"] = item.get("score")
                data_by_date[day]["recovery_score"] = item.get("score")  # Alias for compatibility
                data_by_date[day]["hrv"] = item.get("contributors", {}).get("hrv_balance")
                data_by_date[day]["resting_hr"] = item.get("contributors", {}).get("resting_heart_rate")
                data_by_date[day]["recovery_index"] = item.get("contributors", {}).get("recovery_index")
                data_by_date[day]["body_temperature"] = item.get("contributors", {}).get("body_temperature")

    # Process activity data
    if results["activity"] and "data" in results["activity"]:
        for item in results["activity"]["data"]:
            day = item.get("day")
            if day:
                if day not in data_by_date:
                    data_by_date[day] = {}
                data_by_date[day]["activity_score"] = item.get("score")
                data_by_date[day]["steps"] = item.get("steps")
                data_by_date[day]["active_calories"] = item.get("active_calories")
                data_by_date[day]["total_calories"] = item.get("total_calories")
                data_by_date[day]["low_activity_time"] = item.get("low_activity_time")
                data_by_date[day]["medium_activity_time"] = item.get("medium_activity_time")
                data_by_date[day]["high_activity_time"] = item.get("high_activity_time")

    # Store in database
    async with pool.acquire() as conn:
        async with conn.transaction():
            for day_str, metrics in data_by_date.items():
                try:
                    day_date = date.fromisoformat(day_str)
                    enc_metrics = encrypt_field(json.dumps(metrics), key)

                    await conn.execute(
                        """
                        INSERT INTO daily_wearable_data (user_id, date, source, metrics_json, created_at, updated_at)
                        VALUES ($1, $2, $3, $4, $5, $5)
                        ON CONFLICT (user_id, date, source)
                        DO UPDATE SET metrics_json = $4, updated_at = $5
                        """,
                        user_id,
                        day_date,
                        WearableProvider.OURA,
                        enc_metrics,
                        now,
                    )
                    days_synced += 1
                except Exception as e:
                    errors.append(f"Error storing {day_str}: {str(e)}")

    # Update last sync timestamp
    await update_last_sync(user_id, WearableProvider.OURA)

    return {
        "success": True,
        "days_synced": days_synced,
        "date_range": {"start": start_date.isoformat(), "end": end_date.isoformat()},
        "errors": errors if errors else None,
    }


async def get_oura_today(user_id: UUID) -> dict[str, Any] | None:
    """Get today's Oura data, fetching fresh if needed."""
    pool = get_pool()
    settings = get_settings()
    key = derive_key(settings.FIELD_ENCRYPTION_KEY)
    today = date.today()

    # Check if we have today's data
    row = await pool.fetchrow(
        """
        SELECT metrics_json, updated_at
        FROM daily_wearable_data
        WHERE user_id = $1 AND date = $2 AND source = $3
        """,
        user_id,
        today,
        WearableProvider.OURA,
    )

    # If data is less than 1 hour old, return it
    if row and row["updated_at"]:
        age = datetime.now(timezone.utc) - row["updated_at"]
        if age.total_seconds() < 3600:
            from app.security.encryption import decrypt_field
            return json.loads(decrypt_field(row["metrics_json"], key))

    # Otherwise sync fresh data
    result = await sync_oura_data(user_id, days=1)
    if result["success"] and result["days_synced"] > 0:
        row = await pool.fetchrow(
            """
            SELECT metrics_json
            FROM daily_wearable_data
            WHERE user_id = $1 AND date = $2 AND source = $3
            """,
            user_id,
            today,
            WearableProvider.OURA,
        )
        if row:
            from app.security.encryption import decrypt_field
            return json.loads(decrypt_field(row["metrics_json"], key))

    return None
