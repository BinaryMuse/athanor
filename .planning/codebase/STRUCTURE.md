# Codebase Structure

**Analysis Date:** 2026-02-16

## Directory Layout

```
athanor_umbrella/
├── apps/                              # Umbrella apps
│   ├── athanor/                       # Core domain app
│   │   ├── lib/
│   │   │   ├── athanor.ex             # App module (empty placeholder)
│   │   │   ├── athanor/
│   │   │   │   ├── application.ex     # OTP application start
│   │   │   │   ├── repo.ex            # Ecto.Repo for PostgreSQL
│   │   │   │   ├── mailer.ex          # Email support (stub)
│   │   │   │   ├── experiments.ex     # Context: Instance/Run/Result/Log queries
│   │   │   │   ├── runtime.ex         # Runtime API for experiments
│   │   │   │   ├── experiments/       # Domain schemas
│   │   │   │   │   ├── instance.ex    # Experiment instance schema
│   │   │   │   │   ├── run.ex         # Run schema (pending/running/completed/failed)
│   │   │   │   │   ├── result.ex      # Result key-value storage
│   │   │   │   │   ├── log.ex         # Log entry schema
│   │   │   │   │   ├── discovery.ex   # (stub)
│   │   │   │   │   └── broadcasts.ex  # PubSub event publishing
│   │   │   │   └── runtime/           # Runtime supervision
│   │   │   │       ├── run_server.ex  # GenServer for single run
│   │   │   │       ├── run_supervisor.ex # DynamicSupervisor for runs
│   │   │   │       └── run_context.ex # Data passed to experiment run/1
│   │   │   └── experiment/            # Experiment interface
│   │   │       ├── definition.ex      # Experiment metadata struct
│   │   │       ├── schema.ex          # Experiment behavior (trait)
│   │   │       └── config_schema.ex   # Configuration schema builder
│   │   ├── priv/
│   │   │   └── repo/migrations/       # Database migrations
│   │   │       └── 20260217021346_create_experiments_tables.exs
│   │   └── test/
│   │       └── support/               # Test helpers
│   │           └── data_case.ex
│   │
│   ├── athanor_web/                   # Web presentation app
│   │   ├── lib/athanor_web/
│   │   │   ├── athanor_web.ex         # Web module (quote blocks for using)
│   │   │   ├── application.ex         # Web app OTP start
│   │   │   ├── endpoint.ex            # Phoenix.Endpoint HTTP/WS config
│   │   │   ├── router.ex              # Phoenix.Router with LiveView routes
│   │   │   ├── telemetry.ex           # Metrics setup
│   │   │   ├── controllers/           # HTTP request handlers
│   │   │   │   ├── page_controller.ex # Home page
│   │   │   │   ├── error_html.ex      # Error page templates
│   │   │   │   └── error_json.ex      # JSON error responses
│   │   │   ├── live/                  # LiveView pages
│   │   │   │   └── experiments/
│   │   │   │       ├── instance_live/
│   │   │   │       │   ├── index.ex   # List all experiment instances
│   │   │   │       │   ├── new.ex     # Create new instance
│   │   │   │       │   └── show.ex    # View instance + list runs
│   │   │   │       ├── run_live/
│   │   │   │       │   └── show.ex    # View run: logs, results, progress
│   │   │   │       └── components/    # LiveView components
│   │   │   │           ├── status_badge.ex
│   │   │   │           └── progress_bar.ex
│   │   │   ├── components/            # HTML/Phoenix components
│   │   │   │   ├── core_components.ex # Reusable UI atoms
│   │   │   │   └── layouts/
│   │   │   │       └── layouts.ex     # Layout templates
│   │   ├── assets/                    # Static assets
│   │   │   ├── css/                   # Stylesheets
│   │   │   ├── js/                    # JavaScript
│   │   │   └── vendor/                # Third-party assets
│   │   ├── priv/
│   │   │   └── static/                # Compiled static files
│   │   └── test/
│   │       ├── athanor_web/           # LiveView/controller tests
│   │       └── support/               # Test helpers
│   │           └── conn_case.ex
│   │
│   └── substrate_shift/               # Example experiment app
│       ├── lib/
│       │   └── substrate_shift.ex     # Single experiment module
│       └── test/
│
├── config/                            # Shared configuration
│   ├── config.exs                     # Shared config
│   ├── dev.exs                        # Development overrides
│   ├── prod.exs                       # Production overrides
│   ├── test.exs                       # Test overrides
│   └── runtime.exs                    # Runtime config (secrets from env)
│
├── mix.exs                            # Umbrella project file
├── mix.lock                           # Dependency lock file
├── .formatter.exs                     # Code formatter config
└── README.md
```

## Directory Purposes

**apps/athanor/:**
- Purpose: Core domain logic, data persistence, runtime orchestration
- Contains: Schemas (Ecto), context modules, GenServers, migration files
- Key concept: Experiment-agnostic harness for running pluggable experiments

**apps/athanor_web/:**
- Purpose: HTTP server, LiveView pages, real-time WebSocket updates
- Contains: Router, Controllers, LiveView modules, HTML components, CSS/JS assets
- Key concept: Real-time UI for managing experiment instances and monitoring runs

**apps/substrate_shift/:**
- Purpose: Reference implementation of an experiment
- Contains: Single module implementing Experiment.Schema behavior
- Key concept: Shows how to integrate with Athanor.Runtime API

**config/:**
- Purpose: Application configuration merged from dev/prod/test/runtime
- Contains: Database URLs, port numbers, logger settings, feature flags
- Key concept: runtime.exs loads secrets from environment variables

**priv/repo/migrations/:**
- Purpose: Database schema versions
- Contains: Ecto migration files (numbered chronologically)
- Key concept: Create/alter tables with changesets

## Key File Locations

**Entry Points:**

- `apps/athanor/lib/athanor/application.ex`: Starts Repo, PubSub, Registry, RunSupervisor
- `apps/athanor_web/lib/athanor_web/application.ex`: Starts Telemetry, Endpoint (HTTP/WS server)
- `apps/athanor_web/lib/athanor_web/router.ex`: Defines HTTP routes
- `apps/athanor_web/lib/athanor_web/endpoint.ex`: Phoenix.Endpoint configuration

**Configuration:**

- `config/config.exs`: Shared defaults
- `config/dev.exs`: Development database/port
- `config/prod.exs`: Production settings
- `config/runtime.exs`: Loads DATABASE_URL, SECRET_KEY_BASE from env

**Core Logic:**

- `apps/athanor/lib/athanor/experiments.ex`: Context with CRUD functions for Instance/Run/Result/Log
- `apps/athanor/lib/athanor/runtime.ex`: API for experiments (log, result, progress, complete, cancel)
- `apps/athanor/lib/athanor/runtime/run_server.ex`: GenServer supervising single run execution
- `apps/athanor/lib/athanor/runtime/run_supervisor.ex`: DynamicSupervisor managing all RunServers

**Testing:**

- `apps/athanor/test/`: Tests for context, schemas, runtime
- `apps/athanor_web/test/`: Tests for controllers, LiveViews
- `apps/athanor/test/support/data_case.ex`: Test setup for database fixtures
- `apps/athanor_web/test/support/conn_case.ex`: Test setup for HTTP connections

## Naming Conventions

**Files:**

- `*_live.ex`: LiveView modules
- `*_live/`: Directory containing related LiveView pages
- `*_supervisor.ex`: Supervisor modules
- `*_server.ex`: GenServer modules
- `*_controller.ex`: HTTP controller modules
- `*_html.ex`: HTML rendering templates (Phoenix components)

**Directories:**

- `lib/athanor_web/live/experiments/`: Organized by domain (experiments), then by feature (instance_live, run_live)
- `lib/athanor/experiments/`: Domain schemas grouped together
- `lib/athanor/runtime/`: Runtime supervision/execution subsystem

**Modules (Elixir Naming):**

- `Athanor.*`: Core domain app modules
- `AthanorWeb.*`: Web presentation app modules
- `SubstrateShift`: Example experiment module (singular, implements Experiment.Schema)
- `Athanor.Experiments`: Context module (plural for collection ops)
- `Athanor.Experiments.Instance`: Schema module (singular for data type)

## Where to Add New Code

**New Experiment:**

1. Create new app: `mix phx.new --sup apps/my_experiment` (if separate app)
   OR add module to existing app location
2. Implement module in `apps/my_experiment/lib/my_experiment.ex`
3. Module must use `@behaviour Athanor.Experiment.Schema`
4. Implement callbacks: `experiment/0` (metadata) and `run/1` (logic)
5. Use `Athanor.Runtime.*` functions for logging, results, progress

**New LiveView Page:**

1. Create file: `apps/athanor_web/lib/athanor_web/live/[domain]/[feature]_live/page.ex`
2. Inherit: `use AthanorWeb, :live_view` (provides ~H sigil, helpers)
3. Implement: `mount/3`, `render/1` (HEEx template), optional `handle_event/3`, `handle_info/2`
4. Subscribe: `Phoenix.PubSub.subscribe(Athanor.PubSub, "channel:name")` in mount if connected
5. Add route: `live "path", ModuleName, :action` in `router.ex`

**New Component:**

1. Create file: `apps/athanor_web/lib/athanor_web/live/[domain]/components/[name].ex`
2. Inherit: `use Phoenix.Component`
3. Define slots/attrs with `attr(:name, :type)`, `slot(:inner_block)`
4. Implement render as function: `def render(assigns) do ~H"..." end`
5. Use in LiveView templates: `<Component.name attr="value"></.>`

**New Schema/Context:**

1. Schema: `apps/athanor/lib/athanor/[domain]/[name].ex`
   - Inherit: `use Ecto.Schema` and `import Ecto.Changeset`
   - Define schema block, changeset functions
2. Context: `apps/athanor/lib/athanor/[domain].ex`
   - Create module with functions: list, get, create, update, delete
   - Wrap Repo operations with error handling
3. Migration: `apps/athanor/priv/repo/migrations/[timestamp]_[description].exs`
   - Run: `mix ecto.gen.migration [name] -r Athanor.Repo` in apps/athanor

**New Database Table:**

1. Generate migration: `mix ecto.gen.migration create_table_name` (from apps/athanor/)
2. Edit migration file in `priv/repo/migrations/`
3. Create schema module in `lib/athanor/[domain]/[name].ex`
4. Add context functions in `lib/athanor/[domain].ex`
5. Run: `mix ecto.migrate -r Athanor.Repo`

## Special Directories

**_build/:**
- Purpose: Build artifacts (compiled .beam files, docs)
- Generated: Yes (by Mix during compile)
- Committed: No (.gitignore)

**deps/:**
- Purpose: Downloaded dependency source code
- Generated: Yes (by `mix deps.get`)
- Committed: No (.gitignore)

**priv/:**
- Purpose: Private files packaged with app (migrations, images, static files)
- Generated: No (manually created)
- Committed: Yes (contains migrations)

**config/:**
- Purpose: Configuration files
- Generated: No (manually edited)
- Committed: Yes (except secrets in runtime.exs loaded from env vars)

---

*Structure analysis: 2026-02-16*
