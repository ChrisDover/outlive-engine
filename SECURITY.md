# Security Policy

Outlive Engine handles sensitive personal health data. Security is a core design constraint, not an afterthought.

## Data Sovereignty

- **All health data stays in your PostgreSQL database.** There is no cloud sync, no telemetry, no analytics beacon.
- **Local LLMs are the default.** AI insights run through Ollama on your machine. Your bloodwork, genetics, and wearable data never leave your network unless you explicitly configure a cloud LLM provider.
- **Cloud LLMs are opt-in and clearly gated.** If you set `AIRLLM_BASE_URL` to an external provider, the app will send health context to that API. This is your choice. The default is `localhost`.

## Encryption

### At Rest
- Sensitive database fields (email, bloodwork markers, genomic data, wearable metrics, experiment data) are encrypted using AES-256 with a key you control (`FIELD_ENCRYPTION_KEY`).
- **Generate a strong key:** `openssl rand -base64 32`
- The encryption key never leaves your environment. If you lose it, encrypted data is unrecoverable.

### In Transit
- **Backend supports mTLS** for production deployments (`TLS_CERT_PATH`, `TLS_KEY_PATH`).
- **Web frontend → backend** communication uses a shared service API key over HTTPS.
- All NextAuth sessions use encrypted JWTs with `NEXTAUTH_SECRET`.

## Authentication

### Web Frontend
- **NextAuth v4** with JWT strategy (no session tokens stored server-side)
- Email/password with bcrypt hashing (cost factor 12)
- Passwordless magic link login (15-minute expiry, single-use tokens)
- Session middleware protects all `/dashboard` and `/api` routes

### Backend API
- **Two auth modes:**
  - **Service auth:** Web frontend authenticates with `SERVICE_API_KEY` + `X-Outlive-User-Id` header
  - **JWT auth:** iOS app authenticates with signed access/refresh tokens
- Apple Sign-In identity tokens validated against Apple's JWKS endpoint
- Refresh tokens checked against database (revocable)

### Service Auth
- The web frontend (Next.js server-side) calls the backend using a shared API key
- User identity is passed via `X-Outlive-User-Id` header
- This key should be a cryptographically random string: `openssl rand -hex 32`

## Audit Logging

Every API request is logged to the `audit_log` table:
- User ID, HTTP method, path, status code, IP address, response time
- Useful for detecting unauthorized access or unusual patterns
- Logs do not contain request/response bodies

## Self-Hosting Hardening Checklist

- [ ] Run `make setup` to generate unique secrets automatically (or generate manually — see below)
- [ ] Run PostgreSQL with authentication enabled (not trust mode)
- [ ] Set `ALLOWED_ORIGINS` to your exact domain (not `["*"]`)
- [ ] Enable TLS on the backend (`TLS_CERT_PATH`, `TLS_KEY_PATH`)
- [ ] Run behind a reverse proxy (nginx, Caddy) with HTTPS
- [ ] Keep Ollama bound to localhost (`OLLAMA_HOST=127.0.0.1`)
- [ ] Set PostgreSQL to listen only on localhost or your private network
- [ ] Use a firewall to block direct access to backend port (8000) and database port (5432)
- [ ] Regularly rotate `SERVICE_API_KEY` and `JWT_SECRET`
- [ ] Back up your `FIELD_ENCRYPTION_KEY` securely — data is unrecoverable without it
- [ ] Set database connection to require SSL (`?sslmode=verify-full` in DATABASE_URL)
- [ ] Review audit logs regularly for anomalous access patterns
- [ ] Set up log aggregation and alerting for audit log write failures

## Cloud LLM Warning

When `AIRLLM_BASE_URL` points to an external service:

- Health context (bloodwork values, genetic markers, wearable metrics) is sent in API requests
- The external provider's data retention and privacy policies apply
- Consider what data you're comfortable sharing before enabling this
- You can use local models for sensitive queries and cloud models for general questions

## Reporting Vulnerabilities

If you discover a security issue, please email **security@outlive.engine** (or open a private security advisory on GitHub) rather than filing a public issue. We take all reports seriously and will respond within 48 hours.

## Dependencies

We use well-maintained, audited libraries:
- **bcryptjs** for password hashing
- **jose** (python-jose) for JWT operations
- **next-auth** for web authentication
- **prisma** for database access (parameterized queries, no raw SQL injection surface)
- **asyncpg** for backend database (parameterized queries)

All SQL in the backend uses parameterized queries — no string interpolation of user input.
