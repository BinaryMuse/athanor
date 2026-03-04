+++
title = "API Reference"
description = "Complete reference for the Athanor.Runtime module."
weight = 1
template = "docs.html"
+++

## Configuration

### `config/1`

Retrieves the configuration map for the current run.

```elixir
config = Athanor.Runtime.config(ctx)
iterations = config["iterations"]
model = config["model"]
```

**Parameters:**
- `ctx` — The `RunContext` passed to your `run/1` callback

**Returns:** A map of configuration key-value pairs (string keys)

---

## Logging

### `log/3` and `log/4`

Records a log entry for the current run.

```elixir
# Without metadata
Athanor.Runtime.log(ctx, :info, "Processing started")

# With metadata
Athanor.Runtime.log(ctx, :warn, "Retrying request", %{attempt: 2, delay: 1000})
```

**Parameters:**
- `ctx` — The `RunContext`
- `level` — One of `:debug`, `:info`, `:warn`, `:error`
- `message` — The log message (string)
- `metadata` — Optional map of structured data

**Returns:** `:ok`

### `log_batch/2`

Records multiple log entries efficiently.

```elixir
Athanor.Runtime.log_batch(ctx, [
  {:info, "Step 1 complete", nil},
  {:info, "Step 2 complete", %{duration: 150}},
  {:warn, "Step 3 slow", %{duration: 2500}}
])
```

**Parameters:**
- `ctx` — The `RunContext`
- `entries` — List of `{level, message, metadata}` tuples

**Returns:** `:ok`

---

## Results

### `result/3`

Stores a structured result for the current run.

```elixir
Athanor.Runtime.result(ctx, "trial_1", %{
  input: prompt,
  output: response,
  tokens: 150,
  latency_ms: 340
})
```

**Parameters:**
- `ctx` — The `RunContext`
- `key` — A string identifier for this result
- `value` — Any JSON-serializable value (map, list, string, number, etc.)

**Returns:** `:ok`

Results are persisted to the database and can be queried after the run completes.

---

## Progress

### `progress/3` and `progress/4`

Updates the run's progress indicator.

```elixir
# Basic progress
Athanor.Runtime.progress(ctx, 50, 100)

# With message
Athanor.Runtime.progress(ctx, 50, 100, "Halfway through processing")
```

**Parameters:**
- `ctx` — The `RunContext`
- `current` — Current progress value (integer)
- `total` — Total expected value (integer)
- `message` — Optional status message

**Returns:** `:ok`

Progress is broadcast to connected clients but **not persisted** to the database.

---

## Completion

### `complete/1`

Marks the run as successfully completed.

```elixir
Athanor.Runtime.complete(ctx)
```

**Parameters:**
- `ctx` — The `RunContext`

**Returns:** `:ok`

This finalizes the run, flushes all buffered data, and sets the status to `completed`.

### `fail/2`

Marks the run as failed with an error message.

```elixir
Athanor.Runtime.fail(ctx, "API quota exceeded")
```

**Parameters:**
- `ctx` — The `RunContext`
- `error` — Error message string

**Returns:** `:ok`

This finalizes the run, flushes all buffered data, and sets the status to `failed`.

---

## Cancellation

### `cancelled?/1`

Checks if the run has been cancelled by the user.

```elixir
if Athanor.Runtime.cancelled?(ctx) do
  throw(:cancelled)
end
```

**Parameters:**
- `ctx` — The `RunContext`

**Returns:** `true` if cancelled, `false` otherwise

Use this in loops to respect cancellation requests:

```elixir
for item <- items do
  if Runtime.cancelled?(ctx), do: throw(:cancelled)
  process(item)
end
```

---

## The RunContext

The `ctx` parameter is an `Athanor.Runtime.RunContext` struct:

```elixir
%RunContext{
  run: %Athanor.Experiments.Run{
    id: "uuid",
    status: "running",
    started_at: ~U[...],
    # ...
  },
  instance: %Athanor.Experiments.Instance{
    id: "uuid",
    name: "My Instance",
    experiment_module: "Elixir.MyExperiment",
    # ...
  },
  configuration: %{
    "iterations" => 100,
    "model" => "gpt-4"
  },
  experiment_module: MyExperiment
}
```

Access these fields when needed:

```elixir
run_id = ctx.run.id
instance_name = ctx.instance.name
module = ctx.experiment_module
```
