"""Progress tracking routes: adherence logging, goals, and weekly summaries."""

from __future__ import annotations

import json
from datetime import date, datetime, timedelta, timezone
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.config import get_settings
from app.models.database import get_pool
from app.models.schemas import (
    DailyAdherenceCreate,
    DailyAdherenceResponse,
    DailyAdherenceUpdate,
    GoalDefinitionCreate,
    GoalDefinitionResponse,
    GoalDefinitionUpdate,
    WeeklySummaryResponse,
)
from app.security.auth import get_current_user
from app.security.encryption import decrypt_field, derive_key, encrypt_field
from app.services.ai_service import chat_completion_multi

router = APIRouter(prefix="/progress", tags=["progress"])


def _enc_key() -> bytes:
    return derive_key(get_settings().FIELD_ENCRYPTION_KEY)


# ── Daily Adherence ──────────────────────────────────────────────────────────


@router.get("/adherence", response_model=list[DailyAdherenceResponse])
async def list_adherence(
    start_date: date = Query(default_factory=lambda: date.today() - timedelta(days=7)),
    end_date: date = Query(default_factory=date.today),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[DailyAdherenceResponse]:
    """List adherence records for a date range."""
    pool = get_pool()
    rows = await pool.fetch(
        """
        SELECT id, user_id, date, protocol_id, item_type, item_name, completed, notes, created_at
        FROM daily_adherence
        WHERE user_id = $1 AND date >= $2 AND date <= $3
        ORDER BY date DESC, item_type, item_name
        """,
        current_user["id"],
        start_date,
        end_date,
    )
    return [
        DailyAdherenceResponse(
            id=r["id"],
            user_id=r["user_id"],
            date=r["date"],
            protocol_id=r["protocol_id"],
            item_type=r["item_type"],
            item_name=r["item_name"],
            completed=r["completed"],
            notes=r["notes"],
            created_at=r["created_at"],
        )
        for r in rows
    ]


@router.get("/adherence/today", response_model=list[DailyAdherenceResponse])
async def get_today_adherence(
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[DailyAdherenceResponse]:
    """Get adherence records for today."""
    pool = get_pool()
    today = date.today()
    rows = await pool.fetch(
        """
        SELECT id, user_id, date, protocol_id, item_type, item_name, completed, notes, created_at
        FROM daily_adherence
        WHERE user_id = $1 AND date = $2
        ORDER BY item_type, item_name
        """,
        current_user["id"],
        today,
    )
    return [
        DailyAdherenceResponse(
            id=r["id"],
            user_id=r["user_id"],
            date=r["date"],
            protocol_id=r["protocol_id"],
            item_type=r["item_type"],
            item_name=r["item_name"],
            completed=r["completed"],
            notes=r["notes"],
            created_at=r["created_at"],
        )
        for r in rows
    ]


@router.post("/adherence", response_model=DailyAdherenceResponse, status_code=status.HTTP_201_CREATED)
async def log_adherence(
    body: DailyAdherenceCreate,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> DailyAdherenceResponse:
    """Log an adherence item (supplement taken, workout done, etc.)."""
    pool = get_pool()
    now = datetime.now(timezone.utc)

    row = await pool.fetchrow(
        """
        INSERT INTO daily_adherence (user_id, date, protocol_id, item_type, item_name, completed, notes, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (user_id, date, item_type, item_name) DO UPDATE SET
            completed = EXCLUDED.completed,
            notes = EXCLUDED.notes
        RETURNING id, user_id, date, protocol_id, item_type, item_name, completed, notes, created_at
        """,
        current_user["id"],
        body.date,
        body.protocol_id,
        body.item_type.value,
        body.item_name,
        body.completed,
        body.notes,
        now,
    )

    return DailyAdherenceResponse(
        id=row["id"],
        user_id=row["user_id"],
        date=row["date"],
        protocol_id=row["protocol_id"],
        item_type=row["item_type"],
        item_name=row["item_name"],
        completed=row["completed"],
        notes=row["notes"],
        created_at=row["created_at"],
    )


@router.post("/adherence/batch", response_model=list[DailyAdherenceResponse])
async def log_adherence_batch(
    items: list[DailyAdherenceCreate],
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[DailyAdherenceResponse]:
    """Log multiple adherence items at once."""
    results = []
    for item in items:
        result = await log_adherence(item, current_user)
        results.append(result)
    return results


@router.put("/adherence/{adherence_id}", response_model=DailyAdherenceResponse)
async def update_adherence(
    adherence_id: UUID,
    body: DailyAdherenceUpdate,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> DailyAdherenceResponse:
    """Update an adherence record (mark complete/incomplete, add notes)."""
    pool = get_pool()

    updates = []
    params: list[Any] = [adherence_id, current_user["id"]]
    param_idx = 3

    if body.completed is not None:
        updates.append(f"completed = ${param_idx}")
        params.append(body.completed)
        param_idx += 1

    if body.notes is not None:
        updates.append(f"notes = ${param_idx}")
        params.append(body.notes)
        param_idx += 1

    if not updates:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="No fields to update")

    query = f"""
        UPDATE daily_adherence SET {', '.join(updates)}
        WHERE id = $1 AND user_id = $2
        RETURNING id, user_id, date, protocol_id, item_type, item_name, completed, notes, created_at
    """

    row = await pool.fetchrow(query, *params)

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Adherence record not found")

    return DailyAdherenceResponse(
        id=row["id"],
        user_id=row["user_id"],
        date=row["date"],
        protocol_id=row["protocol_id"],
        item_type=row["item_type"],
        item_name=row["item_name"],
        completed=row["completed"],
        notes=row["notes"],
        created_at=row["created_at"],
    )


@router.post("/adherence/quick-log")
async def quick_log_adherence(
    message: str = Query(..., description="Natural language description of what was done"),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    """
    Quick log adherence from natural language input.

    Example: "Done: cold plunge, took supplements, 45 min workout"
    """
    # Parse the message and log items
    parsed_items = await _parse_adherence_message(message)

    results = []
    today = date.today()

    for item in parsed_items:
        try:
            body = DailyAdherenceCreate(
                date=today,
                item_type=item["type"],
                item_name=item["name"],
                completed=True,
                notes=item.get("notes"),
            )
            result = await log_adherence(body, current_user)
            results.append({
                "logged": True,
                "item_type": item["type"],
                "item_name": item["name"],
            })
        except Exception as e:
            results.append({
                "logged": False,
                "item_type": item["type"],
                "item_name": item["name"],
                "error": str(e),
            })

    return {
        "message": message,
        "items_logged": len([r for r in results if r["logged"]]),
        "results": results,
    }


async def _parse_adherence_message(message: str) -> list[dict[str, Any]]:
    """Parse natural language into adherence items using simple pattern matching."""
    items = []
    message_lower = message.lower()

    # Common patterns
    supplement_keywords = ["supplement", "vitamins", "took", "pills", "capsules", "nmn", "d3", "omega", "magnesium"]
    workout_keywords = ["workout", "exercise", "training", "gym", "run", "lift", "hiit", "zone 2"]
    intervention_keywords = ["cold plunge", "cold shower", "sauna", "meditation", "breath", "nsdr", "light exposure"]
    nutrition_keywords = ["fast", "meal", "ate", "food", "diet"]

    # Check for supplements
    if any(kw in message_lower for kw in supplement_keywords):
        items.append({
            "type": "supplement",
            "name": "Daily supplements",
            "notes": message,
        })

    # Check for workout
    if any(kw in message_lower for kw in workout_keywords):
        # Try to extract duration
        import re
        duration_match = re.search(r'(\d+)\s*(min|minute|hr|hour)', message_lower)
        duration = duration_match.group(0) if duration_match else ""
        items.append({
            "type": "training",
            "name": f"Workout {duration}".strip(),
            "notes": message,
        })

    # Check for interventions
    for kw in intervention_keywords:
        if kw in message_lower:
            items.append({
                "type": "intervention",
                "name": kw.title(),
                "notes": message,
            })
            break

    # Check for nutrition/fasting
    if any(kw in message_lower for kw in nutrition_keywords):
        items.append({
            "type": "nutrition",
            "name": "Nutrition protocol",
            "notes": message,
        })

    # If nothing specific matched, create a generic entry
    if not items:
        items.append({
            "type": "intervention",
            "name": "Activity logged",
            "notes": message,
        })

    return items


# ── Goals ────────────────────────────────────────────────────────────────────


@router.get("/goals", response_model=list[GoalDefinitionResponse])
async def list_goals(
    status_filter: str | None = Query(default=None, description="Filter by status: active, achieved, abandoned"),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[GoalDefinitionResponse]:
    """List user's goals."""
    pool = get_pool()

    if status_filter:
        rows = await pool.fetch(
            """
            SELECT id, user_id, category, target_metric, target_value, target_unit, deadline, status, created_at, updated_at
            FROM goal_definitions
            WHERE user_id = $1 AND status = $2
            ORDER BY created_at DESC
            """,
            current_user["id"],
            status_filter,
        )
    else:
        rows = await pool.fetch(
            """
            SELECT id, user_id, category, target_metric, target_value, target_unit, deadline, status, created_at, updated_at
            FROM goal_definitions
            WHERE user_id = $1
            ORDER BY status, created_at DESC
            """,
            current_user["id"],
        )

    return [
        GoalDefinitionResponse(
            id=r["id"],
            user_id=r["user_id"],
            category=r["category"],
            target_metric=r["target_metric"],
            target_value=r["target_value"],
            target_unit=r["target_unit"],
            deadline=r["deadline"],
            status=r["status"],
            created_at=r["created_at"],
            updated_at=r["updated_at"],
        )
        for r in rows
    ]


@router.post("/goals", response_model=GoalDefinitionResponse, status_code=status.HTTP_201_CREATED)
async def create_goal(
    body: GoalDefinitionCreate,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> GoalDefinitionResponse:
    """Create a new goal."""
    pool = get_pool()
    now = datetime.now(timezone.utc)

    row = await pool.fetchrow(
        """
        INSERT INTO goal_definitions (user_id, category, target_metric, target_value, target_unit, deadline, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING id, user_id, category, target_metric, target_value, target_unit, deadline, status, created_at, updated_at
        """,
        current_user["id"],
        body.category.value,
        body.target_metric,
        body.target_value,
        body.target_unit,
        body.deadline,
        now,
        now,
    )

    return GoalDefinitionResponse(
        id=row["id"],
        user_id=row["user_id"],
        category=row["category"],
        target_metric=row["target_metric"],
        target_value=row["target_value"],
        target_unit=row["target_unit"],
        deadline=row["deadline"],
        status=row["status"],
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


@router.put("/goals/{goal_id}", response_model=GoalDefinitionResponse)
async def update_goal(
    goal_id: UUID,
    body: GoalDefinitionUpdate,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> GoalDefinitionResponse:
    """Update a goal."""
    pool = get_pool()
    now = datetime.now(timezone.utc)

    updates = ["updated_at = $3"]
    params: list[Any] = [goal_id, current_user["id"], now]
    param_idx = 4

    if body.target_value is not None:
        updates.append(f"target_value = ${param_idx}")
        params.append(body.target_value)
        param_idx += 1

    if body.target_unit is not None:
        updates.append(f"target_unit = ${param_idx}")
        params.append(body.target_unit)
        param_idx += 1

    if body.deadline is not None:
        updates.append(f"deadline = ${param_idx}")
        params.append(body.deadline)
        param_idx += 1

    if body.status is not None:
        updates.append(f"status = ${param_idx}")
        params.append(body.status.value)
        param_idx += 1

    query = f"""
        UPDATE goal_definitions SET {', '.join(updates)}
        WHERE id = $1 AND user_id = $2
        RETURNING id, user_id, category, target_metric, target_value, target_unit, deadline, status, created_at, updated_at
    """

    row = await pool.fetchrow(query, *params)

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Goal not found")

    return GoalDefinitionResponse(
        id=row["id"],
        user_id=row["user_id"],
        category=row["category"],
        target_metric=row["target_metric"],
        target_value=row["target_value"],
        target_unit=row["target_unit"],
        deadline=row["deadline"],
        status=row["status"],
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


@router.delete("/goals/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_goal(
    goal_id: UUID,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> None:
    """Delete a goal."""
    pool = get_pool()
    result = await pool.execute(
        "DELETE FROM goal_definitions WHERE id = $1 AND user_id = $2",
        goal_id,
        current_user["id"],
    )
    if result == "DELETE 0":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Goal not found")


# ── Weekly Summaries ─────────────────────────────────────────────────────────


@router.get("/summaries", response_model=list[WeeklySummaryResponse])
async def list_weekly_summaries(
    limit: int = Query(default=12, ge=1, le=52),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[WeeklySummaryResponse]:
    """List weekly summaries."""
    pool = get_pool()
    key = _enc_key()

    rows = await pool.fetch(
        """
        SELECT id, user_id, week_start, summary_json, ai_analysis, created_at
        FROM weekly_summaries
        WHERE user_id = $1
        ORDER BY week_start DESC
        LIMIT $2
        """,
        current_user["id"],
        limit,
    )

    return [
        WeeklySummaryResponse(
            id=r["id"],
            user_id=r["user_id"],
            week_start=r["week_start"],
            summary=json.loads(decrypt_field(r["summary_json"], key)),
            ai_analysis=decrypt_field(r["ai_analysis"], key) if r["ai_analysis"] else None,
            created_at=r["created_at"],
        )
        for r in rows
    ]


@router.post("/summaries/generate")
async def generate_weekly_summary(
    week_start: date = Query(default_factory=lambda: date.today() - timedelta(days=date.today().weekday())),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> WeeklySummaryResponse:
    """Generate a weekly summary with AI analysis."""
    pool = get_pool()
    key = _enc_key()
    now = datetime.now(timezone.utc)

    week_end = week_start + timedelta(days=6)

    # Gather adherence data for the week
    adherence_rows = await pool.fetch(
        """
        SELECT date, item_type, item_name, completed
        FROM daily_adherence
        WHERE user_id = $1 AND date >= $2 AND date <= $3
        ORDER BY date, item_type
        """,
        current_user["id"],
        week_start,
        week_end,
    )

    # Calculate adherence stats
    total_items = len(adherence_rows)
    completed_items = len([r for r in adherence_rows if r["completed"]])
    adherence_rate = (completed_items / total_items * 100) if total_items > 0 else 0

    # Group by type
    by_type: dict[str, dict[str, int]] = {}
    for r in adherence_rows:
        item_type = r["item_type"]
        if item_type not in by_type:
            by_type[item_type] = {"total": 0, "completed": 0}
        by_type[item_type]["total"] += 1
        if r["completed"]:
            by_type[item_type]["completed"] += 1

    summary = {
        "week_start": str(week_start),
        "week_end": str(week_end),
        "total_items": total_items,
        "completed_items": completed_items,
        "adherence_rate": round(adherence_rate, 1),
        "by_type": {
            k: {
                "total": v["total"],
                "completed": v["completed"],
                "rate": round(v["completed"] / v["total"] * 100, 1) if v["total"] > 0 else 0
            }
            for k, v in by_type.items()
        },
    }

    # Generate AI analysis
    ai_analysis = await _generate_weekly_analysis(summary, current_user["id"])

    # Store the summary
    encrypted_summary = encrypt_field(json.dumps(summary), key)
    encrypted_analysis = encrypt_field(ai_analysis, key) if ai_analysis else None

    row = await pool.fetchrow(
        """
        INSERT INTO weekly_summaries (user_id, week_start, summary_json, ai_analysis, created_at)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (user_id, week_start) DO UPDATE SET
            summary_json = EXCLUDED.summary_json,
            ai_analysis = EXCLUDED.ai_analysis
        RETURNING id, user_id, week_start, summary_json, ai_analysis, created_at
        """,
        current_user["id"],
        week_start,
        encrypted_summary,
        encrypted_analysis,
        now,
    )

    return WeeklySummaryResponse(
        id=row["id"],
        user_id=row["user_id"],
        week_start=row["week_start"],
        summary=summary,
        ai_analysis=ai_analysis,
        created_at=row["created_at"],
    )


async def _generate_weekly_analysis(summary: dict[str, Any], user_id: UUID) -> str | None:
    """Generate AI analysis of weekly progress."""
    prompt = f"""Analyze this weekly health protocol adherence data and provide insights:

{json.dumps(summary, indent=2)}

Provide a brief (2-3 paragraph) analysis covering:
1. Overall adherence assessment
2. Areas of strength and areas for improvement
3. One specific, actionable recommendation for next week

Keep the tone encouraging and constructive."""

    try:
        response = await chat_completion_multi(
            [
                {"role": "system", "content": "You are a supportive health coach analyzing weekly adherence data."},
                {"role": "user", "content": prompt},
            ],
            temperature=0.5,
        )
        return response["choices"][0]["message"]["content"]
    except Exception:
        return None


# ── Stats & Insights ─────────────────────────────────────────────────────────


@router.get("/stats")
async def get_progress_stats(
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    """Get overall progress statistics."""
    pool = get_pool()
    today = date.today()
    week_ago = today - timedelta(days=7)
    month_ago = today - timedelta(days=30)

    # This week's adherence
    week_adherence = await pool.fetchrow(
        """
        SELECT COUNT(*) as total, SUM(CASE WHEN completed THEN 1 ELSE 0 END) as completed
        FROM daily_adherence
        WHERE user_id = $1 AND date >= $2
        """,
        current_user["id"],
        week_ago,
    )

    # This month's adherence
    month_adherence = await pool.fetchrow(
        """
        SELECT COUNT(*) as total, SUM(CASE WHEN completed THEN 1 ELSE 0 END) as completed
        FROM daily_adherence
        WHERE user_id = $1 AND date >= $2
        """,
        current_user["id"],
        month_ago,
    )

    # Current streak (consecutive days with at least one completed item)
    streak = await _calculate_streak(pool, current_user["id"])

    # Active goals count
    active_goals = await pool.fetchval(
        "SELECT COUNT(*) FROM goal_definitions WHERE user_id = $1 AND status = 'active'",
        current_user["id"],
    )

    week_rate = (week_adherence["completed"] or 0) / week_adherence["total"] * 100 if week_adherence["total"] else 0
    month_rate = (month_adherence["completed"] or 0) / month_adherence["total"] * 100 if month_adherence["total"] else 0

    return {
        "this_week": {
            "total": week_adherence["total"] or 0,
            "completed": week_adherence["completed"] or 0,
            "rate": round(week_rate, 1),
        },
        "this_month": {
            "total": month_adherence["total"] or 0,
            "completed": month_adherence["completed"] or 0,
            "rate": round(month_rate, 1),
        },
        "current_streak": streak,
        "active_goals": active_goals,
    }


async def _calculate_streak(pool, user_id: UUID) -> int:
    """Calculate current streak of consecutive days with completed items."""
    today = date.today()
    streak = 0
    current_date = today

    while True:
        has_completed = await pool.fetchval(
            """
            SELECT EXISTS(
                SELECT 1 FROM daily_adherence
                WHERE user_id = $1 AND date = $2 AND completed = true
            )
            """,
            user_id,
            current_date,
        )

        if has_completed:
            streak += 1
            current_date -= timedelta(days=1)
        else:
            # Check if today has no data yet (it's early in the day)
            if current_date == today:
                current_date -= timedelta(days=1)
                continue
            break

    return streak
