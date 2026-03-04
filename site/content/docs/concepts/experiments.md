+++
title = "Experiments"
description = "How experiments are defined and discovered."
weight = 1
template = "docs.html"
+++

In Athanor, experiments are **code-defined modules**, not database records. This design decision has important implications for how you work with the system.

## Why Code-Defined?

Defining experiments as Elixir modules provides several benefits:

- **Version control** — Your experiment methodology is tracked alongside your code
- **Type safety** — Leverage Elixir's type system and compile-time checks
- **Reproducibility** — The exact code that ran an experiment is always recoverable
- **Testability** — Unit test your experiment logic like any other module

The trade-off is that adding or modifying experiments requires a code deployment rather than a database update.

## Experiment Structure

An experiment module implements the `Athanor.Experiment.Schema` behavior:

```elixir
defmodule MyExperiment do
  use Athanor.Experiment

  @impl true
  def experiment do
    Experiment.Definition.new()
    |> Experiment.Definition.name("my_experiment")
    |> Experiment.Definition.description("A sample experiment")
    |> Experiment.Definition.configuration(config_schema())
  end

  @impl true
  def run(ctx) do
    # Experiment execution logic
  end

  defp config_schema do
    Experiment.ConfigSchema.new()
    |> Experiment.ConfigSchema.field(:iterations, :integer, default: 10)
  end
end
```

## Required Callbacks

### `experiment/0`

Returns an `Experiment.Definition` struct describing the experiment:

- **name** — Unique identifier for the experiment
- **description** — Human-readable description
- **configuration** — A `ConfigSchema` defining available parameters

### `run/1`

The execution entry point. Receives a `RunContext` struct containing:

- The run and instance records
- The configuration values
- The experiment module reference

This callback is invoked when a run starts and should perform the actual experiment work.

## Discovery

Athanor automatically discovers experiments at runtime by:

1. Scanning all loaded OTP applications
2. Finding modules that implement `Athanor.Experiment.Schema`
3. Verifying each module has the required callbacks

No manual registration is needed. Simply define your module, ensure it's compiled into your application, and Athanor will find it.

```elixir
# Get all discovered experiments
Athanor.Experiments.Discovery.list_experiments()
# => [{MyExperiment, %Experiment.Definition{...}}, ...]

# Get options for a select dropdown
Athanor.Experiments.Discovery.experiment_options()
# => [{"My Experiment", "Elixir.MyExperiment"}, ...]
```
