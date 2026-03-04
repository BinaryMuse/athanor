+++
title = "Instances and Runs"
description = "The relationship between experiment instances and their runs."
weight = 2
template = "docs.html"
+++

Athanor separates the concepts of **instances** and **runs** to enable reproducibility and comparison.

## Instances

An instance represents a configured experiment ready to execute. It captures:

- **experiment_module** — Which experiment code to run
- **name** — A human-readable identifier
- **description** — Optional notes about this configuration
- **configuration** — The parameter values for this instance

When you create an instance, the configuration is **snapshotted**. Even if you later modify the experiment's default values, existing instances retain their original configuration.

```elixir
# Create an instance
{:ok, instance} = Athanor.Experiments.create_instance(%{
  experiment_module: "Elixir.MyExperiment",
  name: "Baseline Config",
  configuration: %{"iterations" => 100, "model" => "gpt-4"}
})
```

## Runs

A run is a single execution of an instance. Each run:

- **References an instance** — Inherits the instance's configuration
- **Tracks status** — `pending` → `running` → `completed|failed|cancelled`
- **Records timing** — `started_at` and `completed_at` timestamps
- **Stores errors** — If the run fails, the error message is captured
- **Collects data** — Logs and results accumulate during execution

```elixir
# Start a run
{:ok, run} = Athanor.Experiments.create_run(instance)
Athanor.Runtime.start(run)

# Check status
run = Athanor.Experiments.get_run!(run.id)
run.status  # => "running"
```

## Why Separate Them?

This separation enables several workflows:

### Reproducibility

Run the same configuration multiple times to verify results:

```
Instance: "GPT-4 Baseline"
├── Run 1: completed (2024-01-15)
├── Run 2: completed (2024-01-16)
└── Run 3: completed (2024-01-17)
```

### Comparison

Compare runs across different configurations:

```
Instance: "GPT-4 Baseline" (model: gpt-4)
└── Run 1: accuracy = 0.87

Instance: "Claude Baseline" (model: claude-3)
└── Run 1: accuracy = 0.91
```

### Iteration

Modify configuration and re-run without losing history:

```
Instance: "v1 Config"
├── Run 1: failed (bug in prompt)
├── Run 2: completed (after fix)

Instance: "v2 Config" (increased iterations)
└── Run 1: completed
```

## Run States

| Status | Description |
|--------|-------------|
| `pending` | Run created, not yet started |
| `running` | Currently executing |
| `completed` | Finished successfully |
| `failed` | Terminated with an error |
| `cancelled` | Stopped by user request |
