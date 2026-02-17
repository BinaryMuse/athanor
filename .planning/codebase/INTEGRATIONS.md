# External Integrations

**Analysis Date:** 2026-02-16

## APIs & External Services

**LLM Providers:**
- OpenRouter (https://openrouter.ai/api/v1/chat/completions)
  - SDK/Client: `req_llm` (0.5.17) via Req HTTP client
  - Auth: `OPENROUTER_API_KEY` environment variable
  - Purpose: Multi-model LLM access (GPT, Claude, local models, etc.)
  - Configuration: Provider options configured in `config/runtime.exs` with logprobs and top_logprobs settings

**OpenAI Compatible APIs:**
- Supported through `req_llm` library which abstracts multiple providers
- Configurable via environment and LLM_DB config

**Integration Location:**
- `apps/athanor/lib/mix/tasks/logprob.ex` - Example LLM task making requests to OpenRouter
- `apps/athanor/` - Core integration points for running LLM-based experiments

## Data Storage

**Databases:**
- PostgreSQL (primary)
  - Connection: Via `DATABASE_URL` environment variable (production) or hardcoded config (development: `athanor_dev`)
  - Client: Postgrex 0.22.0 (PostgreSQL driver)
  - ORM: Ecto 3.13.5 with Ecto SQL 3.13.4 adapter
  - Credentials: Development uses `postgres:postgres` on localhost
  - Location: `apps/athanor/lib/athanor/repo.ex` defines the Ecto repository

**Database Schema:**
- Migration: `apps/athanor/priv/repo/migrations/20260217021346_create_experiments_tables.exs`
- Tables:
  - `experiment_instances` - Experiment definitions and metadata
  - `experiment_runs` - Execution records with status tracking
  - `run_results` - Key-value result storage (JSON map values)
  - `run_logs` - Structured logging with level, message, metadata, timestamp

**File Storage:**
- Local filesystem only
- Static assets: `apps/athanor_web/priv/static/`
- Development asset sources: `apps/athanor_web/assets/` (CSS, JavaScript)

**Caching:**
- None detected - Relies on Erlang in-memory process state
- Phoenix.PubSub for real-time state distribution across connections

## Authentication & Identity

**Auth Provider:**
- Custom or not yet implemented
- No explicit auth service detected (no Ueberauth, Guardian, or similar)
- Application accessible without authentication in current state

**Session Management:**
- Phoenix signing salt configured: "IMCOBuHB" in `config/config.exs`
- Cookie-based via Phoenix built-in mechanism

## Monitoring & Observability

**Error Tracking:**
- Not detected - No Sentry, Rollbar, or similar integration

**Logs:**
- Approach: Elixir Logger with custom telemetry
  - Telemetry integration via `telemetry 1.3.0` and `telemetry_metrics 1.1.0`
  - Structured logging into database: `run_logs` table captures level, message, metadata
  - Development: Console output with format `[$level] $message`
  - Production: `$time $metadata[$level] $message` format with request_id tracking

**Metrics:**
- Telemetry Poller 1.3.0 for periodic metric collection
- Live Dashboard 0.8.7 available for development metrics visualization

## CI/CD & Deployment

**Hosting:**
- Not explicitly configured
- Capable of deployment via OTP releases (commented setup in runtime.exs)
- Supports clustering via DNS_CLUSTER_QUERY environment variable

**CI Pipeline:**
- Not detected - No GitHub Actions, CircleCI, or similar configuration
- Mix tasks available for development: `mix precommit` runs format, compile, tests

**Build Process:**
- `mix setup` - Installs deps and runs ecto.setup
- `mix assets.setup` - Installs esbuild and tailwind
- `mix assets.build` - Compiles JS and CSS
- `mix assets.deploy` - Minified production assets with digest hashing

## Environment Configuration

**Required env vars (Production):**
- `DATABASE_URL` - PostgreSQL connection string (ecto://user:pass@host/database)
- `SECRET_KEY_BASE` - Session/cookie encryption key (generated via `mix phx.gen.secret`)
- `PORT` - HTTP port (default: 4000)
- `OPENROUTER_API_KEY` - LLM provider authentication (if using OpenRouter)

**Optional env vars:**
- `ECTO_IPV6` - Enable IPv6 for database connections (set to "true" or "1")
- `POOL_SIZE` - Database connection pool size (default: 10)
- `DNS_CLUSTER_QUERY` - DNS SRV query for distributed clustering

**Secrets location:**
- Environment variables via system process environment
- Development: `.env` loading via dotenvy library (not explicitly configured but available)
- Production: Environment variables from deployment platform (Fly.io, Heroku, etc.)

## Webhooks & Callbacks

**Incoming:**
- Not detected - No webhook endpoints configured

**Outgoing:**
- Email via Swoosh (not configured for production - commented Mailgun adapter in runtime.exs)
- Phoenix PubSub for internal real-time messaging between client and server
- Server-sent events infrastructure available through req_llm library

**Real-time Communication:**
- Phoenix Live View WebSocket connections for bidirectional updates
- Pub/Sub patterns in:
  - `apps/athanor/lib/athanor/experiments/broadcasts.ex`
  - Pattern: Phoenix.PubSub.subscribe/broadcast on `experiments:run:#{run_id}` topics

## LLM Configuration

**req_llm Settings (runtime.exs):**
```elixir
config :req_llm,
  provider_options: [
    logprobs: true,
    top_logprobs: 20,
    openrouter_logprobs: true,
    openrouter_top_logprobs: 20
  ]
```

**Supported Models:**
- Configurable per request through req_llm
- Example: `openai/gpt-3.5-turbo` (shown in logprob task)
- Multi-model support via OpenRouter abstraction

---

*Integration audit: 2026-02-16*
