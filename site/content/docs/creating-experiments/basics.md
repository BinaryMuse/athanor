+++
title = "Experiment Basics"
description = "The fundamental structure of an Athanor experiment."
weight = 1
template = "docs.html"
+++

Every Athanor experiment is an Elixir module that implements two callbacks: `experiment/0` and `run/1`.

## Minimal Example

```elixir
defmodule MyExperiment do
  use Athanor.Experiment
  alias Athanor.Runtime
  alias Athanor.Experiment.{Definition, ConfigSchema}

  @impl true
  def experiment do
    Definition.new()
    |> Definition.name("my_experiment")
    |> Definition.description("A minimal experiment example")
    |> Definition.configuration(config_schema())
  end

  @impl true
  def run(ctx) do
    config = Runtime.config(ctx)
    iterations = config["iterations"]

    for i <- 1..iterations do
      Runtime.progress(ctx, i, iterations)
      Runtime.log(ctx, :info, "Running iteration #{i}")

      result = do_work(i)
      Runtime.result(ctx, "iteration_#{i}", result)
    end

    Runtime.complete(ctx)
  end

  defp config_schema do
    ConfigSchema.new()
    |> ConfigSchema.field(:iterations, :integer,
      default: 10,
      min: 1,
      max: 100,
      label: "Iterations",
      description: "Number of iterations to run"
    )
  end

  defp do_work(iteration) do
    # Your experiment logic here
    %{iteration: iteration, value: :rand.uniform()}
  end
end
```

## The `experiment/0` Callback

This callback returns an `Experiment.Definition` struct that describes your experiment to the system:

```elixir
@impl true
def experiment do
  Definition.new()
  |> Definition.name("unique_name")           # Required: unique identifier
  |> Definition.description("...")            # Optional: shown in UI
  |> Definition.configuration(config_schema)  # Optional: parameter schema
end
```

The definition is read when:
- Listing available experiments in the UI
- Creating new instances
- Validating configuration values

## The `run/1` Callback

This is your experiment's entry point. It receives a `RunContext` struct:

```elixir
@impl true
def run(ctx) do
  # ctx contains:
  # - ctx.run: the Run database record
  # - ctx.instance: the Instance database record
  # - ctx.configuration: map of config values
  # - ctx.experiment_module: this module's name

  # Always end with complete or fail
  Runtime.complete(ctx)
end
```

### Important Rules

1. **Always call `complete/1` or `fail/2`** — This finalizes the run status
2. **Check for cancellation** in long loops — Respect user requests to stop
3. **Don't swallow exceptions** — Let them propagate so the run fails cleanly
4. **Use the Runtime API** — Don't write directly to the database

## Where to Put Experiments

Experiments are typically organized as umbrella apps:

```
athanor/
├── apps/
│   ├── athanor/           # Core (don't modify)
│   ├── athanor_web/       # Web UI (don't modify)
│   └── my_experiment/     # Your experiment
│       ├── lib/
│       │   └── my_experiment.ex
│       ├── test/
│       └── mix.exs
```

Or as modules within an existing app:

```
apps/experiments/
├── lib/
│   ├── experiments/
│   │   ├── experiment_one.ex
│   │   └── experiment_two.ex
│   └── experiments.ex
└── mix.exs
```

Either way, as long as the module is compiled and loaded, Athanor will discover it.
