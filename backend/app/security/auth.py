"""Apple Sign-In validation, service auth, and JWT token management."""

from __future__ import annotations

import hashlib
import hmac
import logging
import time
from datetime import datetime, timedelta, timezone
from typing import Any
from uuid import UUID

import httpx
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from jose.backends import RSAKey

from app.config import Settings, get_settings
from app.models.database import get_pool

logger = logging.getLogger("outlive.auth")


def _safe_compare(a: str, b: str) -> bool:
    """Constant-time string comparison to prevent timing attacks."""
    return hmac.compare_digest(a.encode(), b.encode())

# ── Constants ─────────────────────────────────────────────────────────────────
APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"
APPLE_JWKS_CACHE_TTL = 3600  # 1 hour

_bearer_scheme = HTTPBearer()

# Simple in-memory JWKS cache
_apple_jwks: dict[str, Any] = {}
_apple_jwks_fetched_at: float = 0.0


# ── Apple JWKS ────────────────────────────────────────────────────────────────

async def _fetch_apple_jwks() -> dict[str, Any]:
    """Fetch and cache Apple's public JWKS."""
    global _apple_jwks, _apple_jwks_fetched_at

    now = time.monotonic()
    if _apple_jwks and (now - _apple_jwks_fetched_at) < APPLE_JWKS_CACHE_TTL:
        return _apple_jwks

    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(APPLE_JWKS_URL)
        resp.raise_for_status()
        _apple_jwks = resp.json()
        _apple_jwks_fetched_at = now

    return _apple_jwks


def _get_apple_public_key(kid: str, jwks: dict[str, Any]) -> RSAKey:
    """Find the matching key in the JWKS by key-id."""
    for key_data in jwks.get("keys", []):
        if key_data["kid"] == kid:
            return RSAKey(key_data, algorithm="RS256")
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Apple public key not found for kid",
    )


async def validate_apple_identity_token(
    identity_token: str,
    settings: Settings,
) -> dict[str, Any]:
    """Validate an Apple identity token and return its claims.

    Checks:
      - Signature against Apple JWKS
      - Issuer == https://appleid.apple.com
      - Audience == configured bundle ID
      - Token not expired
    """
    try:
        unverified_header = jwt.get_unverified_header(identity_token)
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Apple token header: {exc}",
        )

    kid = unverified_header.get("kid")
    if not kid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Apple token missing kid header",
        )

    jwks = await _fetch_apple_jwks()
    public_key = _get_apple_public_key(kid, jwks)

    try:
        claims = jwt.decode(
            identity_token,
            public_key.public_key(),
            algorithms=["RS256"],
            audience=settings.APPLE_BUNDLE_ID,
            issuer=APPLE_ISSUER,
        )
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Apple token verification failed: {exc}",
        )

    return claims


# ── App JWT Issuance ──────────────────────────────────────────────────────────

def create_access_token(
    user_id: UUID,
    settings: Settings,
) -> str:
    """Create a short-lived access JWT."""
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "iat": now,
        "exp": now + timedelta(hours=settings.JWT_EXPIRATION_HOURS),
        "type": "access",
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(
    user_id: UUID,
    settings: Settings,
) -> str:
    """Create a long-lived refresh JWT."""
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "iat": now,
        "exp": now + timedelta(days=settings.JWT_REFRESH_EXPIRATION_DAYS),
        "type": "refresh",
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str, settings: Settings) -> dict[str, Any]:
    """Decode and verify an app JWT.  Raises on invalid / expired."""
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[settings.JWT_ALGORITHM],
        )
        return payload
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {exc}",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ── Token Revocation ──────────────────────────────────────────────────────────

def _hash_token(token: str) -> str:
    """SHA-256 hash of a token for the revocation table."""
    return hashlib.sha256(token.encode()).hexdigest()


async def is_token_revoked(token: str) -> bool:
    """Check if a token has been revoked."""
    pool = get_pool()
    row = await pool.fetchrow(
        "SELECT 1 FROM revoked_tokens WHERE token_hash = $1",
        _hash_token(token),
    )
    return row is not None


async def revoke_token(token: str, settings: Settings) -> None:
    """Add a token to the revocation table."""
    try:
        payload = jwt.decode(
            token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM],
            options={"verify_exp": False},
        )
    except JWTError:
        return  # Can't revoke an unparseable token

    user_id = payload.get("sub")
    exp = payload.get("exp")
    if not user_id or not exp:
        return

    pool = get_pool()
    expires_at = datetime.fromtimestamp(exp, tz=timezone.utc)
    await pool.execute(
        "INSERT INTO revoked_tokens (token_hash, user_id, expires_at) "
        "VALUES ($1, $2, $3) ON CONFLICT (token_hash) DO NOTHING",
        _hash_token(token),
        UUID(user_id),
        expires_at,
    )


# ── Refresh Logic ─────────────────────────────────────────────────────────────

async def refresh_access_token(
    refresh_token: str,
    settings: Settings,
) -> dict[str, str]:
    """Validate a refresh token and return a new access + refresh pair."""
    payload = decode_token(refresh_token, settings)

    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token is not a refresh token",
        )

    # Check revocation
    if await is_token_revoked(refresh_token):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has been revoked",
        )

    pool = get_pool()
    user_id = UUID(payload["sub"])
    row = await pool.fetchrow(
        "SELECT id FROM users WHERE id = $1 AND deleted_at IS NULL",
        user_id,
    )
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or deleted",
        )

    # Revoke the old refresh token (rotation)
    await revoke_token(refresh_token, settings)

    return {
        "access_token": create_access_token(user_id, settings),
        "refresh_token": create_refresh_token(user_id, settings),
        "token_type": "bearer",
    }


# ── FastAPI Dependency ────────────────────────────────────────────────────────

async def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    """Extract and validate the current user from the Authorization header.

    Supports two modes:
    1. Service auth: Bearer token matches SERVICE_API_KEY, user ID from
       X-Outlive-User-Id header (used by Next.js web frontend).
    2. JWT auth: Standard access token decoded to get user ID
       (used by iOS app).

    Returns a dict with at minimum ``{"user_id": UUID, ...}`` pulled from
    the database so downstream handlers have the full user row.
    """
    token = credentials.credentials
    pool = get_pool()

    # ── Service Auth Mode ─────────────────────────────────────────────
    if settings.SERVICE_API_KEY and _safe_compare(token, settings.SERVICE_API_KEY):
        web_user_id = request.headers.get("X-Outlive-User-Id")
        if not web_user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Service auth requires X-Outlive-User-Id header",
            )
        try:
            user_uuid = UUID(web_user_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid X-Outlive-User-Id format",
            )

        row = await pool.fetchrow(
            "SELECT id, apple_user_id, email, display_name, created_at, updated_at "
            "FROM users WHERE id = $1 AND deleted_at IS NULL",
            user_uuid,
        )
        if row is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found or deleted",
            )
        return dict(row)

    # ── JWT Auth Mode ─────────────────────────────────────────────────
    payload = decode_token(token, settings)

    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token is not an access token",
        )

    user_id = payload.get("sub")
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing subject claim",
        )

    row = await pool.fetchrow(
        "SELECT id, apple_user_id, email, display_name, created_at, updated_at "
        "FROM users WHERE id = $1 AND deleted_at IS NULL",
        UUID(user_id),
    )
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or deleted",
        )

    return dict(row)


async def require_service_auth(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme),
    settings: Settings = Depends(get_settings),
) -> None:
    """Dependency that requires service API key auth only."""
    if not settings.SERVICE_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service auth not configured",
        )
    if not _safe_compare(credentials.credentials, settings.SERVICE_API_KEY):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid service API key",
        )
