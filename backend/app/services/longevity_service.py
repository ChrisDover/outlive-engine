"""
Longevity scoring + biomarker aggregation.

Pure functions (no DB / IO) so the scoring logic is unit-testable in isolation.
The router decrypts panels/wearables/body-composition and passes plain dicts in.
"""

from __future__ import annotations

from typing import Any


def _lerp(x: float, x0: float, x1: float, y0: float, y1: float) -> float:
    if x1 == x0:
        return y0
    t = (x - x0) / (x1 - x0)
    t = max(0.0, min(1.0, t))
    return y0 + t * (y1 - y0)


def score_lower_better(value: float, target: float, ref_high: float) -> float:
    """100 at/under target, ~70 at the reference ceiling, →0 well beyond it."""
    if value <= target:
        return 100.0
    if value <= ref_high:
        return _lerp(value, target, ref_high, 100.0, 70.0)
    return _lerp(value, ref_high, ref_high * 1.5, 70.0, 0.0)


def score_higher_better(value: float, ref_low: float, target: float) -> float:
    """100 at/over target, ~70 at the reference floor, →0 well below it."""
    if value >= target:
        return 100.0
    if value >= ref_low:
        return _lerp(value, ref_low, target, 70.0, 100.0)
    return _lerp(value, ref_low * 0.5, ref_low, 0.0, 70.0)


# Marker key (substring match, lowercased) -> (category, direction, p1, p2).
# direction "lower": p1=optimal target, p2=reference ceiling.
# direction "higher": p1=reference floor, p2=optimal target.
BIOMARKER_RULES: list[tuple[str, tuple[str, str, float, float]]] = [
    ("non-hdl", ("Cardiovascular", "lower", 100, 130)),
    ("apolipoprotein", ("Cardiovascular", "lower", 80, 90)),
    ("apob", ("Cardiovascular", "lower", 80, 90)),
    ("apo b", ("Cardiovascular", "lower", 80, 90)),
    ("ldl", ("Cardiovascular", "lower", 80, 100)),
    ("hdl", ("Cardiovascular", "higher", 40, 60)),
    ("lp(a)", ("Cardiovascular", "lower", 30, 50)),
    ("hba1c", ("Metabolic", "lower", 5.3, 5.7)),
    ("a1c", ("Metabolic", "lower", 5.3, 5.7)),
    ("glucose", ("Metabolic", "lower", 90, 100)),
    ("triglyceride", ("Metabolic", "lower", 80, 150)),
    ("insulin", ("Metabolic", "lower", 5, 15)),
    ("hs-crp", ("Inflammation", "lower", 0.5, 1.0)),
    ("crp", ("Inflammation", "lower", 0.5, 1.0)),
]

CATEGORY_ORDER = ["Cardiovascular", "Metabolic", "Recovery", "Body Comp", "Inflammation"]
_BIO_CATEGORIES = ("Cardiovascular", "Metabolic", "Inflammation")


def _match_rule(name: str) -> tuple[str, str, float, float] | None:
    n = name.lower()
    for key, rule in BIOMARKER_RULES:
        if key in n:
            return rule
    return None


def _to_float(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def biomarker_category_scores(markers: list[dict[str, Any]]) -> dict[str, list[tuple[float, str]]]:
    """Map a panel's markers to category -> [(score, marker_name)]."""
    cats: dict[str, list[tuple[float, str]]] = {}
    for m in markers:
        name = (m.get("name") or "").strip()
        v = _to_float(m.get("value"))
        if not name or v is None:
            continue
        rule = _match_rule(name)
        if not rule:
            continue
        category, direction, p1, p2 = rule
        s = score_lower_better(v, p1, p2) if direction == "lower" else score_higher_better(v, p1, p2)
        cats.setdefault(category, []).append((s, name))
    return cats


def _avg(xs: list[float]) -> float:
    return sum(xs) / len(xs)


def recovery_score(wearable_metrics: list[dict[str, Any]]) -> float | None:
    """Average per-day blend of recovery, sleep, and HRV over recent days."""
    days: list[float] = []
    for m in wearable_metrics[-7:]:
        per: list[float] = []
        rec = _to_float(m.get("recovery_score")) or _to_float(m.get("readiness_score"))
        slp = _to_float(m.get("sleep_score"))
        hrv = _to_float(m.get("hrv"))
        if rec is not None:
            per.append(max(0.0, min(100.0, rec)))
        if slp is not None:
            per.append(max(0.0, min(100.0, slp)))
        if hrv is not None:
            per.append(_lerp(hrv, 25, 75, 30, 100))
        if per:
            days.append(_avg(per))
    return _avg(days) if days else None


def bodycomp_score(metrics: dict[str, Any]) -> float | None:
    bf = _to_float(metrics.get("body_fat_pct")) or _to_float(metrics.get("body_fat_percent"))
    if bf is None:
        return None
    return score_lower_better(bf, 14, 25)


def compute_longevity(
    latest_markers: list[dict[str, Any]],
    prev_markers: list[dict[str, Any]],
    wearable_metrics: list[dict[str, Any]],
    bodycomp_metrics: dict[str, Any] | None,
) -> dict[str, Any]:
    """Composite longevity score + per-category breakdown."""
    biocats = biomarker_category_scores(latest_markers)
    values: dict[str, float] = {}
    details: dict[str, str] = {}

    for cat in _BIO_CATEGORIES:
        items = biocats.get(cat)
        if items:
            values[cat] = _avg([s for s, _ in items])
            names = ", ".join(sorted({n for _, n in items}))
            details[cat] = names

    rec = recovery_score(wearable_metrics)
    if rec is not None:
        values["Recovery"] = rec
        details["Recovery"] = "HRV, sleep & recovery (7-day avg)"

    bc = bodycomp_score(bodycomp_metrics) if bodycomp_metrics else None
    if bc is not None:
        values["Body Comp"] = bc
        details["Body Comp"] = "Body fat %"

    breakdown = [
        {"label": cat, "value": round(values[cat]), "detail": details.get(cat, "")}
        for cat in CATEGORY_ORDER
        if cat in values
    ]

    if not breakdown:
        return {"score": 0, "delta": None, "has_data": False, "breakdown": []}

    score = round(_avg(list(values.values())))

    delta: int | None = None
    if prev_markers:
        prevcats = biomarker_category_scores(prev_markers)
        cur_vals, prev_vals = [], []
        for cat in _BIO_CATEGORIES:
            if cat in biocats and cat in prevcats:
                cur_vals.append(_avg([s for s, _ in biocats[cat]]))
                prev_vals.append(_avg([s for s, _ in prevcats[cat]]))
        if cur_vals:
            delta = round(_avg(cur_vals) - _avg(prev_vals))

    return {"score": score, "delta": delta, "has_data": True, "breakdown": breakdown}


def build_biomarker_series(panels: list[tuple[str, list[dict[str, Any]]]]) -> list[dict[str, Any]]:
    """
    Aggregate markers across panels into per-marker time series.

    panels: list of (panel_date_iso, markers) ordered oldest → newest.
    """
    series: dict[str, dict[str, Any]] = {}
    for panel_date_iso, markers in panels:
        for m in markers:
            name = (m.get("name") or "").strip()
            v = _to_float(m.get("value"))
            if not name or v is None:
                continue
            entry = series.setdefault(
                name.lower(),
                {
                    "name": name,
                    "unit": m.get("unit") or "",
                    "reference_low": m.get("reference_low"),
                    "reference_high": m.get("reference_high"),
                    "history": [],
                },
            )
            if m.get("reference_low") is not None:
                entry["reference_low"] = m.get("reference_low")
            if m.get("reference_high") is not None:
                entry["reference_high"] = m.get("reference_high")
            if m.get("unit"):
                entry["unit"] = m.get("unit")
            entry["history"].append({"date": panel_date_iso, "value": v})

    out: list[dict[str, Any]] = []
    for entry in series.values():
        latest = entry["history"][-1]["value"] if entry["history"] else None
        low, high = entry["reference_low"], entry["reference_high"]
        oor = latest is not None and (
            (high is not None and latest > high) or (low is not None and latest < low)
        )
        entry["latest"] = latest
        entry["out_of_range"] = oor
        out.append(entry)

    # Out-of-range first, then markers with the most history.
    out.sort(key=lambda e: (not e["out_of_range"], -len(e["history"])))
    return out
