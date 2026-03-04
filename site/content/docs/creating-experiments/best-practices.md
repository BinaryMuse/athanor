+++
title = "Best Practices"
description = "Patterns and recommendations for well-structured experiments."
weight = 2
template = "docs.html"
+++

These patterns will help you write maintainable, reliable experiments.

## Project Structure

For non-trivial experiments, separate concerns into multiple modules:

```
apps/my_experiment/
├── lib/
│   ├── my_experiment.ex           # Definition and entry point
│   ├── my_experiment/
│   │   ├── runner.ex              # Execution orchestration
│   │   ├── client.ex              # External API calls
│   │   ├── evaluator.ex           # Result evaluation logic
│   │   └── prompts.ex             # Prompt templates (if applicable)
├── priv/
│   └── data/                      # Static data files
└── test/
    └── my_experiment_test.exs
```

## Delegate to a Runner

Keep your main module focused on definition; delegate execution:

```elixir
defmodule MyExperiment do
  use Athanor.Experiment

  @impl true
  def experiment do
    # Definition only
  end

  @impl true
  def run(ctx) do
    MyExperiment.Runner.execute(ctx)
  end
end

defmodule MyExperiment.Runner do
  alias Athanor.Runtime

  def execute(ctx) do
    config = Runtime.config(ctx)
    # All execution logic here
    Runtime.complete(ctx)
  end
end
```

## Handle Cancellation

Always check for cancellation in loops:

```elixir
def execute(ctx) do
  config = Runtime.config(ctx)

  try do
    for item <- items do
      if Runtime.cancelled?(ctx) do
        throw(:cancelled)
      end

      process_item(ctx, item)
    end

    Runtime.complete(ctx)
  catch
    :cancelled ->
      Runtime.log(ctx, :info, "Run cancelled by user")
      # Status is set automatically when cancelled
  end
end
```

## Structured Results

Use consistent, meaningful keys for results:

```elixir
# Good: structured, queryable
Runtime.result(ctx, "trial_001", %{
  input: prompt,
  output: response,
  latency_ms: elapsed,
  tokens: %{prompt: 150, completion: 89}
})

# Avoid: unstructured, hard to analyze
Runtime.result(ctx, "result", "The response was: #{response}")
```

## Meaningful Progress

Update progress frequently with descriptive messages:

```elixir
for {item, idx} <- Enum.with_index(items, 1) do
  Runtime.progress(ctx, idx, total, "Processing #{item.name}")
  # ...
end
```

## Logging Levels

Use appropriate levels:

| Level | Use For |
|-------|---------|
| `:debug` | Internal details, variable dumps |
| `:info` | Major steps, milestones |
| `:warn` | Recoverable issues, retries |
| `:error` | Failures that affect results |

```elixir
Runtime.log(ctx, :info, "Starting phase 1: data collection")
Runtime.log(ctx, :debug, "Loaded #{length(items)} items", %{items: items})
Runtime.log(ctx, :warn, "API rate limited, retrying", %{attempt: 2})
Runtime.log(ctx, :error, "Failed to connect to service", %{error: reason})
```

## Encapsulate External Calls

Wrap API clients for testability and retry logic:

```elixir
defmodule MyExperiment.Client do
  def call(params, opts \\ []) do
    max_retries = Keyword.get(opts, :retries, 3)
    do_call_with_retry(params, max_retries, 1)
  end

  defp do_call_with_retry(params, max, attempt) when attempt <= max do
    case make_request(params) do
      {:ok, result} ->
        {:ok, result}

      {:error, :rate_limited} when attempt < max ->
        Process.sleep(1000 * attempt)
        do_call_with_retry(params, max, attempt + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

## Batch Results for Performance

For high-volume results, batch writes:

```elixir
results
|> Enum.chunk_every(100)
|> Enum.with_index()
|> Enum.each(fn {batch, batch_num} ->
  Runtime.result(ctx, "batch_#{batch_num}", batch)
end)
```

## Fail Fast, Fail Clear

Use `fail/2` with descriptive messages:

```elixir
case Client.call(params) do
  {:ok, result} ->
    process(result)

  {:error, :invalid_api_key} ->
    Runtime.fail(ctx, "Invalid API key - check configuration")

  {:error, reason} ->
    Runtime.fail(ctx, "API call failed: #{inspect(reason)}")
end
```

## Test Your Experiments

Write unit tests for experiment logic:

```elixir
defmodule MyExperimentTest do
  use ExUnit.Case

  alias MyExperiment.{Runner, Evaluator}

  test "evaluator scores responses correctly" do
    response = %{accuracy: 0.95, latency: 100}
    assert Evaluator.score(response) == {:ok, 0.95}
  end

  test "runner handles empty input gracefully" do
    assert {:error, "No items to process"} = Runner.validate_input([])
  end
end
```
