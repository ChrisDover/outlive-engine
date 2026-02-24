"""Whoop data service for parsing exported CSV files and daily input."""

from __future__ import annotations

import csv
import io
import json
import logging
from datetime import date, datetime
from typing import Any

logger = logging.getLogger(__name__)

# Whoop CSV column mappings to our metrics schema
WHOOP_SLEEP_COLUMNS = {
    "Sleep Performance %": "sleep_performance",
    "Sleep Needed (min)": "sleep_needed_minutes",
    "Sleep Debt (min)": "sleep_debt_minutes",
    "Total Sleep Time (min)": "total_sleep_minutes",
    "Time in Bed (min)": "time_in_bed_minutes",
    "Sleep Efficiency %": "sleep_efficiency",
    "Light Sleep Time (min)": "light_sleep_minutes",
    "Deep (SWS) Time (min)": "deep_sleep_minutes",
    "REM Time (min)": "rem_sleep_minutes",
    "Awake Time (min)": "awake_minutes",
    "Sleep Latency (min)": "sleep_latency_minutes",
    "Respiratory Rate": "respiratory_rate",
}

WHOOP_RECOVERY_COLUMNS = {
    "Recovery Score %": "recovery_score",
    "Resting Heart Rate (bpm)": "resting_heart_rate",
    "Heart Rate Variability (ms)": "hrv_rmssd",
    "Skin Temp (C)": "skin_temp_celsius",
    "Blood Oxygen %": "spo2",
}

WHOOP_STRAIN_COLUMNS = {
    "Strain": "strain_score",
    "Max HR": "max_heart_rate",
    "Average HR": "average_heart_rate",
    "Calories": "calories_burned",
}


def _parse_date(date_str: str) -> date | None:
    """Parse various date formats from Whoop exports."""
    formats = [
        "%Y-%m-%d",
        "%m/%d/%Y",
        "%m/%d/%y",
        "%d/%m/%Y",
        "%d-%m-%Y",
    ]
    for fmt in formats:
        try:
            return datetime.strptime(date_str.strip(), fmt).date()
        except ValueError:
            continue
    return None


def _safe_float(value: str) -> float | None:
    """Safely convert a string to float."""
    if not value or value.strip() in ("", "-", "N/A", "null"):
        return None
    try:
        return float(value.strip().replace(",", ""))
    except ValueError:
        return None


def _safe_int(value: str) -> int | None:
    """Safely convert a string to int."""
    f = _safe_float(value)
    return int(f) if f is not None else None


def parse_whoop_csv(content: str) -> list[dict[str, Any]]:
    """Parse a Whoop CSV export file.

    Returns a list of daily entries with metrics.
    """
    reader = csv.DictReader(io.StringIO(content))

    # Group data by date
    daily_data: dict[date, dict[str, Any]] = {}

    for row in reader:
        # Find the date column (various possible names)
        date_val = None
        for col in ["Date", "date", "Cycle start time", "Start", "Start Time"]:
            if col in row and row[col]:
                date_val = _parse_date(row[col].split()[0])  # Take just date part
                if date_val:
                    break

        if not date_val:
            continue

        if date_val not in daily_data:
            daily_data[date_val] = {}

        # Extract sleep metrics
        for csv_col, metric_name in WHOOP_SLEEP_COLUMNS.items():
            if csv_col in row:
                val = _safe_float(row[csv_col])
                if val is not None:
                    daily_data[date_val][metric_name] = val

        # Extract recovery metrics
        for csv_col, metric_name in WHOOP_RECOVERY_COLUMNS.items():
            if csv_col in row:
                val = _safe_float(row[csv_col])
                if val is not None:
                    daily_data[date_val][metric_name] = val

        # Extract strain metrics
        for csv_col, metric_name in WHOOP_STRAIN_COLUMNS.items():
            if csv_col in row:
                val = _safe_float(row[csv_col])
                if val is not None:
                    daily_data[date_val][metric_name] = val

    # Convert to list format expected by wearables batch endpoint
    entries = []
    for d, metrics in sorted(daily_data.items()):
        if metrics:  # Only include days with data
            entries.append({
                "date": d,
                "source": "whoop",
                "metrics": metrics,
            })

    return entries


def parse_whoop_recovery_csv(content: str) -> list[dict[str, Any]]:
    """Parse Whoop recovery-specific CSV export."""
    return _parse_whoop_typed_csv(content, WHOOP_RECOVERY_COLUMNS)


def parse_whoop_sleep_csv(content: str) -> list[dict[str, Any]]:
    """Parse Whoop sleep-specific CSV export."""
    return _parse_whoop_typed_csv(content, WHOOP_SLEEP_COLUMNS)


def parse_whoop_strain_csv(content: str) -> list[dict[str, Any]]:
    """Parse Whoop strain-specific CSV export."""
    return _parse_whoop_typed_csv(content, WHOOP_STRAIN_COLUMNS)


def _parse_whoop_typed_csv(
    content: str, column_mapping: dict[str, str]
) -> list[dict[str, Any]]:
    """Generic parser for typed Whoop CSV exports."""
    reader = csv.DictReader(io.StringIO(content))
    daily_data: dict[date, dict[str, Any]] = {}

    for row in reader:
        date_val = None
        for col in ["Date", "date", "Cycle start time", "Start", "Start Time"]:
            if col in row and row[col]:
                date_val = _parse_date(row[col].split()[0])
                if date_val:
                    break

        if not date_val:
            continue

        if date_val not in daily_data:
            daily_data[date_val] = {}

        for csv_col, metric_name in column_mapping.items():
            if csv_col in row:
                val = _safe_float(row[csv_col])
                if val is not None:
                    daily_data[date_val][metric_name] = val

    entries = []
    for d, metrics in sorted(daily_data.items()):
        if metrics:
            entries.append({
                "date": d,
                "source": "whoop",
                "metrics": metrics,
            })

    return entries


def validate_daily_whoop_input(metrics: dict[str, Any]) -> dict[str, Any]:
    """Validate and normalize daily Whoop input from the frontend.

    Expected metrics:
    - recovery_score: 0-100
    - hrv_rmssd: positive float (ms)
    - resting_heart_rate: positive int (bpm)
    - sleep_performance: 0-100
    - strain_score: 0-21
    - calories_burned: positive int
    """
    validated = {}

    # Recovery score (0-100)
    if "recovery_score" in metrics:
        val = metrics["recovery_score"]
        if isinstance(val, (int, float)) and 0 <= val <= 100:
            validated["recovery_score"] = float(val)

    # HRV (positive, typically 10-200ms)
    if "hrv_rmssd" in metrics:
        val = metrics["hrv_rmssd"]
        if isinstance(val, (int, float)) and val > 0:
            validated["hrv_rmssd"] = float(val)

    # Resting heart rate (positive, typically 30-100 bpm)
    if "resting_heart_rate" in metrics:
        val = metrics["resting_heart_rate"]
        if isinstance(val, (int, float)) and val > 0:
            validated["resting_heart_rate"] = float(val)

    # Sleep performance (0-100)
    if "sleep_performance" in metrics:
        val = metrics["sleep_performance"]
        if isinstance(val, (int, float)) and 0 <= val <= 100:
            validated["sleep_performance"] = float(val)

    # Total sleep minutes
    if "total_sleep_minutes" in metrics:
        val = metrics["total_sleep_minutes"]
        if isinstance(val, (int, float)) and val >= 0:
            validated["total_sleep_minutes"] = float(val)

    # Strain score (0-21)
    if "strain_score" in metrics:
        val = metrics["strain_score"]
        if isinstance(val, (int, float)) and 0 <= val <= 21:
            validated["strain_score"] = float(val)

    # Calories burned
    if "calories_burned" in metrics:
        val = metrics["calories_burned"]
        if isinstance(val, (int, float)) and val >= 0:
            validated["calories_burned"] = float(val)

    # SpO2 (typically 90-100%)
    if "spo2" in metrics:
        val = metrics["spo2"]
        if isinstance(val, (int, float)) and 0 <= val <= 100:
            validated["spo2"] = float(val)

    # Respiratory rate
    if "respiratory_rate" in metrics:
        val = metrics["respiratory_rate"]
        if isinstance(val, (int, float)) and val > 0:
            validated["respiratory_rate"] = float(val)

    return validated
