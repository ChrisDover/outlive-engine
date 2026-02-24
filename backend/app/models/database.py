"""asyncpg connection pool management and schema bootstrap."""

from __future__ import annotations

import asyncpg

from app.config import get_settings

_pool: asyncpg.Pool | None = None


async def init_pool() -> asyncpg.Pool:
    """Create the asyncpg connection pool and bootstrap the schema."""
    global _pool
    settings = get_settings()
    _pool = await asyncpg.create_pool(
        dsn=settings.asyncpg_dsn,
        min_size=2,
        max_size=20,
        command_timeout=30,
    )
    await _create_schema(_pool)
    return _pool


def get_pool() -> asyncpg.Pool:
    """Return the current pool or raise if not initialised."""
    if _pool is None:
        raise RuntimeError("Database pool is not initialised. Call init_pool() first.")
    return _pool


async def close_pool() -> None:
    """Gracefully close the pool."""
    global _pool
    if _pool is not None:
        await _pool.close()
        _pool = None


# ── Schema Bootstrap ──────────────────────────────────────────────────────────

_SCHEMA_SQL = """
-- Enable uuid-ossp for uuid_generate_v4() if not already present
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Users ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    apple_user_id   TEXT UNIQUE,
    email           TEXT UNIQUE,        -- encrypted
    display_name    TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ
);

-- ── Genomic Profiles ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS genomic_profiles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    risk_category   TEXT NOT NULL,          -- e.g. cardiovascular, metabolic
    risk_level      TEXT NOT NULL,          -- e.g. elevated, normal, reduced
    summary         TEXT,                   -- encrypted
    metadata_json   TEXT,                   -- encrypted JSON blob
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, risk_category)
);
CREATE INDEX IF NOT EXISTS idx_genomic_profiles_user ON genomic_profiles(user_id);

-- ── Bloodwork Panels ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bloodwork_panels (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    panel_date      DATE NOT NULL,
    lab_name        TEXT,
    markers_json    TEXT NOT NULL,           -- encrypted JSON array of markers
    notes           TEXT,                    -- encrypted
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_bloodwork_user_date ON bloodwork_panels(user_id, panel_date);

-- ── Daily Wearable Data ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS daily_wearable_data (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date            DATE NOT NULL,
    source          TEXT NOT NULL,           -- e.g. apple_health, whoop, oura
    metrics_json    TEXT NOT NULL,            -- encrypted JSON
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, date, source)
);
CREATE INDEX IF NOT EXISTS idx_wearable_user_date ON daily_wearable_data(user_id, date);

-- ── Body Composition ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS body_composition (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date            DATE NOT NULL,
    metrics_json    TEXT NOT NULL,            -- encrypted JSON
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ,
    UNIQUE (user_id, date)
);
CREATE INDEX IF NOT EXISTS idx_body_comp_user_date ON body_composition(user_id, date);

-- ── Daily Protocols ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS daily_protocols (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date            DATE NOT NULL,
    protocol_json   TEXT NOT NULL,            -- encrypted JSON (exercise, supplements, etc.)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, date)
);
CREATE INDEX IF NOT EXISTS idx_daily_protocols_user_date ON daily_protocols(user_id, date);

-- ── Experiments ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS experiments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    hypothesis      TEXT,
    status          TEXT NOT NULL DEFAULT 'active',   -- active, completed, abandoned
    start_date      DATE NOT NULL,
    end_date        DATE,
    metrics_json    TEXT,                     -- encrypted JSON of tracked metrics
    snapshots_json  TEXT,                     -- encrypted JSON array of snapshots
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_experiments_user ON experiments(user_id);

-- ── Protocol Sources ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS protocol_sources (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source_name     TEXT NOT NULL,            -- e.g. attia, huberman, custom
    enabled         BOOLEAN NOT NULL DEFAULT TRUE,
    priority        INT NOT NULL DEFAULT 0,
    config_json     TEXT,                     -- encrypted JSON for source settings
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, source_name)
);
CREATE INDEX IF NOT EXISTS idx_protocol_sources_user ON protocol_sources(user_id);

-- ── Audit Log ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_log (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID,
    method          TEXT NOT NULL,
    path            TEXT NOT NULL,
    status_code     INT NOT NULL,
    ip_address      TEXT,
    duration_ms     DOUBLE PRECISION,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_log_user ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_created ON audit_log(created_at);

-- ── Sync Log ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sync_log (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entity_type     TEXT NOT NULL,            -- e.g. bloodwork, wearable, experiment
    entity_id       UUID NOT NULL,
    vector_clock    JSONB NOT NULL DEFAULT '{}',
    operation       TEXT NOT NULL,            -- insert, update, delete
    payload_json    TEXT,                     -- encrypted full entity snapshot
    device_id       TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sync_log_user_entity ON sync_log(user_id, entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_sync_log_user_created ON sync_log(user_id, created_at);

-- ── Revoked Tokens ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS revoked_tokens (
    token_hash      TEXT PRIMARY KEY,      -- SHA-256 hash of the token
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    revoked_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ NOT NULL   -- auto-cleanup after token would have expired anyway
);
CREATE INDEX IF NOT EXISTS idx_revoked_tokens_expires ON revoked_tokens(expires_at);
"""


async def _create_schema(pool: asyncpg.Pool) -> None:
    """Run the idempotent schema bootstrap."""
    async with pool.acquire() as conn:
        await conn.execute(_SCHEMA_SQL)
