"""AI routes: insights generation and OCR placeholder."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status

from app.models.schemas import (
    AIInsightRequest,
    AIInsightResponse,
    OCRRequest,
    OCRResponse,
)
from app.security.auth import get_current_user
from app.services.ai_service import analyze_with_ai, process_ocr_image

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


@router.post("/ocr", response_model=OCRResponse)
async def process_ocr(
    body: OCRRequest,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> OCRResponse:
    """Process a bloodwork image via OCR and return extracted markers."""
    result = await process_ocr_image(
        image_base64=body.image_base64,
        lab_name=body.lab_name,
    )
    return result
