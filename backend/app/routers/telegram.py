"""Telegram Bot webhook routes."""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel

from app.config import get_settings
from app.security.auth import get_current_user
from app.services.telegram_bot import (
    generate_link_code,
    get_morning_brief_for_telegram,
    get_user_by_telegram_id,
    handle_chat_message,
    handle_quick_log,
    handle_stats_command,
    unlink_telegram,
    verify_link_code,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/telegram", tags=["telegram"])


# ── Account Linking ──────────────────────────────────────────────────────────


@router.post("/link/generate")
async def generate_telegram_link_code(
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, str]:
    """Generate a one-time code to link Telegram account."""
    code = await generate_link_code(current_user["id"])
    return {
        "code": code,
        "instructions": f"Send this code to the Outlive bot on Telegram: /link {code}",
        "expires_in": "10 minutes",
    }


@router.post("/link/verify")
async def verify_telegram_link(
    code: str = Query(..., min_length=6, max_length=20),
    telegram_chat_id: int = Query(...),
) -> dict[str, Any]:
    """Verify a link code (called by Telegram bot webhook)."""
    user_id = await verify_link_code(code, telegram_chat_id)
    if user_id:
        return {"success": True, "user_id": str(user_id)}
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired link code",
        )


@router.post("/unlink")
async def unlink_telegram_account(
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, bool]:
    """Unlink Telegram from the current user's account."""
    success = await unlink_telegram(current_user["id"])
    return {"success": success}


@router.get("/status")
async def get_telegram_link_status(
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    """Check if Telegram is linked to the current user's account."""
    from app.models.database import get_pool

    pool = get_pool()
    row = await pool.fetchrow(
        "SELECT telegram_chat_id FROM users WHERE id = $1",
        current_user["id"],
    )
    is_linked = row and row["telegram_chat_id"] is not None
    return {
        "linked": is_linked,
        "chat_id": row["telegram_chat_id"] if is_linked else None,
    }


# ── Webhook (for Telegram Bot API) ───────────────────────────────────────────


class TelegramMessage(BaseModel):
    message_id: int
    chat: dict[str, Any]
    text: str | None = None
    from_user: dict[str, Any] | None = None

    class Config:
        extra = "allow"


class TelegramUpdate(BaseModel):
    update_id: int
    message: TelegramMessage | None = None

    class Config:
        extra = "allow"


@router.post("/webhook")
async def telegram_webhook(request: Request) -> dict[str, str]:
    """
    Webhook endpoint for Telegram Bot API.

    Set this up with:
    https://api.telegram.org/bot<TOKEN>/setWebhook?url=<YOUR_URL>/api/v1/telegram/webhook
    """
    settings = get_settings()

    try:
        data = await request.json()
        update = TelegramUpdate(**data)
    except Exception as e:
        logger.error(f"Failed to parse Telegram update: {e}")
        return {"status": "error"}

    if not update.message or not update.message.text:
        return {"status": "ok"}

    chat_id = update.message.chat.get("id")
    text = update.message.text.strip()

    if not chat_id:
        return {"status": "ok"}

    # Process commands
    response_text = await process_telegram_message(chat_id, text)

    # Send response back to Telegram
    if response_text:
        await send_telegram_message(chat_id, response_text)

    return {"status": "ok"}


async def process_telegram_message(chat_id: int, text: str) -> str | None:
    """Process a message from Telegram and return a response."""

    # /start command
    if text.startswith("/start"):
        user = await get_user_by_telegram_id(chat_id)
        if user:
            name = user.get("display_name", "there")
            return f"""👋 Welcome back, {name}!

*Commands:*
/brief - Get your morning brief
/stats - See today's stats
/log [activity] - Quick log (e.g., /log cold plunge)
/chat [message] - Chat with AI advisor
/unlink - Unlink this Telegram account

Just type anything to chat with your AI health advisor!"""
        else:
            return """👋 Welcome to Outlive Engine!

To get started, link your account:
1. Log in to your Outlive dashboard
2. Go to Settings > Telegram
3. Click "Generate Link Code"
4. Send me: /link YOUR_CODE

Example: /link ABC123"""

    # /link command
    if text.startswith("/link"):
        parts = text.split(maxsplit=1)
        if len(parts) < 2:
            return "❌ Please provide your link code: /link YOUR_CODE"

        code = parts[1].strip()
        user_id = await verify_link_code(code, chat_id)
        if user_id:
            return "✅ Success! Your Telegram is now linked to your Outlive account.\n\nTry /brief to get your morning health brief!"
        else:
            return "❌ Invalid or expired link code. Please generate a new one from your dashboard."

    # Check if user is linked for remaining commands
    user = await get_user_by_telegram_id(chat_id)
    if not user:
        return "❌ Please link your account first. Send /start for instructions."

    # /brief command
    if text.startswith("/brief"):
        result = await get_morning_brief_for_telegram(chat_id)
        if result:
            return result["text"]
        return "❌ Couldn't generate your brief. Please try again."

    # /stats command
    if text.startswith("/stats"):
        return await handle_stats_command(chat_id)

    # /log command
    if text.startswith("/log"):
        parts = text.split(maxsplit=1)
        if len(parts) < 2:
            return """📝 *Quick Log Examples:*
/log took supplements
/log cold plunge 3 min
/log 45 min workout
/log meditation"""
        return await handle_quick_log(chat_id, parts[1])

    # /chat command (explicit chat mode)
    if text.startswith("/chat"):
        parts = text.split(maxsplit=1)
        if len(parts) < 2:
            return "💬 What would you like to ask? Example: /chat Should I do cold exposure today?"
        return await handle_chat_message(chat_id, parts[1])

    # /unlink command
    if text.startswith("/unlink"):
        success = await unlink_telegram(user["id"])
        if success:
            return "✅ Your Telegram has been unlinked from your Outlive account."
        return "❌ Failed to unlink. Please try again."

    # /help command
    if text.startswith("/help"):
        return """*Outlive Engine Bot Commands:*

/brief - Get your personalized morning brief
/stats - See today's stats and adherence
/log [activity] - Quick log an activity
/chat [message] - Chat with AI advisor
/unlink - Unlink your Telegram account

*Quick Log Examples:*
/log took supplements
/log cold plunge
/log 45 min workout

*Chat Examples:*
/chat Should I exercise hard today?
/chat What supplements should I prioritize?

Or just type any message to chat with your AI health advisor!"""

    # Default: treat as chat message
    return await handle_chat_message(chat_id, text)


async def send_telegram_message(chat_id: int, text: str) -> bool:
    """Send a message via Telegram Bot API."""
    import httpx

    settings = get_settings()
    telegram_token = getattr(settings, "TELEGRAM_BOT_TOKEN", None)

    if not telegram_token:
        logger.warning("TELEGRAM_BOT_TOKEN not configured")
        return False

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"https://api.telegram.org/bot{telegram_token}/sendMessage",
                json={
                    "chat_id": chat_id,
                    "text": text,
                    "parse_mode": "Markdown",
                },
            )
            return response.status_code == 200
    except Exception as e:
        logger.error(f"Failed to send Telegram message: {e}")
        return False


# ── Manual Endpoints (for testing/admin) ─────────────────────────────────────


@router.post("/send-brief")
async def send_morning_brief_to_user(
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    """Manually trigger sending the morning brief to the linked Telegram account."""
    from app.models.database import get_pool

    pool = get_pool()
    row = await pool.fetchrow(
        "SELECT telegram_chat_id FROM users WHERE id = $1",
        current_user["id"],
    )

    if not row or not row["telegram_chat_id"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No Telegram account linked",
        )

    chat_id = int(row["telegram_chat_id"])
    result = await get_morning_brief_for_telegram(chat_id)

    if result:
        success = await send_telegram_message(chat_id, result["text"])
        return {"sent": success, "chat_id": chat_id}
    else:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate morning brief",
        )
