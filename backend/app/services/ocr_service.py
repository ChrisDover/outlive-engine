"""Robust OCR service for bloodwork extraction.

Uses a multi-stage pipeline:
1. PDF/Image preprocessing (enhance, deskew, resize)
2. Tesseract OCR for raw text extraction
3. LLM parsing for structured biomarker extraction
4. Fallback to vision model if text OCR fails
"""

from __future__ import annotations

import base64
import io
import json
import logging
import re
from dataclasses import dataclass
from typing import Any

import fitz  # PyMuPDF
import httpx
import pytesseract
from PIL import Image, ImageEnhance, ImageFilter, ImageOps

from app.config import get_settings
from app.models.schemas import BloodworkMarker, OCRResponse

logger = logging.getLogger(__name__)

# Common biomarker name variations for normalization
MARKER_ALIASES: dict[str, str] = {
    "wbc": "White Blood Cells",
    "rbc": "Red Blood Cells",
    "hgb": "Hemoglobin",
    "hb": "Hemoglobin",
    "hct": "Hematocrit",
    "plt": "Platelets",
    "mcv": "MCV",
    "mch": "MCH",
    "mchc": "MCHC",
    "rdw": "RDW",
    "mpv": "MPV",
    "glucose": "Glucose",
    "gluc": "Glucose",
    "fasting glucose": "Glucose (Fasting)",
    "bun": "BUN",
    "creatinine": "Creatinine",
    "creat": "Creatinine",
    "egfr": "eGFR",
    "sodium": "Sodium",
    "na": "Sodium",
    "potassium": "Potassium",
    "k": "Potassium",
    "chloride": "Chloride",
    "cl": "Chloride",
    "co2": "CO2",
    "carbon dioxide": "CO2",
    "calcium": "Calcium",
    "ca": "Calcium",
    "total protein": "Total Protein",
    "albumin": "Albumin",
    "alb": "Albumin",
    "globulin": "Globulin",
    "a/g ratio": "A/G Ratio",
    "bilirubin": "Bilirubin Total",
    "total bilirubin": "Bilirubin Total",
    "direct bilirubin": "Bilirubin Direct",
    "alkaline phosphatase": "Alkaline Phosphatase",
    "alk phos": "Alkaline Phosphatase",
    "alp": "Alkaline Phosphatase",
    "ast": "AST",
    "sgot": "AST",
    "alt": "ALT",
    "sgpt": "ALT",
    "ggt": "GGT",
    "ldh": "LDH",
    "cholesterol": "Total Cholesterol",
    "total cholesterol": "Total Cholesterol",
    "hdl": "HDL Cholesterol",
    "hdl cholesterol": "HDL Cholesterol",
    "ldl": "LDL Cholesterol",
    "ldl cholesterol": "LDL Cholesterol",
    "ldl-c": "LDL Cholesterol",
    "triglycerides": "Triglycerides",
    "trig": "Triglycerides",
    "vldl": "VLDL",
    "apob": "ApoB",
    "apolipoprotein b": "ApoB",
    "lp(a)": "Lp(a)",
    "lipoprotein(a)": "Lp(a)",
    "lipoprotein a": "Lp(a)",
    "tsh": "TSH",
    "t3": "T3",
    "free t3": "Free T3",
    "t4": "T4",
    "free t4": "Free T4",
    "ft4": "Free T4",
    "ft3": "Free T3",
    "hemoglobin a1c": "HbA1c",
    "hba1c": "HbA1c",
    "a1c": "HbA1c",
    "glycated hemoglobin": "HbA1c",
    "insulin": "Insulin",
    "fasting insulin": "Insulin (Fasting)",
    "homa-ir": "HOMA-IR",
    "c-reactive protein": "CRP",
    "crp": "CRP",
    "hs-crp": "hs-CRP",
    "high sensitivity crp": "hs-CRP",
    "homocysteine": "Homocysteine",
    "ferritin": "Ferritin",
    "iron": "Iron",
    "tibc": "TIBC",
    "transferrin saturation": "Transferrin Saturation",
    "vitamin d": "Vitamin D",
    "25-hydroxy vitamin d": "Vitamin D",
    "vitamin d, 25-oh": "Vitamin D",
    "vitamin b12": "Vitamin B12",
    "b12": "Vitamin B12",
    "folate": "Folate",
    "folic acid": "Folate",
    "magnesium": "Magnesium",
    "mg": "Magnesium",
    "zinc": "Zinc",
    "testosterone": "Testosterone",
    "total testosterone": "Testosterone Total",
    "free testosterone": "Testosterone Free",
    "estradiol": "Estradiol",
    "e2": "Estradiol",
    "dhea-s": "DHEA-S",
    "dhea sulfate": "DHEA-S",
    "cortisol": "Cortisol",
    "psa": "PSA",
    "uric acid": "Uric Acid",
    "fibrinogen": "Fibrinogen",
    "d-dimer": "D-Dimer",
}


@dataclass
class OCRJob:
    """Represents an OCR processing job for tracking."""
    filename: str
    status: str  # pending, processing, completed, failed
    markers: list[BloodworkMarker]
    raw_text: str | None
    confidence: float | None
    error: str | None


def preprocess_image(img: Image.Image, strategy: str = "standard") -> Image.Image:
    """Preprocess image for better OCR accuracy.

    Args:
        img: Input PIL Image
        strategy: Preprocessing strategy - "standard", "high_contrast", or "photo"
    """
    # Convert to RGB if necessary
    if img.mode not in ("RGB", "L"):
        img = img.convert("RGB")

    # Resize if too small (OCR works better on larger images)
    min_dimension = 1500  # Increased for better OCR
    if min(img.size) < min_dimension:
        scale = min_dimension / min(img.size)
        new_size = (int(img.size[0] * scale), int(img.size[1] * scale))
        img = img.resize(new_size, Image.LANCZOS)

    # Also resize if too large (can cause memory issues)
    max_dimension = 4000
    if max(img.size) > max_dimension:
        scale = max_dimension / max(img.size)
        new_size = (int(img.size[0] * scale), int(img.size[1] * scale))
        img = img.resize(new_size, Image.LANCZOS)

    # Convert to grayscale for OCR
    if img.mode == "RGB":
        gray = ImageOps.grayscale(img)
    else:
        gray = img

    if strategy == "standard":
        # Standard preprocessing for clean scans/PDFs
        enhancer = ImageEnhance.Contrast(gray)
        gray = enhancer.enhance(1.5)

        enhancer = ImageEnhance.Sharpness(gray)
        gray = enhancer.enhance(1.5)

    elif strategy == "high_contrast":
        # For low-contrast or faded documents
        enhancer = ImageEnhance.Contrast(gray)
        gray = enhancer.enhance(2.5)

        enhancer = ImageEnhance.Brightness(gray)
        gray = enhancer.enhance(1.2)

        enhancer = ImageEnhance.Sharpness(gray)
        gray = enhancer.enhance(2.0)

    elif strategy == "photo":
        # For photos of documents (handles shadows, uneven lighting)
        # First, try to normalize the lighting
        enhancer = ImageEnhance.Brightness(gray)
        gray = enhancer.enhance(1.1)

        enhancer = ImageEnhance.Contrast(gray)
        gray = enhancer.enhance(2.0)

        # Reduce noise from camera
        gray = gray.filter(ImageFilter.MedianFilter(size=3))

        enhancer = ImageEnhance.Sharpness(gray)
        gray = enhancer.enhance(2.5)

    # Apply adaptive-like thresholding for cleaner text
    # Use a moderate threshold that works for most documents
    threshold = 128
    gray = gray.point(lambda x: 255 if x > threshold else 0, mode='L')

    return gray


def preprocess_image_multi_strategy(img: Image.Image) -> list[Image.Image]:
    """Try multiple preprocessing strategies and return all versions."""
    strategies = ["standard", "high_contrast", "photo"]
    return [preprocess_image(img.copy(), strategy) for strategy in strategies]


def extract_text_tesseract(img: Image.Image) -> str:
    """Extract text using Tesseract OCR with multiple preprocessing strategies.

    Tries multiple approaches and returns the best result (most text extracted).
    """
    best_text = ""
    best_length = 0

    # Try different preprocessing strategies
    strategies = ["standard", "high_contrast", "photo"]

    # Also try different PSM modes
    # PSM 3: Fully automatic page segmentation (default)
    # PSM 4: Assume a single column of text
    # PSM 6: Assume a single uniform block of text
    psm_modes = [3, 6, 4]

    for strategy in strategies:
        try:
            processed = preprocess_image(img.copy(), strategy)

            for psm in psm_modes:
                try:
                    # OEM 3: Use both legacy and LSTM engines
                    config = f'--oem 3 --psm {psm}'
                    text = pytesseract.image_to_string(processed, config=config)
                    text = text.strip()

                    # Score based on length and presence of numbers (lab reports have lots of numbers)
                    has_numbers = sum(1 for c in text if c.isdigit())
                    score = len(text) + (has_numbers * 2)  # Bonus for numeric content

                    if score > best_length:
                        best_length = score
                        best_text = text
                        logger.debug(f"Better OCR result with strategy={strategy}, psm={psm}: {len(text)} chars, {has_numbers} digits")

                except Exception as e:
                    logger.debug(f"Tesseract failed with strategy={strategy}, psm={psm}: {e}")
                    continue

        except Exception as e:
            logger.debug(f"Preprocessing failed with strategy={strategy}: {e}")
            continue

    if not best_text:
        # Last resort: try with no preprocessing
        try:
            best_text = pytesseract.image_to_string(img).strip()
        except Exception as e:
            logger.error(f"All Tesseract attempts failed: {e}")
            best_text = ""

    logger.info(f"Tesseract extracted {len(best_text)} characters (best of {len(strategies) * len(psm_modes)} attempts)")
    return best_text


def pdf_to_images(pdf_bytes: bytes) -> list[Image.Image]:
    """Convert PDF pages to images."""
    images = []
    try:
        doc = fitz.open(stream=pdf_bytes, filetype="pdf")
        for page_num in range(len(doc)):
            page = doc[page_num]
            # Render at 2x resolution for better OCR
            mat = fitz.Matrix(2, 2)
            pix = page.get_pixmap(matrix=mat)
            img_data = pix.tobytes("png")
            img = Image.open(io.BytesIO(img_data))
            images.append(img)
        doc.close()
    except Exception as e:
        logger.error(f"PDF conversion failed: {e}")
        raise ValueError(f"Could not process PDF: {e}")
    return images


def base64_to_image(base64_data: str) -> Image.Image:
    """Convert base64 string to PIL Image."""
    # Handle data URL format
    if "," in base64_data:
        base64_data = base64_data.split(",")[1]

    img_bytes = base64.b64decode(base64_data)
    return Image.open(io.BytesIO(img_bytes))


def normalize_marker_name(name: str) -> str:
    """Normalize a biomarker name to a standard form."""
    name_lower = name.lower().strip()
    return MARKER_ALIASES.get(name_lower, name.strip())


async def parse_markers_with_llm(raw_text: str) -> tuple[list[BloodworkMarker], float]:
    """Use LLM to extract structured biomarker data from OCR text."""
    settings = get_settings()
    url = f"{settings.AIRLLM_BASE_URL.rstrip('/')}/chat/completions"
    model = settings.AIRLLM_MODEL

    system_prompt = """You are an expert at extracting biomarker data from lab report text. Your job is to find and extract ALL biomarkers/test results from the text, even if the OCR quality is imperfect.

IMPORTANT RULES:
1. Extract EVERY test result you can identify, even partial ones
2. For each biomarker, provide:
   - name: The biomarker name (use full standard names when possible)
   - value: The numeric result (must be a number)
   - unit: The unit of measurement (can be empty string if not visible)
   - reference_low: Lower bound of reference range (null if not shown)
   - reference_high: Upper bound of reference range (null if not shown)
   - flag: "H" if high/abnormal high, "L" if low/abnormal low, null otherwise

3. Common biomarker patterns to look for:
   - CBC: WBC, RBC, Hemoglobin, Hematocrit, Platelets, MCV, MCH, MCHC, RDW
   - Metabolic Panel: Glucose, BUN, Creatinine, Sodium, Potassium, Chloride, CO2, Calcium
   - Liver: AST, ALT, ALP, Bilirubin, Albumin, Total Protein
   - Lipids: Total Cholesterol, HDL, LDL, Triglycerides, VLDL, ApoB, Lp(a)
   - Thyroid: TSH, T3, T4, Free T3, Free T4
   - Diabetes: Glucose, HbA1c, Insulin
   - Inflammation: CRP, hs-CRP, ESR
   - Vitamins: Vitamin D, Vitamin B12, Folate
   - Iron: Iron, Ferritin, TIBC, Transferrin Saturation
   - Hormones: Testosterone, Estradiol, DHEA-S, Cortisol

4. Reference range formats to recognize:
   - "70-100", "70 - 100", "(70-100)", "[70-100]"
   - "< 100" means reference_high = 100
   - "> 40" means reference_low = 40
   - Some labs show ranges in separate columns

5. Flag indicators to recognize:
   - "H", "HIGH", "*", "↑" = flag "H"
   - "L", "LOW", "↓" = flag "L"
   - Text like "ABNORMAL" next to a value

Return ONLY valid JSON: {"markers": [...], "confidence": 0.0-1.0}
If no markers found: {"markers": [], "confidence": 0.0}"""

    user_message = f"""Extract all biomarkers from this lab report text. Look carefully for any test results even if the text is noisy from OCR:

---
{raw_text}
---

Return JSON with all markers found and a confidence score (0.0-1.0) based on text quality."""

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message},
        ],
        "temperature": 0.1,
    }

    try:
        async with httpx.AsyncClient(timeout=90.0) as client:
            resp = await client.post(url, json=payload)
            resp.raise_for_status()
            result = resp.json()

        content = result["choices"][0]["message"]["content"]
        logger.debug(f"LLM response content: {content[:500]}...")

        # Try to extract JSON from response (LLM might include extra text)
        json_match = re.search(r'\{[\s\S]*\}', content)
        if not json_match:
            logger.warning(f"No JSON found in LLM response: {content[:200]}")
            return [], 0.0

        parsed = json.loads(json_match.group())

        markers = []
        for m in parsed.get("markers", []):
            try:
                # Normalize the marker name
                name = normalize_marker_name(m.get("name", ""))
                if not name:
                    continue

                # Parse value - handle string numbers
                value = m.get("value")
                if isinstance(value, str):
                    # Remove any non-numeric chars except . and -
                    value = re.sub(r'[^\d.\-]', '', value)
                    value = float(value) if value else None

                if value is None:
                    continue

                marker = BloodworkMarker(
                    name=name,
                    value=float(value),
                    unit=m.get("unit", ""),
                    reference_low=float(m["reference_low"]) if m.get("reference_low") is not None else None,
                    reference_high=float(m["reference_high"]) if m.get("reference_high") is not None else None,
                    flag=m.get("flag"),
                )
                markers.append(marker)
            except (ValueError, TypeError, KeyError) as e:
                logger.debug(f"Skipping invalid marker {m}: {e}")
                continue

        confidence = parsed.get("confidence", 0.8 if markers else 0.0)
        return markers, confidence

    except httpx.TimeoutException:
        logger.error("LLM parsing timed out after 90s")
        return [], 0.0
    except json.JSONDecodeError as e:
        logger.error(f"LLM returned invalid JSON: {e}")
        return [], 0.0
    except Exception as e:
        logger.exception(f"LLM parsing failed: {type(e).__name__}: {e}")
        return [], 0.0


def extract_markers_regex(raw_text: str) -> list[BloodworkMarker]:
    """Fallback regex-based marker extraction when LLM fails."""
    markers = []

    # Common patterns for lab results
    # Pattern: Name followed by value and optional unit
    # e.g., "Glucose 95 mg/dL", "HDL 55", "HbA1c 5.4 %"
    patterns = [
        # Pattern 1: Name Value Unit [Reference]
        r'(?P<name>[A-Za-z][A-Za-z0-9\s\-\(\)]+?)\s+(?P<value>\d+\.?\d*)\s*(?P<unit>[a-zA-Z/%]+(?:/[a-zA-Z]+)?)?(?:\s*[\[\(]?\s*(?P<ref_low>\d+\.?\d*)\s*[-–]\s*(?P<ref_high>\d+\.?\d*)\s*[\]\)]?)?',
        # Pattern 2: Name: Value
        r'(?P<name>[A-Za-z][A-Za-z0-9\s\-]+?):\s*(?P<value>\d+\.?\d*)\s*(?P<unit>[a-zA-Z/%]+)?',
    ]

    # Known biomarker names to look for
    known_markers = {
        'glucose', 'hdl', 'ldl', 'cholesterol', 'triglycerides', 'hemoglobin', 'hematocrit',
        'wbc', 'rbc', 'platelets', 'creatinine', 'bun', 'sodium', 'potassium', 'chloride',
        'calcium', 'albumin', 'protein', 'bilirubin', 'ast', 'alt', 'alp', 'ggt',
        'tsh', 'hba1c', 'a1c', 'insulin', 'ferritin', 'iron', 'vitamin d', 'b12',
        'testosterone', 'estradiol', 'cortisol', 'crp', 'homocysteine', 'apob', 'lp(a)',
        'egfr', 'mcv', 'mch', 'mchc', 'rdw', 'mpv', 'uric acid', 'magnesium', 'zinc',
        'folate', 'dhea', 'vldl', 'fibrinogen',
    }

    lines = raw_text.split('\n')
    for line in lines:
        line = line.strip()
        if not line:
            continue

        for pattern in patterns:
            match = re.search(pattern, line, re.IGNORECASE)
            if match:
                name = match.group('name').strip()
                name_lower = name.lower()

                # Check if this looks like a biomarker
                is_known = any(known in name_lower for known in known_markers)
                if not is_known and len(name) < 3:
                    continue

                try:
                    value = float(match.group('value'))
                    unit = match.group('unit') or '' if 'unit' in match.groupdict() else ''
                    ref_low = float(match.group('ref_low')) if match.group('ref_low') else None
                    ref_high = float(match.group('ref_high')) if match.group('ref_high') else None

                    # Normalize marker name
                    normalized_name = normalize_marker_name(name)

                    marker = BloodworkMarker(
                        name=normalized_name,
                        value=value,
                        unit=unit,
                        reference_low=ref_low,
                        reference_high=ref_high,
                        flag=None,
                    )
                    markers.append(marker)
                    break  # Found a match for this line
                except (ValueError, AttributeError):
                    continue

    # Deduplicate by name
    seen = set()
    unique_markers = []
    for m in markers:
        if m.name.lower() not in seen:
            seen.add(m.name.lower())
            unique_markers.append(m)

    return unique_markers


async def process_image_ocr(img: Image.Image, use_vision_fallback: bool = True) -> tuple[list[BloodworkMarker], str | None, float]:
    """Process a single image through the OCR pipeline."""

    # Step 1: Extract text with Tesseract
    raw_text = extract_text_tesseract(img)
    logger.info(f"Tesseract extracted {len(raw_text)} characters")

    markers: list[BloodworkMarker] = []
    confidence = 0.0

    # Step 2: If we got meaningful text, parse with LLM
    if len(raw_text) > 50:  # Arbitrary threshold for "meaningful" text
        markers, confidence = await parse_markers_with_llm(raw_text)
        logger.info(f"LLM extracted {len(markers)} markers with confidence {confidence}")

    # Step 3: If LLM failed, try regex-based extraction
    if not markers and len(raw_text) > 50:
        logger.info("LLM failed, trying regex extraction")
        markers = extract_markers_regex(raw_text)
        if markers:
            confidence = 0.5  # Lower confidence for regex extraction
            logger.info(f"Regex extracted {len(markers)} markers")

    # Step 4: If still no markers, try vision model as last resort
    if not markers and use_vision_fallback:
        logger.info("Falling back to vision model")
        markers, _, confidence = await process_with_vision(img)

    return markers, raw_text, confidence


async def process_with_vision(img: Image.Image) -> tuple[list[BloodworkMarker], str | None, float]:
    """Use vision model for direct image-to-markers extraction."""
    settings = get_settings()
    url = f"{settings.AIRLLM_BASE_URL.rstrip('/')}/chat/completions"

    # Convert image to base64
    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    img_base64 = base64.b64encode(buffer.getvalue()).decode()

    system_prompt = """You are an expert at reading lab reports and bloodwork panels.
Extract ALL biomarkers visible in this image.

For each biomarker provide:
- name: The biomarker name
- value: The numeric value
- unit: The unit of measurement
- reference_low: Lower bound of normal range (null if not shown)
- reference_high: Upper bound of normal range (null if not shown)
- flag: "H" if high, "L" if low, null otherwise

Return ONLY valid JSON: {"markers": [...], "raw_text": "all visible text", "confidence": 0.0-1.0}"""

    user_content = [
        {"type": "text", "text": "Extract all biomarkers from this lab report image. Return as JSON."},
        {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{img_base64}"}},
    ]

    payload = {
        "model": "llava:7b",
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_content},
        ],
        "temperature": 0.1,
    }

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            resp = await client.post(url, json=payload)
            resp.raise_for_status()
            result = resp.json()

        content = result["choices"][0]["message"]["content"]

        # Try to extract JSON from response
        json_match = re.search(r'\{[\s\S]*\}', content)
        if json_match:
            parsed = json.loads(json_match.group())
            markers = [BloodworkMarker(**m) for m in parsed.get("markers", [])]
            return markers, parsed.get("raw_text"), parsed.get("confidence", 0.5)

        return [], content, 0.3

    except httpx.TimeoutException:
        logger.error("Vision model timed out after 120s")
        return [], None, 0.0
    except json.JSONDecodeError as e:
        logger.error(f"Vision model returned invalid JSON: {e}")
        return [], None, 0.0
    except Exception as e:
        logger.exception(f"Vision model failed: {type(e).__name__}: {e}")
        return [], None, 0.0


async def process_single_file(
    file_bytes: bytes,
    filename: str,
    content_type: str,
) -> OCRResponse:
    """Process a single file (PDF or image) and extract biomarkers."""

    all_markers: list[BloodworkMarker] = []
    all_text_parts: list[str] = []
    total_confidence = 0.0
    page_count = 0

    try:
        # Handle PDF
        if content_type == "application/pdf" or filename.lower().endswith(".pdf"):
            images = pdf_to_images(file_bytes)
            logger.info(f"Processing PDF with {len(images)} pages")

            for i, img in enumerate(images):
                markers, raw_text, confidence = await process_image_ocr(img)
                all_markers.extend(markers)
                if raw_text:
                    all_text_parts.append(f"--- Page {i+1} ---\n{raw_text}")
                total_confidence += confidence
                page_count += 1

        # Handle image
        else:
            img = Image.open(io.BytesIO(file_bytes))
            markers, raw_text, confidence = await process_image_ocr(img)
            all_markers.extend(markers)
            if raw_text:
                all_text_parts.append(raw_text)
            total_confidence = confidence
            page_count = 1

        # Deduplicate markers by name (keep highest confidence/latest)
        seen_markers: dict[str, BloodworkMarker] = {}
        for marker in all_markers:
            key = marker.name.lower()
            seen_markers[key] = marker

        final_markers = list(seen_markers.values())
        avg_confidence = total_confidence / page_count if page_count > 0 else 0.0

        return OCRResponse(
            markers=final_markers,
            raw_text="\n\n".join(all_text_parts) if all_text_parts else None,
            confidence=round(avg_confidence, 2),
        )

    except Exception as e:
        logger.exception(f"OCR processing failed for {filename}")
        return OCRResponse(
            markers=[],
            raw_text=None,
            confidence=0.0,
        )


async def process_bulk_files(
    files: list[tuple[bytes, str, str]],  # (bytes, filename, content_type)
) -> list[OCRResponse]:
    """Process multiple files and return results for each."""
    results = []
    for file_bytes, filename, content_type in files:
        logger.info(f"Processing file: {filename}")
        result = await process_single_file(file_bytes, filename, content_type)
        results.append(result)
    return results
