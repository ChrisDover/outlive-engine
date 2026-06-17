"""Wearable Connection Service - OAuth token management and sync state.

Handles secure storage and refresh of OAuth tokens for wearable integrations.
Supports Oura, Withings, and WHOOP.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

import asyncpg

from app.config import get_settings
from app.models.database import get_pool
from app.security.encryption import decrypt_field, derive_key, encrypt_field

logger = logging.getLogger(__name__)


class WearableProvider:
    """Supported wearable providers."""
    OURA = "oura"
    WITHINGS = "withings"
    WHOOP = "whoop"
    APPLE_HEALTH = "apple_health"


async def get_connection(
    user_id: UUID,
    provider: str,
) -> dict[str, Any] | None:
    """
    Get wearable connection details for a user and provider.

    Returns decrypted tokens if connection exists.
    """
    pool = get_pool()
    settings = get_settings()
    key = derive_key(settings.FIELD_ENCRYPTION_KEY)

    row = await pool.fetchrow(
        """
        SELECT id, provider, access_token, refresh_token, provider_user_id,
               expires_at, last_sync_at, created_at, updated_at
        FROM wearable_connections
        WHERE user_id = $1 AND provider = $2
        """,
        user_id,
        provider,
    )

    if not row:
        return None

    return {
        "id": row["id"],
        "provider": row["provider"],
        "access_token": decrypt_field(row["access_token"], key) if row["access_token"] else None,
        "refresh_token": decrypt_field(row["refresh_token"], key) if row["refresh_token"] else None,
        "provider_user_id": row["provider_user_id"],
        "expires_at": row["expires_at"],
        "last_sync_at": row["last_sync_at"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


async def get_all_connections(user_id: UUID) -> list[dict[str, Any]]:
    """Get all wearable connections for a user (without tokens)."""
    pool = get_pool()

    rows = await pool.fetch(
        """
        SELECT id, provider, provider_user_id, expires_at, last_sync_at, created_at, updated_at
        FROM wearable_connections
        WHERE user_id = $1
        ORDER BY provider
        """,
        user_id,
    )

    return [
        {
            "id": row["id"],
            "provider": row["provider"],
            "provider_user_id": row["provider_user_id"],
            "expires_at": row["expires_at"],
            "last_sync_at": row["last_sync_at"],
            "is_connected": True,
            "token_expired": row["expires_at"] and row["expires_at"] < datetime.now(timezone.utc),
        }
        for row in rows
    ]


async def save_connection(
    user_id: UUID,
    provider: str,
    access_token: str,
    refresh_token: str | None = None,
    provider_user_id: str | None = None,
    expires_at: datetime | None = None,
) -> dict[str, Any]:
    """
    Save or update a wearable connection with encrypted tokens.
    """
    pool = get_pool()
    settings = get_settings()
    key = derive_key(settings.FIELD_ENCRYPTION_KEY)
    now = datetime.now(timezone.utc)

    enc_access = encrypt_field(access_token, key)
    enc_refresh = encrypt_field(refresh_token, key) if refresh_token else None

    row = await pool.fetchrow(
        """
        INSERT INTO wearable_connections
            (user_id, provider, access_token, refresh_token, provider_user_id, expires_at, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $7)
        ON CONFLICT (user_id, provider)
        DO UPDATE SET
            access_token = $3,
            refresh_token = COALESCE($4, wearable_connections.refresh_token),
            provider_user_id = COALESCE($5, wearable_connections.provider_user_id),
            expires_at = $6,
            updated_at = $7
        RETURNING id, provider, provider_user_id, expires_at, last_sync_at, created_at, updated_at
        """,
        user_id,
        provider,
        enc_access,
        enc_refresh,
        provider_user_id,
        expires_at,
        now,
    )

    logger.info(f"Saved wearable connection for user {user_id}, provider {provider}")

    return {
        "id": row["id"],
        "provider": row["provider"],
        "provider_user_id": row["provider_user_id"],
        "expires_at": row["expires_at"],
        "last_sync_at": row["last_sync_at"],
        "is_connected": True,
    }


async def update_tokens(
    user_id: UUID,
    provider: str,
    access_token: str,
    refresh_token: str | None = None,
    expires_at: datetime | None = None,
) -> bool:
    """
    Update tokens after a refresh operation.
    """
    pool = get_pool()
    settings = get_settings()
    key = derive_key(settings.FIELD_ENCRYPTION_KEY)
    now = datetime.now(timezone.utc)

    enc_access = encrypt_field(access_token, key)
    enc_refresh = encrypt_field(refresh_token, key) if refresh_token else None

    result = await pool.execute(
        """
        UPDATE wearable_connections
        SET access_token = $3,
            refresh_token = COALESCE($4, refresh_token),
            expires_at = $5,
            updated_at = $6
        WHERE user_id = $1 AND provider = $2
        """,
        user_id,
        provider,
        enc_access,
        enc_refresh,
        expires_at,
        now,
    )

    return result == "UPDATE 1"


async def update_last_sync(
    user_id: UUID,
    provider: str,
) -> None:
    """Update the last_sync_at timestamp for a connection."""
    pool = get_pool()
    now = datetime.now(timezone.utc)

    await pool.execute(
        """
        UPDATE wearable_connections
        SET last_sync_at = $3, updated_at = $3
        WHERE user_id = $1 AND provider = $2
        """,
        user_id,
        provider,
        now,
    )


async def delete_connection(user_id: UUID, provider: str) -> bool:
    """Remove a wearable connection."""
    pool = get_pool()

    result = await pool.execute(
        """
        DELETE FROM wearable_connections
        WHERE user_id = $1 AND provider = $2
        """,
        user_id,
        provider,
    )

    logger.info(f"Deleted wearable connection for user {user_id}, provider {provider}")
    return result == "DELETE 1"


async def is_token_valid(user_id: UUID, provider: str) -> bool:
    """Check if a connection's token is still valid."""
    pool = get_pool()

    row = await pool.fetchrow(
        """
        SELECT expires_at
        FROM wearable_connections
        WHERE user_id = $1 AND provider = $2
        """,
        user_id,
        provider,
    )

    if not row:
        return False

    if not row["expires_at"]:
        # No expiry set, assume valid
        return True

    return row["expires_at"] > datetime.now(timezone.utc)


async def get_connections_needing_refresh() -> list[dict[str, Any]]:
    """
    Get all connections where tokens are expiring soon (within 1 hour).
    Used for proactive token refresh.
    """
    pool = get_pool()
    settings = get_settings()
    key = derive_key(settings.FIELD_ENCRYPTION_KEY)

    # Tokens expiring within the next hour
    threshold = datetime.now(timezone.utc)

    rows = await pool.fetch(
        """
        SELECT user_id, provider, refresh_token
        FROM wearable_connections
        WHERE expires_at IS NOT NULL
          AND expires_at < $1
          AND refresh_token IS NOT NULL
        ORDER BY expires_at
        LIMIT 100
        """,
        threshold,
    )

    return [
        {
            "user_id": row["user_id"],
            "provider": row["provider"],
            "refresh_token": decrypt_field(row["refresh_token"], key),
        }
        for row in rows
    ]


async def get_sync_status(user_id: UUID) -> dict[str, Any]:
    """Get sync status for all wearable connections."""
    connections = await get_all_connections(user_id)

    status = {}
    for conn in connections:
        provider = conn["provider"]
        status[provider] = {
            "connected": True,
            "last_sync": conn["last_sync_at"].isoformat() if conn["last_sync_at"] else None,
            "token_expired": conn.get("token_expired", False),
        }

    # Add status for disconnected providers
    for provider in [WearableProvider.OURA, WearableProvider.WITHINGS, WearableProvider.WHOOP]:
        if provider not in status:
            status[provider] = {
                "connected": False,
                "last_sync": None,
                "token_expired": False,
            }

    return status
