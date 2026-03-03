"""AI service - local Ollama by default, optional external APIs.

Supports:
- Local: Ollama (llama3.1, llava, etc.)
- External: Anthropic Claude, OpenAI GPT (requires user acknowledgment)
"""

from __future__ import annotations

import logging
from typing import Any
from uuid import UUID

import httpx

from app.config import get_settings
from app.models.database import get_pool
from app.models.schemas import AIInsightResponse, BloodworkMarker, OCRResponse
from app.security.encryption import decrypt_field, derive_key

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
    model: str | None = None,
) -> dict[str, Any]:
    """Call the AirLLM-compatible chat completions endpoint."""
    settings = get_settings()
    url = f"{settings.AIRLLM_BASE_URL.rstrip('/')}/chat/completions"
    model = model or settings.AIRLLM_MODEL

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


async def _get_user_ai_config(user_id: UUID | None) -> dict[str, Any]:
    """Get user's AI configuration preferences."""
    if not user_id:
        return {"use_local_only": True, "external_provider": None, "external_api_key": None}

    pool = get_pool()
    row = await pool.fetchrow(
        """
        SELECT use_local_only, external_provider, external_api_key,
               acknowledged_external_warning, preferred_model
        FROM ai_preferences
        WHERE user_id = $1
        """,
        user_id,
    )

    if not row:
        return {"use_local_only": True, "external_provider": None, "external_api_key": None}

    return dict(row)


async def _call_anthropic(
    messages: list[dict[str, str]],
    api_key: str,
    model: str = "claude-3-haiku-20240307",
    temperature: float = 0.5,
) -> dict[str, Any]:
    """Call Anthropic Claude API."""
    # Convert messages to Anthropic format
    system_message = None
    anthropic_messages = []

    for msg in messages:
        if msg["role"] == "system":
            system_message = msg["content"]
        else:
            anthropic_messages.append({
                "role": msg["role"],
                "content": msg["content"],
            })

    payload = {
        "model": model,
        "max_tokens": 4096,
        "temperature": temperature,
        "messages": anthropic_messages,
    }
    if system_message:
        payload["system"] = system_message

    async with httpx.AsyncClient(timeout=120.0) as client:
        resp = await client.post(
            "https://api.anthropic.com/v1/messages",
            json=payload,
            headers={
                "x-api-key": api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
        )
        resp.raise_for_status()
        data = resp.json()

        # Convert to OpenAI-compatible format
        return {
            "choices": [{
                "message": {
                    "role": "assistant",
                    "content": data["content"][0]["text"],
                }
            }],
            "model": data.get("model"),
            "usage": {
                "prompt_tokens": data.get("usage", {}).get("input_tokens"),
                "completion_tokens": data.get("usage", {}).get("output_tokens"),
            },
        }


async def _call_openai(
    messages: list[dict[str, str]],
    api_key: str,
    model: str = "gpt-4o-mini",
    temperature: float = 0.5,
) -> dict[str, Any]:
    """Call OpenAI API."""
    payload = {
        "model": model,
        "messages": messages,
        "temperature": temperature,
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        resp = await client.post(
            "https://api.openai.com/v1/chat/completions",
            json=payload,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
        )
        resp.raise_for_status()
        return resp.json()


async def _call_local_ollama(
    messages: list[dict[str, str]],
    model: str | None = None,
    temperature: float = 0.5,
) -> dict[str, Any]:
    """Call local Ollama API."""
    settings = get_settings()
    url = f"{settings.AIRLLM_BASE_URL.rstrip('/')}/chat/completions"
    model = model or settings.AIRLLM_MODEL

    payload = {
        "model": model,
        "messages": messages,
        "temperature": temperature,
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        resp = await client.post(url, json=payload)
        resp.raise_for_status()
        return resp.json()


async def chat_completion_multi(
    messages: list[dict[str, str]],
    temperature: float = 0.5,
    model: str | None = None,
    user_id: UUID | None = None,
    require_local: bool = False,
) -> dict[str, Any]:
    """
    Call the LLM with a full multi-turn message history.

    Routes to local or external AI based on user preferences.
    Falls back to local if external fails.

    Args:
        messages: Chat message history
        temperature: Sampling temperature
        model: Model override (optional)
        user_id: User ID for preference lookup (optional)
        require_local: Force local AI regardless of preferences
    """
    settings = get_settings()

    # Get user preferences if user_id provided
    config = await _get_user_ai_config(user_id) if user_id and not require_local else None

    # Determine which AI to use
    use_external = (
        config
        and not config.get("use_local_only", True)
        and config.get("external_api_key")
        and config.get("acknowledged_external_warning", False)
        and not require_local
    )

    if use_external:
        try:
            key = derive_key(settings.FIELD_ENCRYPTION_KEY)
            api_key = decrypt_field(config["external_api_key"], key)
            provider = config.get("external_provider", "anthropic")

            if provider == "anthropic":
                return await _call_anthropic(messages, api_key, model or "claude-3-haiku-20240307", temperature)
            elif provider == "openai":
                return await _call_openai(messages, api_key, model or "gpt-4o-mini", temperature)
            else:
                logger.warning(f"Unknown provider {provider}, falling back to local")
        except Exception as e:
            logger.warning(f"External AI failed ({e}), falling back to local")

    # Default: use local Ollama
    return await _call_local_ollama(messages, model, temperature)


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


async def _vision_completion(
    system_prompt: str,
    text_prompt: str,
    image_base64: str,
    model: str = "llava:7b",
) -> dict[str, Any]:
    """Call the Ollama-compatible chat completions endpoint with vision."""
    settings = get_settings()
    url = f"{settings.AIRLLM_BASE_URL.rstrip('/')}/chat/completions"

    # Build multimodal content for vision model
    user_content = [
        {"type": "text", "text": text_prompt},
        {
            "type": "image_url",
            "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"},
        },
    ]

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_content},
        ],
        "temperature": 0.1,
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        resp = await client.post(url, json=payload)
        resp.raise_for_status()
        return resp.json()


async def process_ocr_image(
    image_base64: str,
    lab_name: str | None = None,
) -> OCRResponse:
    """Process a bloodwork image through AI OCR using vision model.

    Uses llava to extract biomarkers from lab report images.
    """
    text_prompt = f"""Analyze this bloodwork/lab report image from {lab_name or 'an unknown lab'}.

Extract ALL biomarkers visible in the image. For each marker, provide:
- name: The biomarker name (e.g., "Glucose", "HDL Cholesterol", "TSH")
- value: The numeric value as a float
- unit: The unit of measurement (e.g., "mg/dL", "mmol/L")
- reference_low: Lower bound of normal range (null if not shown)
- reference_high: Upper bound of normal range (null if not shown)
- flag: "H" if high, "L" if low, null if normal or not indicated

Return your response as valid JSON with this exact structure:
{{"markers": [...], "raw_text": "all text visible in image", "confidence": 0.0-1.0}}

Be thorough - extract every single biomarker visible."""

    try:
        response = await _vision_completion(
            _OCR_SYSTEM_PROMPT,
            text_prompt,
            image_base64,
            model="llava:7b",
        )

        # Parse the response - vision models may not always return perfect JSON
        content = response["choices"][0]["message"]["content"]

        # Try to extract JSON from the response
        import re
        json_match = re.search(r'\{[\s\S]*\}', content)
        if json_match:
            import json as _json
            result = _json.loads(json_match.group())
        else:
            # Fallback: return raw text if JSON parsing fails
            return OCRResponse(
                markers=[],
                raw_text=content,
                confidence=0.3,
            )

        markers = [BloodworkMarker(**m) for m in result.get("markers", [])]
        return OCRResponse(
            markers=markers,
            raw_text=result.get("raw_text"),
            confidence=result.get("confidence", 0.8),
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
