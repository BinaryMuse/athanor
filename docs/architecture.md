# Athanor Architecture

Athanor is an experiment harness for AI research, built as a Phoenix umbrella application.

## Application Structure

```
athanor_umbrella/
├── apps/
│   ├── athanor/           # Core business logic
│   ├── athanor_web/       # Phoenix web interface
│   └── substrate_shift/   # Example experiment
```

### `athanor` - Core Application

Contains all business logic, database schemas, and the runtime system for executing experiments. Has no web dependencies.

### `athanor_web` - Web Interface

Phoenix 1.8 application with LiveView for real-time experiment management. Depends on `athanor`.

### Experiment Apps (e.g., `substrate_shift`)

Separate OTP applications that implement experiments. Each depends on `athanor` for the runtime API.

## Key Architectural Decisions

### 1. Code-Defined Experiments

**Decision:** Experiments are Elixir modules implementing the `Athanor.Experiment.Schema` behavior, not database records.

**Rationale:**
- Experiments are versioned with code, making them reproducible
- Schema definitions use Elixir's type system and macros
- No need to synchronize code and database state
- Discovery happens at runtime via `Athanor.Experiments.Discovery`

**Trade-offs:**
- Adding a new experiment requires code deployment
- Cannot dynamically create experiment types via UI

### 2. Instance + Run Separation

**Decision:** Split experiment execution into two concepts:
- **Instance**: A configured experiment (name + configuration snapshot)
- **Run**: A single execution of an instance

**Rationale:**
- Same configuration can be run multiple times for reproducibility
- Configuration is snapshotted at instance creation, not at run time
- Enables comparing runs with identical configurations

### 3. Supervised Run Execution

**Decision:** Each experiment run executes in its own GenServer under a DynamicSupervisor.

```
Athanor.Runtime.RunSupervisor (DynamicSupervisor)
└── Athanor.Runtime.RunServer (per run)
    └── Task (executes experiment's run/1)
```

**Rationale:**
- Crashes are isolated to individual runs
- Cancellation is clean (GenServer receives cancel message)
- Registry enables lookup by run ID
- Process dies when run completes, freeing resources

**Trade-offs:**
- Cannot survive application restarts (runs are ephemeral)
- No distributed execution across nodes (would need different architecture)

### 4. PubSub for Real-Time Updates

**Decision:** Use Phoenix.PubSub to broadcast all experiment events.

**Topics:**
```
experiments:instances          # All instance changes
experiments:instance:{id}      # Specific instance + its runs
experiments:run:{id}           # Run status, logs, results, progress
```

**Rationale:**
- Decouples event producers from consumers
- Multiple browser tabs stay in sync automatically
- LiveView subscribes in `mount/3`, receives updates via `handle_info/2`
- Easy to add additional consumers (metrics, logging, etc.)

### 5. Runtime API Design

**Decision:** Single `Athanor.Runtime` module as the public API for experiments.

```elixir
Runtime.log(ctx, :info, "message")
Runtime.result(ctx, "key", %{value: ...})
Runtime.progress(ctx, current, total)
Runtime.complete(ctx) / Runtime.fail(ctx, error)
Runtime.cancelled?(ctx)
```

**Rationale:**
- Simple, consistent interface for experiment authors
- Context struct (`RunContext`) carries all necessary state
- Each operation persists to database AND broadcasts via PubSub
- Experiments don't need to know about PubSub, Ecto, etc.

### 6. Streams for LiveView Lists

**Decision:** Use LiveView streams for logs, results, and run lists.

**Rationale:**
- Efficient handling of large, append-only lists
- Only diffs are sent over the wire
- Memory-efficient on the server

**Trade-offs:**
- Cannot easily check `Enum.empty?` on streams (tracked separately via assigns)

### 7. Configuration Schema System

**Decision:** Custom `Experiment.ConfigSchema` DSL for defining experiment configuration.

```elixir
Experiment.ConfigSchema.new()
|> field(:runs_per_pair, :integer, default: 10)
|> list(:model_pairs, model_pair_schema)
```

**Rationale:**
- Type-safe configuration definitions
- Supports nested schemas for complex configurations
- Defaults are defined in code alongside the experiment
- Can generate dynamic forms from schema

**Future considerations:**
- Add validation rules to schema
- Generate JSON Schema for API validation

### 8. Ephemeral Progress, Persistent Results

**Decision:** Progress updates are broadcast-only (not persisted), while results and logs are persisted.

**Rationale:**
- Progress is only useful during execution
- Reduces database writes during hot loops
- Results and logs are needed for post-run analysis

## Data Model

```
experiment_instances
├── id (UUID)
├── experiment_module (string)
├── name, description
├── configuration (JSONB)
└── timestamps

experiment_runs
├── id (UUID)
├── instance_id (FK)
├── status (pending|running|completed|failed|cancelled)
├── started_at, completed_at
├── error (text)
├── metadata (JSONB)
└── timestamps

run_results
├── id (UUID)
├── run_id (FK)
├── key (string)
├── value (JSONB)
└── inserted_at

run_logs
├── id (UUID)
├── run_id (FK)
├── level (debug|info|warn|error)
├── message (text)
├── metadata (JSONB)
├── timestamp
└── inserted_at
```

## Request Flow

### Starting a Run

```
User clicks "Start Run"
    │
    ▼
LiveView handle_event("start_run")
    │
    ▼
Runtime.start_run(instance)
    ├── Experiments.create_run()      # Create DB record
    ├── Experiments.start_run()       # Set status to "running"
    ├── RunSupervisor.start_run()     # Start GenServer
    │   └── RunServer.init()
    │       └── Task.async(module.run(ctx))
    └── Broadcasts.run_started()      # PubSub broadcast
    │
    ▼
LiveView receives {:run_created, run}
    │
    ▼
UI updates via stream_insert
```

### Experiment Execution

```
Experiment calls Runtime.log(ctx, :info, "message")
    │
    ▼
Experiments.create_log()        # Persist to DB
    │
    ▼
Broadcasts.log_added()          # PubSub broadcast
    │
    ▼
All subscribed LiveViews receive {:log_added, log}
    │
    ▼
UI updates via stream_insert
```

## Future Considerations

- **Distributed execution**: Currently single-node; would need job queue for multi-node
- **Run resumption**: Runs don't survive restarts; could checkpoint state
- **Result comparisons**: Add first-class support for comparing runs
- **Artifact storage**: Store files/blobs produced by experiments
- **Scheduling**: Run experiments on a schedule or in response to events
