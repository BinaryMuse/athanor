# Architecture

**Analysis Date:** 2026-02-16

## Pattern Overview

**Overall:** Elixir/Phoenix Umbrella Application with Multi-App Architecture

**Key Characteristics:**
- Umbrella project structure with three independent applications
- Layered architecture: Core domain (Athanor) → Supervised runtime → Web presentation (AthanorWeb)
- Experiment-driven harness pattern with pluggable experiment modules
- Event-driven real-time updates via Phoenix PubSub
- OTP supervision trees for run process management

## Layers

**Athanor (Core Domain App):**
- Purpose: Domain logic, data models, runtime orchestration, and experiment execution
- Location: `apps/athanor/lib/`
- Contains: Database schemas (Instance, Run, Result, Log), experiment context, runtime supervision
- Depends on: Ecto, PostgreSQL, Phoenix.PubSub
- Used by: AthanorWeb (for UI integration), SubstrateShift (example experiment)

**AthanorWeb (Presentation App):**
- Purpose: Web UI, routes, LiveView pages, real-time socket connections
- Location: `apps/athanor_web/lib/`
- Contains: Router, Endpoint, LiveView pages (Instance/Run management), Components
- Depends on: Phoenix, Phoenix.LiveView, Athanor (core domain)
- Used by: End users via browser

**SubstrateShift (Example Experiment App):**
- Purpose: Reference implementation of an experiment module
- Location: `apps/substrate_shift/lib/`
- Contains: Single experiment module implementing Experiment.Schema behavior
- Depends on: Athanor (for runtime API)
- Used by: Demonstrates how to implement experiments

## Data Flow

**Experiment Creation & Configuration:**

1. User navigates to `/experiments/new` (AthanorWeb.Experiments.InstanceLive.New)
2. Creates Instance record via Athanor.Experiments.create_instance/1
3. Instance stores: experiment_module (atom name), configuration (map)
4. Instance validation calls experiment module's `experiment/0` callback to verify module exists

**Run Execution:**

1. User triggers run from Instance detail view
2. AthanorWeb calls Athanor.Runtime.start_run/2
3. Runtime creates Run record in DB (status: pending)
4. Athanor.Runtime.RunSupervisor dynamically starts RunServer GenServer
5. RunServer async-spawns Task calling experiment module's `run/1` callback
6. Experiment receives RunContext containing run, instance, configuration

**Experiment Progress & Results:**

1. Experiment code calls Athanor.Runtime.log/4, Runtime.progress/4, Runtime.result/4
2. Runtime functions write to DB and broadcast via Phoenix.PubSub
3. Broadcasts published to channel: `experiments:run:{run_id}`
4. AthanorWeb.Experiments.RunLive.Show subscribes to channel, receives updates
5. LiveView streams new logs/results to HTML without full page reload
6. Progress updates are ephemeral (broadcast only, not persisted)

**Run Completion:**

1. Experiment completes or fails, task completes
2. RunServer receives task completion via handle_info
3. Updates Run record status (completed/failed/cancelled)
4. Broadcasts :run_completed to channel `experiments:runs:active`
5. LiveView updates run status and displays final results

**State Management:**

- **Persistent State:** Stored in PostgreSQL (Instances, Runs, Results, Logs)
- **Live State:** Phoenix.PubSub channels for real-time updates (Progress, Log additions)
- **Runtime State:** GenServer RunServer holds task reference and cancellation flag
- **UI State:** LiveView socket assigns (run, logs stream, results stream, progress)

## Key Abstractions

**Athanor.Experiment.Schema (Behavior):**
- Purpose: Contract for experiment implementations
- Examples: `apps/substrate_shift/lib/substrate_shift.ex`
- Pattern: Behavior defines two callbacks:
  - `experiment/0` → returns Experiment.Definition with metadata
  - `run/1` → receives RunContext, executes experiment logic

**Athanor.Runtime (API Module):**
- Purpose: Interface experiments use to interact with harness
- Examples: `apps/athanor/lib/athanor/runtime.ex`
- Pattern: Static functions wrapping Experiments context and broadcasts
  - log/4 → persist log entry, broadcast
  - result/4 → persist result, broadcast
  - progress/4 → broadcast progress (no persistence)
  - complete/1, fail/2 → mark run complete, broadcast
  - cancelled?/1 → check if user requested cancellation

**Athanor.Runtime.RunContext (Data Structure):**
- Purpose: Passed to experiment run/1, contains run + configuration
- Examples: `apps/athanor/lib/athanor/runtime/run_context.ex`
- Pattern: Struct bundling run, instance, configuration, experiment_module atom

**Athanor.Experiments.Broadcasts (Event Coordinator):**
- Purpose: Centralized PubSub event publishing
- Examples: `apps/athanor/lib/athanor/experiments/broadcasts.ex`
- Pattern: Functions for each event type, publish to specific channels

**Athanor.Runtime.RunServer (GenServer):**
- Purpose: Supervises single experiment run execution
- Examples: `apps/athanor/lib/athanor/runtime/run_server.ex`
- Pattern: Spawns async Task, monitors completion, handles cancellation
- State: Tracks run, context, task ref, cancelled flag

**AthanorWeb.Experiments.InstanceLive (LiveView):**
- Purpose: Real-time UI pages for managing experiments
- Examples: `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/`
- Pattern: Three pages (Index, New, Show), subscribe to PubSub channels, stream updates

## Entry Points

**Application Start:**
- Location: `apps/athanor/lib/athanor/application.ex`
- Triggers: Mix.start() during app boot
- Responsibilities: Start Repo, PubSub, Registry, RunSupervisor

**Web Server Start:**
- Location: `apps/athanor_web/lib/athanor_web/application.ex`
- Triggers: Mix.start() during app boot
- Responsibilities: Start Telemetry, Endpoint (HTTP server)

**HTTP Requests:**
- Location: `apps/athanor_web/lib/athanor_web/router.ex`
- Triggers: Browser GET/POST to `/`
- Routes: `/`, `/experiments`, `/experiments/:id`, `/runs/:id` (all LiveView)

**WebSocket (LiveView Connection):**
- Location: `apps/athanor_web/lib/athanor_web/endpoint.ex` (socket "/live")
- Triggers: Browser connects via WebSocket on LiveView page
- Responsibilities: Establish Phoenix.LiveView.Socket, restore session, enable PubSub

## Error Handling

**Strategy:** Multi-layer error handling with escalation

**Patterns:**

- **Schema Validation:** Ecto.Changeset with validate_required, validate_inclusion, custom validators
  - Example: Instance validates experiment_module exists via Code.ensure_loaded/1
  - Pattern: changeset functions return {:error, changeset} with error details

- **Context Layer:** Repo operations return {:ok, result} or {:error, reason}
  - Example: Athanor.Experiments.create_instance wraps Repo.insert result
  - Pattern: Callers pattern match on result tuples

- **Runtime Execution:** RunServer catches exceptions in Task
  - Pattern: Task.async wraps experiment run/1 in try/rescue/catch
  - Catches: Exceptions (rescue), process exits (:exit), explicit throws (:cancelled)
  - Result: Experiment either completes, fails, or cancels

- **LiveView Events:** handle_event pattern matches on results
  - Example: cancel_run returns {:error, :not_running} if run already stopped
  - Pattern: Errors converted to flash messages for user display

- **Database Errors:** Propagated as {:error, changeset} with validation messages
  - Pattern: Changeset has errors field with field-level error tuples

## Cross-Cutting Concerns

**Logging:**
- Approach: Experiment calls Athanor.Runtime.log/4 with level (debug/info/warn/error)
- Stored: run_logs table with run_id, level, message, metadata, timestamp
- Displayed: RunLive.Show streams logs in real-time

**Validation:**
- Approach: Ecto changesets with validators in schema modules
  - Instance: validates experiment_module exists
  - Run: validates status is one of statuses
  - Log: validates level is one of allowed levels
  - Result: validates required fields present

**Authentication:**
- Approach: Not implemented (currently public)
- Configuration: Could be added via Phoenix.Router pipelines
- Session: Basic cookie-based session configured in Endpoint

**Concurrency & Cancellation:**
- Approach: RunServer maintains cancelled flag, experiments check via Runtime.cancelled?/1
- Pattern: Experiments should check periodically and throw(:cancelled) to exit gracefully
- Registry: Athanor.Runtime.RunRegistry tracks active run pids for lookup

---

*Architecture analysis: 2026-02-16*
