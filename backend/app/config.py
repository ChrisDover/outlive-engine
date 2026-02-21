"""Application configuration via Pydantic Settings."""

from __future__ import annotations

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


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
    JWT_SECRET: str = "change-me-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION_HOURS: int = 24
    JWT_REFRESH_EXPIRATION_DAYS: int = 30

    # ── TLS / mTLS ────────────────────────────────────────────────────────
    TLS_CERT_PATH: str = ""
    TLS_KEY_PATH: str = ""

    # ── External Services ─────────────────────────────────────────────────
    AIRLLM_BASE_URL: str = "http://localhost:11434/v1"

    # ── CORS ──────────────────────────────────────────────────────────────
    ALLOWED_ORIGINS: list[str] = ["*"]

    # ── Encryption ────────────────────────────────────────────────────────
    FIELD_ENCRYPTION_KEY: str = "change-me-32-byte-base64-key-here"

    # ── Apple Sign-In ─────────────────────────────────────────────────────
    APPLE_BUNDLE_ID: str = "com.outlive.engine"

    @property
    def asyncpg_dsn(self) -> str:
        """Return a plain asyncpg DSN (without the +asyncpg dialect)."""
        return self.DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://")


@lru_cache
def get_settings() -> Settings:
    """Cached singleton so settings are only parsed once."""
    return Settings()
