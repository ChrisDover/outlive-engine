"""Circaseptan Engine - 7-day biological rhythm integration.

Circaseptan rhythms are ~7-day biological cycles that affect immune function,
hormones, and recovery capacity. This engine integrates these rhythms into
daily protocol generation.
"""

from __future__ import annotations

import json
from datetime import date
from pathlib import Path
from typing import Any

# Load circaseptan profiles from data file
_CIRCASEPTAN_DATA: dict[str, Any] | None = None


def _load_circaseptan_data() -> dict[str, Any]:
    """Load circaseptan profiles from JSON file."""
    global _CIRCASEPTAN_DATA
    if _CIRCASEPTAN_DATA is not None:
        return _CIRCASEPTAN_DATA

    data_path = Path(__file__).parent.parent.parent / "data" / "circaseptan.json"
    if data_path.exists():
        with open(data_path) as f:
            _CIRCASEPTAN_DATA = json.load(f)
    else:
        # Fallback inline data
        _CIRCASEPTAN_DATA = {"profiles": _get_default_profiles()}

    return _CIRCASEPTAN_DATA


def _get_default_profiles() -> list[dict[str, Any]]:
    """Default circaseptan profiles if file not found."""
    return [
        {
            "day_of_week": 0,
            "name": "Monday - Cortisol Peak",
            "focus": "immune_reset",
            "training_emphasis": "Moderate compound movements, RPE 6-7",
            "nutrition_focus": "Anti-inflammatory emphasis",
            "intervention_focus": "Cold shower, meditation, red light",
            "hormonal_notes": "Cortisol peaks early. Good for challenging work.",
            "immune_notes": "Immune function recovering. Support with zinc, vitamin C."
        },
        {
            "day_of_week": 1,
            "name": "Tuesday - Anabolic Window",
            "focus": "muscle_building",
            "training_emphasis": "High intensity, RPE 8-9. Push compounds.",
            "nutrition_focus": "Higher carbs around training. Protein bolus post-workout.",
            "intervention_focus": "Sauna post-workout for GH. Skip cold post-training.",
            "hormonal_notes": "Anabolic hormones favorable. Best day for maximal effort.",
            "immune_notes": "Brief immunosuppression post-training is normal."
        },
        {
            "day_of_week": 2,
            "name": "Wednesday - Anabolic Continuation",
            "focus": "muscle_building",
            "training_emphasis": "Upper body or accessory work. RPE 7-8.",
            "nutrition_focus": "Protein emphasis. Leucine-rich foods.",
            "intervention_focus": "Contrast therapy if recovered. Sleep optimization.",
            "hormonal_notes": "Anabolic environment continues. IGF-1 responsive.",
            "immune_notes": "Good for vitamin D optimization."
        },
        {
            "day_of_week": 3,
            "name": "Thursday - Metabolic Flexibility",
            "focus": "fat_oxidation",
            "training_emphasis": "Zone 2 cardio. Fasted training beneficial.",
            "nutrition_focus": "Lower carb window. Higher fat. Extended fast option.",
            "intervention_focus": "Cold exposure enhances fat oxidation.",
            "hormonal_notes": "Good day for metabolic stress without high cortisol.",
            "immune_notes": "Fasting activates autophagy - immune cleanup."
        },
        {
            "day_of_week": 4,
            "name": "Friday - Hormetic Stress",
            "focus": "adaptation",
            "training_emphasis": "Hard finish. HIIT or heavy lifts. RPE 8-9.",
            "nutrition_focus": "Refeed opportunity. Higher carbs post-workout.",
            "intervention_focus": "Full protocol: training + sauna + cold plunge.",
            "hormonal_notes": "Growth hormone spike from combined stressors.",
            "immune_notes": "Ensure zinc, vitamin C, sleep after stress day."
        },
        {
            "day_of_week": 5,
            "name": "Saturday - Social Recovery",
            "focus": "recovery",
            "training_emphasis": "Active recovery only. Mobility, yoga, recreation.",
            "nutrition_focus": "Flexible eating. Maintain protein. Moderate indulgence OK.",
            "intervention_focus": "Social connection. Massage. Nature exposure.",
            "hormonal_notes": "Let anabolic recovery complete. Avoid cortisol spikes.",
            "immune_notes": "Social connection supports immune function."
        },
        {
            "day_of_week": 6,
            "name": "Sunday - Melatonin Peak",
            "focus": "gut_reset",
            "training_emphasis": "Rest or very light Zone 2. No intensity.",
            "nutrition_focus": "Gut-friendly. Fermented foods. Early dinner.",
            "intervention_focus": "Red light evening. Blue light blocking. Sleep prep.",
            "hormonal_notes": "Melatonin production critical tonight.",
            "immune_notes": "Gut-immune axis day. Feed beneficial bacteria."
        }
    ]


def get_circaseptan_day(target_date: date) -> int:
    """Get the day of week (0=Monday, 6=Sunday) for a date."""
    return target_date.weekday()


async def get_circaseptan_profile(target_date: date) -> dict[str, Any]:
    """
    Get the circaseptan profile for a target date.

    Args:
        target_date: The date to get the profile for

    Returns:
        Profile dict with focus, training, nutrition, intervention guidance
    """
    day_of_week = get_circaseptan_day(target_date)
    data = _load_circaseptan_data()

    for profile in data.get("profiles", []):
        if profile.get("day_of_week") == day_of_week:
            return profile

    # Fallback
    return {
        "day_of_week": day_of_week,
        "name": f"Day {day_of_week}",
        "focus": "balanced",
        "training_emphasis": "Moderate training",
        "nutrition_focus": "Balanced nutrition",
        "intervention_focus": "Standard protocol"
    }


def apply_circaseptan_adjustments(
    protocol: dict[str, Any],
    profile: dict[str, Any]
) -> dict[str, Any]:
    """
    Apply circaseptan day-specific adjustments to a protocol.

    Args:
        protocol: The daily protocol to adjust
        profile: The circaseptan profile for the day

    Returns:
        Adjusted protocol with circaseptan modifications
    """
    adjusted = protocol.copy()
    focus = profile.get("focus", "balanced")

    # Add circaseptan metadata
    adjusted["circaseptan"] = {
        "day_name": profile.get("name"),
        "focus": focus,
        "notes": []
    }

    # Apply focus-specific adjustments
    if focus == "immune_reset":
        adjusted = _apply_immune_focus(adjusted, profile)
    elif focus == "muscle_building":
        adjusted = _apply_anabolic_focus(adjusted, profile)
    elif focus == "fat_oxidation":
        adjusted = _apply_metabolic_focus(adjusted, profile)
    elif focus == "adaptation":
        adjusted = _apply_hormetic_focus(adjusted, profile)
    elif focus == "recovery":
        adjusted = _apply_recovery_focus(adjusted, profile)
    elif focus == "gut_reset":
        adjusted = _apply_gut_focus(adjusted, profile)

    return adjusted


def _apply_immune_focus(protocol: dict[str, Any], profile: dict[str, Any]) -> dict[str, Any]:
    """Apply Monday immune reset focus."""
    protocol["circaseptan"]["notes"].append("Immune reset day - prioritize anti-inflammatory nutrition")

    # Adjust training
    if "training" in protocol:
        training = protocol["training"]
        training["circaseptan_guidance"] = profile.get("training_emphasis")
        if "rpe_target" in training:
            training["rpe_target"] = min(training.get("rpe_target", 7), 7)

    # Adjust nutrition
    if "nutrition" in protocol:
        protocol["nutrition"]["circaseptan_guidance"] = profile.get("nutrition_focus")
        protocol["nutrition"]["emphasis"] = ["omega-3s", "colorful_vegetables", "anti-inflammatory"]

    # Prioritize immune supplements
    if "supplements" in protocol:
        for supp in protocol["supplements"]:
            if any(imm in supp.get("name", "").lower() for imm in ["zinc", "vitamin c", "d3", "elderberry"]):
                supp["circaseptan_priority"] = True

    return protocol


def _apply_anabolic_focus(protocol: dict[str, Any], profile: dict[str, Any]) -> dict[str, Any]:
    """Apply Tuesday/Wednesday anabolic focus."""
    protocol["circaseptan"]["notes"].append("Anabolic window - favorable hormones for building")

    # Training adjustments
    if "training" in protocol:
        training = protocol["training"]
        training["circaseptan_guidance"] = profile.get("training_emphasis")
        training["anabolic_window"] = True
        # Allow higher intensity
        if "rpe_target" in training:
            training["rpe_target"] = max(training.get("rpe_target", 8), 8)

    # Nutrition adjustments
    if "nutrition" in protocol:
        protocol["nutrition"]["circaseptan_guidance"] = profile.get("nutrition_focus")
        protocol["nutrition"]["carb_timing"] = "around_training"
        protocol["nutrition"]["protein_bolus"] = "post_workout"

    # Intervention adjustments
    if "interventions" in protocol:
        for intervention in protocol["interventions"]:
            # Skip cold immediately post-training on anabolic days
            if "cold" in intervention.get("type", "").lower():
                intervention["timing_note"] = "Wait 3+ hours after training to preserve hypertrophy signal"

    return protocol


def _apply_metabolic_focus(protocol: dict[str, Any], profile: dict[str, Any]) -> dict[str, Any]:
    """Apply Thursday metabolic flexibility focus."""
    protocol["circaseptan"]["notes"].append("Metabolic flexibility day - fat oxidation emphasis")

    # Training adjustments
    if "training" in protocol:
        training = protocol["training"]
        training["circaseptan_guidance"] = profile.get("training_emphasis")
        training["fasted_option"] = True
        training["zone2_emphasis"] = True

    # Nutrition adjustments
    if "nutrition" in protocol:
        nutrition = protocol["nutrition"]
        nutrition["circaseptan_guidance"] = profile.get("nutrition_focus")
        nutrition["carb_reduction"] = True
        nutrition["fat_emphasis"] = True
        nutrition["fasting_window_suggestion"] = "16-20 hours"

    # Cold exposure more beneficial
    if "interventions" in protocol:
        for intervention in protocol["interventions"]:
            if "cold" in intervention.get("type", "").lower():
                intervention["circaseptan_priority"] = True
                intervention["fat_oxidation_benefit"] = True

    return protocol


def _apply_hormetic_focus(protocol: dict[str, Any], profile: dict[str, Any]) -> dict[str, Any]:
    """Apply Friday hormetic stress focus."""
    protocol["circaseptan"]["notes"].append("Hormetic stress day - push hard before recovery weekend")

    # Training - go hard
    if "training" in protocol:
        training = protocol["training"]
        training["circaseptan_guidance"] = profile.get("training_emphasis")
        training["intensity_day"] = True

    # Nutrition - refeed
    if "nutrition" in protocol:
        nutrition = protocol["nutrition"]
        nutrition["circaseptan_guidance"] = profile.get("nutrition_focus")
        nutrition["refeed_day"] = True
        nutrition["carb_replenishment"] = True

    # Full intervention stack
    if "interventions" in protocol:
        protocol["circaseptan"]["notes"].append("Full intervention stack: sauna + cold plunge")
        for intervention in protocol["interventions"]:
            intervention["circaseptan_priority"] = True

    return protocol


def _apply_recovery_focus(protocol: dict[str, Any], profile: dict[str, Any]) -> dict[str, Any]:
    """Apply Saturday recovery focus."""
    protocol["circaseptan"]["notes"].append("Social recovery day - prioritize rest and connection")

    # Training - active recovery only
    if "training" in protocol:
        training = protocol["training"]
        training["circaseptan_guidance"] = profile.get("training_emphasis")
        training["recovery_day"] = True
        training["type"] = "active_recovery"
        training["activities"] = ["mobility", "yoga", "walking", "recreation"]

    # Nutrition - flexible
    if "nutrition" in protocol:
        nutrition = protocol["nutrition"]
        nutrition["circaseptan_guidance"] = profile.get("nutrition_focus")
        nutrition["flexible_day"] = True
        nutrition["social_eating_ok"] = True

    # Social focus
    protocol["circaseptan"]["social_priority"] = True
    protocol["circaseptan"]["notes"].append("Social connection supports immune function and recovery")

    return protocol


def _apply_gut_focus(protocol: dict[str, Any], profile: dict[str, Any]) -> dict[str, Any]:
    """Apply Sunday gut reset focus."""
    protocol["circaseptan"]["notes"].append("Gut reset day - prepare for strong Monday")

    # Training - minimal
    if "training" in protocol:
        training = protocol["training"]
        training["circaseptan_guidance"] = profile.get("training_emphasis")
        training["rest_day"] = True

    # Nutrition - gut-friendly
    if "nutrition" in protocol:
        nutrition = protocol["nutrition"]
        nutrition["circaseptan_guidance"] = profile.get("nutrition_focus")
        nutrition["gut_focus"] = True
        nutrition["emphasis"] = ["fermented_foods", "prebiotic_fiber", "bone_broth"]
        nutrition["early_dinner"] = True
        nutrition["overnight_fast"] = "12-14 hours"

    # Evening wind-down
    if "sleep" in protocol:
        protocol["sleep"]["early_wind_down"] = True
        protocol["sleep"]["blue_light_cutoff"] = "sunset"

    return protocol


def get_circaseptan_summary(target_date: date) -> str:
    """Get a brief summary of the circaseptan day."""
    day = get_circaseptan_day(target_date)
    summaries = {
        0: "Monday: Cortisol Peak - Immune reset, moderate training",
        1: "Tuesday: Anabolic Window - Push hard, high intensity",
        2: "Wednesday: Anabolic Continuation - Upper body, technique focus",
        3: "Thursday: Metabolic Flexibility - Zone 2, low carb, fasting",
        4: "Friday: Hormetic Stress - Hard finish, full intervention stack",
        5: "Saturday: Social Recovery - Active recovery, flexibility",
        6: "Sunday: Melatonin Peak - Gut reset, early dinner, sleep prep"
    }
    return summaries.get(day, f"Day {day}")


def get_training_modifier_for_day(target_date: date) -> dict[str, Any]:
    """Get training-specific modifiers for the circaseptan day."""
    day = get_circaseptan_day(target_date)
    modifiers = {
        0: {"intensity_cap": 7, "volume_modifier": 0.85, "type_suggestion": "compound"},
        1: {"intensity_cap": 9, "volume_modifier": 1.0, "type_suggestion": "strength"},
        2: {"intensity_cap": 8, "volume_modifier": 0.9, "type_suggestion": "hypertrophy"},
        3: {"intensity_cap": 6, "volume_modifier": 0.7, "type_suggestion": "zone2"},
        4: {"intensity_cap": 9, "volume_modifier": 1.0, "type_suggestion": "hiit"},
        5: {"intensity_cap": 4, "volume_modifier": 0.3, "type_suggestion": "recovery"},
        6: {"intensity_cap": 5, "volume_modifier": 0.25, "type_suggestion": "rest"},
    }
    return modifiers.get(day, {"intensity_cap": 7, "volume_modifier": 0.8})


def get_nutrition_modifier_for_day(target_date: date) -> dict[str, Any]:
    """Get nutrition-specific modifiers for the circaseptan day."""
    day = get_circaseptan_day(target_date)
    modifiers = {
        0: {"carb_modifier": 0.9, "focus": "anti-inflammatory", "fasting_ok": False},
        1: {"carb_modifier": 1.2, "focus": "performance", "fasting_ok": False},
        2: {"carb_modifier": 1.0, "focus": "protein", "fasting_ok": False},
        3: {"carb_modifier": 0.6, "focus": "fat_oxidation", "fasting_ok": True},
        4: {"carb_modifier": 1.3, "focus": "refeed", "fasting_ok": False},
        5: {"carb_modifier": 1.0, "focus": "flexible", "fasting_ok": False},
        6: {"carb_modifier": 0.8, "focus": "gut_health", "fasting_ok": True},
    }
    return modifiers.get(day, {"carb_modifier": 1.0, "focus": "balanced"})
