"""Analytics: derived longevity score and biomarker time series."""

from __future__ import annotations

import json
import logging
from typing import Any

from fastapi import APIRouter, Depends

from app.config import get_settings
from app.models.database import get_pool
from app.security.auth import get_current_user
from app.security.encryption import decrypt_field, derive_key
from app.services.longevity_service import build_biomarker_series, compute_longevity

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/analytics", tags=["analytics"])


def _key() -> bytes:
    return derive_key(get_settings().FIELD_ENCRYPTION_KEY)


def _decrypt_json(blob: Any, key: bytes) -> Any:
    try:
        return json.loads(decrypt_field(blob, key))
    except Exception:  # noqa: BLE001 — bad/legacy rows shouldn't break analytics
        return None


async def _load_panels(user_id: Any, key: bytes) -> list[tuple[str, list[dict[str, Any]]]]:
    pool = get_pool()
    rows = await pool.fetch(
        "SELECT panel_date, markers_json FROM bloodwork_panels "
        "WHERE user_id = $1 AND deleted_at IS NULL ORDER BY panel_date ASC",
        user_id,
    )
    panels: list[tuple[str, list[dict[str, Any]]]] = []
    for r in rows:
        markers = _decrypt_json(r["markers_json"], key) or []
        panels.append((r["panel_date"].isoformat(), markers))
    return panels


@router.get("/biomarkers")
async def get_biomarkers(
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[dict[str, Any]]:
    """Per-marker time series across all of the user's bloodwork panels."""
    key = _key()
    panels = await _load_panels(current_user["id"], key)
    return build_biomarker_series(panels)


@router.get("/longevity-score")
async def get_longevity_score(
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    """Composite longevity score from bloodwork, wearables and body composition."""
    key = _key()
    pool = get_pool()
    user_id = current_user["id"]

    panels = await _load_panels(user_id, key)
    latest_markers = panels[-1][1] if panels else []
    prev_markers = panels[-2][1] if len(panels) >= 2 else []

    wrows = await pool.fetch(
        "SELECT metrics_json FROM daily_wearable_data WHERE user_id = $1 "
        "ORDER BY date DESC LIMIT 14",
        user_id,
    )
    wearable_metrics: list[dict[str, Any]] = []
    for r in reversed(wrows):  # oldest → newest
        m = _decrypt_json(r["metrics_json"], key)
        if isinstance(m, dict):
            wearable_metrics.append(m)

    brow = await pool.fetchrow(
        "SELECT metrics_json FROM body_composition WHERE user_id = $1 AND deleted_at IS NULL "
        "ORDER BY date DESC LIMIT 1",
        user_id,
    )
    bodycomp = _decrypt_json(brow["metrics_json"], key) if brow else None
    if not isinstance(bodycomp, dict):
        bodycomp = None

    return compute_longevity(latest_markers, prev_markers, wearable_metrics, bodycomp)
