+++
title = "Real-Time Updates"
description = "How Athanor broadcasts experiment progress to connected clients."
weight = 4
template = "docs.html"
+++

Athanor uses Phoenix.PubSub to broadcast experiment events in real-time, enabling live UI updates and external integrations.

## PubSub Topics

Events are organized into topics:

| Topic | Events |
|-------|--------|
| `experiments:instances` | All instance changes (create, update, delete) |
| `experiments:instance:{id}` | Specific instance and its runs |
| `experiments:run:{id}` | Run status, logs, results, progress |

## Event Types

### Instance Events

```elixir
# Broadcast when an instance is created
{:instance_created, instance}

# Broadcast when an instance is updated
{:instance_updated, instance}

# Broadcast when an instance is deleted
{:instance_deleted, instance_id}
```

### Run Events

```elixir
# Run lifecycle
{:run_created, run}
{:run_started, run}
{:run_completed, run}
{:run_failed, run, error}
{:run_cancelled, run}

# Data updates
{:run_log, run_id, log_entry}
{:run_logs, run_id, [log_entries]}
{:run_result, run_id, result}
{:run_results, run_id, [results]}
{:run_progress, run_id, current, total, message}
```

## Subscribing to Events

### In LiveView

```elixir
def mount(%{"id" => id}, _session, socket) do
  if connected?(socket) do
    Athanor.Experiments.subscribe_to_run(id)
  end
  {:ok, socket}
end

def handle_info({:run_progress, _run_id, current, total, message}, socket) do
  {:noreply, assign(socket, progress: {current, total, message})}
end
```

### In a GenServer

```elixir
def init(run_id) do
  Phoenix.PubSub.subscribe(Athanor.PubSub, "experiments:run:#{run_id}")
  {:ok, %{run_id: run_id}}
end

def handle_info({:run_completed, run}, state) do
  # Handle completion
  {:noreply, state}
end
```

## Progress vs. Persistence

Athanor treats different data types differently:

| Data | Persisted | Broadcast |
|------|-----------|-----------|
| Progress | No | Yes |
| Logs | Yes | Yes |
| Results | Yes | Yes |

**Progress** is ephemeral—it's only meaningful during execution. Broadcasting without persistence avoids database writes for frequent updates.

**Logs and Results** are persisted so they can be queried after the run completes, but they're also broadcast for live viewing.

## Buffering Strategy

To balance real-time updates with database performance:

1. **ETS Buffer** — Logs and results accumulate in memory
2. **Periodic Flush** — Every 100ms, buffered data writes to the database
3. **Broadcast on Write** — Events fire when data flushes
4. **Final Flush** — Synchronous flush on run completion ensures nothing is lost

This means the UI might be up to 100ms behind the actual execution, but database load stays manageable even with high-frequency logging.
