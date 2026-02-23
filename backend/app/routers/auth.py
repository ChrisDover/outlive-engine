"""Authentication routes: Apple Sign-In, token refresh, revoke."""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from app.config import Settings, get_settings
from app.models.database import get_pool
from app.models.schemas import (
    AppleAuthRequest,
    RefreshRequest,
    RevokeRequest,
    TokenResponse,
)
from app.security.auth import (
    create_access_token,
    create_refresh_token,
    refresh_access_token,
    revoke_token,
    validate_apple_identity_token,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/apple", response_model=TokenResponse, status_code=status.HTTP_200_OK)
async def apple_sign_in(
    body: AppleAuthRequest,
    settings: Settings = Depends(get_settings),
) -> TokenResponse:
    """Validate an Apple identity token, create or fetch the user, return JWTs."""
    claims = await validate_apple_identity_token(body.identity_token, settings)

    apple_user_id: str = claims["sub"]
    email: str | None = claims.get("email")

    pool = get_pool()

    # Upsert user
    row = await pool.fetchrow(
        "SELECT id FROM users WHERE apple_user_id = $1", apple_user_id
    )

    if row is None:
        row = await pool.fetchrow(
            """
            INSERT INTO users (apple_user_id, email, display_name)
            VALUES ($1, $2, $3)
            RETURNING id
            """,
            apple_user_id,
            email,
            body.display_name,
        )
    else:
        # Update last-seen info
        await pool.execute(
            "UPDATE users SET updated_at = $1 WHERE id = $2",
            datetime.now(timezone.utc),
            row["id"],
        )

    user_id: UUID = row["id"]

    return TokenResponse(
        access_token=create_access_token(user_id, settings),
        refresh_token=create_refresh_token(user_id, settings),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    body: RefreshRequest,
    settings: Settings = Depends(get_settings),
) -> TokenResponse:
    """Exchange a valid refresh token for a new access + refresh pair."""
    tokens = await refresh_access_token(body.refresh_token, settings)
    return TokenResponse(**tokens)


@router.post("/revoke", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_refresh_token(
    body: RevokeRequest,
    settings: Settings = Depends(get_settings),
) -> None:
    """Revoke a refresh token by adding it to the deny-list."""
    await revoke_token(body.refresh_token, settings)
