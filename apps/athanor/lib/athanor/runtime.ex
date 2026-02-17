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
  alias Athanor.Runtime.{RunContext, RunSupervisor}

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
    level_str = to_string(level)

    case Experiments.create_log(ctx.run, level_str, message, metadata) do
      {:ok, log} ->
        Broadcasts.log_added(ctx.run.id, log)
        :ok

      error ->
        error
    end
  end

  @doc """
  Batch log multiple entries efficiently.
  """
  def log_batch(%RunContext{} = ctx, entries) when is_list(entries) do
    {count, _} = Experiments.create_logs(ctx.run, entries)
    Broadcasts.logs_added(ctx.run.id, count)
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
    value = if is_map(value), do: value, else: %{value: value}

    case Experiments.create_result(ctx.run, key, value) do
      {:ok, result} ->
        Broadcasts.result_added(ctx.run.id, result)
        :ok

      error ->
        error
    end
  end

  # --- Progress ---

  @doc """
  Report progress for the current run.
  Progress is ephemeral (not persisted) but broadcast for UI updates.

  ## Examples

      Runtime.progress(ctx, 50, 100)                    # 50%
      Runtime.progress(ctx, 3, 10, "Processing batch")  # 30% with message
  """
  def progress(%RunContext{} = ctx, current, total, message \\ nil)
      when is_integer(current) and is_integer(total) do
    progress = %{
      current: current,
      total: total,
      percent: if(total > 0, do: round(current / total * 100), else: 0),
      message: message,
      updated_at: DateTime.utc_now()
    }

    Broadcasts.progress_updated(ctx.run.id, progress)
    :ok
  end

  # --- Completion ---

  @doc """
  Mark the run as successfully completed.
  """
  def complete(%RunContext{} = ctx) do
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
