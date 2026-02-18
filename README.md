# Athanor

Athanor is an experiment harness for AI research, built as an Elixir/Phoenix umbrella application. It provides a framework for defining, configuring, executing, and monitoring experiments that test AI models.

## Project Structure

The core umbrella contains two applications:

- **`athanor`** - Core business logic and runtime system
- **`athanor_web`** - Phoenix web interface with LiveView for real-time experiment management

## Setup

```bash
# Install dependencies
mix setup

# Set up the database; see `config/dev.exs` for credentials
mix ecto.setup

# Start the server
iex -S mix phx.server
```

The web interface runs at http://localhost:4000 — you can choose a port by setting the `PORT` environment variable when starting the app.

## Core Concepts

### Code-Defined Experiments

Experiments are Elixir modules that `use Athanor.Experiment`. Each experiment defines its configuration schema and execution logic in code, making experiments versioned and reproducible.

### Instance + Run Separation

- **Instance**: A configured experiment with a name, description, and configuration values
- **Run**: A single execution of an instance

This separation allows the same configuration to be executed multiple times for reproducibility.

### Supervised Execution

Each run executes in its own GenServer under a DynamicSupervisor, isolating failures and enabling cancellation.

## Creating an Experiment

Create a module that uses `Athanor.Experiment`:

```elixir
defmodule MyExperiment do
  use Athanor.Experiment

  alias Athanor.Experiment

  @impl true
  def experiment do
    Experiment.Definition.new()
    |> Experiment.Definition.name("my_experiment")
    |> Experiment.Definition.description("Tests something interesting")
    |> Experiment.Definition.configuration(config())
  end

  defp config do
    Experiment.ConfigSchema.new()
    |> Experiment.ConfigSchema.field(:iterations, :integer,
      default: 10,
      min: 1,
      max: 100,
      label: "Iterations",
      description: "Number of test iterations"
    )
    |> Experiment.ConfigSchema.field(:model, :string,
      default: "gpt-4",
      label: "Model",
      required: true
    )
  end

  @impl true
  def run(ctx) do
    config = Athanor.Runtime.config(ctx)
    total = config["iterations"]

    Athanor.Runtime.log(ctx, :info, "Starting experiment with #{total} iterations")
    Athanor.Runtime.progress(ctx, 0, total)

    for i <- 1..total do
      # Check for cancellation
      if Athanor.Runtime.cancelled?(ctx), do: throw(:cancelled)

      # Do work...
      result = perform_iteration(config, i)

      # Record result and update progress
      Athanor.Runtime.result(ctx, "iteration_#{i}", result)
      Athanor.Runtime.progress(ctx, i, total)
    end

    Athanor.Runtime.complete(ctx)
  catch
    :cancelled -> {:error, "Cancelled by user"}
  end

  defp perform_iteration(config, i) do
    # Your experiment logic here
    %{iteration: i, model: config["model"], output: "..."}
  end
end
```

Experiments are auto-discovered by the system at runtime.

## Runtime API

The `Athanor.Runtime` module provides the interface for experiments to interact with the harness during execution:

### Configuration

```elixir
# Get the instance configuration as a map
config = Athanor.Runtime.config(ctx)
```

### Logging

```elixir
# Log messages at different levels
Athanor.Runtime.log(ctx, :info, "Processing item")
Athanor.Runtime.log(ctx, :warn, "Retrying request", %{attempt: 2})
Athanor.Runtime.log(ctx, :error, "Failed to connect")

# Batch multiple log entries
Athanor.Runtime.log_batch(ctx, [
  {:info, "Step 1 complete", nil},
  {:info, "Step 2 complete", nil}
])
```

### Results

Results are persisted to the database and displayed in the web UI:

```elixir
# Store a result with a key and value
Athanor.Runtime.result(ctx, "model_response", %{
  input: prompt,
  output: response,
  tokens: token_count
})
```

### Progress

Progress updates are broadcast to the web UI in real-time:

```elixir
# Update progress (current, total, optional message)
Athanor.Runtime.progress(ctx, 5, 100)
Athanor.Runtime.progress(ctx, 50, 100, "Halfway done")
```

### Completion

```elixir
# Mark the run as successfully completed
Athanor.Runtime.complete(ctx)

# Mark the run as failed with an error message
Athanor.Runtime.fail(ctx, "API rate limit exceeded")
```

### Cancellation

```elixir
# Check if the user has requested cancellation
if Athanor.Runtime.cancelled?(ctx) do
  # Clean up and exit
end
```

## Executing Experiments

### Via Web UI

1. Navigate to `/experiments`
2. Click "New" to create an instance
3. Select an experiment module and configure it
4. Click "Run" to execute
5. Watch logs, results, and progress update in real-time

### Programmatically

```elixir
# Start a run for an existing instance
{:ok, run} = Athanor.Runtime.start_run(instance)

# Cancel a running experiment
Athanor.Runtime.cancel_run(run)
```

## Analyzing Results

Results are stored as a simple key/value store in the `run_results` table. Each result has:
- **`run_id`** - The run it belongs to
- **`key`** - A string identifier (e.g., `"iteration_1"`, `"model_response"`)
- **`value`** - A JSONB column containing arbitrary data

This structure makes results easy to query and analyze outside of Athanor.

### Querying Results

```elixir
# Get all results for a run
Athanor.Experiments.list_results(run_id)

# Query directly with Ecto
import Ecto.Query

Athanor.Repo.all(
  from r in Athanor.Experiments.Result,
  where: r.run_id == ^run_id,
  where: r.key == "model_response"
)
```

### Jupyter Notebook Analysis

Results can be loaded directly into Jupyter notebooks (using Livebook or Python) for analysis:

```python
import psycopg2
import pandas as pd

conn = psycopg2.connect("postgresql://localhost/athanor_dev")

# Load results for a specific run
df = pd.read_sql("""
    SELECT key, value, inserted_at
    FROM run_results
    WHERE run_id = %s
    ORDER BY inserted_at
""", conn, params=[run_id])

# The 'value' column contains JSON - expand it
df = pd.concat([df, pd.json_normalize(df['value'])], axis=1)
```

Or with Livebook (Elixir):

```elixir
# In a Livebook connected to your Athanor node
results = Athanor.Experiments.list_results(run_id)

# Convert to a table for analysis
results
|> Enum.map(fn r -> Map.merge(%{key: r.key}, r.value) end)
|> Kino.DataTable.new()
```

## Example: SubstrateShift

The `substrate_shift` app contains a complete example experiment that tests whether LLMs can detect when they're running on a different underlying model.

Configuration options:
- `runs_per_pair` - Number of test runs per model pair
- `parallelism` - Concurrent pairs to test
- `model_pairs` - List of model pairs to compare

See `apps/substrate_shift/lib/substrate_shift.ex` for the full implementation.

## Development

```bash
# Run tests
mix test

# Format code and run checks
mix precommit

# Start interactive shell with server
iex -S mix phx.server
```

## Data Model

- **`experiment_instances`** - Configured experiments with name, description, and configuration
- **`experiment_runs`** - Execution records with status, timing, and error info
- **`run_results`** - Key-value results from each run
- **`run_logs`** - Log entries with level, message, and metadata
