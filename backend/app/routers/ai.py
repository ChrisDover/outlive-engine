"""AI routes: insights generation and OCR processing."""

from __future__ import annotations

import base64
import json
import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse

from app.models.schemas import (
    AIInsightRequest,
    AIInsightResponse,
    OCRRequest,
    OCRResponse,
)
from app.security.auth import get_current_user
from app.services.ai_service import analyze_with_ai, stream_chat_insight

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/insights", response_model=AIInsightResponse)
async def generate_insights(
    body: AIInsightRequest,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> AIInsightResponse:
    """Generate AI-powered health insights from user data."""
    result = await analyze_with_ai(
        user_id=current_user["id"],
        context=body.context,
        question=body.question,
    )
    return result


@router.post("/insights/stream")
async def stream_insights(
    body: AIInsightRequest,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> StreamingResponse:
    """Stream conversational health insights as Server-Sent Events."""

    async def event_generator():
        try:
            async for delta in stream_chat_insight(
                user_id=current_user["id"],
                context=body.context,
                question=body.question,
            ):
                yield f"data: {json.dumps({'delta': delta})}\n\n"
        except Exception:
            logger.exception("Streaming insight failed")
            yield f"data: {json.dumps({'error': 'stream_failed'})}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.post("/ocr", response_model=OCRResponse)
async def process_ocr(
    body: OCRRequest,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> OCRResponse:
    """
    Process a bloodwork image via OCR and return extracted markers.

    Uses a robust multi-stage pipeline:
    1. Image preprocessing (enhance contrast, deskew)
    2. Tesseract OCR for text extraction
    3. LLM parsing for structured biomarkers
    4. Vision model fallback if text OCR fails
    """
    from app.services.ocr_service import process_single_file

    try:
        # Decode base64 image
        image_data = body.image_base64
        if "," in image_data:
            image_data = image_data.split(",")[1]

        file_bytes = base64.b64decode(image_data)

        # Process through OCR pipeline
        result = await process_single_file(
            file_bytes=file_bytes,
            filename="uploaded_image",
            content_type="image/png",
        )

        return result

    except Exception as e:
        logger.exception("OCR processing failed")
        return OCRResponse(
            markers=[],
            raw_text=None,
            confidence=0.0,
        )
