"""Bidirectional sync with vector-clock conflict resolution."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from app.config import get_settings
from app.models.database import get_pool
from app.models.schemas import SyncChange, SyncOperation, SyncRequest, SyncResponse
from app.security.encryption import derive_key, encrypt_field


def _enc_key() -> bytes:
    return derive_key(get_settings().FIELD_ENCRYPTION_KEY)


def _clock_dominates(a: dict[str, int], b: dict[str, int]) -> bool:
    """Return True if vector clock *a* strictly dominates *b*.

    a dominates b iff for every device in b, a[device] >= b[device],
    and there is at least one device where a[device] > b[device].
    """
    all_devices = set(a) | set(b)
    at_least_one_greater = False
    for d in all_devices:
        va = a.get(d, 0)
        vb = b.get(d, 0)
        if va < vb:
            return False
        if va > vb:
            at_least_one_greater = True
    return at_least_one_greater


def _merge_clocks(a: dict[str, int], b: dict[str, int]) -> dict[str, int]:
    """Element-wise max of two vector clocks."""
    all_devices = set(a) | set(b)
    return {d: max(a.get(d, 0), b.get(d, 0)) for d in all_devices}


async def push_changes(
    user_id: UUID,
    request: SyncRequest,
) -> SyncResponse:
    """Accept client changes and persist them, resolving conflicts.

    Conflict strategy: last-write-wins based on vector clock dominance.
    When neither clock dominates (true conflict) the server keeps its
    version and reports the conflict back to the client.
    """
    pool = get_pool()
    key = _enc_key()
    now = datetime.now(timezone.utc)
    conflicts: list[dict[str, Any]] = []

    for change in request.changes:
        # Check for an existing sync entry for this entity
        existing = await pool.fetchrow(
            "SELECT id, vector_clock, payload_json, device_id "
            "FROM sync_log WHERE user_id = $1 AND entity_type = $2 AND entity_id = $3 "
            "ORDER BY created_at DESC LIMIT 1",
            user_id,
            change.entity_type,
            change.entity_id,
        )

        if existing is not None:
            server_clock: dict[str, int] = dict(existing["vector_clock"])
            client_clock = change.vector_clock

            if _clock_dominates(client_clock, server_clock):
                # Client wins -- accept
                pass
            elif _clock_dominates(server_clock, client_clock):
                # Server wins -- reject silently (client will get server
                # version on next pull)
                conflicts.append(
                    {
                        "entity_type": change.entity_type,
                        "entity_id": str(change.entity_id),
                        "resolution": "server_wins",
                        "server_clock": server_clock,
                        "client_clock": client_clock,
                    }
                )
                continue
            else:
                # True conflict -- last-write-wins (server keeps its copy)
                conflicts.append(
                    {
                        "entity_type": change.entity_type,
                        "entity_id": str(change.entity_id),
                        "resolution": "conflict_server_kept",
                        "server_clock": server_clock,
                        "client_clock": client_clock,
                    }
                )
                continue

        merged_clock = (
            _merge_clocks(
                dict(existing["vector_clock"]) if existing else {},
                change.vector_clock,
            )
        )

        enc_payload = (
            encrypt_field(json.dumps(change.payload), key)
            if change.payload
            else None
        )

        await pool.execute(
            """
            INSERT INTO sync_log (user_id, entity_type, entity_id, vector_clock, operation, payload_json, device_id, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            """,
            user_id,
            change.entity_type,
            change.entity_id,
            json.dumps(merged_clock),
            change.operation.value,
            enc_payload,
            change.device_id,
            now,
        )

    return SyncResponse(
        changes=[],
        current_timestamp=now,
        conflicts=conflicts,
    )


async def pull_changes(
    user_id: UUID,
    request: SyncRequest,
) -> SyncResponse:
    """Return all server-side changes since the client's last pull."""
    pool = get_pool()
    now = datetime.now(timezone.utc)

    query = (
        "SELECT entity_type, entity_id, vector_clock, operation, payload_json, device_id "
        "FROM sync_log WHERE user_id = $1"
    )
    params: list[Any] = [user_id]
    idx = 2

    if request.last_pulled_at is not None:
        query += f" AND created_at > ${idx}"
        params.append(request.last_pulled_at)
        idx += 1

    # Exclude changes originated from the requesting device to avoid echo
    query += f" AND device_id != ${idx}"
    params.append(request.device_id)

    query += " ORDER BY created_at ASC"

    rows = await pool.fetch(query, *params)

    changes: list[SyncChange] = []
    for r in rows:
        # Payload is stored encrypted -- return clock and metadata only;
        # the actual entity should be fetched via the normal CRUD endpoints.
        # For convenience we include the operation and clock so the client
        # knows what changed.
        changes.append(
            SyncChange(
                entity_type=r["entity_type"],
                entity_id=r["entity_id"],
                operation=SyncOperation(r["operation"]),
                payload=None,  # clients fetch full data via CRUD
                vector_clock=json.loads(r["vector_clock"]) if isinstance(r["vector_clock"], str) else dict(r["vector_clock"]),
                device_id=r["device_id"],
            )
        )

    return SyncResponse(
        changes=changes,
        current_timestamp=now,
        conflicts=[],
    )
