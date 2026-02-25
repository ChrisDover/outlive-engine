"""Bloodwork panel CRUD routes with bulk OCR upload support."""

from __future__ import annotations

import json
import logging
from datetime import date, datetime, timezone
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, UploadFile, status
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.config import get_settings
from app.models.database import get_pool
from app.models.schemas import (
    BloodworkPanelCreate,
    BloodworkPanelResponse,
    BulkOCRFileResult,
    BulkOCRResponse,
)
from app.security.auth import get_current_user
from app.security.encryption import decrypt_field, derive_key, encrypt_field

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/bloodwork", tags=["bloodwork"])
limiter = Limiter(key_func=get_remote_address)


def _enc_key() -> bytes:
    return derive_key(get_settings().FIELD_ENCRYPTION_KEY)


def _row_to_response(row: Any, key: bytes) -> BloodworkPanelResponse:
    markers = json.loads(decrypt_field(row["markers_json"], key))
    notes = decrypt_field(row["notes"], key) if row["notes"] else None
    return BloodworkPanelResponse(
        id=row["id"],
        user_id=row["user_id"],
        panel_date=row["panel_date"],
        lab_name=row["lab_name"],
        markers=markers,
        notes=notes,
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


@router.get("", response_model=list[BloodworkPanelResponse])
async def list_panels(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[BloodworkPanelResponse]:
    """List bloodwork panels for the current user, newest first."""
    pool = get_pool()
    key = _enc_key()

    rows = await pool.fetch(
        "SELECT id, user_id, panel_date, lab_name, markers_json, notes, created_at, updated_at "
        "FROM bloodwork_panels WHERE user_id = $1 AND deleted_at IS NULL "
        "ORDER BY panel_date DESC LIMIT $2 OFFSET $3",
        current_user["id"],
        limit,
        offset,
    )
    return [_row_to_response(r, key) for r in rows]


@router.post("", response_model=BloodworkPanelResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("60/minute")
async def create_panel(
    request: Request,
    body: BloodworkPanelCreate,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> BloodworkPanelResponse:
    """Create a new bloodwork panel."""
    pool = get_pool()
    key = _enc_key()
    now = datetime.now(timezone.utc)

    enc_markers = encrypt_field(
        json.dumps([m.model_dump() for m in body.markers]), key
    )
    enc_notes = encrypt_field(body.notes, key) if body.notes else None

    row = await pool.fetchrow(
        """
        INSERT INTO bloodwork_panels (user_id, panel_date, lab_name, markers_json, notes, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $6)
        RETURNING id, user_id, panel_date, lab_name, markers_json, notes, created_at, updated_at
        """,
        current_user["id"],
        body.panel_date,
        body.lab_name,
        enc_markers,
        enc_notes,
        now,
    )
    return _row_to_response(row, key)


@router.get("/{panel_id}", response_model=BloodworkPanelResponse)
async def get_panel(
    panel_id: UUID,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> BloodworkPanelResponse:
    """Get a single bloodwork panel by ID."""
    pool = get_pool()
    key = _enc_key()

    row = await pool.fetchrow(
        "SELECT id, user_id, panel_date, lab_name, markers_json, notes, created_at, updated_at "
        "FROM bloodwork_panels WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL",
        panel_id,
        current_user["id"],
    )
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Panel not found")

    return _row_to_response(row, key)


@router.delete("/{panel_id}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("60/minute")
async def delete_panel(
    request: Request,
    panel_id: UUID,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> None:
    """Soft-delete a bloodwork panel."""
    pool = get_pool()
    result = await pool.execute(
        "UPDATE bloodwork_panels SET deleted_at = $1 WHERE id = $2 AND user_id = $3 AND deleted_at IS NULL",
        datetime.now(timezone.utc),
        panel_id,
        current_user["id"],
    )
    if result == "UPDATE 0":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Panel not found")


@router.delete("", status_code=status.HTTP_200_OK)
@limiter.limit("10/minute")
async def bulk_delete_panels(
    request: Request,
    panel_ids: list[UUID] = Query(..., description="List of panel IDs to delete"),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, int]:
    """Bulk soft-delete multiple bloodwork panels."""
    pool = get_pool()
    now = datetime.now(timezone.utc)

    deleted = 0
    for panel_id in panel_ids:
        result = await pool.execute(
            "UPDATE bloodwork_panels SET deleted_at = $1 WHERE id = $2 AND user_id = $3 AND deleted_at IS NULL",
            now,
            panel_id,
            current_user["id"],
        )
        if result != "UPDATE 0":
            deleted += 1

    return {"deleted": deleted}


@router.get("/trends/{marker_name}")
async def get_marker_trends(
    marker_name: str,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[dict[str, Any]]:
    """Get historical values for a specific marker across all panels."""
    pool = get_pool()
    key = _enc_key()

    rows = await pool.fetch(
        "SELECT id, panel_date, markers_json FROM bloodwork_panels "
        "WHERE user_id = $1 AND deleted_at IS NULL "
        "ORDER BY panel_date ASC",
        current_user["id"],
    )

    trends = []
    marker_name_lower = marker_name.lower()

    for row in rows:
        markers = json.loads(decrypt_field(row["markers_json"], key))
        for marker in markers:
            if marker.get("name", "").lower() == marker_name_lower:
                trends.append({
                    "date": row["panel_date"].isoformat(),
                    "value": marker.get("value"),
                    "unit": marker.get("unit", ""),
                    "flag": marker.get("flag"),
                    "reference_low": marker.get("reference_low"),
                    "reference_high": marker.get("reference_high"),
                    "panel_id": str(row["id"]),
                })
                break

    return trends


@router.get("/markers/unique")
async def get_unique_markers(
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[dict[str, Any]]:
    """Get list of unique markers across all panels with counts."""
    pool = get_pool()
    key = _enc_key()

    rows = await pool.fetch(
        "SELECT markers_json FROM bloodwork_panels "
        "WHERE user_id = $1 AND deleted_at IS NULL",
        current_user["id"],
    )

    marker_counts: dict[str, dict] = {}

    for row in rows:
        markers = json.loads(decrypt_field(row["markers_json"], key))
        for marker in markers:
            name = marker.get("name", "").strip()
            if not name:
                continue
            name_lower = name.lower()
            if name_lower not in marker_counts:
                marker_counts[name_lower] = {
                    "name": name,
                    "count": 0,
                    "unit": marker.get("unit", ""),
                }
            marker_counts[name_lower]["count"] += 1

    # Sort by count descending
    return sorted(marker_counts.values(), key=lambda x: x["count"], reverse=True)


# ── Bulk OCR Upload ──────────────────────────────────────────────────────────


@router.post("/upload", response_model=BulkOCRResponse)
@limiter.limit("10/minute")
async def bulk_upload_bloodwork(
    request: Request,
    files: list[UploadFile] = File(..., description="PDF or image files of lab reports"),
    panel_date: date = Form(default=None, description="Date for all panels (defaults to today)"),
    lab_name: str = Form(default=None, description="Lab name for all panels"),
    auto_save: bool = Form(default=True, description="Automatically save extracted panels"),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> BulkOCRResponse:
    """
    Bulk upload bloodwork files (PDF or images) for OCR extraction.

    Supports:
    - Multiple files at once
    - PDF files (extracts all pages)
    - Image files (PNG, JPG, etc.)

    The OCR pipeline:
    1. Preprocesses images (enhance contrast, deskew)
    2. Uses Tesseract for text extraction
    3. Uses LLM to parse biomarkers from text
    4. Falls back to vision model if text OCR fails

    Set auto_save=true to automatically create bloodwork panels.
    """
    from app.services.ocr_service import process_single_file

    if not files:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No files provided",
        )

    # Validate file count
    if len(files) > 20:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Maximum 20 files per upload",
        )

    results: list[BulkOCRFileResult] = []
    successful = 0
    failed = 0
    total_markers = 0

    panel_date_value = panel_date or date.today()
    pool = get_pool()
    key = _enc_key()
    now = datetime.now(timezone.utc)

    for upload_file in files:
        filename = upload_file.filename or "unknown"
        content_type = upload_file.content_type or ""

        # Validate file type
        valid_types = [
            "application/pdf",
            "image/png",
            "image/jpeg",
            "image/jpg",
            "image/gif",
            "image/webp",
            "image/tiff",
        ]
        is_valid = (
            content_type in valid_types
            or filename.lower().endswith((".pdf", ".png", ".jpg", ".jpeg", ".gif", ".webp", ".tiff"))
        )

        if not is_valid:
            results.append(BulkOCRFileResult(
                filename=filename,
                success=False,
                error=f"Unsupported file type: {content_type}",
            ))
            failed += 1
            continue

        try:
            # Read file bytes
            file_bytes = await upload_file.read()

            # Validate file size (max 50MB)
            if len(file_bytes) > 50 * 1024 * 1024:
                results.append(BulkOCRFileResult(
                    filename=filename,
                    success=False,
                    error="File too large (max 50MB)",
                ))
                failed += 1
                continue

            logger.info(f"Processing file: {filename} ({len(file_bytes)} bytes)")

            # Process with OCR
            ocr_result = await process_single_file(file_bytes, filename, content_type)

            if not ocr_result.markers:
                results.append(BulkOCRFileResult(
                    filename=filename,
                    success=False,
                    markers=[],
                    raw_text=ocr_result.raw_text,
                    confidence=ocr_result.confidence,
                    error="No markers could be extracted. The image may be unclear or not contain lab results.",
                ))
                failed += 1
                continue

            # Auto-save if requested
            panel_id = None
            if auto_save:
                enc_markers = encrypt_field(
                    json.dumps([m.model_dump() for m in ocr_result.markers]), key
                )
                row = await pool.fetchrow(
                    """
                    INSERT INTO bloodwork_panels (user_id, panel_date, lab_name, markers_json, notes, created_at, updated_at)
                    VALUES ($1, $2, $3, $4, $5, $6, $6)
                    RETURNING id
                    """,
                    current_user["id"],
                    panel_date_value,
                    lab_name,
                    enc_markers,
                    encrypt_field(f"Extracted from {filename}", key),
                    now,
                )
                panel_id = row["id"]

            results.append(BulkOCRFileResult(
                filename=filename,
                success=True,
                markers=ocr_result.markers,
                raw_text=ocr_result.raw_text,
                confidence=ocr_result.confidence,
                panel_id=panel_id,
            ))
            successful += 1
            total_markers += len(ocr_result.markers)

        except Exception as e:
            logger.exception(f"Failed to process {filename}")
            results.append(BulkOCRFileResult(
                filename=filename,
                success=False,
                error=str(e),
            ))
            failed += 1

    return BulkOCRResponse(
        total_files=len(files),
        successful=successful,
        failed=failed,
        total_markers=total_markers,
        results=results,
    )
