"""AI service wrapping AirLLM via an OpenAI-compatible API."""

from __future__ import annotations

import logging
from typing import Any
from uuid import UUID

import httpx

from app.config import get_settings
from app.models.schemas import AIInsightResponse, BloodworkMarker, OCRResponse

logger = logging.getLogger(__name__)

_INSIGHT_SYSTEM_PROMPT = """\
You are a longevity-focused health advisor embedded in the Outlive Engine app.
Analyze the user's health data and provide concise, actionable insights.
Focus on cardiovascular, metabolic, neurodegenerative, and cancer risk factors.
Always cite which data points led to each insight.
Return your answer as a JSON object with a single key "insights" containing a list of strings.
"""

_EXPERIMENT_SYSTEM_PROMPT = """\
You are a longevity experiment analyst.  Given the experiment data including
hypothesis, tracked metrics, and snapshots over time, provide a brief analysis
of trends and whether the hypothesis is supported.
Return your answer as a JSON object with a single key "insights" containing a list of strings.
"""

_OCR_SYSTEM_PROMPT = """\
You are a medical lab report OCR processor.  Given a base64-encoded image of a
bloodwork panel, extract each biomarker with its name, value, unit, and reference range.
Return your answer as a JSON object with keys:
  "markers": [{{"name": str, "value": float, "unit": str, "reference_low": float|null, "reference_high": float|null, "flag": str|null}}],
  "raw_text": str,
  "confidence": float
"""


async def _chat_completion(
    system_prompt: str,
    user_message: str,
    model: str = "gpt-4o",
) -> dict[str, Any]:
    """Call the AirLLM-compatible chat completions endpoint."""
    settings = get_settings()
    url = f"{settings.AIRLLM_BASE_URL.rstrip('/')}/chat/completions"

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message},
        ],
        "temperature": 0.3,
        "response_format": {"type": "json_object"},
    }

    async with httpx.AsyncClient(timeout=60.0) as client:
        resp = await client.post(url, json=payload)
        resp.raise_for_status()
        return resp.json()


async def analyze_with_ai(
    user_id: UUID,
    context: dict[str, Any],
    question: str | None = None,
) -> AIInsightResponse:
    """Generate health insights from user data context."""
    user_message_parts = [f"User data context:\n{context}"]
    if question:
        user_message_parts.append(f"\nSpecific question: {question}")
    user_message = "\n".join(user_message_parts)

    try:
        result = _parse_completion(
            await _chat_completion(_INSIGHT_SYSTEM_PROMPT, user_message)
        )
        return AIInsightResponse(
            insights=result.get("insights", []),
            model=result.get("model"),
            usage=result.get("usage"),
        )
    except Exception:
        logger.exception("AI insight generation failed, returning fallback")
        return AIInsightResponse(
            insights=["AI service is temporarily unavailable. Please try again later."],
            model=None,
            usage=None,
        )


async def analyze_experiment(experiment_data: dict[str, Any]) -> AIInsightResponse:
    """Analyze experiment data for trends and hypothesis validation."""
    user_message = f"Experiment data:\n{experiment_data}"

    try:
        result = _parse_completion(
            await _chat_completion(_EXPERIMENT_SYSTEM_PROMPT, user_message)
        )
        return AIInsightResponse(
            insights=result.get("insights", []),
            model=result.get("model"),
            usage=result.get("usage"),
        )
    except Exception:
        logger.exception("AI experiment analysis failed, returning fallback")
        return AIInsightResponse(
            insights=["AI service is temporarily unavailable. Please try again later."],
            model=None,
            usage=None,
        )


async def process_ocr_image(
    image_base64: str,
    lab_name: str | None = None,
) -> OCRResponse:
    """Process a bloodwork image through AI OCR.

    This is a placeholder that delegates to the AI model's vision
    capabilities.  When the AI service is unavailable it returns an
    empty result rather than crashing.
    """
    user_message = f"Lab: {lab_name or 'unknown'}\nImage (base64): {image_base64[:200]}..."

    try:
        result = _parse_completion(
            await _chat_completion(_OCR_SYSTEM_PROMPT, user_message)
        )
        markers = [BloodworkMarker(**m) for m in result.get("markers", [])]
        return OCRResponse(
            markers=markers,
            raw_text=result.get("raw_text"),
            confidence=result.get("confidence"),
        )
    except Exception:
        logger.exception("OCR processing failed, returning empty result")
        return OCRResponse(markers=[], raw_text=None, confidence=None)


def _parse_completion(response: dict[str, Any]) -> dict[str, Any]:
    """Extract the parsed JSON content from a chat completion response."""
    import json as _json

    content = response["choices"][0]["message"]["content"]
    parsed = _json.loads(content)
    parsed["model"] = response.get("model")
    parsed["usage"] = response.get("usage")
    return parsed
