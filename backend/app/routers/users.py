"""User profile routes."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status

from app.models.database import get_pool
from app.models.schemas import UserResponse, UserUpdate, WebUserCreate
from app.security.auth import get_current_user, require_service_auth

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/web-register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def web_register(
    body: WebUserCreate,
    _: None = Depends(require_service_auth),
) -> UserResponse:
    """Register a web user. Protected by service auth only."""
    pool = get_pool()
    now = datetime.now(timezone.utc)

    row = await pool.fetchrow(
        "INSERT INTO users (email, display_name, created_at, updated_at) "
        "VALUES ($1, $2, $3, $3) "
        "RETURNING id, apple_user_id, email, display_name, created_at, updated_at",
        body.email,
        body.display_name,
        now,
    )
    return UserResponse(**dict(row))


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: dict[str, Any] = Depends(get_current_user)) -> UserResponse:
    """Return the authenticated user's profile."""
    return UserResponse(
        id=current_user["id"],
        apple_user_id=current_user["apple_user_id"],
        email=current_user.get("email"),
        display_name=current_user.get("display_name"),
        created_at=current_user["created_at"],
        updated_at=current_user["updated_at"],
    )


@router.put("/me", response_model=UserResponse)
async def update_me(
    body: UserUpdate,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> UserResponse:
    """Update the authenticated user's profile."""
    pool = get_pool()

    updates: dict[str, Any] = {}
    if body.email is not None:
        updates["email"] = body.email
    if body.display_name is not None:
        updates["display_name"] = body.display_name

    if not updates:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No fields to update",
        )

    set_clauses = ", ".join(f"{k} = ${i+2}" for i, k in enumerate(updates))
    values = list(updates.values())
    now = datetime.now(timezone.utc)

    row = await pool.fetchrow(
        f"UPDATE users SET {set_clauses}, updated_at = ${len(values)+2} "
        f"WHERE id = $1 AND deleted_at IS NULL "
        f"RETURNING id, apple_user_id, email, display_name, created_at, updated_at",
        current_user["id"],
        *values,
        now,
    )

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return UserResponse(**dict(row))
