"""Pydantic v2 request / response schemas mirroring the Swift domain models."""

from __future__ import annotations

from datetime import date, datetime
from enum import Enum
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


# ── Enums ─────────────────────────────────────────────────────────────────────

class GenomicRiskLevel(str, Enum):
    ELEVATED = "elevated"
    MODERATE = "moderate"
    NORMAL = "normal"
    REDUCED = "reduced"


class ExperimentStatus(str, Enum):
    ACTIVE = "active"
    COMPLETED = "completed"
    ABANDONED = "abandoned"


class SyncOperation(str, Enum):
    INSERT = "insert"
    UPDATE = "update"
    DELETE = "delete"


# ── Users ─────────────────────────────────────────────────────────────────────

class UserCreate(BaseModel):
    apple_user_id: str
    email: str | None = None
    display_name: str | None = None


class UserUpdate(BaseModel):
    email: str | None = None
    display_name: str | None = None


class WebUserCreate(BaseModel):
    email: str
    display_name: str | None = None
    web_user_id: str


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    apple_user_id: str | None = None
    email: str | None = None
    display_name: str | None = None
    created_at: datetime
    updated_at: datetime


# ── Auth ──────────────────────────────────────────────────────────────────────

class AppleAuthRequest(BaseModel):
    identity_token: str = Field(..., min_length=10)
    display_name: str | None = None


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str = Field(..., min_length=10)


class RevokeRequest(BaseModel):
    refresh_token: str = Field(..., min_length=10)


# ── Bloodwork ─────────────────────────────────────────────────────────────────

class BloodworkMarker(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    value: float
    unit: str = Field(..., min_length=1, max_length=50)
    reference_low: float | None = None
    reference_high: float | None = None
    flag: str | None = None  # H, L, or None

    @field_validator("name")
    @classmethod
    def strip_name(cls, v: str) -> str:
        return v.strip()


class BloodworkPanelCreate(BaseModel):
    panel_date: date
    lab_name: str | None = None
    markers: list[BloodworkMarker] = Field(..., min_length=1)
    notes: str | None = None


class BloodworkPanelResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    panel_date: date
    lab_name: str | None = None
    markers: list[BloodworkMarker]
    notes: str | None = None
    created_at: datetime
    updated_at: datetime


# ── Wearables ─────────────────────────────────────────────────────────────────

class WearableDataCreate(BaseModel):
    date: date
    source: str = Field(..., min_length=1, max_length=100)
    metrics: dict[str, Any]

    @field_validator("source")
    @classmethod
    def normalise_source(cls, v: str) -> str:
        return v.strip().lower()


class WearableDataBatchCreate(BaseModel):
    entries: list[WearableDataCreate] = Field(..., min_length=1, max_length=365)


class WearableDataResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    date: date
    source: str
    metrics: dict[str, Any]
    created_at: datetime
    updated_at: datetime


# ── Genomics ──────────────────────────────────────────────────────────────────

class GenomicRiskCategory(BaseModel):
    risk_category: str = Field(..., min_length=1, max_length=100)
    risk_level: GenomicRiskLevel
    summary: str | None = None
    metadata: dict[str, Any] | None = None


class GenomicRiskResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    risk_category: str
    risk_level: GenomicRiskLevel
    summary: str | None = None
    metadata: dict[str, Any] | None = None
    updated_at: datetime


class GenomicRiskUpdate(BaseModel):
    risks: list[GenomicRiskCategory] = Field(..., min_length=1)


# ── Daily Protocols ───────────────────────────────────────────────────────────

class DailyProtocolResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    date: date
    protocol: dict[str, Any]
    created_at: datetime
    updated_at: datetime


class ProtocolSourceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    source_name: str
    enabled: bool
    priority: int
    config: dict[str, Any] | None = None
    updated_at: datetime


class ProtocolSourceUpdate(BaseModel):
    enabled: bool | None = None
    priority: int | None = None
    config: dict[str, Any] | None = None


# ── Experiments ───────────────────────────────────────────────────────────────

class ExperimentCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=500)
    hypothesis: str | None = None
    start_date: date
    end_date: date | None = None
    metrics: dict[str, Any] | None = None


class ExperimentUpdate(BaseModel):
    title: str | None = None
    hypothesis: str | None = None
    status: ExperimentStatus | None = None
    end_date: date | None = None
    metrics: dict[str, Any] | None = None


class ExperimentSnapshot(BaseModel):
    date: date
    notes: str | None = None
    measurements: dict[str, Any] = Field(default_factory=dict)


class ExperimentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    title: str
    hypothesis: str | None = None
    status: ExperimentStatus
    start_date: date
    end_date: date | None = None
    metrics: dict[str, Any] | None = None
    snapshots: list[ExperimentSnapshot] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime


# ── Sync ──────────────────────────────────────────────────────────────────────

class SyncChange(BaseModel):
    entity_type: str
    entity_id: UUID
    operation: SyncOperation
    payload: dict[str, Any] | None = None
    vector_clock: dict[str, int]
    device_id: str


class SyncRequest(BaseModel):
    changes: list[SyncChange] = Field(default_factory=list)
    last_pulled_at: datetime | None = None
    device_id: str = Field(..., min_length=1)


class SyncResponse(BaseModel):
    changes: list[SyncChange] = Field(default_factory=list)
    current_timestamp: datetime
    conflicts: list[dict[str, Any]] = Field(default_factory=list)


# ── AI ────────────────────────────────────────────────────────────────────────

class AIInsightRequest(BaseModel):
    context: dict[str, Any] = Field(default_factory=dict)
    question: str | None = None


class AIInsightResponse(BaseModel):
    insights: list[str]
    model: str | None = None
    usage: dict[str, Any] | None = None


class OCRRequest(BaseModel):
    image_base64: str = Field(..., min_length=10)
    lab_name: str | None = None


class OCRResponse(BaseModel):
    markers: list[BloodworkMarker]
    raw_text: str | None = None
    confidence: float | None = None
