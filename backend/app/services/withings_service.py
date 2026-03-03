"""Withings Sync Service - Fetch and store data from Withings API.

Syncs body composition, weight, and activity data from Withings devices.
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

WITHINGS_API_BASE = "https://wbsapi.withings.net"
WITHINGS_TOKEN_URL = "https://wbsapi.withings.net/v2/oauth2"


async def refresh_withings_token(user_id: UUID, refresh_token: str) -> dict[str, Any] | None:
    """
    Refresh Withings OAuth tokens.

    Returns new tokens on success, None on failure.
    """
    settings = get_settings()

    async with httpx.AsyncClient() as client:
        try:
            resp = await client.post(
                WITHINGS_TOKEN_URL,
                data={
                    "action": "requesttoken",
                    "grant_type": "refresh_token",
                    "refresh_token": refresh_token,
                    "client_id": settings.WITHINGS_CLIENT_ID or "",
                    "client_secret": settings.WITHINGS_CLIENT_SECRET or "",
                },
            )

            if resp.status_code != 200:
                logger.error(f"Withings token refresh failed: {resp.status_code}")
                return None

            data = resp.json()
            if data.get("status") != 0:
                logger.error(f"Withings token refresh error: {data.get('error')}")
                return None

            body = data.get("body", {})
            expires_in = body.get("expires_in", 10800)
            expires_at = datetime.now(timezone.utc) + timedelta(seconds=expires_in)

            # Update stored tokens
            await update_tokens(
                user_id=user_id,
                provider=WearableProvider.WITHINGS,
                access_token=body["access_token"],
                refresh_token=body.get("refresh_token"),
                expires_at=expires_at,
            )

            return {
                "access_token": body["access_token"],
                "refresh_token": body.get("refresh_token", refresh_token),
                "expires_at": expires_at,
            }

        except Exception as e:
            logger.exception(f"Withings token refresh error: {e}")
            return None


async def _withings_api_call(
    user_id: UUID,
    access_token: str,
    refresh_token: str,
    endpoint: str,
    params: dict[str, Any],
) -> dict[str, Any] | None:
    """Make an authenticated call to Withings API with automatic token refresh."""
    url = f"{WITHINGS_API_BASE}/{endpoint}"

    async with httpx.AsyncClient() as client:
        # First attempt
        resp = await client.post(
            url,
            data={**params, "action": params.get("action", "getmeas")},
            headers={"Authorization": f"Bearer {access_token}"},
        )

        data = resp.json()

        # Token expired - refresh and retry
        if data.get("status") == 401 and refresh_token:
            new_tokens = await refresh_withings_token(user_id, refresh_token)
            if not new_tokens:
                return None

            resp = await client.post(
                url,
                data={**params, "action": params.get("action", "getmeas")},
                headers={"Authorization": f"Bearer {new_tokens['access_token']}"},
            )
            data = resp.json()

        if data.get("status") != 0:
            logger.error(f"Withings API error {endpoint}: status={data.get('status')}")
            return None

        return data.get("body", {})


async def sync_withings_data(user_id: UUID, days: int = 30) -> dict[str, Any]:
    """
    Sync Withings data for the specified number of days.

    Fetches body composition, weight, and activity data.

    Args:
        user_id: User's UUID
        days: Number of days to sync (default 30)

    Returns:
        Sync result summary
    """
    # Get connection details
    connection = await get_connection(user_id, WearableProvider.WITHINGS)
    if not connection:
        return {"success": False, "error": "Not connected to Withings"}

    access_token = connection["access_token"]
    refresh_token = connection["refresh_token"]

    if not access_token:
        return {"success": False, "error": "No access token"}

    # Calculate date range
    end_date = datetime.now(timezone.utc)
    start_date = end_date - timedelta(days=days)

    # Withings uses Unix timestamps
    startdate = int(start_date.timestamp())
    enddate = int(end_date.timestamp())

    # Fetch measurements
    meas_params = {
        "action": "getmeas",
        "startdate": startdate,
        "enddate": enddate,
        "category": 1,  # Real measurements only
    }

    measurements = await _withings_api_call(
        user_id, access_token, refresh_token, "measure", meas_params
    )

    # Process and store data
    pool = get_pool()
    settings = get_settings()
    key = derive_key(settings.FIELD_ENCRYPTION_KEY)
    now = datetime.now(timezone.utc)

    days_synced = 0
    errors = []

    # Group measurements by date
    data_by_date: dict[str, dict[str, Any]] = {}

    if measurements and "measuregrps" in measurements:
        for grp in measurements["measuregrps"]:
            # Convert Unix timestamp to date
            grp_date = datetime.fromtimestamp(grp["date"], tz=timezone.utc).date()
            day_str = grp_date.isoformat()

            if day_str not in data_by_date:
                data_by_date[day_str] = {}

            for measure in grp.get("measures", []):
                # Withings measure types
                mtype = measure["type"]
                # Value needs to be multiplied by 10^unit
                value = measure["value"] * (10 ** measure["unit"])

                if mtype == 1:  # Weight (kg)
                    data_by_date[day_str]["weight_kg"] = round(value, 2)
                elif mtype == 6:  # Fat Ratio (%)
                    data_by_date[day_str]["body_fat_percent"] = round(value, 1)
                elif mtype == 8:  # Fat Mass (kg)
                    data_by_date[day_str]["fat_mass_kg"] = round(value, 2)
                elif mtype == 5:  # Fat Free Mass (kg)
                    data_by_date[day_str]["lean_mass_kg"] = round(value, 2)
                elif mtype == 76:  # Muscle Mass (kg)
                    data_by_date[day_str]["muscle_mass_kg"] = round(value, 2)
                elif mtype == 77:  # Hydration (kg)
                    data_by_date[day_str]["hydration_kg"] = round(value, 2)
                elif mtype == 88:  # Bone Mass (kg)
                    data_by_date[day_str]["bone_mass_kg"] = round(value, 2)
                elif mtype == 91:  # Pulse Wave Velocity
                    data_by_date[day_str]["pulse_wave_velocity"] = round(value, 2)
                elif mtype == 11:  # Heart Rate (bpm)
                    data_by_date[day_str]["heart_rate"] = int(value)
                elif mtype == 9:  # Diastolic Blood Pressure
                    data_by_date[day_str]["bp_diastolic"] = int(value)
                elif mtype == 10:  # Systolic Blood Pressure
                    data_by_date[day_str]["bp_systolic"] = int(value)
                elif mtype == 54:  # SpO2 (%)
                    data_by_date[day_str]["spo2"] = round(value, 1)
                elif mtype == 71:  # Body Temperature (C)
                    data_by_date[day_str]["body_temp_c"] = round(value, 1)
                elif mtype == 73:  # Skin Temperature (C)
                    data_by_date[day_str]["skin_temp_c"] = round(value, 1)
                elif mtype == 155:  # Visceral Fat Index
                    data_by_date[day_str]["visceral_fat_index"] = round(value, 1)

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
                        WearableProvider.WITHINGS,
                        enc_metrics,
                        now,
                    )
                    days_synced += 1
                except Exception as e:
                    errors.append(f"Error storing {day_str}: {str(e)}")

    # Update last sync timestamp
    await update_last_sync(user_id, WearableProvider.WITHINGS)

    return {
        "success": True,
        "days_synced": days_synced,
        "date_range": {
            "start": start_date.date().isoformat(),
            "end": end_date.date().isoformat(),
        },
        "errors": errors if errors else None,
    }


async def get_withings_latest(user_id: UUID) -> dict[str, Any] | None:
    """Get most recent Withings data, fetching fresh if needed."""
    pool = get_pool()
    settings = get_settings()
    key = derive_key(settings.FIELD_ENCRYPTION_KEY)

    # Check if we have recent data (within 24 hours)
    row = await pool.fetchrow(
        """
        SELECT metrics_json, updated_at
        FROM daily_wearable_data
        WHERE user_id = $1 AND source = $2
        ORDER BY date DESC
        LIMIT 1
        """,
        user_id,
        WearableProvider.WITHINGS,
    )

    # If data is less than 24 hours old, return it
    if row and row["updated_at"]:
        age = datetime.now(timezone.utc) - row["updated_at"]
        if age.total_seconds() < 86400:
            from app.security.encryption import decrypt_field
            return json.loads(decrypt_field(row["metrics_json"], key))

    # Otherwise sync fresh data
    result = await sync_withings_data(user_id, days=7)
    if result["success"] and result["days_synced"] > 0:
        row = await pool.fetchrow(
            """
            SELECT metrics_json
            FROM daily_wearable_data
            WHERE user_id = $1 AND source = $2
            ORDER BY date DESC
            LIMIT 1
            """,
            user_id,
            WearableProvider.WITHINGS,
        )
        if row:
            from app.security.encryption import decrypt_field
            return json.loads(decrypt_field(row["metrics_json"], key))

    return None


async def get_body_composition_trend(
    user_id: UUID, days: int = 30
) -> list[dict[str, Any]]:
    """Get body composition trend over time."""
    pool = get_pool()
    settings = get_settings()
    key = derive_key(settings.FIELD_ENCRYPTION_KEY)

    end_date = date.today()
    start_date = end_date - timedelta(days=days)

    rows = await pool.fetch(
        """
        SELECT date, metrics_json
        FROM daily_wearable_data
        WHERE user_id = $1 AND source = $2 AND date >= $3
        ORDER BY date ASC
        """,
        user_id,
        WearableProvider.WITHINGS,
        start_date,
    )

    from app.security.encryption import decrypt_field

    trend = []
    for row in rows:
        metrics = json.loads(decrypt_field(row["metrics_json"], key))
        trend.append({
            "date": row["date"].isoformat(),
            "weight_kg": metrics.get("weight_kg"),
            "body_fat_percent": metrics.get("body_fat_percent"),
            "muscle_mass_kg": metrics.get("muscle_mass_kg"),
            "lean_mass_kg": metrics.get("lean_mass_kg"),
        })

    return trend
