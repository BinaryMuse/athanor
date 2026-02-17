defmodule Athanor.Runtime do
  @moduledoc """
  Runtime API for experiments to interact with the harness.

  This module provides the interface experiments use to:
  - Log messages
  - Store results
  - Report progress
  - Signal completion or failure

  ## Usage in Experiments

      defmodule MyExperiment do
        alias Athanor.Runtime

        def run(ctx) do
          Runtime.log(ctx, :info, "Starting experiment...")

          for i <- 1..100 do
            if Runtime.cancelled?(ctx), do: throw(:cancelled)

            Runtime.progress(ctx, i, 100)
            Runtime.result(ctx, "iteration_\#{i}", %{value: result})
          end

          Runtime.complete(ctx)
        end
      end
  """

  alias Athanor.Experiments
  alias Athanor.Experiments.{Run, Broadcasts}
  alias Athanor.Runtime.{RunContext, RunSupervisor, RunBuffer}

  # --- Context Creation ---

  @doc """
  Creates a runtime context for a run.
  The context holds run information and is passed to experiment functions.
  """
  def context(%Run{} = run) do
    RunContext.new(run)
  end

  # --- Starting/Stopping Runs ---

  @doc """
  Starts a new run for the given instance.
  Creates a Run record and starts the experiment under supervision.
  """
  def start_run(instance, opts \\ []) do
    with {:ok, run} <- Experiments.create_run(instance),
         {:ok, run} <- Experiments.start_run(run),
         {:ok, _pid} <- RunSupervisor.start_run(run, opts) do
      Broadcasts.run_started(run)
      {:ok, run}
    end
  end

  @doc """
  Cancels a running experiment.
  """
  def cancel_run(%Run{} = run) do
    case RunSupervisor.cancel_run(run.id) do
      :ok ->
        {:ok, run}

      {:error, :not_running} ->
        # Already stopped, just update the status if needed
        if run.status == "running" do
          with {:ok, run} <- Experiments.cancel_run(run) do
            Broadcasts.run_completed(run)
            {:ok, run}
          end
        else
          {:ok, run}
        end
    end
  end

  # --- Logging ---

  @doc """
  Log a message for the current run.

  ## Examples

      Runtime.log(ctx, :info, "Processing item")
      Runtime.log(ctx, :warn, "Retrying request", %{attempt: 3})
      Runtime.log(ctx, :error, "Failed to connect")
  """
  def log(%RunContext{} = ctx, level, message, metadata \\ nil)
      when level in [:debug, :info, :warn, :error] do
    tables = RunBuffer.table_names(ctx.run.id)
    key = System.monotonic_time(:nanosecond)

    now = DateTime.utc_now()

    entry = %{
      level: to_string(level),
      message: message,
      metadata: metadata,
      timestamp: now,
      inserted_at: now
    }

    :ets.insert(tables.logs, {key, entry})
    :ok
  end

  @doc """
  Batch log multiple entries efficiently.
  """
  def log_batch(%RunContext{} = ctx, entries) when is_list(entries) do
    tables = RunBuffer.table_names(ctx.run.id)
    now = DateTime.utc_now()

    ets_entries =
      entries
      |> Enum.with_index()
      |> Enum.map(fn {{level, message, metadata}, idx} ->
        key = System.monotonic_time(:nanosecond) + idx
        {key, %{
          level: to_string(level),
          message: message,
          metadata: metadata,
          inserted_at: now
        }}
      end)

    :ets.insert(tables.logs, ets_entries)
    :ok
  end

  # --- Results ---

  @doc """
  Store a key-value result for the current run.

  ## Examples

      Runtime.result(ctx, "accuracy", %{value: 0.95, confidence: 0.02})
      Runtime.result(ctx, "model_response", %{text: "Hello", tokens: 5})
  """
  def result(%RunContext{} = ctx, key, value) when is_binary(key) do
    tables = RunBuffer.table_names(ctx.run.id)
    mono_key = System.monotonic_time(:nanosecond)
    value = if is_map(value), do: value, else: %{value: value}

    :ets.insert(tables.results, {mono_key, %{key: key, value: value}})
    :ok
  end

  # --- Progress ---

  @doc """
  Report progress for the current run.
  Progress is buffered and broadcast on the next flush interval (every 100ms).

  ## Examples

      Runtime.progress(ctx, 50, 100)                    # 50%
      Runtime.progress(ctx, 3, 10, "Processing batch")  # 30% with message
  """
  def progress(%RunContext{} = ctx, current, total, message \\ nil)
      when is_integer(current) and is_integer(total) do
    tables = RunBuffer.table_names(ctx.run.id)

    progress = %{
      current: current,
      total: total,
      percent: if(total > 0, do: round(current / total * 100), else: 0),
      message: message,
      updated_at: DateTime.utc_now()
    }

    # Single key - always overwrites previous
    :ets.insert(tables.progress, {:current, progress})
    :ok
  end

  # --- Completion ---

  @doc """
  Mark the run as successfully completed.
  """
  def complete(%RunContext{} = ctx) do
    # Flush all pending data before marking complete
    RunBuffer.flush_sync(ctx.run.id)

    case Experiments.complete_run(ctx.run) do
      {:ok, run} ->
        Broadcasts.run_completed(run)
        {:ok, run}

      error ->
        error
    end
  end

  @doc """
  Mark the run as failed with an error message.
  """
  def fail(%RunContext{} = ctx, error) when is_binary(error) do
    # Flush pending data even on failure
    RunBuffer.flush_sync(ctx.run.id)

    case Experiments.fail_run(ctx.run, error) do
      {:ok, run} ->
        Broadcasts.run_completed(run)
        {:ok, run}

      error ->
        error
    end
  end

  # --- Run State ---

  @doc """
  Check if cancellation has been requested.
  Experiments should periodically check this and gracefully stop.
  """
  def cancelled?(%RunContext{} = ctx) do
    RunSupervisor.cancelled?(ctx.run.id)
  end

  @doc """
  Get the current configuration for this run.
  """
  def config(%RunContext{} = ctx) do
    ctx.configuration
  end
end
