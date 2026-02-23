# Outlive Engine

Open-source longevity protocol platform. Feed it your health data — bloodwork, genetics, wearables, body composition — and it generates a personalized daily protocol across training, nutrition, supplements, interventions, and sleep.

Your data stays on your hardware. Your models run locally. No cloud dependency required.

## Architecture

```
Browser → Next.js (web/) → FastAPI Backend (backend/)
                                    ↓
                              PostgreSQL (all health data)
```

- **Web frontend:** Next.js 16, React 19, TypeScript, Tailwind CSS v4
- **Backend API:** FastAPI, asyncpg, PostgreSQL
- **AI:** Local LLMs by default (Ollama), optional cloud LLM support

## Security Model

**Your health data is yours.** Outlive Engine is designed for self-hosting with security as a first-class concern:

- **All sensitive fields encrypted at rest** in the database (field-level encryption)
- **No telemetry, no analytics, no phone-home** — zero data leaves your machine
- **Local LLMs by default** via Ollama — your health data never hits external APIs
- **Optional cloud LLM support** (OpenAI, Anthropic) if you choose — clearly gated behind explicit configuration
- **Service auth between frontend and backend** via API key + user ID headers (no shared cookies)
- **mTLS support** for production backend deployments
- **Audit logging** on every API request
- **Startup validation** — app refuses to start with default/missing secrets
- **Constant-time key comparison** — timing-attack resistant service auth
- **Token revocation** — compromised refresh tokens can be killed immediately

See [SECURITY.md](SECURITY.md) for the full security policy and self-hosting hardening guide.

## What It Tracks

| Domain | Description |
|--------|-------------|
| **Training** | Workout programming adjusted by recovery zone |
| **Nutrition** | Calorie and macro targets tuned to activity and goals |
| **Supplements** | Personalized stack informed by bloodwork and genetics |
| **Interventions** | Sauna, cold plunge, breathwork, red light scheduling |
| **Sleep** | Target bedtime/wake, sleep hygiene protocols |
| **Bloodwork** | Biomarker tracking with optimal ranges and trend charts |
| **Genomics** | Genetic risk categories (APOE, MTHFR, etc.) informing protocols |

## Quick Start

### Prerequisites

- Node.js 20+
- Python 3.11+
- PostgreSQL 15+
- [Ollama](https://ollama.ai) (for local AI)

### 1. Backend

```bash
cd backend
cp .env.example .env          # Edit with your values
pip install -r requirements.txt
uvicorn app.main:app --reload
```

The backend creates all database tables on startup.

### 2. Web Frontend

```bash
cd web
cp .env.example .env          # Edit with your values
npm install
npx prisma db push            # Create auth tables
npm run dev
```

Open http://localhost:3000, create an account, and you're in.

### 3. Local AI (Optional)

```bash
ollama pull llama3.1           # Or any model you prefer
```

Set `AIRLLM_BASE_URL=http://localhost:11434/v1` in `backend/.env` (this is the default).

### Using Cloud LLMs Instead

If you prefer cloud models, set these in `backend/.env`:

```bash
# OpenAI
AIRLLM_BASE_URL=https://api.openai.com/v1
AIRLLM_API_KEY=sk-...
AIRLLM_MODEL=gpt-4o

# Or Anthropic
AIRLLM_BASE_URL=https://api.anthropic.com/v1
AIRLLM_API_KEY=sk-ant-...
AIRLLM_MODEL=claude-sonnet-4-20250514
```

**Be aware:** when using cloud LLMs, your health context is sent to external APIs. Use local models if data sovereignty is important to you.

## Environment Variables

### Backend (`backend/.env`)

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection string | Yes |
| `JWT_SECRET` | Secret for signing JWT tokens | Yes (app won't start without it) |
| `FIELD_ENCRYPTION_KEY` | 32-byte base64 key for field encryption | Yes (app won't start without it) |
| `SERVICE_API_KEY` | Shared key for web → backend auth | Yes for web frontend |
| `AIRLLM_BASE_URL` | LLM API endpoint (Ollama, OpenAI, etc.) | No (defaults to localhost Ollama) |
| `ALLOWED_ORIGINS` | CORS origins (no wildcards allowed) | Yes |

### Web (`web/.env`)

| Variable | Description |
|----------|-------------|
| `POSTGRES_PRISMA_URL` | PostgreSQL for auth database |
| `NEXTAUTH_SECRET` | Secret for NextAuth session encryption |
| `NEXTAUTH_URL` | Public URL of the web app |
| `OUTLIVE_BACKEND_URL` | FastAPI backend URL |
| `OUTLIVE_SERVICE_KEY` | Must match backend's `SERVICE_API_KEY` |

## Wearable Integrations

| Device | Status | Auth |
|--------|--------|------|
| Oura Ring | Planned | OAuth 2.0 |
| Whoop | Planned | OAuth 2.0 + PKCE |

## Project Structure

```
├── backend/              # FastAPI backend
│   ├── app/
│   │   ├── routers/      # API endpoints
│   │   ├── models/       # Database schema + Pydantic schemas
│   │   ├── security/     # Auth, audit logging, encryption
│   │   └── services/     # Business logic
│   └── alembic/          # Database migrations
└── web/                  # Next.js web frontend
    ├── src/
    │   ├── app/          # Pages and API routes
    │   ├── components/   # Reusable UI components
    │   └── lib/          # Auth, Prisma, backend client
    └── prisma/           # Auth-only schema
```

## Contributing

Contributions welcome. Please:

1. Fork the repo
2. Create a feature branch
3. Ensure `npm run build` passes in `web/`
4. Submit a PR

## License

MIT License. See [LICENSE](LICENSE).

---

Built for people who take their health seriously and want full control of their data.
