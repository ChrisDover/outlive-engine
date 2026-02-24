"""Pydantic v2 request / response schemas mirroring the Swift domain models."""

from __future__ import annotations

from datetime import date, datetime
from enum import Enum
from typing import Any
from uuid import UUID

import re

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

    @field_validator("web_user_id")
    @classmethod
    def validate_cuid(cls, v: str) -> str:
        if not re.match(r"^c[a-z0-9]{24}$", v):
            raise ValueError("web_user_id must be a valid CUID")
        return v


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


class GenomeUploadResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    source: str
    filename: str | None
    variant_count: int
    status: str
    error_message: str | None = None
    created_at: datetime
    completed_at: datetime | None = None


class GenomicVariantResponse(BaseModel):
    rsid: str
    chromosome: str
    position: int
    genotype: str
    source: str


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


# ── Body Composition ─────────────────────────────────────────────────────────

_NUMERIC_BODY_FIELDS = {"weight", "body_fat_pct", "lean_mass", "waist"}


class BodyCompositionCreate(BaseModel):
    date: date
    metrics: dict[str, Any]  # weight, body_fat_pct, lean_mass, waist, etc.

    @field_validator("metrics")
    @classmethod
    def validate_metrics(cls, v: dict[str, Any]) -> dict[str, Any]:
        for key in _NUMERIC_BODY_FIELDS & v.keys():
            if not isinstance(v[key], (int, float)):
                raise ValueError(f"{key} must be a number")
        return v


class BodyCompositionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    date: date
    metrics: dict[str, Any]
    created_at: datetime
    updated_at: datetime


# ── AI ────────────────────────────────────────────────────────────────────────

class AIInsightRequest(BaseModel):
    context: dict[str, Any] = Field(default_factory=dict)
    question: str | None = None


class AIInsightResponse(BaseModel):
    insights: list[str]
    model: str | None = None
    usage: dict[str, Any] | None = None


# ── Chat ─────────────────────────────────────────────────────────────────────

class ChatMessageRequest(BaseModel):
    conversation_id: UUID | None = None
    message: str = Field(..., min_length=1, max_length=10000)
    include_context: bool = False


class ChatMessageResponse(BaseModel):
    conversation_id: str
    response: str
    model: str | None = None


class ChatMessage(BaseModel):
    id: str
    role: str
    content: str
    created_at: str


class ChatHistoryResponse(BaseModel):
    conversation_id: str
    messages: list[dict[str, Any]]


class OCRRequest(BaseModel):
    image_base64: str = Field(..., min_length=10)
    lab_name: str | None = None


class OCRResponse(BaseModel):
    markers: list[BloodworkMarker]
    raw_text: str | None = None
    confidence: float | None = None
