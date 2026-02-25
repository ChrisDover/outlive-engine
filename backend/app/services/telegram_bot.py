"""Telegram Bot service for Outlive Engine."""

from __future__ import annotations

import logging
import secrets
from datetime import date, datetime, timezone
from typing import Any
from uuid import UUID

from app.config import get_settings
from app.models.database import get_pool
from app.security.encryption import decrypt_field, derive_key, encrypt_field
from app.services.daily_plan_service import generate_morning_brief
from app.services.chat_service import chat

logger = logging.getLogger(__name__)

# Store pending link codes (in production, use Redis)
_pending_link_codes: dict[str, dict[str, Any]] = {}


async def generate_link_code(user_id: UUID) -> str:
    """Generate a one-time code to link Telegram account."""
    code = secrets.token_hex(4).upper()  # 8-character hex code
    _pending_link_codes[code] = {
        "user_id": user_id,
        "created_at": datetime.now(timezone.utc),
    }
    return code


async def verify_link_code(code: str, telegram_chat_id: int) -> UUID | None:
    """Verify a link code and associate the Telegram chat ID with a user."""
    code = code.upper().strip()
    if code not in _pending_link_codes:
        return None

    link_data = _pending_link_codes.pop(code)
    user_id = link_data["user_id"]

    # Store the Telegram chat ID in the database
    pool = get_pool()
    await pool.execute(
        """
        UPDATE users SET
            telegram_chat_id = $2,
            updated_at = $3
        WHERE id = $1
        """,
        user_id,
        str(telegram_chat_id),
        datetime.now(timezone.utc),
    )

    return user_id


async def get_user_by_telegram_id(telegram_chat_id: int) -> dict[str, Any] | None:
    """Get user by their linked Telegram chat ID."""
    pool = get_pool()
    row = await pool.fetchrow(
        "SELECT id, email, display_name, telegram_chat_id FROM users WHERE telegram_chat_id = $1",
        str(telegram_chat_id),
    )
    if row:
        return {
            "id": row["id"],
            "email": row["email"],
            "display_name": row["display_name"],
            "telegram_chat_id": row["telegram_chat_id"],
        }
    return None


async def unlink_telegram(user_id: UUID) -> bool:
    """Unlink Telegram from a user account."""
    pool = get_pool()
    result = await pool.execute(
        """
        UPDATE users SET telegram_chat_id = NULL, updated_at = $2
        WHERE id = $1
        """,
        user_id,
        datetime.now(timezone.utc),
    )
    return result != "UPDATE 0"


async def get_morning_brief_for_telegram(telegram_chat_id: int) -> dict[str, Any] | None:
    """Get formatted morning brief for Telegram delivery."""
    user = await get_user_by_telegram_id(telegram_chat_id)
    if not user:
        return None

    brief = await generate_morning_brief(user["id"], date.today())

    # Format for Telegram (with markdown)
    formatted = format_brief_for_telegram(brief, user.get("display_name"))
    return {
        "text": formatted,
        "brief": brief,
    }


def format_brief_for_telegram(brief: dict[str, Any], name: str | None = None) -> str:
    """Format a morning brief for Telegram message."""
    lines = []

    # Header
    day_name = date.today().strftime("%A")
    lines.append(f"*Good morning{', ' + name if name else ''}!*")
    lines.append(f"_{day_name}, {date.today().strftime('%B %d')}_")
    lines.append("")

    # Recovery Status
    recovery = brief.get("recovery_status", {})
    status = recovery.get("status", "unknown").upper()
    status_emoji = {"good": "🟢", "moderate": "🟡", "low": "🔴", "unknown": "⚪"}.get(
        recovery.get("status", "unknown"), "⚪"
    )
    lines.append(f"{status_emoji} *Recovery:* {status}")

    if recovery.get("hrv"):
        lines.append(f"   HRV: {recovery['hrv']}ms")
    if recovery.get("sleep_hours"):
        lines.append(f"   Sleep: {recovery['sleep_hours']:.1f}h")
    lines.append("")

    # Greeting (abbreviated for Telegram)
    greeting = brief.get("greeting", "")
    if len(greeting) > 500:
        greeting = greeting[:500] + "..."
    lines.append(greeting)
    lines.append("")

    # Top Priorities
    lines.append("*Today's Focus:*")
    for i, priority in enumerate(brief.get("top_priorities", []), 1):
        lines.append(f"{i}. {priority}")
    lines.append("")

    # Supplements (abbreviated)
    supplements = brief.get("supplement_plan", [])
    if supplements:
        lines.append("*Supplements:*")
        for supp in supplements[:5]:  # Show first 5
            lines.append(f"• {supp['name']} {supp.get('dose', '')}{supp.get('unit', '')}")
        if len(supplements) > 5:
            lines.append(f"  _{len(supplements) - 5} more..._")
        lines.append("")

    # Training
    workout = brief.get("workout_plan", {})
    if workout.get("type"):
        lines.append("*Training:*")
        lines.append(f"• {workout['type']} - {workout.get('duration', 45)} min")
        lines.append("")

    # Expert citations
    citations = brief.get("expert_citations", [])
    if citations:
        lines.append(f"_Protocols: {', '.join(citations[:3])}_")

    return "\n".join(lines)


async def handle_quick_log(telegram_chat_id: int, message: str) -> str:
    """Handle quick logging from Telegram."""
    user = await get_user_by_telegram_id(telegram_chat_id)
    if not user:
        return "❌ Your Telegram is not linked to an Outlive account. Use /start to link."

    pool = get_pool()
    now = datetime.now(timezone.utc)
    today = date.today()

    # Parse the message for common patterns
    message_lower = message.lower()
    logged_items = []

    # Check for supplements
    if any(kw in message_lower for kw in ["supplement", "vitamin", "took", "pills"]):
        await pool.execute(
            """
            INSERT INTO daily_adherence (user_id, date, item_type, item_name, completed, notes, created_at)
            VALUES ($1, $2, 'supplement', 'Daily supplements', true, $3, $4)
            ON CONFLICT (user_id, date, item_type, item_name) DO UPDATE SET completed = true, notes = EXCLUDED.notes
            """,
            user["id"],
            today,
            message,
            now,
        )
        logged_items.append("Supplements ✓")

    # Check for workout
    if any(kw in message_lower for kw in ["workout", "exercise", "training", "gym", "run", "lift"]):
        await pool.execute(
            """
            INSERT INTO daily_adherence (user_id, date, item_type, item_name, completed, notes, created_at)
            VALUES ($1, $2, 'training', 'Workout', true, $3, $4)
            ON CONFLICT (user_id, date, item_type, item_name) DO UPDATE SET completed = true, notes = EXCLUDED.notes
            """,
            user["id"],
            today,
            message,
            now,
        )
        logged_items.append("Training ✓")

    # Check for interventions
    interventions = [
        ("cold plunge", "Cold plunge"),
        ("cold shower", "Cold shower"),
        ("sauna", "Sauna"),
        ("meditation", "Meditation"),
        ("breathwork", "Breathwork"),
    ]
    for keyword, name in interventions:
        if keyword in message_lower:
            await pool.execute(
                """
                INSERT INTO daily_adherence (user_id, date, item_type, item_name, completed, notes, created_at)
                VALUES ($1, $2, 'intervention', $3, true, $4, $5)
                ON CONFLICT (user_id, date, item_type, item_name) DO UPDATE SET completed = true
                """,
                user["id"],
                today,
                name,
                message,
                now,
            )
            logged_items.append(f"{name} ✓")

    if logged_items:
        return f"✅ Logged: {', '.join(logged_items)}"
    else:
        # Generic log
        await pool.execute(
            """
            INSERT INTO daily_adherence (user_id, date, item_type, item_name, completed, notes, created_at)
            VALUES ($1, $2, 'intervention', 'Activity', true, $3, $4)
            ON CONFLICT (user_id, date, item_type, item_name) DO UPDATE SET completed = true, notes = EXCLUDED.notes
            """,
            user["id"],
            today,
            message,
            now,
        )
        return f"✅ Logged: {message}"


async def handle_chat_message(telegram_chat_id: int, message: str) -> str:
    """Handle a chat message from Telegram."""
    user = await get_user_by_telegram_id(telegram_chat_id)
    if not user:
        return "❌ Your Telegram is not linked to an Outlive account. Use /start to link."

    try:
        response = await chat(
            user_id=user["id"],
            conversation_id=None,  # Start new conversation for Telegram
            message=message,
            include_context=True,
        )
        return response.get("response", "I couldn't process that. Please try again.")
    except Exception as e:
        logger.exception("Telegram chat error")
        return "❌ Sorry, I'm having trouble right now. Please try again later."


async def handle_stats_command(telegram_chat_id: int) -> str:
    """Get quick stats for Telegram."""
    user = await get_user_by_telegram_id(telegram_chat_id)
    if not user:
        return "❌ Your Telegram is not linked to an Outlive account. Use /start to link."

    pool = get_pool()
    settings = get_settings()
    key = derive_key(settings.FIELD_ENCRYPTION_KEY)
    today = date.today()

    # Get today's adherence
    adherence = await pool.fetch(
        "SELECT item_type, item_name, completed FROM daily_adherence WHERE user_id = $1 AND date = $2",
        user["id"],
        today,
    )
    completed = len([a for a in adherence if a["completed"]])
    total = len(adherence)

    # Get wearable data
    wearable = await pool.fetchrow(
        "SELECT metrics_json FROM daily_wearable_data WHERE user_id = $1 AND date = $2 LIMIT 1",
        user["id"],
        today,
    )

    lines = [f"*📊 Today's Stats*", ""]

    if wearable:
        import json
        metrics = json.loads(decrypt_field(wearable["metrics_json"], key))
        if "hrv" in metrics:
            lines.append(f"💓 HRV: {metrics['hrv']}ms")
        if "sleep_hours" in metrics or "total_sleep" in metrics:
            sleep = metrics.get("sleep_hours") or metrics.get("total_sleep", 0) / 60
            lines.append(f"😴 Sleep: {sleep:.1f}h")
        if "recovery_score" in metrics:
            lines.append(f"🔋 Recovery: {metrics['recovery_score']}%")
        lines.append("")

    lines.append(f"*Adherence:* {completed}/{total} items")
    if adherence:
        for a in adherence[:5]:
            status = "✅" if a["completed"] else "⬜"
            lines.append(f"  {status} {a['item_name']}")
        if len(adherence) > 5:
            lines.append(f"  _...and {len(adherence) - 5} more_")

    return "\n".join(lines)
