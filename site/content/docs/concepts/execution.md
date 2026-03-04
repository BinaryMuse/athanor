+++
title = "Execution Model"
description = "How Athanor supervises and executes experiment runs."
weight = 3
template = "docs.html"
+++

Athanor uses Elixir's OTP supervision to execute experiments in a fault-tolerant manner.

## Supervision Tree

Each run executes under a dedicated process tree:

```
Athanor.Runtime.RunSupervisor (DynamicSupervisor)
└── Athanor.Runtime.RunServer (GenServer, one per run)
    └── Task (executes experiment's run/1)
```

### RunSupervisor

A `DynamicSupervisor` that manages all active RunServers. It allows runs to start and stop independently without affecting each other.

### RunServer

A `GenServer` responsible for a single run's lifecycle:

- Initializes the run context
- Spawns and monitors the execution Task
- Handles cancellation requests
- Manages ETS buffer flushing
- Updates run status on completion or failure

### Execution Task

The actual experiment code runs in a monitored `Task`:

- Isolated from the RunServer process
- Failures are caught and reported
- Can be cancelled via the RunServer

## Isolation Benefits

This architecture provides:

- **Fault containment** — A crashing experiment doesn't affect other runs
- **Clean cancellation** — Users can stop runs gracefully
- **Resource cleanup** — Process termination releases all resources
- **Status tracking** — The RunServer always knows the run's state

## Trade-offs

The current design has some limitations:

- **No persistence across restarts** — If the application restarts, running experiments are lost
- **Single-node execution** — Runs don't distribute across cluster nodes
- **Memory-bound** — Very long-running experiments accumulate state in the RunServer

Future versions may address these through job queues or checkpoint mechanisms.

## Process Registry

Active runs are registered by their run ID:

```elixir
# Check if a run is active
Athanor.Runtime.active?(run_id)

# Get the RunServer pid
Athanor.Runtime.RunServer.whereis(run_id)
```

## Lifecycle

1. **Create Run** — Database record created with status `pending`
2. **Start Run** — RunServer spawned, status → `running`
3. **Execute** — Experiment's `run/1` callback invoked in Task
4. **Buffer** — Logs and results accumulated in ETS
5. **Flush** — Periodic and final flush to database
6. **Complete** — Status → `completed`, `failed`, or `cancelled`
7. **Cleanup** — RunServer terminates, resources released
