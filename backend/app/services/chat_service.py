"""Chat service — multi-turn conversation with health context."""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from typing import Any
from uuid import UUID, uuid4

from app.config import get_settings
from app.models.database import get_pool
from app.security.encryption import decrypt_field, derive_key, encrypt_field
from app.services.ai_service import chat_completion_multi

logger = logging.getLogger(__name__)

_CHAT_SYSTEM_PROMPT = """\
You are a longevity-focused health advisor embedded in the Outlive Engine app.
You help users understand their health data, protocols, and longevity strategies.

Guidelines:
- Be concise but thorough
- Cite specific data points when referencing the user's health context
- If you don't have enough data to answer, say so and suggest what data to add
- Focus on the "big four" longevity risks: cardiovascular, metabolic, neurodegenerative, cancer
- Do not provide specific medical diagnoses — recommend professional consultation for concerns
- You are running on a local model; keep responses focused and avoid excessive length
"""

MAX_HISTORY = 50


async def chat(
    user_id: UUID,
    conversation_id: UUID | None,
    message: str,
    include_context: bool = False,
) -> dict[str, Any]:
    """Process a chat message and return the assistant response."""
    pool = get_pool()
    settings = get_settings()
    key = derive_key(settings.FIELD_ENCRYPTION_KEY)

    if conversation_id is None:
        conversation_id = uuid4()

    # Load conversation history
    rows = await pool.fetch(
        "SELECT role, content FROM chat_messages "
        "WHERE user_id = $1 AND conversation_id = $2 "
        "ORDER BY created_at ASC LIMIT $3",
        user_id,
        conversation_id,
        MAX_HISTORY,
    )

    messages: list[dict[str, str]] = [{"role": "system", "content": _CHAT_SYSTEM_PROMPT}]

    # Optionally inject health context
    if include_context:
        context = await _build_chat_context(pool, key, user_id)
        if context:
            messages.append({
                "role": "system",
                "content": f"User health context:\n{json.dumps(context, default=str)}",
            })

    # Add conversation history
    for r in rows:
        messages.append({"role": r["role"], "content": decrypt_field(r["content"], key)})

    # Add the new user message
    messages.append({"role": "user", "content": message})

    # Call LLM
    try:
        response = await chat_completion_multi(messages, temperature=0.5)
        assistant_content = response["choices"][0]["message"]["content"]
        model_name = response.get("model", "unknown")
    except Exception:
        logger.exception("Chat completion failed")
        assistant_content = "I'm sorry, I'm having trouble connecting to the AI service right now. Please try again in a moment."
        model_name = None

    # Store both messages (encrypted)
    now = datetime.now(timezone.utc)
    encrypted_user = encrypt_field(message, key)
    encrypted_assistant = encrypt_field(assistant_content, key)

    await pool.executemany(
        "INSERT INTO chat_messages (user_id, conversation_id, role, content, created_at) "
        "VALUES ($1, $2, $3, $4, $5)",
        [
            (user_id, conversation_id, "user", encrypted_user, now),
            (user_id, conversation_id, "assistant", encrypted_assistant, now),
        ],
    )

    return {
        "conversation_id": str(conversation_id),
        "response": assistant_content,
        "model": model_name,
    }


async def get_conversations(user_id: UUID) -> list[dict[str, Any]]:
    """List distinct conversations for a user with their latest message timestamp."""
    pool = get_pool()
    rows = await pool.fetch(
        "SELECT conversation_id, MIN(created_at) AS started_at, MAX(created_at) AS last_message_at, COUNT(*) AS message_count "
        "FROM chat_messages WHERE user_id = $1 "
        "GROUP BY conversation_id ORDER BY last_message_at DESC",
        user_id,
    )
    return [
        {
            "conversation_id": str(r["conversation_id"]),
            "started_at": r["started_at"].isoformat(),
            "last_message_at": r["last_message_at"].isoformat(),
            "message_count": r["message_count"],
        }
        for r in rows
    ]


async def get_conversation_history(user_id: UUID, conversation_id: UUID) -> list[dict[str, Any]]:
    """Fetch full decrypted message history for a conversation."""
    pool = get_pool()
    settings = get_settings()
    key = derive_key(settings.FIELD_ENCRYPTION_KEY)

    rows = await pool.fetch(
        "SELECT id, role, content, created_at FROM chat_messages "
        "WHERE user_id = $1 AND conversation_id = $2 ORDER BY created_at ASC",
        user_id,
        conversation_id,
    )
    return [
        {
            "id": str(r["id"]),
            "role": r["role"],
            "content": decrypt_field(r["content"], key),
            "created_at": r["created_at"].isoformat(),
        }
        for r in rows
    ]


async def _build_chat_context(pool, key: bytes, user_id: UUID) -> dict[str, Any]:
    """Build a lightweight health context for chat."""
    context: dict[str, Any] = {}

    # Genomic risks
    rows = await pool.fetch(
        "SELECT risk_category, risk_level FROM genomic_profiles WHERE user_id = $1",
        user_id,
    )
    if rows:
        context["genomic_risks"] = [{"category": r["risk_category"], "level": r["risk_level"]} for r in rows]

    # Latest bloodwork date
    row = await pool.fetchrow(
        "SELECT panel_date FROM bloodwork_panels WHERE user_id = $1 AND deleted_at IS NULL ORDER BY panel_date DESC LIMIT 1",
        user_id,
    )
    if row:
        context["latest_bloodwork_date"] = str(row["panel_date"])

    # Today's wearable
    from datetime import date
    rows = await pool.fetch(
        "SELECT source, metrics_json FROM daily_wearable_data WHERE user_id = $1 AND date = $2",
        user_id,
        date.today(),
    )
    if rows:
        context["today_wearables"] = [
            {"source": r["source"], "metrics": json.loads(decrypt_field(r["metrics_json"], key))}
            for r in rows
        ]

    return context
