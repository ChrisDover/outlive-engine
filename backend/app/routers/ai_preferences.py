"""AI Preferences Router - Manage user AI configuration.

Handles local vs external AI preferences, model selection, and API key management.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.security.auth import get_current_user
from app.config import get_settings
from app.models.database import get_pool
from app.security.encryption import decrypt_field, derive_key, encrypt_field

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])


# Request/Response Models


class AIPreferencesResponse(BaseModel):
    """Current AI preferences."""
    use_local_only: bool = True
    external_provider: str | None = None
    has_external_api_key: bool = False
    acknowledged_external_warning: bool = False
    preferred_model: str = "llama3.1"


class AIPreferencesUpdate(BaseModel):
    """Update AI preferences."""
    use_local_only: bool | None = None
    external_provider: str | None = None
    external_api_key: str | None = None
    preferred_model: str | None = None


class ExternalWarningAcknowledgment(BaseModel):
    """Acknowledge external AI warning."""
    acknowledged: bool


class AIStatusResponse(BaseModel):
    """AI system status."""
    local_available: bool
    local_model: str | None
    external_configured: bool
    external_provider: str | None
    current_mode: str  # 'local' or 'external'


# Helper Functions


async def get_or_create_preferences(user_id: UUID) -> dict[str, Any]:
    """Get user AI preferences, creating defaults if none exist."""
    pool = get_pool()

    row = await pool.fetchrow(
        """
        SELECT use_local_only, external_provider, external_api_key,
               acknowledged_external_warning, preferred_model
        FROM ai_preferences
        WHERE user_id = $1
        """,
        user_id,
    )

    if row:
        return dict(row)

    # Create default preferences
    await pool.execute(
        """
        INSERT INTO ai_preferences (user_id, use_local_only, preferred_model)
        VALUES ($1, TRUE, 'llama3.1')
        ON CONFLICT (user_id) DO NOTHING
        """,
        user_id,
    )

    return {
        "use_local_only": True,
        "external_provider": None,
        "external_api_key": None,
        "acknowledged_external_warning": False,
        "preferred_model": "llama3.1",
    }


# Endpoints


@router.get("/preferences", response_model=AIPreferencesResponse)
async def get_ai_preferences(
    current_user: dict = Depends(get_current_user),
) -> AIPreferencesResponse:
    """
    Get current AI preferences.

    Returns whether local or external AI is configured.
    """
    user_id = UUID(current_user["sub"])
    prefs = await get_or_create_preferences(user_id)

    return AIPreferencesResponse(
        use_local_only=prefs["use_local_only"],
        external_provider=prefs["external_provider"],
        has_external_api_key=prefs["external_api_key"] is not None,
        acknowledged_external_warning=prefs["acknowledged_external_warning"],
        preferred_model=prefs["preferred_model"] or "llama3.1",
    )


@router.put("/preferences", response_model=AIPreferencesResponse)
async def update_ai_preferences(
    update: AIPreferencesUpdate,
    current_user: dict = Depends(get_current_user),
) -> AIPreferencesResponse:
    """
    Update AI preferences.

    To enable external AI, user must first acknowledge the warning.
    """
    user_id = UUID(current_user["sub"])
    pool = get_pool()
    settings = get_settings()

    # Get current preferences
    prefs = await get_or_create_preferences(user_id)

    # If trying to enable external AI, check acknowledgment
    if update.use_local_only is False and not prefs["acknowledged_external_warning"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must acknowledge external AI warning before enabling external AI",
        )

    # Build update query
    updates = []
    params = [user_id]
    param_idx = 2

    if update.use_local_only is not None:
        updates.append(f"use_local_only = ${param_idx}")
        params.append(update.use_local_only)
        param_idx += 1

    if update.external_provider is not None:
        updates.append(f"external_provider = ${param_idx}")
        params.append(update.external_provider)
        param_idx += 1

    if update.external_api_key is not None:
        # Encrypt the API key
        key = derive_key(settings.FIELD_ENCRYPTION_KEY)
        encrypted_key = encrypt_field(update.external_api_key, key)
        updates.append(f"external_api_key = ${param_idx}")
        params.append(encrypted_key)
        param_idx += 1

    if update.preferred_model is not None:
        updates.append(f"preferred_model = ${param_idx}")
        params.append(update.preferred_model)
        param_idx += 1

    if updates:
        updates.append(f"updated_at = ${param_idx}")
        params.append(datetime.now(timezone.utc))

        query = f"""
            UPDATE ai_preferences
            SET {', '.join(updates)}
            WHERE user_id = $1
        """
        await pool.execute(query, *params)

    # Return updated preferences
    return await get_ai_preferences(current_user)


@router.post("/acknowledge-external", response_model=AIPreferencesResponse)
async def acknowledge_external_warning(
    ack: ExternalWarningAcknowledgment,
    current_user: dict = Depends(get_current_user),
) -> AIPreferencesResponse:
    """
    Acknowledge the external AI warning.

    User must acknowledge that their health data will be sent to external servers.
    """
    user_id = UUID(current_user["sub"])
    pool = get_pool()

    if not ack.acknowledged:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Must acknowledge warning to enable external AI",
        )

    # Ensure preferences exist
    await get_or_create_preferences(user_id)

    # Update acknowledgment
    await pool.execute(
        """
        UPDATE ai_preferences
        SET acknowledged_external_warning = TRUE, updated_at = $2
        WHERE user_id = $1
        """,
        user_id,
        datetime.now(timezone.utc),
    )

    return await get_ai_preferences(current_user)


@router.get("/status", response_model=AIStatusResponse)
async def get_ai_status(
    current_user: dict = Depends(get_current_user),
) -> AIStatusResponse:
    """
    Get AI system status.

    Shows whether local and/or external AI is available and configured.
    """
    user_id = UUID(current_user["sub"])
    settings = get_settings()
    prefs = await get_or_create_preferences(user_id)

    # Check local AI availability
    local_available = False
    local_model = None
    try:
        import httpx
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{settings.OLLAMA_HOST}/api/tags")
            if resp.status_code == 200:
                data = resp.json()
                models = data.get("models", [])
                if models:
                    local_available = True
                    local_model = models[0].get("name", "unknown")
    except Exception:
        pass

    # Check external configuration
    external_configured = (
        prefs["external_api_key"] is not None
        and prefs["acknowledged_external_warning"]
        and not prefs["use_local_only"]
    )

    current_mode = "local" if prefs["use_local_only"] or not external_configured else "external"

    return AIStatusResponse(
        local_available=local_available,
        local_model=local_model,
        external_configured=external_configured,
        external_provider=prefs["external_provider"] if external_configured else None,
        current_mode=current_mode,
    )


@router.post("/test-connection")
async def test_ai_connection(
    current_user: dict = Depends(get_current_user),
) -> dict[str, Any]:
    """
    Test connection to configured AI.

    Tests both local and external AI connections.
    """
    user_id = UUID(current_user["sub"])
    settings = get_settings()
    prefs = await get_or_create_preferences(user_id)

    results = {
        "local": {"available": False, "model": None, "error": None},
        "external": {"available": False, "provider": None, "error": None},
    }

    # Test local AI (Ollama)
    try:
        import httpx
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(f"{settings.OLLAMA_HOST}/api/tags")
            if resp.status_code == 200:
                data = resp.json()
                models = data.get("models", [])
                if models:
                    results["local"]["available"] = True
                    results["local"]["model"] = models[0].get("name")
                else:
                    results["local"]["error"] = "No models installed"
            else:
                results["local"]["error"] = f"HTTP {resp.status_code}"
    except Exception as e:
        results["local"]["error"] = str(e)

    # Test external AI if configured
    if prefs["external_api_key"] and prefs["external_provider"]:
        key = derive_key(settings.FIELD_ENCRYPTION_KEY)
        api_key = decrypt_field(prefs["external_api_key"], key)
        provider = prefs["external_provider"]

        try:
            import httpx
            async with httpx.AsyncClient(timeout=10.0) as client:
                if provider == "anthropic":
                    resp = await client.get(
                        "https://api.anthropic.com/v1/messages",
                        headers={
                            "x-api-key": api_key,
                            "anthropic-version": "2023-06-01",
                        },
                    )
                    # 401 means invalid key, 405 means valid key (wrong method)
                    if resp.status_code in (200, 405):
                        results["external"]["available"] = True
                        results["external"]["provider"] = "anthropic"
                    else:
                        results["external"]["error"] = f"HTTP {resp.status_code}"

                elif provider == "openai":
                    resp = await client.get(
                        "https://api.openai.com/v1/models",
                        headers={"Authorization": f"Bearer {api_key}"},
                    )
                    if resp.status_code == 200:
                        results["external"]["available"] = True
                        results["external"]["provider"] = "openai"
                    else:
                        results["external"]["error"] = f"HTTP {resp.status_code}"

        except Exception as e:
            results["external"]["error"] = str(e)

    return results
