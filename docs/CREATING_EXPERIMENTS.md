# Creating Experiments in Athanor

This guide walks through the process of creating a new experiment in the Athanor harness, using the existing `substrate_shift` and `battle_royale` experiments as reference implementations.

## Overview

Experiments in Athanor are Elixir modules that live in their own Mix application under the `apps/` directory. Each experiment:
- Uses the `Athanor.Experiment` behavior
- Defines a configuration schema for user input
- Implements execution logic that reports progress and results
- Runs in isolation under supervision

## Step 1: Create the Mix Application

From the umbrella root, create a new Mix app:

```bash
cd apps
mix new your_experiment_name
```

This creates the basic structure:
```
apps/your_experiment_name/
├── lib/
│   └── your_experiment_name.ex
├── test/
├── mix.exs
└── README.md
```

## Step 2: Add Dependencies

Edit `apps/your_experiment_name/mix.exs` to depend on the core Athanor app:

```elixir
def deps do
  [
    {:athanor, in_umbrella: true},
    # Add any other dependencies your experiment needs
    {:req, "~> 0.5"}  # Example: HTTP client
  ]
end
```

Run `mix deps.get` from the umbrella root to fetch dependencies.

## Step 3: Define the Experiment Module

The main module should `use Athanor.Experiment` and implement two callbacks:

### Basic Structure

```elixir
defmodule YourExperimentName do
  @moduledoc """
  Description of what this experiment does.
  """

  use Athanor.Experiment

  @impl true
  def experiment do
    Experiment.Definition.new()
    |> Experiment.Definition.name("your_experiment_name")
    |> Experiment.Definition.description("Human-readable description")
    |> Experiment.Definition.configuration(config())
  end

  @impl true
  def run(ctx) do
    YourExperimentName.Runner.run(ctx)
  end

  defp config do
    # Define your configuration schema here
  end
end
```

### Configuration Schema

Use `Experiment.ConfigSchema` to define what users can configure:

```elixir
defp config do
  Experiment.ConfigSchema.new()
  |> field(:iterations, :integer,
    default: 10,
    min: 1,
    max: 100,
    label: "Iterations",
    description: "Number of test runs",
    required: true
  )
  |> field(:model, :string,
    default: "gpt-4",
    label: "Model",
    description: "Which LLM to use",
    required: true
  )
  |> field(:temperature, :float,
    default: 0.7,
    min: 0.0,
    max: 2.0,
    label: "Temperature",
    description: "Sampling temperature"
  )
end
```

#### Nested Schemas

For complex configuration, use nested schemas:

```elixir
defp config do
  model_pair_schema =
    Experiment.ConfigSchema.new()
    |> field(:model_a, :string, default: "gpt-4", label: "Model A", required: true)
    |> field(:model_b, :string, default: "gpt-4o-mini", label: "Model B", required: true)

  Experiment.ConfigSchema.new()
  |> field(:runs_per_pair, :integer, default: 10, label: "Runs Per Pair", required: true)
  |> list(:model_pairs, model_pair_schema,
    label: "Model Pairs",
    description: "Pairs of models to compare"
  )
end
```

#### Field Types

Available field types:
- `:integer` - with optional `min` and `max`
- `:float` - with optional `min` and `max`
- `:string` - free text
- `:boolean` - true/false
- `:list` - use `list/3` instead of `field/3`

## Step 4: Implement the Runner

Create a separate module for execution logic (recommended pattern):

```elixir
defmodule YourExperimentName.Runner do
  alias Athanor.Runtime

  def run(ctx) do
    config = Runtime.config(ctx)

    # Extract configuration
    iterations = config["iterations"]
    model = config["model"]

    Runtime.log(ctx, :info, "Starting experiment with #{iterations} iterations")
    Runtime.progress(ctx, 0, iterations)

    # Main execution loop
    for i <- 1..iterations do
      # Check for cancellation
      if Runtime.cancelled?(ctx) do
        Runtime.log(ctx, :warn, "Cancelled by user")
        throw(:cancelled)
      end

      # Do work
      result = perform_work(model, i)

      # Record result
      Runtime.result(ctx, "iteration_#{i}", result)

      # Update progress
      Runtime.progress(ctx, i, iterations, "Completed iteration #{i}")

      Runtime.log(ctx, :debug, "Iteration #{i} complete", %{result: result})
    end

    Runtime.log(ctx, :info, "Experiment completed successfully")
    Runtime.complete(ctx)
  catch
    :cancelled ->
      {:error, "Cancelled by user"}
  end

  defp perform_work(model, iteration) do
    # Your experiment logic here
    %{iteration: iteration, model: model, output: "..."}
  end
end
```

## Step 5: Runtime API Reference

### Getting Configuration

```elixir
config = Runtime.config(ctx)
# Returns a map of configuration values
iterations = config["iterations"]
model = config["model"]
```

### Logging

```elixir
# Log at different levels
Runtime.log(ctx, :info, "Processing started")
Runtime.log(ctx, :warn, "Retrying request", %{attempt: 2})
Runtime.log(ctx, :error, "API call failed", %{status: 500})
Runtime.log(ctx, :debug, "Internal state", %{step: 3})

# Batch multiple logs
Runtime.log_batch(ctx, [
  {:info, "Step 1 complete", nil},
  {:info, "Step 2 complete", nil}
])
```

### Recording Results

Results are stored in the database and displayed in the UI:

```elixir
Runtime.result(ctx, "key_name", %{
  # Any JSON-serializable data
  input: "...",
  output: "...",
  score: 0.95,
  tokens: 150
})
```

### Progress Updates

Progress is broadcast to the UI in real-time:

```elixir
# progress(ctx, current, total, optional_message)
Runtime.progress(ctx, 5, 100)
Runtime.progress(ctx, 50, 100, "Halfway through")
```

### Completion

```elixir
# Success
Runtime.complete(ctx)

# Failure
Runtime.fail(ctx, "Error message describing what went wrong")
```

### Checking Cancellation

Always check for cancellation in long-running loops:

```elixir
for item <- items do
  if Runtime.cancelled?(ctx) do
    Runtime.log(ctx, :warn, "Cancelled by user")
    throw(:cancelled)
  end

  # Process item
end
```

## Step 6: External API Clients (Optional)

If your experiment calls external APIs, create a dedicated client module:

```elixir
defmodule YourExperimentName.Client do
  @moduledoc """
  Client for interacting with the XYZ API.
  """

  defstruct [:base_url, :api_key]

  def new(opts \\ []) do
    %__MODULE__{
      base_url: opts[:base_url] || default_url(),
      api_key: opts[:api_key] || get_api_key()
    }
  end

  def call(client, params) do
    headers = [
      {"content-type", "application/json"},
      {"authorization", "Bearer #{client.api_key}"}
    ]

    body = Jason.encode!(params)

    case Req.post(client.base_url, headers: headers, body: body) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp default_url, do: "https://api.example.com/v1"

  defp get_api_key do
    System.get_env("API_KEY") ||
      raise "API_KEY environment variable not set"
  end
end
```

## Step 7: Testing

Create tests in `test/your_experiment_name_test.exs`:

```elixir
defmodule YourExperimentNameTest do
  use ExUnit.Case
  doctest YourExperimentName

  test "experiment definition" do
    definition = YourExperimentName.experiment()

    assert definition.name == "your_experiment_name"
    assert definition.description != ""
    assert definition.configuration != nil
  end
end
```

## Complete Example: Battle Royale Structure

Here's how the `battle_royale` experiment is organized:

```
apps/battle_royale/
├── lib/
│   ├── battle_royale.ex           # Main experiment definition
│   ├── battle_royale/
│   │   ├── runner.ex              # Execution orchestration
│   │   ├── client.ex              # Ollama API client
│   │   ├── judge.ex               # Evaluation logic
│   │   └── prompts.ex             # Prompt library
├── priv/
│   └── prompts.yaml               # Prompt definitions
├── test/
├── mix.exs
└── README.md
```

## Experiment Discovery

Athanor automatically discovers all modules that `use Athanor.Experiment` at runtime. No registration needed — just implement the behavior and it will appear in the UI.

## Best Practices

1. **Separation of Concerns**: Keep the main module focused on configuration, delegate execution to a `Runner` module
2. **Client Modules**: Encapsulate external API calls in dedicated client modules
3. **Cancellation Checks**: Always check `Runtime.cancelled?(ctx)` in loops
4. **Structured Results**: Use consistent result keys and structure for easier analysis
5. **Meaningful Progress**: Update progress frequently with descriptive messages
6. **Error Handling**: Use `Runtime.fail(ctx, message)` for clear error reporting
7. **Logging Levels**:
   - `:debug` for internal details
   - `:info` for major steps
   - `:warn` for recoverable issues
   - `:error` for failures

## Common Patterns

### Parallel Execution

```elixir
results =
  items
  |> Task.async_stream(fn item ->
    if Runtime.cancelled?(ctx), do: throw(:cancelled)
    process_item(item)
  end, max_concurrency: parallelism)
  |> Enum.to_list()
```

### Retry Logic

```elixir
def call_with_retry(client, params, max_attempts \\ 3) do
  Enum.reduce_while(1..max_attempts, nil, fn attempt, _acc ->
    case Client.call(client, params) do
      {:ok, result} -> {:halt, {:ok, result}}
      {:error, reason} when attempt < max_attempts ->
        Process.sleep(1000 * attempt)
        {:cont, {:error, reason}}
      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end)
end
```

### Batched Results

```elixir
results
|> Enum.chunk_every(100)
|> Enum.with_index()
|> Enum.each(fn {batch, batch_num} ->
  Runtime.result(ctx, "batch_#{batch_num}", batch)
end)
```

## Next Steps

1. Implement your experiment following this guide
2. Test it locally via `iex -S mix phx.server`
3. Create an instance in the web UI at http://localhost:4000/experiments
4. Run and iterate on your implementation
5. Analyze results via the UI or direct database queries

## Reference Implementations

- **Simple**: `apps/substrate_shift/lib/substrate_shift.ex` - Basic model comparison
- **Complex**: `apps/battle_royale/lib/battle_royale.ex` - Multi-dimensional evaluation with judge architecture
