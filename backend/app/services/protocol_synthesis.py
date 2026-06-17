"""Protocol Synthesis Engine - Intelligent protocol generation with conflict resolution.

This engine synthesizes personalized daily protocols by:
1. Loading applicable expert protocols
2. Filtering by genome (exclude contraindicated)
3. Filtering by bloodwork (prioritize deficiencies)
4. Applying recovery zone adaptations
5. Applying circaseptan adjustments
6. Resolving conflicts via priority hierarchy
"""

from __future__ import annotations

from datetime import date
from typing import Any
from uuid import UUID

import asyncpg

from app.models.database import get_pool
from app.services.recovery_adapter import (
    RecoveryZone,
    adapt_interventions,
    adapt_supplements,
    adapt_training,
    calculate_recovery_zone,
    get_recovery_summary,
)
from app.services.circaseptan_engine import (
    apply_circaseptan_adjustments,
    get_circaseptan_profile,
    get_circaseptan_summary,
)


# Conflict resolution priority hierarchy (highest to lowest)
CONFLICT_PRIORITY = [
    "genetic_risk",          # 1. User's genetic profile (highest priority)
    "drug_interaction",      # 2. Drug interactions
    "biomarker",             # 3. Current bloodwork
    "recovery",              # 4. Today's recovery status
    "user_preference",       # 5. User-selected protocol priority
    "expert_consensus",      # 6. Multiple experts agree
    "scientific_evidence",   # 7. Evidence level
]

# Supplement timing conflicts
TIMING_CONFLICTS = {
    "iron": {"conflicts_with": ["calcium", "zinc", "coffee", "tea"], "separate_by_hours": 2},
    "calcium": {"conflicts_with": ["iron", "zinc", "magnesium"], "separate_by_hours": 2},
    "zinc": {"conflicts_with": ["iron", "calcium", "copper"], "separate_by_hours": 2},
    "thyroid_medication": {"conflicts_with": ["calcium", "iron", "coffee"], "separate_by_hours": 4},
    "magnesium": {"conflicts_with": ["calcium"], "separate_by_hours": 2},
}

# Supplement dose limits
MAX_DAILY_DOSES = {
    "vitamin_d3": {"max_iu": 10000, "warning_iu": 5000},
    "vitamin_a": {"max_iu": 10000, "warning_iu": 5000},
    "zinc": {"max_mg": 40, "warning_mg": 30},
    "selenium": {"max_mcg": 400, "warning_mcg": 200},
    "vitamin_b6": {"max_mg": 100, "warning_mg": 50},
}


async def synthesize_daily_protocol(
    user_id: UUID,
    target_date: date,
    user_snps: list[dict[str, Any]] | None = None,
    bloodwork: dict[str, Any] | None = None,
    wearable_data: dict[str, Any] | None = None,
    user_preferences: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """
    Synthesize a personalized daily protocol.

    Args:
        user_id: User's UUID
        target_date: Date for the protocol
        user_snps: User's genomic variants with matched knowledge
        bloodwork: Recent bloodwork data
        wearable_data: Today's wearable metrics
        user_preferences: User's protocol preferences

    Returns:
        Complete synthesized daily protocol
    """
    pool = get_pool()

    # Step 1: Calculate recovery zone
    recovery_zone, recovery_score, recovery_breakdown = _calculate_user_recovery(wearable_data)

    # Step 2: Get circaseptan profile
    circaseptan = await get_circaseptan_profile(target_date)

    # Step 3: Load expert protocols user is subscribed to
    expert_protocols = await _load_user_protocols(pool, user_id)

    # Step 4: Filter protocols by genome
    filtered_protocols = await _filter_by_genome(expert_protocols, user_snps)

    # Step 5: Prioritize by bloodwork
    prioritized = _prioritize_by_bloodwork(filtered_protocols, bloodwork)

    # Step 6: Build base protocol
    base_protocol = _build_base_protocol(prioritized, target_date)

    # Step 7: Add SNP-specific recommendations
    base_protocol = _add_snp_recommendations(base_protocol, user_snps)

    # Step 8: Apply recovery adaptations
    base_protocol = _apply_recovery_adaptations(base_protocol, recovery_zone)

    # Step 9: Apply circaseptan adjustments
    base_protocol = apply_circaseptan_adjustments(base_protocol, circaseptan)

    # Step 10: Resolve conflicts
    resolved = _resolve_conflicts(base_protocol)

    # Step 11: Add metadata
    resolved["recovery_zone"] = recovery_zone.value
    resolved["recovery_score"] = round(recovery_score, 1)
    resolved["recovery_breakdown"] = recovery_breakdown
    resolved["recovery_summary"] = get_recovery_summary(recovery_zone, recovery_score)
    resolved["circaseptan_day"] = circaseptan.get("day_of_week")
    resolved["circaseptan_name"] = circaseptan.get("name")
    resolved["circaseptan_summary"] = get_circaseptan_summary(target_date)
    resolved["date"] = target_date.isoformat()
    resolved["synthesis_version"] = "1.0"

    return resolved


def _calculate_user_recovery(wearable_data: dict[str, Any] | None) -> tuple[RecoveryZone, float, dict]:
    """Extract wearable metrics and calculate recovery zone."""
    if not wearable_data:
        return RecoveryZone.YELLOW, 50.0, {"note": "No wearable data"}

    return calculate_recovery_zone(
        hrv=wearable_data.get("hrv"),
        hrv_baseline=wearable_data.get("hrv_baseline"),
        recovery_score=wearable_data.get("recovery_score"),
        sleep_score=wearable_data.get("sleep_score"),
        strain_yesterday=wearable_data.get("strain_yesterday"),
        resting_hr=wearable_data.get("resting_hr"),
        rhr_baseline=wearable_data.get("rhr_baseline"),
    )


async def _load_user_protocols(pool: asyncpg.Pool, user_id: UUID) -> list[dict[str, Any]]:
    """Load expert protocols the user is subscribed to."""
    async with pool.acquire() as conn:
        # Get user's enabled protocol sources
        sources = await conn.fetch(
            """
            SELECT source_name, priority, config_json
            FROM protocol_sources
            WHERE user_id = $1 AND enabled = TRUE
            ORDER BY priority DESC
            """,
            user_id
        )

        if not sources:
            # Default to all experts if no preferences
            source_names = None
        else:
            source_names = [s["source_name"] for s in sources]

        # Load protocols with supplements and interventions
        if source_names:
            protocols = await conn.fetch(
                """
                SELECT p.*, e.name as expert_name, e.focus_areas
                FROM protocols p
                LEFT JOIN experts e ON p.expert_id = e.id
                WHERE e.name = ANY($1)
                ORDER BY p.category, e.name
                """,
                source_names
            )
        else:
            protocols = await conn.fetch(
                """
                SELECT p.*, e.name as expert_name, e.focus_areas
                FROM protocols p
                LEFT JOIN experts e ON p.expert_id = e.id
                ORDER BY p.category, e.name
                """
            )

        return [dict(p) for p in protocols]


async def _filter_by_genome(
    protocols: list[dict[str, Any]],
    user_snps: list[dict[str, Any]] | None
) -> list[dict[str, Any]]:
    """
    Filter protocols based on user's genetic profile.

    Removes contraindicated protocols and marks genetically-relevant ones.
    """
    if not user_snps:
        return protocols

    # Build lookup of user's risk SNPs
    user_risk_variants = {}
    for snp in user_snps:
        if snp.get("has_risk_allele"):
            rsid = snp.get("rsid")
            user_risk_variants[rsid] = snp

    filtered = []
    for protocol in protocols:
        # Check for genetic contraindications
        contraindicated = False
        genetic_match = False

        # Example checks based on common SNP-protocol relationships
        protocol_name = protocol.get("name", "").lower()

        # MTHFR and folic acid
        if "folic acid" in protocol_name and "rs1801133" in user_risk_variants:
            contraindicated = True
            protocol["contraindication_reason"] = "MTHFR variant - use methylfolate instead"

        # Slow caffeine metabolizer
        if "caffeine" in protocol_name and "rs762551" in user_risk_variants:
            protocol["genetic_note"] = "Slow caffeine metabolizer - limit intake"

        # APOE4 and saturated fat
        if "saturated" in protocol_name and "rs429358" in user_risk_variants:
            contraindicated = True
            protocol["contraindication_reason"] = "APOE4 - reduce saturated fat"

        # Mark genetic matches
        if any(snp.get("category") in str(protocol.get("category", "")).lower()
               for snp in user_snps if snp.get("has_risk_allele")):
            genetic_match = True
            protocol["genetic_relevance"] = True

        if not contraindicated:
            protocol["filtered_by_genome"] = True
            protocol["genetic_match"] = genetic_match
            filtered.append(protocol)

    return filtered


def _prioritize_by_bloodwork(
    protocols: list[dict[str, Any]],
    bloodwork: dict[str, Any] | None
) -> list[dict[str, Any]]:
    """
    Prioritize protocols based on bloodwork deficiencies.
    """
    if not bloodwork or not bloodwork.get("markers"):
        return protocols

    markers = {m.get("name", "").lower(): m for m in bloodwork.get("markers", [])}

    # Define deficiency thresholds
    deficiencies = []

    # Vitamin D
    vit_d = markers.get("vitamin d") or markers.get("25-oh vitamin d")
    if vit_d and vit_d.get("value", 100) < 30:
        deficiencies.append("vitamin_d")

    # B12
    b12 = markers.get("b12") or markers.get("vitamin b12")
    if b12 and b12.get("value", 1000) < 400:
        deficiencies.append("b12")

    # Iron/Ferritin
    ferritin = markers.get("ferritin")
    if ferritin and ferritin.get("value", 100) < 30:
        deficiencies.append("iron")

    # Omega-3 index
    omega3 = markers.get("omega-3 index")
    if omega3 and omega3.get("value", 10) < 8:
        deficiencies.append("omega3")

    # Mark protocols addressing deficiencies as high priority
    for protocol in protocols:
        protocol_text = f"{protocol.get('name', '')} {protocol.get('description', '')}".lower()
        for deficiency in deficiencies:
            if deficiency in protocol_text:
                protocol["bloodwork_priority"] = True
                protocol["addresses_deficiency"] = deficiency
                break

    # Sort by bloodwork priority
    return sorted(protocols, key=lambda p: (not p.get("bloodwork_priority", False), p.get("name", "")))


def _build_base_protocol(protocols: list[dict[str, Any]], target_date: date) -> dict[str, Any]:
    """Build base protocol structure from filtered protocols."""
    base = {
        "training": {
            "type": "strength",
            "exercises": [],
            "duration_mins": 45,
            "rpe_target": 7,
        },
        "nutrition": {
            "meals": [],
            "macros": {},
            "emphasis": [],
            "timing": {},
        },
        "supplements": [],
        "interventions": [],
        "sleep": {
            "target_hours": 8,
            "wind_down_mins": 30,
            "recommendations": [],
        },
        "expert_sources": [],
        "protocol_notes": [],
    }

    # Aggregate from protocols
    seen_supplements = set()
    seen_interventions = set()

    for protocol in protocols:
        category = protocol.get("category", "").lower()
        expert = protocol.get("expert_name")

        if expert and expert not in base["expert_sources"]:
            base["expert_sources"].append(expert)

        # TODO: Load actual supplement/intervention data from protocol relationships
        # For now, add protocol info to notes
        if protocol.get("genetic_relevance"):
            base["protocol_notes"].append(f"Genetically relevant: {protocol.get('name')} ({expert})")
        if protocol.get("bloodwork_priority"):
            base["protocol_notes"].append(f"Addresses deficiency: {protocol.get('name')} ({expert})")

    return base


def _add_snp_recommendations(
    protocol: dict[str, Any],
    user_snps: list[dict[str, Any]] | None
) -> dict[str, Any]:
    """Add SNP-specific supplement and intervention recommendations."""
    if not user_snps:
        return protocol

    snp_supplements = []
    snp_interventions = []
    snp_avoid = []
    snp_notes = []

    for snp in user_snps:
        if not snp.get("has_risk_allele"):
            continue

        # Add recommended supplements
        for supp in snp.get("supplements", []):
            supp_entry = {
                "name": supp.get("name"),
                "dose": supp.get("dose"),
                "timing": supp.get("timing"),
                "rationale": supp.get("rationale"),
                "snp_source": snp.get("rsid"),
                "gene": snp.get("gene"),
                "genetic_priority": True,
            }
            snp_supplements.append(supp_entry)

        # Add avoid list
        for avoid in snp.get("avoid", []):
            snp_avoid.append({
                "item": avoid.get("item"),
                "reason": avoid.get("reason"),
                "snp_source": snp.get("rsid"),
            })

        # Add interventions
        for intervention in snp.get("interventions", []):
            snp_interventions.append({
                "type": intervention.get("type"),
                "action": intervention.get("action"),
                "snp_source": snp.get("rsid"),
            })

        # Add notes
        if snp.get("condition"):
            snp_notes.append(f"{snp.get('gene')}: {snp.get('condition')}")

    # Merge into protocol
    protocol["supplements"].extend(snp_supplements)
    protocol["snp_avoid"] = snp_avoid
    protocol["snp_interventions"] = snp_interventions
    protocol["snp_notes"] = snp_notes

    return protocol


def _apply_recovery_adaptations(protocol: dict[str, Any], zone: RecoveryZone) -> dict[str, Any]:
    """Apply recovery zone adaptations to the protocol."""
    # Adapt training
    if "training" in protocol:
        protocol["training"] = adapt_training(protocol["training"], zone)

    # Adapt supplements
    if "supplements" in protocol:
        protocol["supplements"] = adapt_supplements(protocol["supplements"], zone)

    # Adapt interventions
    if "interventions" in protocol:
        protocol["interventions"] = adapt_interventions(protocol["interventions"], zone)

    return protocol


def _resolve_conflicts(protocol: dict[str, Any]) -> dict[str, Any]:
    """
    Resolve conflicts in the protocol using priority hierarchy.
    """
    conflicts_found = []

    # Resolve supplement conflicts
    if "supplements" in protocol:
        protocol["supplements"], supp_conflicts = _resolve_supplement_conflicts(protocol["supplements"])
        conflicts_found.extend(supp_conflicts)

    # Resolve timing conflicts
    if "supplements" in protocol:
        protocol["supplements"] = _resolve_timing_conflicts(protocol["supplements"])

    # Check dose limits
    if "supplements" in protocol:
        protocol["supplements"], dose_warnings = _check_dose_limits(protocol["supplements"])
        conflicts_found.extend(dose_warnings)

    # Handle genetic vs expert disagreements
    # (genetic always wins per priority hierarchy)

    protocol["conflicts_resolved"] = conflicts_found
    return protocol


def _resolve_supplement_conflicts(supplements: list[dict[str, Any]]) -> tuple[list[dict], list[dict]]:
    """
    Resolve duplicate and conflicting supplements.

    Returns: (resolved_supplements, conflicts_found)
    """
    conflicts = []
    seen = {}

    for supp in supplements:
        name = supp.get("name", "").lower().strip()
        base_name = _get_base_supplement_name(name)

        if base_name in seen:
            existing = seen[base_name]
            # Genetic recommendations take priority
            if supp.get("genetic_priority") and not existing.get("genetic_priority"):
                conflicts.append({
                    "type": "supplement_replaced",
                    "original": existing.get("name"),
                    "replacement": supp.get("name"),
                    "reason": "Genetic recommendation takes priority"
                })
                seen[base_name] = supp
            elif existing.get("genetic_priority") and not supp.get("genetic_priority"):
                conflicts.append({
                    "type": "supplement_skipped",
                    "skipped": supp.get("name"),
                    "kept": existing.get("name"),
                    "reason": "Genetic recommendation already present"
                })
            else:
                # Same priority - keep higher dose or combine
                conflicts.append({
                    "type": "duplicate_merged",
                    "supplements": [existing.get("name"), supp.get("name")],
                    "reason": "Duplicate supplement from different sources"
                })
        else:
            seen[base_name] = supp

    return list(seen.values()), conflicts


def _get_base_supplement_name(name: str) -> str:
    """Extract base supplement name for deduplication."""
    # Remove common suffixes and normalize
    name = name.lower().strip()
    removals = ["(", "mg", "mcg", "iu", "g ", " capsule", " tablet", " powder"]
    for r in removals:
        if r in name:
            name = name.split(r)[0].strip()
    return name


def _resolve_timing_conflicts(supplements: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Adjust supplement timing to avoid absorption conflicts."""
    for supp in supplements:
        name = supp.get("name", "").lower()
        for conflict_name, conflict_info in TIMING_CONFLICTS.items():
            if conflict_name in name:
                # Check if any conflicting supplements are present
                for other_supp in supplements:
                    other_name = other_supp.get("name", "").lower()
                    for conflicts_with in conflict_info.get("conflicts_with", []):
                        if conflicts_with in other_name:
                            hours = conflict_info.get("separate_by_hours", 2)
                            supp["timing_note"] = f"Take {hours}+ hours apart from {conflicts_with}"
                            break
    return supplements


def _check_dose_limits(supplements: list[dict[str, Any]]) -> tuple[list[dict], list[dict]]:
    """Check for supplements exceeding safe daily doses."""
    warnings = []

    # Aggregate doses by supplement type
    totals: dict[str, float] = {}

    for supp in supplements:
        name = supp.get("name", "").lower()
        dose_str = supp.get("dose", "")

        for limit_name, limits in MAX_DAILY_DOSES.items():
            if limit_name.replace("_", " ") in name:
                # Try to parse dose
                dose_value = _parse_dose(dose_str)
                if dose_value:
                    totals[limit_name] = totals.get(limit_name, 0) + dose_value

    # Check against limits
    for supp_name, total in totals.items():
        limits = MAX_DAILY_DOSES.get(supp_name, {})
        max_dose = limits.get(f"max_{_get_dose_unit(supp_name)}")
        warning_dose = limits.get(f"warning_{_get_dose_unit(supp_name)}")

        if max_dose and total > max_dose:
            warnings.append({
                "type": "dose_exceeded",
                "supplement": supp_name,
                "total": total,
                "max": max_dose,
                "severity": "high"
            })
        elif warning_dose and total > warning_dose:
            warnings.append({
                "type": "dose_warning",
                "supplement": supp_name,
                "total": total,
                "warning_threshold": warning_dose,
                "severity": "moderate"
            })

    return supplements, warnings


def _parse_dose(dose_str: str) -> float | None:
    """Parse a dose string to numeric value."""
    import re
    match = re.search(r"(\d+(?:\.\d+)?)", str(dose_str))
    if match:
        return float(match.group(1))
    return None


def _get_dose_unit(supplement_name: str) -> str:
    """Get the standard unit for a supplement."""
    if "vitamin_d" in supplement_name or "vitamin_a" in supplement_name:
        return "iu"
    elif "selenium" in supplement_name:
        return "mcg"
    else:
        return "mg"


def filter_by_genome(protocols: list[dict], user_snps: list[dict]) -> list[dict]:
    """
    Public interface for filtering protocols by genome.

    Removes contraindicated protocols and prioritizes genetic matches.
    """
    import asyncio
    return asyncio.get_event_loop().run_until_complete(
        _filter_by_genome(protocols, user_snps)
    )


def resolve_supplement_conflicts(supplements: list[dict]) -> list[dict]:
    """Public interface for resolving supplement conflicts."""
    resolved, _ = _resolve_supplement_conflicts(supplements)
    return resolved
