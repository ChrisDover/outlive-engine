"""Application configuration via Pydantic Settings."""

from __future__ import annotations

import logging
import sys
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict

logger = logging.getLogger("outlive.config")

# Secrets that must be changed from defaults before production use.
_INSECURE_DEFAULTS = frozenset({
    "change-me-in-production",
    "change-me-32-byte-base64-key-here",
})


class Settings(BaseSettings):
    """Central configuration loaded from environment / .env file."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # ── Database ──────────────────────────────────────────────────────────
    DATABASE_URL: str = (
        "postgresql+asyncpg://outlive:outlive@localhost:5432/outlive_engine"
    )

    # ── JWT / Auth ────────────────────────────────────────────────────────
    JWT_SECRET: str = ""
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION_HOURS: int = 24
    JWT_REFRESH_EXPIRATION_DAYS: int = 30

    # ── TLS / mTLS ────────────────────────────────────────────────────────
    TLS_CERT_PATH: str = ""
    TLS_KEY_PATH: str = ""

    # ── AI / LLM ──────────────────────────────────────────────────────────
    # Default: Ollama local. Set to OpenAI/Anthropic URL for cloud models.
    AIRLLM_BASE_URL: str = "http://localhost:11434/v1"
    AIRLLM_API_KEY: str = ""       # Only needed for cloud LLM providers
    AIRLLM_MODEL: str = "llama3.1" # Model name (ollama model or cloud model ID)

    # ── CORS ──────────────────────────────────────────────────────────────
    ALLOWED_ORIGINS: list[str] = ["http://localhost:3000"]

    # ── Encryption ────────────────────────────────────────────────────────
    FIELD_ENCRYPTION_KEY: str = ""

    # ── Apple Sign-In (optional, for mobile clients) ────────────────────────
    APPLE_BUNDLE_ID: str = ""

    # ── Service Auth (Next.js → FastAPI) ──────────────────────────────────
    SERVICE_API_KEY: str = ""

    @property
    def asyncpg_dsn(self) -> str:
        """Return a plain asyncpg DSN (without the +asyncpg dialect)."""
        return self.DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://")


def validate_settings(settings: Settings) -> None:
    """Refuse to start if critical secrets are missing or insecure."""
    errors: list[str] = []

    if not settings.JWT_SECRET or settings.JWT_SECRET in _INSECURE_DEFAULTS:
        errors.append(
            "JWT_SECRET is missing or uses an insecure default. "
            "Generate one: python -c \"import secrets; print(secrets.token_urlsafe(64))\""
        )

    if not settings.FIELD_ENCRYPTION_KEY or settings.FIELD_ENCRYPTION_KEY in _INSECURE_DEFAULTS:
        errors.append(
            "FIELD_ENCRYPTION_KEY is missing or uses an insecure default. "
            "Generate one: openssl rand -base64 32"
        )

    if not settings.SERVICE_API_KEY or settings.SERVICE_API_KEY in _INSECURE_DEFAULTS:
        errors.append(
            "SERVICE_API_KEY is missing or uses an insecure default. "
            "Generate one: openssl rand -hex 32"
        )

    if "*" in settings.ALLOWED_ORIGINS:
        errors.append(
            "ALLOWED_ORIGINS contains '*' — this allows any website to make "
            "authenticated requests. Set it to your actual frontend URL(s)."
        )

    if errors:
        for err in errors:
            logger.critical("SECURITY: %s", err)
        sys.exit(
            "\n\nFATAL: Refusing to start with insecure configuration.\n"
            + "\n".join(f"  - {e}" for e in errors)
            + "\n\nSee .env.example for required values.\n"
        )


@lru_cache
def get_settings() -> Settings:
    """Cached singleton so settings are only parsed once."""
    return Settings()
