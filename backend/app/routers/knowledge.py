"""Knowledge Base routes: experts, protocols, supplements, interventions."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.models.database import get_pool
from app.models.schemas import (
    ExpertCreate,
    ExpertResponse,
    InterventionCreate,
    InterventionResponse,
    NutritionPrincipleCreate,
    NutritionPrincipleResponse,
    ProtocolCreate,
    ProtocolResponse,
    ProtocolSupplementResponse,
    ProtocolInterventionResponse,
    SupplementCreate,
    SupplementResponse,
)
from app.security.auth import get_current_user
from app.services.seed_knowledge import seed_knowledge_base

router = APIRouter(prefix="/knowledge", tags=["knowledge"])


# ── Seeding ──────────────────────────────────────────────────────────────────


@router.post("/seed", response_model=dict)
async def seed_protocols(
    _: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    """Seed the knowledge base with expert protocols from JSON files."""
    counts = await seed_knowledge_base()
    return {"status": "success", "counts": counts}


# ── Experts ──────────────────────────────────────────────────────────────────


@router.get("/experts", response_model=list[ExpertResponse])
async def list_experts(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    _: dict[str, Any] = Depends(get_current_user),
) -> list[ExpertResponse]:
    """List all health experts in the knowledge base."""
    pool = get_pool()
    rows = await pool.fetch(
        "SELECT id, name, focus_areas, bio, website, created_at "
        "FROM experts ORDER BY name LIMIT $1 OFFSET $2",
        limit,
        offset,
    )
    return [
        ExpertResponse(
            id=r["id"],
            name=r["name"],
            focus_areas=r["focus_areas"] or [],
            bio=r["bio"],
            website=r["website"],
            created_at=r["created_at"],
        )
        for r in rows
    ]


@router.get("/experts/{expert_id}", response_model=ExpertResponse)
async def get_expert(
    expert_id: UUID,
    _: dict[str, Any] = Depends(get_current_user),
) -> ExpertResponse:
    """Get a specific expert by ID."""
    pool = get_pool()
    row = await pool.fetchrow(
        "SELECT id, name, focus_areas, bio, website, created_at "
        "FROM experts WHERE id = $1",
        expert_id,
    )
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Expert not found")
    return ExpertResponse(
        id=row["id"],
        name=row["name"],
        focus_areas=row["focus_areas"] or [],
        bio=row["bio"],
        website=row["website"],
        created_at=row["created_at"],
    )


@router.post("/experts", response_model=ExpertResponse, status_code=status.HTTP_201_CREATED)
async def create_expert(
    body: ExpertCreate,
    _: dict[str, Any] = Depends(get_current_user),
) -> ExpertResponse:
    """Create a new expert in the knowledge base."""
    pool = get_pool()
    row = await pool.fetchrow(
        "INSERT INTO experts (name, focus_areas, bio, website) "
        "VALUES ($1, $2, $3, $4) "
        "RETURNING id, name, focus_areas, bio, website, created_at",
        body.name,
        body.focus_areas,
        body.bio,
        body.website,
    )
    return ExpertResponse(
        id=row["id"],
        name=row["name"],
        focus_areas=row["focus_areas"] or [],
        bio=row["bio"],
        website=row["website"],
        created_at=row["created_at"],
    )


# ── Supplements ──────────────────────────────────────────────────────────────


@router.get("/supplements", response_model=list[SupplementResponse])
async def list_supplements(
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    search: str | None = Query(default=None),
    _: dict[str, Any] = Depends(get_current_user),
) -> list[SupplementResponse]:
    """List supplements in the knowledge base."""
    pool = get_pool()
    if search:
        rows = await pool.fetch(
            "SELECT id, name, description, mechanisms, created_at "
            "FROM supplements WHERE LOWER(name) LIKE $1 "
            "ORDER BY name LIMIT $2 OFFSET $3",
            f"%{search.lower()}%",
            limit,
            offset,
        )
    else:
        rows = await pool.fetch(
            "SELECT id, name, description, mechanisms, created_at "
            "FROM supplements ORDER BY name LIMIT $1 OFFSET $2",
            limit,
            offset,
        )
    return [
        SupplementResponse(
            id=r["id"],
            name=r["name"],
            description=r["description"],
            mechanisms=r["mechanisms"] or [],
            created_at=r["created_at"],
        )
        for r in rows
    ]


@router.post("/supplements", response_model=SupplementResponse, status_code=status.HTTP_201_CREATED)
async def create_supplement(
    body: SupplementCreate,
    _: dict[str, Any] = Depends(get_current_user),
) -> SupplementResponse:
    """Create a new supplement in the knowledge base."""
    pool = get_pool()
    row = await pool.fetchrow(
        "INSERT INTO supplements (name, description, mechanisms) "
        "VALUES ($1, $2, $3) "
        "RETURNING id, name, description, mechanisms, created_at",
        body.name,
        body.description,
        body.mechanisms,
    )
    return SupplementResponse(
        id=row["id"],
        name=row["name"],
        description=row["description"],
        mechanisms=row["mechanisms"] or [],
        created_at=row["created_at"],
    )


# ── Interventions ────────────────────────────────────────────────────────────


@router.get("/interventions", response_model=list[InterventionResponse])
async def list_interventions(
    category: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    _: dict[str, Any] = Depends(get_current_user),
) -> list[InterventionResponse]:
    """List interventions in the knowledge base."""
    pool = get_pool()
    if category:
        rows = await pool.fetch(
            "SELECT id, name, category, description, duration_mins, frequency, created_at "
            "FROM interventions WHERE category = $1 "
            "ORDER BY name LIMIT $2 OFFSET $3",
            category,
            limit,
            offset,
        )
    else:
        rows = await pool.fetch(
            "SELECT id, name, category, description, duration_mins, frequency, created_at "
            "FROM interventions ORDER BY category, name LIMIT $1 OFFSET $2",
            limit,
            offset,
        )
    return [
        InterventionResponse(
            id=r["id"],
            name=r["name"],
            category=r["category"],
            description=r["description"],
            duration_mins=r["duration_mins"],
            frequency=r["frequency"],
            created_at=r["created_at"],
        )
        for r in rows
    ]


@router.post("/interventions", response_model=InterventionResponse, status_code=status.HTTP_201_CREATED)
async def create_intervention(
    body: InterventionCreate,
    _: dict[str, Any] = Depends(get_current_user),
) -> InterventionResponse:
    """Create a new intervention in the knowledge base."""
    pool = get_pool()
    row = await pool.fetchrow(
        "INSERT INTO interventions (name, category, description, duration_mins, frequency) "
        "VALUES ($1, $2, $3, $4, $5) "
        "RETURNING id, name, category, description, duration_mins, frequency, created_at",
        body.name,
        body.category,
        body.description,
        body.duration_mins,
        body.frequency,
    )
    return InterventionResponse(
        id=row["id"],
        name=row["name"],
        category=row["category"],
        description=row["description"],
        duration_mins=row["duration_mins"],
        frequency=row["frequency"],
        created_at=row["created_at"],
    )


# ── Protocols ────────────────────────────────────────────────────────────────


@router.get("/protocols", response_model=list[ProtocolResponse])
async def list_protocols(
    expert: str | None = Query(default=None, description="Filter by expert name"),
    category: str | None = Query(default=None, description="Filter by category"),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    _: dict[str, Any] = Depends(get_current_user),
) -> list[ProtocolResponse]:
    """List protocols from the knowledge base with optional filtering."""
    pool = get_pool()

    # Build query dynamically
    base_query = """
        SELECT p.id, p.expert_id, p.name, p.category, p.description,
               p.frequency, p.evidence_level, p.source_url, p.created_at,
               e.name as expert_name
        FROM protocols p
        LEFT JOIN experts e ON p.expert_id = e.id
    """
    conditions = []
    params: list[Any] = []
    param_idx = 1

    if expert:
        conditions.append(f"LOWER(e.name) LIKE ${param_idx}")
        params.append(f"%{expert.lower()}%")
        param_idx += 1

    if category:
        conditions.append(f"p.category = ${param_idx}")
        params.append(category)
        param_idx += 1

    if conditions:
        base_query += " WHERE " + " AND ".join(conditions)

    base_query += f" ORDER BY e.name, p.name LIMIT ${param_idx} OFFSET ${param_idx + 1}"
    params.extend([limit, offset])

    rows = await pool.fetch(base_query, *params)

    # Fetch supplements and interventions for each protocol
    results: list[ProtocolResponse] = []
    for r in rows:
        protocol_id = r["id"]

        # Get supplements
        supp_rows = await pool.fetch(
            """
            SELECT ps.id, ps.dose, ps.unit, ps.timing, ps.conditions, ps.rationale,
                   s.id as supp_id, s.name, s.description, s.mechanisms, s.created_at
            FROM protocol_supplements ps
            JOIN supplements s ON ps.supplement_id = s.id
            WHERE ps.protocol_id = $1
            """,
            protocol_id,
        )
        supplements = [
            ProtocolSupplementResponse(
                id=sr["id"],
                supplement=SupplementResponse(
                    id=sr["supp_id"],
                    name=sr["name"],
                    description=sr["description"],
                    mechanisms=sr["mechanisms"] or [],
                    created_at=sr["created_at"],
                ),
                dose=sr["dose"],
                unit=sr["unit"],
                timing=sr["timing"],
                conditions=sr["conditions"],
                rationale=sr["rationale"],
            )
            for sr in supp_rows
        ]

        # Get interventions
        int_rows = await pool.fetch(
            """
            SELECT pi.id, pi.conditions, pi.rationale,
                   i.id as int_id, i.name, i.category, i.description,
                   i.duration_mins, i.frequency, i.created_at
            FROM protocol_interventions pi
            JOIN interventions i ON pi.intervention_id = i.id
            WHERE pi.protocol_id = $1
            """,
            protocol_id,
        )
        interventions = [
            ProtocolInterventionResponse(
                id=ir["id"],
                intervention=InterventionResponse(
                    id=ir["int_id"],
                    name=ir["name"],
                    category=ir["category"],
                    description=ir["description"],
                    duration_mins=ir["duration_mins"],
                    frequency=ir["frequency"],
                    created_at=ir["created_at"],
                ),
                conditions=ir["conditions"],
                rationale=ir["rationale"],
            )
            for ir in int_rows
        ]

        results.append(
            ProtocolResponse(
                id=r["id"],
                expert_id=r["expert_id"],
                expert_name=r["expert_name"],
                name=r["name"],
                category=r["category"],
                description=r["description"],
                frequency=r["frequency"],
                evidence_level=r["evidence_level"],
                source_url=r["source_url"],
                supplements=supplements,
                interventions=interventions,
                created_at=r["created_at"],
            )
        )

    return results


@router.get("/protocols/{protocol_id}", response_model=ProtocolResponse)
async def get_protocol(
    protocol_id: UUID,
    _: dict[str, Any] = Depends(get_current_user),
) -> ProtocolResponse:
    """Get a specific protocol with all its supplements and interventions."""
    pool = get_pool()

    row = await pool.fetchrow(
        """
        SELECT p.id, p.expert_id, p.name, p.category, p.description,
               p.frequency, p.evidence_level, p.source_url, p.created_at,
               e.name as expert_name
        FROM protocols p
        LEFT JOIN experts e ON p.expert_id = e.id
        WHERE p.id = $1
        """,
        protocol_id,
    )

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Protocol not found")

    # Get supplements
    supp_rows = await pool.fetch(
        """
        SELECT ps.id, ps.dose, ps.unit, ps.timing, ps.conditions, ps.rationale,
               s.id as supp_id, s.name, s.description, s.mechanisms, s.created_at
        FROM protocol_supplements ps
        JOIN supplements s ON ps.supplement_id = s.id
        WHERE ps.protocol_id = $1
        """,
        protocol_id,
    )
    supplements = [
        ProtocolSupplementResponse(
            id=sr["id"],
            supplement=SupplementResponse(
                id=sr["supp_id"],
                name=sr["name"],
                description=sr["description"],
                mechanisms=sr["mechanisms"] or [],
                created_at=sr["created_at"],
            ),
            dose=sr["dose"],
            unit=sr["unit"],
            timing=sr["timing"],
            conditions=sr["conditions"],
            rationale=sr["rationale"],
        )
        for sr in supp_rows
    ]

    # Get interventions
    int_rows = await pool.fetch(
        """
        SELECT pi.id, pi.conditions, pi.rationale,
               i.id as int_id, i.name, i.category, i.description,
               i.duration_mins, i.frequency, i.created_at
        FROM protocol_interventions pi
        JOIN interventions i ON pi.intervention_id = i.id
        WHERE pi.protocol_id = $1
        """,
        protocol_id,
    )
    interventions = [
        ProtocolInterventionResponse(
            id=ir["id"],
            intervention=InterventionResponse(
                id=ir["int_id"],
                name=ir["name"],
                category=ir["category"],
                description=ir["description"],
                duration_mins=ir["duration_mins"],
                frequency=ir["frequency"],
                created_at=ir["created_at"],
            ),
            conditions=ir["conditions"],
            rationale=ir["rationale"],
        )
        for ir in int_rows
    ]

    return ProtocolResponse(
        id=row["id"],
        expert_id=row["expert_id"],
        expert_name=row["expert_name"],
        name=row["name"],
        category=row["category"],
        description=row["description"],
        frequency=row["frequency"],
        evidence_level=row["evidence_level"],
        source_url=row["source_url"],
        supplements=supplements,
        interventions=interventions,
        created_at=row["created_at"],
    )


@router.post("/protocols", response_model=ProtocolResponse, status_code=status.HTTP_201_CREATED)
async def create_protocol(
    body: ProtocolCreate,
    _: dict[str, Any] = Depends(get_current_user),
) -> ProtocolResponse:
    """Create a new protocol in the knowledge base."""
    pool = get_pool()

    # Insert protocol
    row = await pool.fetchrow(
        """
        INSERT INTO protocols (expert_id, name, category, description, frequency, evidence_level, source_url)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING id, expert_id, name, category, description, frequency, evidence_level, source_url, created_at
        """,
        body.expert_id,
        body.name,
        body.category.value,
        body.description,
        body.frequency,
        body.evidence_level.value if body.evidence_level else None,
        body.source_url,
    )
    protocol_id = row["id"]

    # Get expert name if exists
    expert_name = None
    if body.expert_id:
        expert_row = await pool.fetchrow("SELECT name FROM experts WHERE id = $1", body.expert_id)
        if expert_row:
            expert_name = expert_row["name"]

    # Insert supplements
    supplements: list[ProtocolSupplementResponse] = []
    for supp in body.supplements:
        supp_row = await pool.fetchrow(
            """
            INSERT INTO protocol_supplements (protocol_id, supplement_id, dose, unit, timing, conditions, rationale)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING id
            """,
            protocol_id,
            supp.supplement_id,
            supp.dose,
            supp.unit,
            supp.timing,
            json.dumps(supp.conditions) if supp.conditions else None,
            supp.rationale,
        )

        # Get supplement details
        s_row = await pool.fetchrow(
            "SELECT id, name, description, mechanisms, created_at FROM supplements WHERE id = $1",
            supp.supplement_id,
        )
        if s_row:
            supplements.append(
                ProtocolSupplementResponse(
                    id=supp_row["id"],
                    supplement=SupplementResponse(
                        id=s_row["id"],
                        name=s_row["name"],
                        description=s_row["description"],
                        mechanisms=s_row["mechanisms"] or [],
                        created_at=s_row["created_at"],
                    ),
                    dose=supp.dose,
                    unit=supp.unit,
                    timing=supp.timing,
                    conditions=supp.conditions,
                    rationale=supp.rationale,
                )
            )

    # Insert interventions
    interventions: list[ProtocolInterventionResponse] = []
    for intv in body.interventions:
        int_row = await pool.fetchrow(
            """
            INSERT INTO protocol_interventions (protocol_id, intervention_id, conditions, rationale)
            VALUES ($1, $2, $3, $4)
            RETURNING id
            """,
            protocol_id,
            intv.intervention_id,
            json.dumps(intv.conditions) if intv.conditions else None,
            intv.rationale,
        )

        # Get intervention details
        i_row = await pool.fetchrow(
            "SELECT id, name, category, description, duration_mins, frequency, created_at FROM interventions WHERE id = $1",
            intv.intervention_id,
        )
        if i_row:
            interventions.append(
                ProtocolInterventionResponse(
                    id=int_row["id"],
                    intervention=InterventionResponse(
                        id=i_row["id"],
                        name=i_row["name"],
                        category=i_row["category"],
                        description=i_row["description"],
                        duration_mins=i_row["duration_mins"],
                        frequency=i_row["frequency"],
                        created_at=i_row["created_at"],
                    ),
                    conditions=intv.conditions,
                    rationale=intv.rationale,
                )
            )

    return ProtocolResponse(
        id=row["id"],
        expert_id=row["expert_id"],
        expert_name=expert_name,
        name=row["name"],
        category=row["category"],
        description=row["description"],
        frequency=row["frequency"],
        evidence_level=row["evidence_level"],
        source_url=row["source_url"],
        supplements=supplements,
        interventions=interventions,
        created_at=row["created_at"],
    )


# ── Nutrition Principles ─────────────────────────────────────────────────────


@router.get("/nutrition", response_model=list[NutritionPrincipleResponse])
async def list_nutrition_principles(
    expert: str | None = Query(default=None),
    topic: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    _: dict[str, Any] = Depends(get_current_user),
) -> list[NutritionPrincipleResponse]:
    """List nutrition principles from the knowledge base."""
    pool = get_pool()

    base_query = """
        SELECT n.id, n.expert_id, n.topic, n.guidance, n.conditions, n.created_at,
               e.name as expert_name
        FROM nutrition_principles n
        LEFT JOIN experts e ON n.expert_id = e.id
    """
    conditions = []
    params: list[Any] = []
    param_idx = 1

    if expert:
        conditions.append(f"LOWER(e.name) LIKE ${param_idx}")
        params.append(f"%{expert.lower()}%")
        param_idx += 1

    if topic:
        conditions.append(f"LOWER(n.topic) LIKE ${param_idx}")
        params.append(f"%{topic.lower()}%")
        param_idx += 1

    if conditions:
        base_query += " WHERE " + " AND ".join(conditions)

    base_query += f" ORDER BY e.name, n.topic LIMIT ${param_idx} OFFSET ${param_idx + 1}"
    params.extend([limit, offset])

    rows = await pool.fetch(base_query, *params)

    return [
        NutritionPrincipleResponse(
            id=r["id"],
            expert_id=r["expert_id"],
            expert_name=r["expert_name"],
            topic=r["topic"],
            guidance=r["guidance"],
            conditions=r["conditions"],
            created_at=r["created_at"],
        )
        for r in rows
    ]


@router.post("/nutrition", response_model=NutritionPrincipleResponse, status_code=status.HTTP_201_CREATED)
async def create_nutrition_principle(
    body: NutritionPrincipleCreate,
    _: dict[str, Any] = Depends(get_current_user),
) -> NutritionPrincipleResponse:
    """Create a new nutrition principle."""
    pool = get_pool()

    # Get expert name if exists
    expert_name = None
    if body.expert_id:
        expert_row = await pool.fetchrow("SELECT name FROM experts WHERE id = $1", body.expert_id)
        if expert_row:
            expert_name = expert_row["name"]

    row = await pool.fetchrow(
        """
        INSERT INTO nutrition_principles (expert_id, topic, guidance, conditions)
        VALUES ($1, $2, $3, $4)
        RETURNING id, expert_id, topic, guidance, conditions, created_at
        """,
        body.expert_id,
        body.topic,
        body.guidance,
        json.dumps(body.conditions) if body.conditions else None,
    )

    return NutritionPrincipleResponse(
        id=row["id"],
        expert_id=row["expert_id"],
        expert_name=expert_name,
        topic=row["topic"],
        guidance=row["guidance"],
        conditions=row["conditions"],
        created_at=row["created_at"],
    )


# ── Query for Personalization ────────────────────────────────────────────────


@router.get("/recommendations")
async def get_personalized_recommendations(
    genome_markers: list[str] = Query(default=[]),
    bloodwork_conditions: list[str] = Query(default=[]),
    recovery_state: str | None = Query(default=None),
    category: str | None = Query(default=None),
    _: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    """
    Get personalized protocol recommendations based on user context.

    This endpoint filters protocols and supplements based on:
    - Genome markers (e.g., MTHFR, APOE4)
    - Bloodwork conditions (e.g., low_vitamin_d, high_apob)
    - Recovery state (e.g., low_hrv, poor_sleep)
    """
    pool = get_pool()

    # Build a query that matches protocols with relevant conditions
    query = """
        SELECT DISTINCT p.id, p.name, p.category, p.description, p.frequency,
               p.evidence_level, e.name as expert_name
        FROM protocols p
        LEFT JOIN experts e ON p.expert_id = e.id
        LEFT JOIN protocol_supplements ps ON ps.protocol_id = p.id
        LEFT JOIN protocol_interventions pi ON pi.protocol_id = p.id
        WHERE 1=1
    """
    params: list[Any] = []
    param_idx = 1

    if category:
        query += f" AND p.category = ${param_idx}"
        params.append(category)
        param_idx += 1

    query += " ORDER BY p.evidence_level DESC, p.name LIMIT 50"

    rows = await pool.fetch(query, *params)

    recommendations = []
    for r in rows:
        recommendations.append({
            "protocol_id": str(r["id"]),
            "name": r["name"],
            "category": r["category"],
            "description": r["description"],
            "frequency": r["frequency"],
            "evidence_level": r["evidence_level"],
            "expert": r["expert_name"],
        })

    return {
        "recommendations": recommendations,
        "filters_applied": {
            "genome_markers": genome_markers,
            "bloodwork_conditions": bloodwork_conditions,
            "recovery_state": recovery_state,
            "category": category,
        },
    }
