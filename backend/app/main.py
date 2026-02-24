"""Outlive Engine -- FastAPI application entry point."""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from app.config import get_settings, validate_settings
from app.models.database import close_pool, init_pool, get_pool
from app.routers import ai, auth, bloodwork, experiments, genomics, protocols, sync, users, wearables
from app.security.audit import AuditLogMiddleware

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
)
logger = logging.getLogger("outlive")


# ── Lifespan ──────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    """Startup: create DB pool.  Shutdown: close it."""
    import asyncio

    logger.info("Initialising database connection pool ...")
    await init_pool()
    logger.info("Database pool ready.")

    # Background: purge expired revoked tokens every hour
    async def _cleanup_revoked_tokens() -> None:
        while True:
            try:
                await asyncio.sleep(3600)
                pool = get_pool()
                result = await pool.execute(
                    "DELETE FROM revoked_tokens WHERE expires_at < now()"
                )
                logger.info("Revoked token cleanup: %s", result)
            except asyncio.CancelledError:
                break
            except Exception:
                logger.error("Revoked token cleanup failed", exc_info=True)

    cleanup_task = asyncio.create_task(_cleanup_revoked_tokens())

    yield

    cleanup_task.cancel()
    logger.info("Shutting down database connection pool ...")
    await close_pool()
    logger.info("Database pool closed.")


# ── App Factory ───────────────────────────────────────────────────────────────

limiter = Limiter(key_func=get_remote_address)


def create_app() -> FastAPI:
    settings = get_settings()
    validate_settings(settings)

    application = FastAPI(
        title="Outlive Engine API",
        version="1.0.0",
        description="Backend for the Outlive Engine longevity-tracking platform.",
        lifespan=lifespan,
    )

    # ── Rate Limiting ──────────────────────────────────────────────────
    application.state.limiter = limiter

    @application.exception_handler(RateLimitExceeded)
    async def _rate_limit_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
        return JSONResponse(
            status_code=429,
            content={"detail": "Too many requests. Please slow down."},
        )

    # ── Security Headers ────────────────────────────────────────────────
    @application.middleware("http")
    async def add_security_headers(request: Request, call_next):  # type: ignore[no-untyped-def]
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Request-ID"] = request.headers.get(
            "X-Request-ID", ""
        )
        return response

    # ── CORS ──────────────────────────────────────────────────────────────
    application.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ── Audit Logging ─────────────────────────────────────────────────────
    application.add_middleware(AuditLogMiddleware)

    # ── Routers ───────────────────────────────────────────────────────────
    api_prefix = "/api/v1"
    application.include_router(auth.router, prefix=api_prefix)
    application.include_router(users.router, prefix=api_prefix)
    application.include_router(genomics.router, prefix=api_prefix)
    application.include_router(bloodwork.router, prefix=api_prefix)
    application.include_router(wearables.router, prefix=api_prefix)
    application.include_router(protocols.router, prefix=api_prefix)
    application.include_router(experiments.router, prefix=api_prefix)
    application.include_router(ai.router, prefix=api_prefix)
    application.include_router(sync.router, prefix=api_prefix)

    # ── Health Check ──────────────────────────────────────────────────────
    @application.get("/health", tags=["health"])
    async def health_check() -> dict[str, str]:
        return {"status": "healthy"}

    return application


app = create_app()
