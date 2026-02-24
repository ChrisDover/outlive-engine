"""Daily plan generation service — builds personalized protocols from health data."""

from __future__ import annotations

import json
import logging
from datetime import date, datetime, timedelta, timezone
from typing import Any
from uuid import UUID

from app.config import get_settings
from app.models.database import get_pool
from app.security.encryption import decrypt_field, derive_key, encrypt_field
from app.services.ai_service import chat_completion_multi

logger = logging.getLogger(__name__)

_DAILY_PLAN_SYSTEM_PROMPT = """\
You are a longevity-focused health advisor powering the Outlive Engine app.
Generate a personalised daily protocol based on the user's health data.

Return ONLY valid JSON with this structure:
{
  "training": {"type": str, "duration": int, "rpe": int, "exercises": [{"name": str, "sets": int, "reps": str}]},
  "nutrition": {"tdee": int, "protein": int, "carbs": int, "fat": int, "notes": str},
  "supplements": [{"name": str, "dose": str, "unit": str, "timing": str}],
  "interventions": [{"type": str, "duration": int, "notes": str}],
  "sleep": {"bedtime": str, "wake_time": str, "target_hours": float},
  "summary": str,
  "rationale": str
}

Rules:
- Adapt training intensity to recovery status (HRV, sleep score, recovery score)
- Assume yesterday's protocol was followed unless data suggests otherwise
- Align recommendations with genomic risk factors (e.g. cardiovascular → more zone 2)
- If data is sparse, provide reasonable defaults and note assumptions in rationale
- Keep summary to 1-2 sentences; rationale can be longer explaining the reasoning
"""


async def generate_daily_plan(user_id: UUID, target_date: date) -> dict[str, Any]:
    """Generate a daily protocol by gathering health context and calling the LLM."""
    pool = get_pool()
    settings = get_settings()
    key = derive_key(settings.FIELD_ENCRYPTION_KEY)

    # Gather context
    context = await _build_context(pool, key, user_id, target_date)

    messages = [
        {"role": "system", "content": _DAILY_PLAN_SYSTEM_PROMPT},
        {"role": "user", "content": f"Generate today's protocol.\n\nHealth context:\n{json.dumps(context, default=str)}"},
    ]

    try:
        response = await chat_completion_multi(messages, temperature=0.3)
        content = response["choices"][0]["message"]["content"]

        # Try to parse JSON from LLM response
        import re
        json_match = re.search(r'\{[\s\S]*\}', content)
        if json_match:
            protocol = json.loads(json_match.group())
        else:
            protocol = {"summary": "Could not generate protocol — AI returned non-JSON.", "rationale": content}

        model_name = response.get("model", "unknown")
    except Exception:
        logger.exception("Daily plan generation failed")
        protocol = {
            "summary": "Protocol generation temporarily unavailable.",
            "rationale": "The AI service could not be reached. Please try again later.",
        }
        model_name = None

    # Upsert into daily_protocols
    encrypted = encrypt_field(json.dumps(protocol), key)
    now = datetime.now(timezone.utc)

    await pool.execute(
        """INSERT INTO daily_protocols (user_id, date, protocol_json, created_at, updated_at)
           VALUES ($1, $2, $3, $4, $5)
           ON CONFLICT (user_id, date)
           DO UPDATE SET protocol_json = $3, updated_at = $5""",
        user_id,
        target_date,
        encrypted,
        now,
        now,
    )

    protocol["_model"] = model_name
    return protocol


async def _build_context(pool, key: bytes, user_id: UUID, target_date: date) -> dict[str, Any]:
    """Gather genomic risks, latest bloodwork, wearable data, and yesterday's protocol."""
    context: dict[str, Any] = {"date": str(target_date)}

    # Genomic risks
    rows = await pool.fetch(
        "SELECT risk_category, risk_level, summary FROM genomic_profiles WHERE user_id = $1",
        user_id,
    )
    if rows:
        context["genomic_risks"] = [
            {
                "category": r["risk_category"],
                "level": r["risk_level"],
                "summary": decrypt_field(r["summary"], key) if r["summary"] else None,
            }
            for r in rows
        ]

    # Latest bloodwork
    row = await pool.fetchrow(
        "SELECT markers_json, panel_date FROM bloodwork_panels "
        "WHERE user_id = $1 AND deleted_at IS NULL ORDER BY panel_date DESC LIMIT 1",
        user_id,
    )
    if row:
        context["latest_bloodwork"] = {
            "date": str(row["panel_date"]),
            "markers": json.loads(decrypt_field(row["markers_json"], key)),
        }

    # Today's wearable data
    wearable_rows = await pool.fetch(
        "SELECT source, metrics_json FROM daily_wearable_data WHERE user_id = $1 AND date = $2",
        user_id,
        target_date,
    )
    if wearable_rows:
        context["wearable_data"] = [
            {"source": r["source"], "metrics": json.loads(decrypt_field(r["metrics_json"], key))}
            for r in wearable_rows
        ]

    # Yesterday's protocol
    yesterday = target_date - timedelta(days=1)
    row = await pool.fetchrow(
        "SELECT protocol_json FROM daily_protocols WHERE user_id = $1 AND date = $2",
        user_id,
        yesterday,
    )
    if row:
        context["yesterday_protocol"] = json.loads(decrypt_field(row["protocol_json"], key))

    return context
