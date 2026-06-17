"""User context / memory routes: goals doc + directives, plus chat extraction."""

from __future__ import annotations

import json
import logging
import re
import uuid
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.config import get_settings
from app.models.database import get_pool
from app.security.auth import get_current_user
from app.security.encryption import decrypt_field, derive_key, encrypt_field
from app.services.ai_service import chat_completion_multi
from app.services.context_service import load_user_context

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/context", tags=["context"])

VALID_CATEGORIES = {"supplement", "nutrition", "training", "sleep", "lifestyle", "goal", "other"}


def _key() -> bytes:
    return derive_key(get_settings().FIELD_ENCRYPTION_KEY)


class GoalsUpdate(BaseModel):
    goals_md: str = Field(default="", max_length=20000)


class DirectiveCreate(BaseModel):
    text: str = Field(..., min_length=1, max_length=500)
    category: str | None = None


class ExtractRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4000)


async def _ensure_row(pool: Any, user_id: Any) -> None:
    await pool.execute(
        "INSERT INTO user_context (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING",
        user_id,
    )


async def _get_directives(pool: Any, user_id: Any) -> list[dict[str, Any]]:
    row = await pool.fetchrow("SELECT directives FROM user_context WHERE user_id = $1", user_id)
    if not row or not row["directives"]:
        return []
    d = row["directives"]
    return json.loads(d) if isinstance(d, str) else d


async def _save_directives(pool: Any, user_id: Any, directives: list[dict[str, Any]]) -> None:
    await _ensure_row(pool, user_id)
    await pool.execute(
        "UPDATE user_context SET directives = $2::jsonb, updated_at = now() WHERE user_id = $1",
        user_id,
        json.dumps(directives),
    )


def _new_directive(text: str, category: str | None, source: str) -> dict[str, Any]:
    cat = category if category in VALID_CATEGORIES else None
    return {
        "id": str(uuid.uuid4()),
        "text": text.strip(),
        "category": cat,
        "source": source,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }


@router.get("")
async def get_context(current_user: dict[str, Any] = Depends(get_current_user)) -> dict[str, Any]:
    return await load_user_context(get_pool(), _key(), current_user["id"])


@router.put("")
async def update_goals(
    body: GoalsUpdate,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    pool = get_pool()
    enc = encrypt_field(body.goals_md, _key()) if body.goals_md else encrypt_field("", _key())
    await pool.execute(
        """
        INSERT INTO user_context (user_id, goals_md, updated_at)
        VALUES ($1, $2, now())
        ON CONFLICT (user_id) DO UPDATE SET goals_md = $2, updated_at = now()
        """,
        current_user["id"],
        enc,
    )
    return await load_user_context(pool, _key(), current_user["id"])


@router.post("/directives")
async def add_directive(
    body: DirectiveCreate,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    pool = get_pool()
    directives = await _get_directives(pool, current_user["id"])
    directives.append(_new_directive(body.text, body.category, "manual"))
    await _save_directives(pool, current_user["id"], directives)
    return {"directives": directives}


@router.delete("/directives/{directive_id}")
async def delete_directive(
    directive_id: str,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    pool = get_pool()
    directives = [d for d in await _get_directives(pool, current_user["id"]) if d.get("id") != directive_id]
    await _save_directives(pool, current_user["id"], directives)
    return {"directives": directives}


_EXTRACT_SYSTEM_PROMPT = """You extract durable health directives from a user's chat message.
Return ONLY JSON: {"directives": [{"text": str, "category": str}]}.
Allowed categories: supplement, nutrition, training, sleep, lifestyle, goal, other.
Include ONLY clear, persistent decisions/preferences/rules the user wants remembered going forward
(e.g. "no food after 7pm", "add creatine 5g daily", "training for a marathon in October", "stop caffeine after noon").
Do NOT include questions, greetings, one-off remarks, or things the user is merely asking about.
Rewrite each directive as a concise standing instruction. If there are none, return {"directives": []}."""


@router.post("/extract")
async def extract_directives(
    body: ExtractRequest,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    """Pull durable directives out of a chat message and persist new ones."""
    pool = get_pool()
    user_id = current_user["id"]

    try:
        resp = await chat_completion_multi(
            [
                {"role": "system", "content": _EXTRACT_SYSTEM_PROMPT},
                {"role": "user", "content": body.message},
            ],
            temperature=0.0,
            user_id=user_id,
            response_format={"type": "json_object"},
        )
        content = resp["choices"][0]["message"]["content"]
        match = re.search(r"\{[\s\S]*\}", content)
        parsed = json.loads(match.group()) if match else {}
        extracted = parsed.get("directives", []) if isinstance(parsed, dict) else []
    except Exception:
        logger.exception("Directive extraction failed")
        return {"added": []}

    existing = await _get_directives(pool, user_id)
    existing_texts = {(d.get("text") or "").strip().lower() for d in existing}

    added: list[dict[str, Any]] = []
    for item in extracted:
        if not isinstance(item, dict):
            continue
        text = (item.get("text") or "").strip()
        if not text or text.lower() in existing_texts:
            continue
        directive = _new_directive(text, item.get("category"), "chat")
        existing.append(directive)
        existing_texts.add(text.lower())
        added.append(directive)

    if added:
        await _save_directives(pool, user_id, existing)

    return {"added": added}
