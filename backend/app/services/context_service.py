"""User context / memory: free-form goals + structured directives the engine
reasons against. Loaded into the daily-plan and chat prompts."""

from __future__ import annotations

import json
from typing import Any
from uuid import UUID

from app.security.encryption import decrypt_field


async def load_user_context(pool: Any, key: bytes, user_id: UUID) -> dict[str, Any]:
    """Return {goals_md, directives} for a user (decrypted)."""
    row = await pool.fetchrow(
        "SELECT goals_md, directives FROM user_context WHERE user_id = $1",
        user_id,
    )
    if not row:
        return {"goals_md": "", "directives": []}

    goals = ""
    if row["goals_md"]:
        try:
            goals = decrypt_field(row["goals_md"], key)
        except Exception:  # noqa: BLE001
            goals = ""

    directives = row["directives"] or []
    if isinstance(directives, str):
        try:
            directives = json.loads(directives)
        except json.JSONDecodeError:
            directives = []

    return {"goals_md": goals, "directives": directives}


def format_context_block(ctx: dict[str, Any]) -> str:
    """Render the user's goals + directives as a prompt block."""
    parts: list[str] = []

    goals = (ctx.get("goals_md") or "").strip()
    if goals:
        parts.append("USER GOALS & FOCUS (written by the user):\n" + goals)

    directives = ctx.get("directives") or []
    if directives:
        lines = []
        for d in directives:
            text = (d.get("text") or "").strip()
            if not text:
                continue
            cat = d.get("category")
            lines.append(f"- {text}" + (f"  [{cat}]" if cat else ""))
        if lines:
            parts.append(
                "USER DIRECTIVES — these are standing rules the user has set and you MUST respect them "
                "(they override default recommendations, e.g. meal timing, excluded foods, supplement choices):\n"
                + "\n".join(lines)
            )

    return "\n\n".join(parts)
