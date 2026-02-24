"""Chat routes: send messages, list conversations, fetch history."""

from __future__ import annotations

from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends

from app.models.schemas import ChatHistoryResponse, ChatMessageRequest, ChatMessageResponse
from app.security.auth import get_current_user
from app.services import chat_service

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("/message", response_model=ChatMessageResponse)
async def send_message(
    body: ChatMessageRequest,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> ChatMessageResponse:
    """Send a chat message and receive an AI response."""
    result = await chat_service.chat(
        user_id=current_user["id"],
        conversation_id=body.conversation_id,
        message=body.message,
        include_context=body.include_context,
    )
    return ChatMessageResponse(**result)


@router.get("/conversations")
async def list_conversations(
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[dict[str, Any]]:
    """List all conversations for the current user."""
    return await chat_service.get_conversations(current_user["id"])


@router.get("/conversations/{conversation_id}", response_model=ChatHistoryResponse)
async def get_conversation(
    conversation_id: UUID,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> ChatHistoryResponse:
    """Get full message history for a conversation."""
    messages = await chat_service.get_conversation_history(
        current_user["id"], conversation_id
    )
    return ChatHistoryResponse(
        conversation_id=str(conversation_id),
        messages=messages,
    )
