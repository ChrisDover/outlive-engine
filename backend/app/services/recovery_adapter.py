"""Recovery Zone Adapter - Calculates recovery zones and adapts protocols accordingly.

Recovery zones are determined by composite wearable metrics (HRV, recovery score, sleep).
Protocols are then adapted based on the user's current recovery state.
"""

from __future__ import annotations

from enum import Enum
from typing import Any


class RecoveryZone(str, Enum):
    """Recovery zone classification based on composite metrics."""
    GREEN = "GREEN"   # 67-100% recovery - full capacity
    YELLOW = "YELLOW"  # 34-66% recovery - moderate adaptation
    RED = "RED"        # 0-33% recovery - recovery focus


# Adaptation matrix defines protocol modifications for each zone
ADAPTATION_MATRIX: dict[RecoveryZone, dict[str, Any]] = {
    RecoveryZone.GREEN: {
        "training": {
            "volume_modifier": 1.0,
            "intensity_modifier": 1.0,
            "rpe_target": 8.5,
            "allow_intensity": True,
            "allow_volume": True,
            "session_type": "full_protocol",
            "notes": "Full training capacity. Push hard if feeling good."
        },
        "supplements": {
            "full_stack": True,
            "performance_enhancers": True,
            "skip_stimulants": False,
            "recovery_stack": False,
            "notes": "Full supplement protocol including performance enhancers."
        },
        "interventions": {
            "sauna": True,
            "sauna_duration_mins": 20,
            "cold_plunge": True,
            "cold_duration_mins": 5,
            "red_light": True,
            "contrast_therapy": True,
            "notes": "All interventions available. Optimal day for hormetic stress."
        },
        "nutrition": {
            "calorie_modifier": 1.0,
            "carb_modifier": 1.0,
            "protein_priority": True,
            "fasting_allowed": True,
            "notes": "Normal nutrition protocol. Carbs around training."
        }
    },
    RecoveryZone.YELLOW: {
        "training": {
            "volume_modifier": 0.75,
            "intensity_modifier": 0.85,
            "rpe_target": 7.0,
            "allow_intensity": False,
            "allow_volume": True,
            "session_type": "moderate",
            "notes": "Reduce intensity, maintain movement. Focus on technique."
        },
        "supplements": {
            "full_stack": True,
            "performance_enhancers": False,
            "skip_stimulants": True,
            "recovery_stack": True,
            "notes": "Skip stimulants, add recovery support (magnesium, zinc)."
        },
        "interventions": {
            "sauna": "optional",
            "sauna_duration_mins": 15,
            "cold_plunge": "shower_only",
            "cold_duration_mins": 2,
            "red_light": True,
            "contrast_therapy": False,
            "notes": "Gentle interventions only. Cold shower instead of plunge."
        },
        "nutrition": {
            "calorie_modifier": 1.1,
            "carb_modifier": 1.2,
            "protein_priority": True,
            "fasting_allowed": False,
            "notes": "Slightly increase calories. No fasting - prioritize recovery."
        }
    },
    RecoveryZone.RED: {
        "training": {
            "volume_modifier": 0.25,
            "intensity_modifier": 0.5,
            "rpe_target": 4.0,
            "allow_intensity": False,
            "allow_volume": False,
            "session_type": "recovery_only",
            "notes": "Active recovery only: walking, mobility, gentle yoga."
        },
        "supplements": {
            "full_stack": False,
            "performance_enhancers": False,
            "skip_stimulants": True,
            "recovery_stack": True,
            "priority_supplements": ["magnesium", "zinc", "NAC", "vitamin_c", "adaptogens"],
            "notes": "Recovery supplements only. Focus on sleep and immune support."
        },
        "interventions": {
            "sauna": False,
            "sauna_duration_mins": 0,
            "cold_plunge": False,
            "cold_duration_mins": 0,
            "red_light": True,
            "contrast_therapy": False,
            "notes": "Skip thermal stress. Red light for recovery only."
        },
        "nutrition": {
            "calorie_modifier": 1.2,
            "carb_modifier": 1.3,
            "protein_priority": True,
            "fasting_allowed": False,
            "notes": "Increase calories significantly. Early dinner. Extra sleep."
        }
    }
}


def calculate_recovery_zone(
    hrv: float | None = None,
    hrv_baseline: float | None = None,
    recovery_score: float | None = None,
    sleep_score: float | None = None,
    strain_yesterday: float | None = None,
    resting_hr: float | None = None,
    rhr_baseline: float | None = None,
) -> tuple[RecoveryZone, float, dict[str, Any]]:
    """
    Calculate recovery zone from composite wearable metrics.

    Uses a weighted average of available metrics to determine recovery state.

    Args:
        hrv: Heart rate variability (ms RMSSD)
        hrv_baseline: User's rolling HRV baseline
        recovery_score: Recovery score from wearable (0-100)
        sleep_score: Sleep score from wearable (0-100)
        strain_yesterday: Previous day's strain/load
        resting_hr: Current resting heart rate
        rhr_baseline: User's rolling RHR baseline

    Returns:
        Tuple of (RecoveryZone, composite_score, breakdown_details)
    """
    scores: list[tuple[float, float]] = []  # (score, weight)
    breakdown: dict[str, Any] = {}

    # HRV relative to baseline (weight: 0.35)
    if hrv is not None and hrv_baseline is not None and hrv_baseline > 0:
        hrv_pct = (hrv / hrv_baseline) * 100
        hrv_score = min(100, max(0, hrv_pct))
        scores.append((hrv_score, 0.35))
        breakdown["hrv"] = {
            "value": hrv,
            "baseline": hrv_baseline,
            "score": hrv_score,
            "status": "above" if hrv >= hrv_baseline else "below"
        }
    elif hrv is not None:
        # No baseline, use absolute thresholds
        if hrv >= 60:
            hrv_score = 85
        elif hrv >= 40:
            hrv_score = 60
        else:
            hrv_score = 35
        scores.append((hrv_score, 0.30))
        breakdown["hrv"] = {"value": hrv, "score": hrv_score, "note": "no baseline"}

    # Direct recovery score from wearable (weight: 0.30)
    if recovery_score is not None:
        scores.append((recovery_score, 0.30))
        breakdown["recovery_score"] = {"value": recovery_score}

    # Sleep score (weight: 0.25)
    if sleep_score is not None:
        scores.append((sleep_score, 0.25))
        breakdown["sleep_score"] = {"value": sleep_score}

    # RHR relative to baseline (weight: 0.10) - inverted (higher is worse)
    if resting_hr is not None and rhr_baseline is not None and rhr_baseline > 0:
        rhr_deviation = ((rhr_baseline - resting_hr) / rhr_baseline) * 50 + 50
        rhr_score = min(100, max(0, rhr_deviation))
        scores.append((rhr_score, 0.10))
        breakdown["resting_hr"] = {
            "value": resting_hr,
            "baseline": rhr_baseline,
            "score": rhr_score,
            "status": "elevated" if resting_hr > rhr_baseline else "normal"
        }

    # Calculate weighted composite score
    if not scores:
        # No data available - default to YELLOW (cautious)
        return RecoveryZone.YELLOW, 50.0, {"note": "No wearable data available"}

    total_weight = sum(w for _, w in scores)
    composite_score = sum(s * w for s, w in scores) / total_weight

    # Apply strain penalty if available
    if strain_yesterday is not None and strain_yesterday > 15:
        strain_penalty = min(10, (strain_yesterday - 15) * 0.5)
        composite_score = max(0, composite_score - strain_penalty)
        breakdown["strain_penalty"] = {"yesterday_strain": strain_yesterday, "penalty": strain_penalty}

    # Determine zone
    if composite_score >= 67:
        zone = RecoveryZone.GREEN
    elif composite_score >= 34:
        zone = RecoveryZone.YELLOW
    else:
        zone = RecoveryZone.RED

    breakdown["composite_score"] = round(composite_score, 1)
    breakdown["zone"] = zone.value

    return zone, composite_score, breakdown


def get_adaptation_matrix(zone: RecoveryZone) -> dict[str, Any]:
    """Get the full adaptation matrix for a recovery zone."""
    return ADAPTATION_MATRIX.get(zone, ADAPTATION_MATRIX[RecoveryZone.YELLOW])


def adapt_training(training_plan: dict[str, Any], zone: RecoveryZone) -> dict[str, Any]:
    """
    Adapt a training plan based on recovery zone.

    Args:
        training_plan: Original training plan
        zone: Current recovery zone

    Returns:
        Adapted training plan with modifications
    """
    adaptations = ADAPTATION_MATRIX[zone]["training"]
    adapted = training_plan.copy()

    # Apply volume modifier
    if "sets" in adapted:
        adapted["sets"] = int(adapted["sets"] * adaptations["volume_modifier"])
    if "duration_mins" in adapted:
        adapted["duration_mins"] = int(adapted["duration_mins"] * adaptations["volume_modifier"])

    # Apply intensity modifier
    if "target_rpe" in adapted:
        adapted["target_rpe"] = min(adapted["target_rpe"], adaptations["rpe_target"])
    if "intensity_pct" in adapted:
        adapted["intensity_pct"] = int(adapted["intensity_pct"] * adaptations["intensity_modifier"])

    # Add session type and notes
    adapted["session_type"] = adaptations["session_type"]
    adapted["recovery_zone"] = zone.value
    adapted["adaptation_notes"] = adaptations["notes"]

    # Handle RED zone - replace with recovery
    if zone == RecoveryZone.RED:
        adapted["original_workout"] = training_plan.get("type", "scheduled workout")
        adapted["type"] = "active_recovery"
        adapted["exercises"] = [
            {"name": "Walking", "duration_mins": 20, "notes": "Easy pace"},
            {"name": "Mobility work", "duration_mins": 15, "notes": "Focus on tight areas"},
            {"name": "Stretching", "duration_mins": 10, "notes": "Gentle, no forcing"}
        ]

    return adapted


def adapt_supplements(supplements: list[dict[str, Any]], zone: RecoveryZone) -> list[dict[str, Any]]:
    """
    Adapt supplement protocol based on recovery zone.

    Args:
        supplements: Original supplement list
        zone: Current recovery zone

    Returns:
        Adapted supplement list
    """
    adaptations = ADAPTATION_MATRIX[zone]["supplements"]
    adapted = []

    # Define supplement categories
    stimulants = {"caffeine", "pre-workout", "ephedrine", "dmaa"}
    performance = {"creatine", "beta-alanine", "citrulline", "pump"}
    recovery = {"magnesium", "zinc", "nac", "vitamin_c", "glycine", "ashwagandha", "adaptogen"}

    for supp in supplements:
        supp_name = supp.get("name", "").lower()
        include = True
        modified = supp.copy()

        # Skip stimulants in YELLOW/RED
        if adaptations.get("skip_stimulants"):
            if any(stim in supp_name for stim in stimulants):
                include = False
                continue

        # Skip performance enhancers in YELLOW/RED
        if not adaptations.get("performance_enhancers", True):
            if any(perf in supp_name for perf in performance):
                include = False
                continue

        if include:
            adapted.append(modified)

    # Add recovery supplements in YELLOW/RED
    if adaptations.get("recovery_stack"):
        recovery_adds = [
            {"name": "Magnesium Glycinate", "dose": "400mg", "timing": "before bed", "rationale": "Recovery support"},
            {"name": "Zinc", "dose": "30mg", "timing": "with dinner", "rationale": "Immune support"},
            {"name": "Vitamin C", "dose": "1000mg", "timing": "morning", "rationale": "Recovery support"},
        ]
        # Add if not already present
        existing_names = {s.get("name", "").lower() for s in adapted}
        for add in recovery_adds:
            if add["name"].lower() not in existing_names:
                add["added_for_recovery"] = True
                adapted.append(add)

    return adapted


def adapt_interventions(interventions: list[dict[str, Any]], zone: RecoveryZone) -> list[dict[str, Any]]:
    """
    Adapt interventions based on recovery zone.

    Args:
        interventions: Original intervention list
        zone: Current recovery zone

    Returns:
        Adapted intervention list
    """
    adaptations = ADAPTATION_MATRIX[zone]["interventions"]
    adapted = []

    for intervention in interventions:
        int_type = intervention.get("type", "").lower()
        modified = intervention.copy()

        # Handle sauna
        if "sauna" in int_type or "heat" in int_type:
            if adaptations["sauna"] is False:
                modified["skipped"] = True
                modified["skip_reason"] = "Recovery zone: Skip thermal stress today"
            elif adaptations["sauna"] == "optional":
                modified["optional"] = True
                modified["duration_mins"] = min(
                    intervention.get("duration_mins", 20),
                    adaptations["sauna_duration_mins"]
                )
                modified["notes"] = "Optional - only if feeling well recovered"

        # Handle cold
        if "cold" in int_type or "plunge" in int_type or "ice" in int_type:
            if adaptations["cold_plunge"] is False:
                modified["skipped"] = True
                modified["skip_reason"] = "Recovery zone: Skip cold stress today"
            elif adaptations["cold_plunge"] == "shower_only":
                modified["type"] = "cold_shower"
                modified["duration_mins"] = adaptations["cold_duration_mins"]
                modified["notes"] = "Cold shower only - no full plunge"

        adapted.append(modified)

    # Ensure red light is included for RED zone
    if zone == RecoveryZone.RED:
        has_red_light = any("red" in i.get("type", "").lower() for i in adapted)
        if not has_red_light:
            adapted.append({
                "type": "red_light",
                "duration_mins": 15,
                "notes": "Recovery support - low stress intervention",
                "added_for_recovery": True
            })

    return adapted


def get_recovery_summary(zone: RecoveryZone, composite_score: float) -> str:
    """Generate a human-readable recovery summary."""
    if zone == RecoveryZone.GREEN:
        return f"Recovery: GREEN ({composite_score:.0f}%) - Full capacity. Training at normal intensity."
    elif zone == RecoveryZone.YELLOW:
        return f"Recovery: YELLOW ({composite_score:.0f}%) - Moderate recovery. Training volume reduced 25%."
    else:
        return f"Recovery: RED ({composite_score:.0f}%) - Low recovery. Active recovery only. Focus on sleep."
