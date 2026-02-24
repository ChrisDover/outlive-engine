.PHONY: setup dev reset

# ---------------------------------------------------------------------------
# make setup — one-command local environment bootstrap
# ---------------------------------------------------------------------------
setup:
	@echo "=== Outlive Engine — Setup ==="; \
	echo ""; \
	echo "Checking prerequisites..."; \
	command -v node   >/dev/null 2>&1 || { echo "ERROR: node is not installed. Install Node.js and try again.";   exit 1; }; \
	command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 is not installed. Install Python 3 and try again."; exit 1; }; \
	command -v psql   >/dev/null 2>&1 || { echo "ERROR: psql is not installed. Install PostgreSQL and try again.";  exit 1; }; \
	command -v openssl >/dev/null 2>&1 || { echo "ERROR: openssl is not installed. Install OpenSSL and try again."; exit 1; }; \
	echo "All prerequisites found."; \
	echo ""; \
	echo "Generating secrets..."; \
	JWT_SECRET=$$(python3 -c "import secrets; print(secrets.token_urlsafe(64))"); \
	FIELD_ENCRYPTION_KEY=$$(openssl rand -base64 32); \
	SERVICE_API_KEY=$$(openssl rand -hex 32); \
	NEXTAUTH_SECRET=$$(openssl rand -base64 32); \
	echo "Secrets generated."; \
	echo ""; \
	echo "Creating database outlive_engine (if it doesn't already exist)..."; \
	createdb outlive_engine 2>/dev/null || echo "Database outlive_engine already exists — skipping."; \
	echo ""; \
	echo "Writing backend/.env ..."; \
	printf '%s\n' \
		"DATABASE_URL=postgresql+asyncpg://localhost:5432/outlive_engine" \
		"POSTGRES_PASSWORD=" \
		"JWT_SECRET=$$JWT_SECRET" \
		"JWT_ALGORITHM=HS256" \
		"JWT_EXPIRATION_HOURS=24" \
		"JWT_REFRESH_EXPIRATION_DAYS=30" \
		"FIELD_ENCRYPTION_KEY=$$FIELD_ENCRYPTION_KEY" \
		"TLS_CERT_PATH=" \
		"TLS_KEY_PATH=" \
		"AIRLLM_BASE_URL=http://localhost:11434/v1" \
		"AIRLLM_API_KEY=" \
		"AIRLLM_MODEL=llama3.1" \
		'ALLOWED_ORIGINS=["http://localhost:3000"]' \
		"SERVICE_API_KEY=$$SERVICE_API_KEY" \
		> backend/.env; \
	echo "backend/.env written."; \
	echo ""; \
	echo "Writing web/.env ..."; \
	printf '%s\n' \
		"POSTGRES_PRISMA_URL=postgresql://localhost:5432/outlive_engine" \
		"NEXTAUTH_SECRET=$$NEXTAUTH_SECRET" \
		"NEXTAUTH_URL=http://localhost:3000" \
		"OUTLIVE_BACKEND_URL=http://localhost:8000" \
		"OUTLIVE_SERVICE_KEY=$$SERVICE_API_KEY" \
		"OURA_CLIENT_ID=" \
		"OURA_CLIENT_SECRET=" \
		"WHOOP_CLIENT_ID=" \
		"WHOOP_CLIENT_SECRET=" \
		"RESEND_API_KEY=" \
		> web/.env; \
	echo "web/.env written."; \
	echo ""; \
	echo "Setting up Python virtual environment..."; \
	cd backend && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt; \
	cd ..; \
	echo ""; \
	echo "Installing Node dependencies..."; \
	cd web && npm install; \
	cd ..; \
	echo ""; \
	echo "Bootstrapping backend database schema..."; \
	cd backend && .venv/bin/python -c "import asyncio; from app.models.database import init_pool; asyncio.run(init_pool())"; \
	cd ..; \
	echo ""; \
	echo "Pushing Prisma schema..."; \
	cd web && npx prisma db push; \
	cd ..; \
	echo ""; \
	echo "============================================"; \
	echo "  Setup complete!"; \
	echo "  Run 'make dev' to start both servers."; \
	echo "============================================"

# ---------------------------------------------------------------------------
# make dev — run backend + frontend with clean Ctrl-C shutdown
# ---------------------------------------------------------------------------
dev:
	@echo "=== Outlive Engine — Dev Servers ==="; \
	echo "Starting backend (port 8000) and frontend (port 3000)..."; \
	echo "Press Ctrl-C to stop both servers."; \
	echo ""; \
	trap 'kill 0; exit 0' INT TERM; \
	(cd backend && .venv/bin/uvicorn app.main:app --reload --port 8000) & \
	(cd web && npm run dev) & \
	wait

# ---------------------------------------------------------------------------
# make reset — tear down and re-run setup
# ---------------------------------------------------------------------------
reset:
	@echo "=== Outlive Engine — Reset ==="; \
	echo "Dropping database outlive_engine..."; \
	dropdb outlive_engine 2>/dev/null || echo "Database outlive_engine does not exist — skipping."; \
	echo "Removing .env files..."; \
	rm -f backend/.env web/.env; \
	echo "Re-running setup..."
	@$(MAKE) setup
