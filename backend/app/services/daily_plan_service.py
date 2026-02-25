"""Daily plan generation service — builds personalized protocols from health data and expert knowledge."""

from __future__ import annotations

import json
import logging
import re
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
Generate a personalised daily protocol based on the user's health data AND the expert protocols from our knowledge base.

Return ONLY valid JSON with this structure:
{
  "training": {"type": str, "duration": int, "rpe": int, "exercises": [{"name": str, "sets": int, "reps": str}]},
  "nutrition": {"tdee": int, "protein": int, "carbs": int, "fat": int, "meal_timing": str, "notes": str},
  "supplements": [{"name": str, "dose": str, "unit": str, "timing": str, "rationale": str, "source_expert": str}],
  "interventions": [{"type": str, "duration": int, "notes": str, "source_expert": str}],
  "sleep": {"bedtime": str, "wake_time": str, "target_hours": float},
  "summary": str,
  "rationale": str,
  "expert_citations": [str]
}

Rules:
- Incorporate expert protocols from the knowledge base when applicable to the user's context
- Adapt training intensity to recovery status (HRV, sleep score, recovery score)
  - Low HRV (<50) or poor recovery: recommend light activity, Zone 2, or rest
  - Good recovery: can recommend higher intensity
- Personalize supplements based on genomic markers:
  - MTHFR variants → recommend methylfolate not folic acid
  - APOE4 → emphasize omega-3s, avoid saturated fats
- Adjust based on bloodwork:
  - Low vitamin D (<40 ng/mL) → recommend D3 supplementation
  - High ApoB (>90) → emphasize cardiovascular protocols
  - Low omega-3 index (<8%) → increase fish oil
- Include "source_expert" for each recommendation citing the expert (e.g., "Huberman", "Bryan Johnson")
- Keep summary to 2-3 sentences highlighting the day's focus
- The rationale should explain WHY these specific recommendations based on the user's data
"""

_MORNING_BRIEF_SYSTEM_PROMPT = """\
You are a friendly, knowledgeable health coach generating a personalized morning brief.
Write in a warm, conversational tone as if speaking directly to the user.

Based on the user's health data and daily protocol, create an engaging morning brief that:
1. Greets the user and acknowledges their current state (recovery, sleep)
2. Highlights the 3 most important priorities for today
3. Explains the "why" behind key recommendations
4. References expert protocols when applicable

Keep it concise but motivating - about 200-300 words.
End with an encouraging note about their health journey.
"""


async def generate_daily_plan(user_id: UUID, target_date: date) -> dict[str, Any]:
    """Generate a daily protocol by gathering health context and calling the LLM."""
    pool = get_pool()
    settings = get_settings()
    key = derive_key(settings.FIELD_ENCRYPTION_KEY)

    # Gather context including knowledge base protocols
    context = await _build_context(pool, key, user_id, target_date)

    # Fetch applicable protocols from knowledge base
    kb_protocols = await _get_applicable_protocols(pool, context)
    context["knowledge_base_protocols"] = kb_protocols

    messages = [
        {"role": "system", "content": _DAILY_PLAN_SYSTEM_PROMPT},
        {"role": "user", "content": f"Generate today's protocol.\n\nHealth context:\n{json.dumps(context, default=str)}"},
    ]

    try:
        response = await chat_completion_multi(messages, temperature=0.3)
        content = response["choices"][0]["message"]["content"]

        # Try to parse JSON from LLM response
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


async def generate_morning_brief(user_id: UUID, target_date: date) -> dict[str, Any]:
    """
    Generate a conversational morning brief based on the daily protocol.

    This is the primary interface for the AI health coach - a friendly,
    personalized message each morning explaining what to focus on and why.
    """
    pool = get_pool()
    settings = get_settings()
    key = derive_key(settings.FIELD_ENCRYPTION_KEY)

    # First, ensure we have a daily plan
    row = await pool.fetchrow(
        "SELECT protocol_json FROM daily_protocols WHERE user_id = $1 AND date = $2",
        user_id,
        target_date,
    )

    if row:
        protocol = json.loads(decrypt_field(row["protocol_json"], key))
    else:
        # Generate one if it doesn't exist
        protocol = await generate_daily_plan(user_id, target_date)

    # Build context for the morning brief
    context = await _build_context(pool, key, user_id, target_date)
    recovery_status = _assess_recovery(context.get("wearable_data", []))

    brief_context = {
        "date": str(target_date),
        "day_of_week": target_date.strftime("%A"),
        "protocol": protocol,
        "recovery_status": recovery_status,
        "genomic_risks": context.get("genomic_risks", []),
        "latest_bloodwork": context.get("latest_bloodwork"),
    }

    messages = [
        {"role": "system", "content": _MORNING_BRIEF_SYSTEM_PROMPT},
        {"role": "user", "content": f"Generate my morning brief.\n\nContext:\n{json.dumps(brief_context, default=str)}"},
    ]

    try:
        response = await chat_completion_multi(messages, temperature=0.6)
        greeting = response["choices"][0]["message"]["content"]
        model_name = response.get("model", "unknown")
    except Exception:
        logger.exception("Morning brief generation failed")
        greeting = "Good morning! I had some trouble generating your personalized brief today, but your daily protocol is ready below."
        model_name = None

    # Extract top priorities from protocol
    top_priorities = _extract_priorities(protocol, recovery_status)

    return {
        "date": str(target_date),
        "greeting": greeting,
        "top_priorities": top_priorities,
        "eating_plan": {
            "summary": protocol.get("nutrition", {}).get("notes", "Focus on whole foods"),
            "macros": {
                "protein": protocol.get("nutrition", {}).get("protein"),
                "carbs": protocol.get("nutrition", {}).get("carbs"),
                "fat": protocol.get("nutrition", {}).get("fat"),
            },
            "meal_timing": protocol.get("nutrition", {}).get("meal_timing", "Standard meals"),
        },
        "supplement_plan": protocol.get("supplements", []),
        "workout_plan": protocol.get("training", {}),
        "interventions_plan": protocol.get("interventions", []),
        "rationale": protocol.get("rationale", ""),
        "expert_citations": protocol.get("expert_citations", []),
        "recovery_status": recovery_status,
        "_model": model_name,
    }


def _assess_recovery(wearable_data: list[dict]) -> dict[str, Any]:
    """Assess recovery status from wearable data."""
    recovery = {
        "status": "unknown",
        "hrv": None,
        "sleep_hours": None,
        "sleep_quality": None,
        "recovery_score": None,
        "recommendation": "No wearable data available",
    }

    for source_data in wearable_data:
        metrics = source_data.get("metrics", {})
        source = source_data.get("source", "")

        # Extract HRV
        if "hrv" in metrics:
            recovery["hrv"] = metrics["hrv"]
        elif "hrv_rmssd" in metrics:
            recovery["hrv"] = metrics["hrv_rmssd"]

        # Extract sleep
        if "sleep_hours" in metrics:
            recovery["sleep_hours"] = metrics["sleep_hours"]
        elif "total_sleep" in metrics:
            recovery["sleep_hours"] = metrics["total_sleep"] / 60 if metrics["total_sleep"] > 24 else metrics["total_sleep"]

        # Extract recovery score (WHOOP, Oura)
        if "recovery_score" in metrics:
            recovery["recovery_score"] = metrics["recovery_score"]
        elif "readiness_score" in metrics:
            recovery["recovery_score"] = metrics["readiness_score"]

        # Sleep quality
        if "sleep_score" in metrics:
            recovery["sleep_quality"] = metrics["sleep_score"]

    # Determine overall status
    if recovery["hrv"] is not None or recovery["recovery_score"] is not None:
        hrv = recovery["hrv"] or 50
        rec_score = recovery["recovery_score"] or 70

        if hrv < 40 or rec_score < 50:
            recovery["status"] = "low"
            recovery["recommendation"] = "Recovery is low. Focus on rest, light movement, and stress reduction."
        elif hrv < 55 or rec_score < 70:
            recovery["status"] = "moderate"
            recovery["recommendation"] = "Moderate recovery. Consider zone 2 cardio or light training."
        else:
            recovery["status"] = "good"
            recovery["recommendation"] = "Recovery looks good! You can handle higher intensity today."

    return recovery


def _extract_priorities(protocol: dict[str, Any], recovery: dict[str, Any]) -> list[str]:
    """Extract top 3 priorities from the daily protocol."""
    priorities = []

    # Recovery-based priority
    if recovery["status"] == "low":
        priorities.append("Prioritize recovery today - light movement and stress management")
    elif recovery["status"] == "good":
        training = protocol.get("training", {})
        if training.get("type"):
            priorities.append(f"Training: {training.get('type')} - {training.get('duration', 45)} minutes")

    # Key supplements
    supplements = protocol.get("supplements", [])
    if supplements:
        top_supps = [s["name"] for s in supplements[:3]]
        priorities.append(f"Take: {', '.join(top_supps)}")

    # Key intervention
    interventions = protocol.get("interventions", [])
    if interventions:
        top_int = interventions[0]
        priorities.append(f"{top_int.get('type', 'Intervention')}: {top_int.get('duration', 10)} min")

    # Sleep target
    sleep = protocol.get("sleep", {})
    if sleep.get("target_hours"):
        priorities.append(f"Sleep target: {sleep['target_hours']} hours (bed by {sleep.get('bedtime', '10pm')})")

    return priorities[:3]


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

    # Genomic variants (for MTHFR, APOE, etc.)
    key_variants = await pool.fetch(
        "SELECT rsid, genotype FROM genomic_variants WHERE user_id = $1 AND rsid IN ('rs1801133', 'rs1801131', 'rs429358', 'rs7412')",
        user_id,
    )
    if key_variants:
        context["genomic_markers"] = {r["rsid"]: r["genotype"] for r in key_variants}
        # Interpret key markers
        markers = context["genomic_markers"]
        if "rs1801133" in markers and markers["rs1801133"] in ["CT", "TT"]:
            context["mthfr_variant"] = True
        if "rs429358" in markers and markers["rs429358"] == "TC":
            context["apoe4_carrier"] = True

    # Latest bloodwork
    row = await pool.fetchrow(
        "SELECT markers_json, panel_date FROM bloodwork_panels "
        "WHERE user_id = $1 AND deleted_at IS NULL ORDER BY panel_date DESC LIMIT 1",
        user_id,
    )
    if row:
        markers = json.loads(decrypt_field(row["markers_json"], key))
        context["latest_bloodwork"] = {
            "date": str(row["panel_date"]),
            "markers": markers,
        }
        # Extract key biomarkers for protocol decisions
        context["bloodwork_flags"] = _analyze_bloodwork(markers)

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

    # Active experiments
    experiments = await pool.fetch(
        "SELECT title, hypothesis FROM experiments WHERE user_id = $1 AND status = 'active' AND deleted_at IS NULL",
        user_id,
    )
    if experiments:
        context["active_experiments"] = [{"title": e["title"], "hypothesis": e["hypothesis"]} for e in experiments]

    return context


def _analyze_bloodwork(markers: list[dict]) -> dict[str, Any]:
    """Analyze bloodwork markers and flag areas needing attention."""
    flags = {}

    for marker in markers:
        name = marker.get("name", "").lower()
        value = marker.get("value")
        ref_high = marker.get("reference_high")
        ref_low = marker.get("reference_low")

        if value is None:
            continue

        # Vitamin D
        if "vitamin d" in name or "25-oh" in name:
            if value < 40:
                flags["low_vitamin_d"] = {"value": value, "target": "40-60 ng/mL"}
            elif value < 30:
                flags["deficient_vitamin_d"] = {"value": value, "target": "40-60 ng/mL"}

        # ApoB
        if "apob" in name or "apo b" in name:
            if value > 90:
                flags["elevated_apob"] = {"value": value, "target": "<90 mg/dL"}
            if value > 120:
                flags["high_apob"] = {"value": value, "target": "<90 mg/dL"}

        # HbA1c
        if "hba1c" in name or "a1c" in name:
            if value > 5.6:
                flags["elevated_hba1c"] = {"value": value, "target": "<5.5%"}

        # Inflammation markers
        if "hs-crp" in name or "hscrp" in name or "c-reactive" in name:
            if value > 1.0:
                flags["elevated_inflammation"] = {"value": value, "target": "<1.0 mg/L"}

        # Homocysteine
        if "homocysteine" in name:
            if value > 10:
                flags["elevated_homocysteine"] = {"value": value, "target": "<10 umol/L"}

        # Omega-3 index
        if "omega" in name and "index" in name:
            if value < 8:
                flags["low_omega3_index"] = {"value": value, "target": "8-12%"}

    return flags


async def _get_applicable_protocols(pool, context: dict[str, Any]) -> list[dict[str, Any]]:
    """Fetch protocols from knowledge base that apply to the user's context."""
    applicable = []

    # Get all protocols with their supplements and interventions
    protocols = await pool.fetch(
        """
        SELECT p.id, p.name, p.category, p.description, p.frequency, p.evidence_level,
               e.name as expert_name
        FROM protocols p
        LEFT JOIN experts e ON p.expert_id = e.id
        ORDER BY
            CASE p.evidence_level
                WHEN 'high' THEN 1
                WHEN 'moderate' THEN 2
                WHEN 'low' THEN 3
                ELSE 4
            END,
            p.name
        LIMIT 50
        """
    )

    # Filter based on context
    bloodwork_flags = context.get("bloodwork_flags", {})
    recovery_status = "unknown"
    if context.get("wearable_data"):
        recovery = _assess_recovery(context["wearable_data"])
        recovery_status = recovery["status"]

    has_mthfr = context.get("mthfr_variant", False)
    has_apoe4 = context.get("apoe4_carrier", False)

    for p in protocols:
        relevance_score = 0
        relevance_reasons = []

        # Check if protocol matches user context
        category = p["category"]

        # Sleep protocols always relevant
        if category == "sleep":
            relevance_score += 1
            relevance_reasons.append("Core sleep optimization")

        # Training protocols - check recovery
        if category == "training":
            if recovery_status == "good":
                relevance_score += 2
                relevance_reasons.append("Good recovery supports training")
            elif recovery_status == "low":
                if "recovery" in p["name"].lower() or "rest" in p["name"].lower():
                    relevance_score += 2
                    relevance_reasons.append("Low recovery - rest protocol")

        # Supplement protocols - check bloodwork
        if category == "supplements" or category == "longevity":
            relevance_score += 1

            # MTHFR considerations
            if has_mthfr and "mthfr" in p["name"].lower():
                relevance_score += 3
                relevance_reasons.append("MTHFR variant detected")

            # Vitamin D protocol
            if "low_vitamin_d" in bloodwork_flags or "deficient_vitamin_d" in bloodwork_flags:
                if "vitamin d" in p["name"].lower() or "d3" in p["name"].lower():
                    relevance_score += 2
                    relevance_reasons.append("Low vitamin D levels")

            # Cardiovascular focus
            if "elevated_apob" in bloodwork_flags or "high_apob" in bloodwork_flags:
                if "cardio" in p["name"].lower() or "heart" in p["name"].lower() or "omega" in p["name"].lower():
                    relevance_score += 2
                    relevance_reasons.append("Elevated ApoB")

        # Interventions
        if category == "interventions":
            relevance_score += 1
            if recovery_status == "good" and "cold" in p["name"].lower():
                relevance_score += 1
                relevance_reasons.append("Good recovery for cold exposure")

        if relevance_score > 0:
            applicable.append({
                "name": p["name"],
                "category": p["category"],
                "description": p["description"],
                "expert": p["expert_name"],
                "evidence_level": p["evidence_level"],
                "relevance_score": relevance_score,
                "relevance_reasons": relevance_reasons,
            })

    # Sort by relevance and return top protocols
    applicable.sort(key=lambda x: x["relevance_score"], reverse=True)
    return applicable[:10]
