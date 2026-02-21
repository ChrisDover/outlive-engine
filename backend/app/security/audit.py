"""Audit-logging middleware -- records every request to the audit_log table."""

from __future__ import annotations

import asyncio
import time
from datetime import datetime, timezone
from uuid import UUID

from fastapi import Request, Response
from jose import jwt
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint

from app.config import get_settings
from app.models.database import get_pool


def _extract_user_id(request: Request) -> UUID | None:
    """Best-effort extraction of user_id from the Authorization header.

    This is intentionally lenient -- if the token is invalid we still want
    the request to proceed (the router-level dependency will reject it).
    """
    auth_header = request.headers.get("authorization", "")
    if not auth_header.startswith("Bearer "):
        return None

    token = auth_header[7:]
    settings = get_settings()
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[settings.JWT_ALGORITHM],
            options={"verify_exp": False},
        )
        sub = payload.get("sub")
        return UUID(sub) if sub else None
    except Exception:
        return None


async def _persist_audit_entry(
    user_id: UUID | None,
    method: str,
    path: str,
    status_code: int,
    ip_address: str,
    duration_ms: float,
) -> None:
    """Fire-and-forget insert into audit_log."""
    try:
        pool = get_pool()
        await pool.execute(
            """
            INSERT INTO audit_log (user_id, method, path, status_code, ip_address, duration_ms, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            """,
            user_id,
            method,
            path,
            status_code,
            ip_address,
            duration_ms,
            datetime.now(timezone.utc),
        )
    except Exception:
        # Audit logging must never break the request pipeline.
        pass


class AuditLogMiddleware(BaseHTTPMiddleware):
    """Logs every HTTP request to the ``audit_log`` table asynchronously."""

    async def dispatch(
        self,
        request: Request,
        call_next: RequestResponseEndpoint,
    ) -> Response:
        start = time.perf_counter()
        response = await call_next(request)
        duration_ms = (time.perf_counter() - start) * 1000.0

        user_id = _extract_user_id(request)
        ip_address = request.client.host if request.client else "unknown"

        # Fire and forget -- do not await on the hot path
        asyncio.create_task(
            _persist_audit_entry(
                user_id=user_id,
                method=request.method,
                path=request.url.path,
                status_code=response.status_code,
                ip_address=ip_address,
                duration_ms=round(duration_ms, 2),
            )
        )

        return response
