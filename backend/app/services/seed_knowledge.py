"""Seed the knowledge base with expert protocols from JSON files."""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any
from uuid import UUID

from app.models.database import get_pool

logger = logging.getLogger(__name__)

DATA_DIR = Path(__file__).parent.parent.parent / "data" / "protocols"


async def seed_knowledge_base() -> dict[str, int]:
    """
    Load all protocol JSON files and seed the knowledge base.

    Returns counts of inserted records.
    """
    pool = get_pool()
    counts = {
        "experts": 0,
        "supplements": 0,
        "interventions": 0,
        "protocols": 0,
        "protocol_supplements": 0,
        "protocol_interventions": 0,
        "nutrition_principles": 0,
    }

    # Find all JSON files
    json_files = list(DATA_DIR.glob("*.json"))
    logger.info(f"Found {len(json_files)} protocol files to seed")

    for json_file in json_files:
        logger.info(f"Processing {json_file.name}")
        with open(json_file) as f:
            data = json.load(f)

        try:
            file_counts = await _seed_file(pool, data)
            for key, val in file_counts.items():
                counts[key] += val
        except Exception as e:
            logger.error(f"Error seeding {json_file.name}: {e}")
            raise

    logger.info(f"Seeding complete: {counts}")
    return counts


async def _seed_file(pool, data: dict[str, Any]) -> dict[str, int]:
    """Seed a single protocol file."""
    counts = {
        "experts": 0,
        "supplements": 0,
        "interventions": 0,
        "protocols": 0,
        "protocol_supplements": 0,
        "protocol_interventions": 0,
        "nutrition_principles": 0,
    }

    # 1. Insert expert
    expert_data = data.get("expert", {})
    expert_id = await _upsert_expert(pool, expert_data)
    if expert_id:
        counts["experts"] += 1

    # 2. Insert supplements (global, not tied to expert)
    supplement_ids: dict[str, UUID] = {}
    for supp in data.get("supplements", []):
        supp_id = await _upsert_supplement(pool, supp)
        if supp_id:
            supplement_ids[supp["name"]] = supp_id
            counts["supplements"] += 1

    # 3. Insert interventions
    intervention_ids: dict[str, UUID] = {}
    for intv in data.get("interventions", []):
        intv_id = await _upsert_intervention(pool, intv)
        if intv_id:
            intervention_ids[intv["name"]] = intv_id
            counts["interventions"] += 1

    # 4. Insert protocols with their supplements and interventions
    for protocol in data.get("protocols", []):
        protocol_id = await _upsert_protocol(pool, protocol, expert_id)
        if protocol_id:
            counts["protocols"] += 1

            # Link supplements
            for ps in protocol.get("supplements", []):
                supp_name = ps.get("name")
                if supp_name in supplement_ids:
                    linked = await _link_protocol_supplement(
                        pool, protocol_id, supplement_ids[supp_name], ps
                    )
                    if linked:
                        counts["protocol_supplements"] += 1

            # Link interventions
            for pi in protocol.get("interventions", []):
                intv_name = pi.get("name")
                if intv_name in intervention_ids:
                    linked = await _link_protocol_intervention(
                        pool, protocol_id, intervention_ids[intv_name], pi
                    )
                    if linked:
                        counts["protocol_interventions"] += 1

    # 5. Insert nutrition principles
    for np in data.get("nutrition_principles", []):
        inserted = await _upsert_nutrition_principle(pool, np, expert_id)
        if inserted:
            counts["nutrition_principles"] += 1

    return counts


async def _upsert_expert(pool, data: dict[str, Any]) -> UUID | None:
    """Insert or update an expert."""
    if not data.get("name"):
        return None

    row = await pool.fetchrow(
        """
        INSERT INTO experts (name, focus_areas, bio, website)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (name) DO UPDATE SET
            focus_areas = EXCLUDED.focus_areas,
            bio = EXCLUDED.bio,
            website = EXCLUDED.website
        RETURNING id
        """,
        data["name"],
        data.get("focus_areas", []),
        data.get("bio"),
        data.get("website"),
    )
    return row["id"] if row else None


async def _upsert_supplement(pool, data: dict[str, Any]) -> UUID | None:
    """Insert or update a supplement."""
    if not data.get("name"):
        return None

    row = await pool.fetchrow(
        """
        INSERT INTO supplements (name, description, mechanisms)
        VALUES ($1, $2, $3)
        ON CONFLICT (name) DO UPDATE SET
            description = EXCLUDED.description,
            mechanisms = EXCLUDED.mechanisms
        RETURNING id
        """,
        data["name"],
        data.get("description"),
        data.get("mechanisms", []),
    )
    return row["id"] if row else None


async def _upsert_intervention(pool, data: dict[str, Any]) -> UUID | None:
    """Insert or update an intervention."""
    if not data.get("name"):
        return None

    row = await pool.fetchrow(
        """
        INSERT INTO interventions (name, category, description, duration_mins, frequency)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (name) DO UPDATE SET
            category = EXCLUDED.category,
            description = EXCLUDED.description,
            duration_mins = EXCLUDED.duration_mins,
            frequency = EXCLUDED.frequency
        RETURNING id
        """,
        data["name"],
        data.get("category", "general"),
        data.get("description"),
        data.get("duration_mins"),
        data.get("frequency"),
    )
    return row["id"] if row else None


async def _upsert_protocol(pool, data: dict[str, Any], expert_id: UUID | None) -> UUID | None:
    """Insert or update a protocol."""
    if not data.get("name"):
        return None

    # Check if protocol exists for this expert
    existing = await pool.fetchrow(
        "SELECT id FROM protocols WHERE name = $1 AND (expert_id = $2 OR (expert_id IS NULL AND $2 IS NULL))",
        data["name"],
        expert_id,
    )

    if existing:
        # Update existing
        await pool.execute(
            """
            UPDATE protocols SET
                category = $1,
                description = $2,
                frequency = $3,
                evidence_level = $4,
                source_url = $5
            WHERE id = $6
            """,
            data.get("category", "general"),
            data.get("description"),
            data.get("frequency"),
            data.get("evidence_level"),
            data.get("source_url"),
            existing["id"],
        )
        return existing["id"]
    else:
        # Insert new
        row = await pool.fetchrow(
            """
            INSERT INTO protocols (expert_id, name, category, description, frequency, evidence_level, source_url)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING id
            """,
            expert_id,
            data["name"],
            data.get("category", "general"),
            data.get("description"),
            data.get("frequency"),
            data.get("evidence_level"),
            data.get("source_url"),
        )
        return row["id"] if row else None


async def _link_protocol_supplement(
    pool, protocol_id: UUID, supplement_id: UUID, data: dict[str, Any]
) -> bool:
    """Link a supplement to a protocol."""
    conditions = data.get("conditions")
    if conditions:
        conditions = json.dumps(conditions)

    try:
        await pool.execute(
            """
            INSERT INTO protocol_supplements (protocol_id, supplement_id, dose, unit, timing, conditions, rationale)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            ON CONFLICT (protocol_id, supplement_id) DO UPDATE SET
                dose = EXCLUDED.dose,
                unit = EXCLUDED.unit,
                timing = EXCLUDED.timing,
                conditions = EXCLUDED.conditions,
                rationale = EXCLUDED.rationale
            """,
            protocol_id,
            supplement_id,
            data.get("dose"),
            data.get("unit"),
            data.get("timing"),
            conditions,
            data.get("rationale"),
        )
        return True
    except Exception as e:
        logger.error(f"Error linking supplement: {e}")
        return False


async def _link_protocol_intervention(
    pool, protocol_id: UUID, intervention_id: UUID, data: dict[str, Any]
) -> bool:
    """Link an intervention to a protocol."""
    conditions = data.get("conditions")
    if conditions:
        conditions = json.dumps(conditions)

    try:
        await pool.execute(
            """
            INSERT INTO protocol_interventions (protocol_id, intervention_id, conditions, rationale)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT (protocol_id, intervention_id) DO UPDATE SET
                conditions = EXCLUDED.conditions,
                rationale = EXCLUDED.rationale
            """,
            protocol_id,
            intervention_id,
            conditions,
            data.get("rationale"),
        )
        return True
    except Exception as e:
        logger.error(f"Error linking intervention: {e}")
        return False


async def _upsert_nutrition_principle(pool, data: dict[str, Any], expert_id: UUID | None) -> bool:
    """Insert a nutrition principle."""
    if not data.get("topic") or not data.get("guidance"):
        return False

    conditions = data.get("conditions")
    if conditions:
        conditions = json.dumps(conditions)

    try:
        await pool.execute(
            """
            INSERT INTO nutrition_principles (expert_id, topic, guidance, conditions)
            VALUES ($1, $2, $3, $4)
            """,
            expert_id,
            data["topic"],
            data["guidance"],
            conditions,
        )
        return True
    except Exception as e:
        # May already exist, that's OK
        logger.debug(f"Nutrition principle may already exist: {e}")
        return False
