#!/usr/bin/env bash
# Wait for PostgreSQL to be ready, then bootstrap the schema via the app.
set -euo pipefail

HOST="${DB_HOST:-localhost}"
PORT="${DB_PORT:-5432}"
USER="${DB_USER:-outlive}"

echo "Waiting for PostgreSQL at ${HOST}:${PORT} ..."

until pg_isready -h "$HOST" -p "$PORT" -U "$USER" > /dev/null 2>&1; do
    sleep 1
done

echo "PostgreSQL is ready.  Running schema bootstrap ..."

python -c "
import asyncio
from app.models.database import init_pool, close_pool

async def main():
    await init_pool()
    print('Schema created successfully.')
    await close_pool()

asyncio.run(main())
"

echo "Done."
