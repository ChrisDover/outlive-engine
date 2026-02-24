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
from app.models.database import close_pool, init_pool
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
    logger.info("Initialising database connection pool ...")
    await init_pool()
    logger.info("Database pool ready.")
    yield
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
