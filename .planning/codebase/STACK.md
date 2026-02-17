# Technology Stack

**Analysis Date:** 2026-02-16

## Languages

**Primary:**
- Elixir 1.15+ - Core business logic, backend runtime, GenServer-based supervision
- Elixir 1.18 - SubstrateShift app (can potentially use 1.18 features)

**Frontend:**
- JavaScript/TypeScript - Browser-based UI in `apps/athanor_web/assets`
- HEEX (Phoenix templates) - Server-rendered HTML templates

## Runtime

**Environment:**
- Erlang/OTP - Powers Elixir runtime with supervision trees and distribution

**Package Manager:**
- Mix - Elixir package/dependency manager
- Lockfile: `mix.lock` present (58 dependencies tracked)

## Frameworks

**Core Web:**
- Phoenix 1.8.3 - Web framework for `athanor_web` app
  - Configured with Bandit 1.10.2 as HTTP adapter
  - Phoenix Live View 1.1.24 - Real-time interactive UI components
  - Phoenix Live Dashboard 0.8.7 - Development dashboard

**Database/ORM:**
- Ecto 3.13.5 - Query builder and change tracking
- Ecto SQL 3.13.4 - SQL adapter
- Postgrex 0.22.0 - PostgreSQL driver

**Email:**
- Swoosh 1.21.0 - Email abstraction layer (configured for Local adapter in dev)

**Build/Asset Processing:**
- esbuild 0.10.0 (v0.25.4) - JavaScript/TypeScript bundler
- Tailwind 0.4.1 (v4.1.12) - CSS framework and compiler

**HTTP Clients:**
- Req 0.5.17 - Lightweight HTTP client
- Finch 0.21.0 - Connection pooling for HTTP

**Testing:**
- lazy_html 0.1.10 (compile-time only, test env) - HTML parsing for LiveView tests
- ExUnit (built-in) - Standard Elixir testing framework

## Key Dependencies

**Critical:**
- phoenix_pubsub 2.2.0 - Pub/Sub system for real-time messaging between processes
- req_llm 1.5.1 - LLM integration library (OpenAI/OpenRouter compatible)
- llm_db 2026.2.6 - LLM database abstraction with TOML config support

**LLM/AI Integration:**
- req_llm - Handles LLM provider interactions (OpenRouter, OpenAI, etc.)
- jsv 0.16.0 - JSON Schema validation
- zoi 0.17.0 - Decoding/encoding utilities

**Infrastructure:**
- dns_cluster 0.2.0 - DNS-based clustering for distributed Erlang
- telemetry 1.3.0 - Metrics and observability
- telemetry_metrics 1.1.0 - Metrics aggregation
- telemetry_poller 1.3.0 - Metric collection polling

**Utilities:**
- jason 1.4.4 - JSON encoding/decoding
- decimal 2.3.0 - Arbitrary-precision decimal arithmetic
- dotenvy 1.1.1 - Environment variable loading (for dotenvy configs)
- deep_merge 1.0.0 - Recursive map merging
- db_connection 2.9.0 - Database connection pooling

**Assets:**
- heroicons - Git-sourced SVG icon library (v2.2.0, optimized sparse checkout)
- phoenix_live_reload 1.6.2 - Development: Hot reloading on file changes

## Configuration

**Environment:**
- Environment-specific config files in `config/` directory:
  - `config/config.exs` - Shared configuration for all apps and environments
  - `config/dev.exs` - Development overrides (database, hot reload, debug tools)
  - `config/runtime.exs` - Runtime configuration loaded at startup (secrets, prod config)
  - `config/test.exs` - Test environment configuration
  - `config/prod.exs` - Production overrides

**Key Configs:**
- Bandit HTTP adapter on port 4000 (configurable via PORT env var)
- esbuild configured with Node path aliasing for dependency resolution
- Tailwind configured with minification for production
- Phoenix Live View with signing salt for session security
- Logger with request_id metadata

**Build Configuration:**
- Mix tasks for asset handling: `assets.setup`, `assets.build`, `assets.deploy`
- Umbrella project structure with shared config across three apps: `athanor`, `athanor_web`, `substrate_shift`

## Platform Requirements

**Development:**
- PostgreSQL database (configured as `athanor_dev` locally with postgres/postgres credentials)
- Elixir 1.15+
- Mix toolchain
- esbuild executable (installed via Mix task)
- Tailwind CLI (installed via Mix task)

**Production:**
- PostgreSQL database (configured via DATABASE_URL environment variable)
- Erlang/OTP runtime
- Environment variables: `DATABASE_URL`, `SECRET_KEY_BASE`, `PORT`, `ECTO_IPV6`, `POOL_SIZE`, `DNS_CLUSTER_QUERY`
- Optional: LLM provider API key (OPENROUTER_API_KEY) for experiment execution

---

*Stack analysis: 2026-02-16*
