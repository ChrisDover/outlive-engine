"""Experiment CRUD routes with snapshot support."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from app.config import get_settings
from app.models.database import get_pool
from app.models.schemas import (
    ExperimentCreate,
    ExperimentResponse,
    ExperimentSnapshot,
    ExperimentUpdate,
)
from app.security.auth import get_current_user
from app.security.encryption import decrypt_field, derive_key, encrypt_field

router = APIRouter(prefix="/experiments", tags=["experiments"])


def _enc_key() -> bytes:
    return derive_key(get_settings().FIELD_ENCRYPTION_KEY)


def _row_to_response(row: Any, key: bytes) -> ExperimentResponse:
    metrics = (
        json.loads(decrypt_field(row["metrics_json"], key))
        if row["metrics_json"]
        else None
    )
    snapshots_raw = (
        json.loads(decrypt_field(row["snapshots_json"], key))
        if row["snapshots_json"]
        else []
    )
    snapshots = [ExperimentSnapshot(**s) for s in snapshots_raw]

    return ExperimentResponse(
        id=row["id"],
        user_id=row["user_id"],
        title=row["title"],
        hypothesis=row["hypothesis"],
        status=row["status"],
        start_date=row["start_date"],
        end_date=row["end_date"],
        metrics=metrics,
        snapshots=snapshots,
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


@router.get("", response_model=list[ExperimentResponse])
async def list_experiments(
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[ExperimentResponse]:
    """List all experiments for the current user."""
    pool = get_pool()
    key = _enc_key()

    rows = await pool.fetch(
        "SELECT id, user_id, title, hypothesis, status, start_date, end_date, "
        "metrics_json, snapshots_json, created_at, updated_at "
        "FROM experiments WHERE user_id = $1 AND deleted_at IS NULL "
        "ORDER BY created_at DESC",
        current_user["id"],
    )
    return [_row_to_response(r, key) for r in rows]


@router.post("", response_model=ExperimentResponse, status_code=status.HTTP_201_CREATED)
async def create_experiment(
    body: ExperimentCreate,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> ExperimentResponse:
    """Create a new experiment."""
    pool = get_pool()
    key = _enc_key()
    now = datetime.now(timezone.utc)

    enc_metrics = (
        encrypt_field(json.dumps(body.metrics), key) if body.metrics else None
    )

    row = await pool.fetchrow(
        """
        INSERT INTO experiments (user_id, title, hypothesis, start_date, end_date, metrics_json, snapshots_json, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $8)
        RETURNING id, user_id, title, hypothesis, status, start_date, end_date, metrics_json, snapshots_json, created_at, updated_at
        """,
        current_user["id"],
        body.title,
        body.hypothesis,
        body.start_date,
        body.end_date,
        enc_metrics,
        None,  # no snapshots yet
        now,
    )
    return _row_to_response(row, key)


@router.get("/{experiment_id}", response_model=ExperimentResponse)
async def get_experiment(
    experiment_id: UUID,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> ExperimentResponse:
    """Get a single experiment by ID."""
    pool = get_pool()
    key = _enc_key()

    row = await pool.fetchrow(
        "SELECT id, user_id, title, hypothesis, status, start_date, end_date, "
        "metrics_json, snapshots_json, created_at, updated_at "
        "FROM experiments WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL",
        experiment_id,
        current_user["id"],
    )
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Experiment not found")

    return _row_to_response(row, key)


@router.put("/{experiment_id}", response_model=ExperimentResponse)
async def update_experiment(
    experiment_id: UUID,
    body: ExperimentUpdate,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> ExperimentResponse:
    """Update an experiment."""
    pool = get_pool()
    key = _enc_key()
    now = datetime.now(timezone.utc)

    updates: dict[str, Any] = {}
    if body.title is not None:
        updates["title"] = body.title
    if body.hypothesis is not None:
        updates["hypothesis"] = body.hypothesis
    if body.status is not None:
        updates["status"] = body.status.value
    if body.end_date is not None:
        updates["end_date"] = body.end_date
    if body.metrics is not None:
        updates["metrics_json"] = encrypt_field(json.dumps(body.metrics), key)

    if not updates:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No fields to update",
        )

    set_clauses = ", ".join(f"{k} = ${i+3}" for i, k in enumerate(updates))
    values = list(updates.values())

    row = await pool.fetchrow(
        f"UPDATE experiments SET {set_clauses}, updated_at = ${len(values)+3} "
        f"WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL "
        f"RETURNING id, user_id, title, hypothesis, status, start_date, end_date, "
        f"metrics_json, snapshots_json, created_at, updated_at",
        experiment_id,
        current_user["id"],
        *values,
        now,
    )

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Experiment not found")

    return _row_to_response(row, key)


@router.delete("/{experiment_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_experiment(
    experiment_id: UUID,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> None:
    """Soft-delete an experiment."""
    pool = get_pool()
    result = await pool.execute(
        "UPDATE experiments SET deleted_at = $1 WHERE id = $2 AND user_id = $3 AND deleted_at IS NULL",
        datetime.now(timezone.utc),
        experiment_id,
        current_user["id"],
    )
    if result == "UPDATE 0":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Experiment not found")


@router.post("/{experiment_id}/snapshots", response_model=ExperimentResponse)
async def add_snapshot(
    experiment_id: UUID,
    body: ExperimentSnapshot,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> ExperimentResponse:
    """Append a snapshot to an experiment."""
    pool = get_pool()
    key = _enc_key()
    now = datetime.now(timezone.utc)

    row = await pool.fetchrow(
        "SELECT id, user_id, title, hypothesis, status, start_date, end_date, "
        "metrics_json, snapshots_json, created_at, updated_at "
        "FROM experiments WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL",
        experiment_id,
        current_user["id"],
    )
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Experiment not found")

    existing_snapshots: list[dict[str, Any]] = []
    if row["snapshots_json"]:
        existing_snapshots = json.loads(decrypt_field(row["snapshots_json"], key))

    existing_snapshots.append(body.model_dump(mode="json"))
    enc_snapshots = encrypt_field(json.dumps(existing_snapshots), key)

    updated_row = await pool.fetchrow(
        "UPDATE experiments SET snapshots_json = $1, updated_at = $2 "
        "WHERE id = $3 AND user_id = $4 "
        "RETURNING id, user_id, title, hypothesis, status, start_date, end_date, "
        "metrics_json, snapshots_json, created_at, updated_at",
        enc_snapshots,
        now,
        experiment_id,
        current_user["id"],
    )

    return _row_to_response(updated_row, key)
