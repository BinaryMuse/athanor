defmodule Athanor.Runtime.RunServer do
  @moduledoc """
  GenServer managing a single experiment run.

  Provides:
  - Supervised execution (crashes are handled)
  - Cancellation support
  - Proper cleanup on termination
  """

  use GenServer, restart: :temporary

  alias Athanor.Runtime.RunContext
  alias Athanor.Experiments

  defstruct [:run, :ctx, :task_ref, :cancelled]

  # --- Client API ---

  def start_link(args) do
    run = Keyword.fetch!(args, :run)

    GenServer.start_link(__MODULE__, args,
      name: {:via, Registry, {Athanor.Runtime.RunRegistry, run.id}}
    )
  end

  def cancel(pid) do
    GenServer.call(pid, :cancel)
  end

  def cancelled?(pid) do
    GenServer.call(pid, :cancelled?)
  end

  # --- Server Callbacks ---

  @impl true
  def init(args) do
    run = Keyword.fetch!(args, :run)
    ctx = RunContext.new(run)

    state = %__MODULE__{
      run: run,
      ctx: ctx,
      cancelled: false
    }

    {:ok, state, {:continue, :start_experiment}}
  end

  @impl true
  def handle_continue(:start_experiment, state) do
    module = state.ctx.experiment_module

    unless function_exported?(module, :run, 1) do
      fail_run(state.ctx, "Experiment module does not implement run/1")
      {:stop, :normal, state}
    else
      task =
        Task.async(fn ->
          try do
            apply(module, :run, [state.ctx])
          rescue
            e ->
              {:error, Exception.format(:error, e, __STACKTRACE__)}
          catch
            :exit, reason ->
              {:error, "Process exited: #{inspect(reason)}"}

            :throw, :cancelled ->
              {:cancelled, "Cancelled by user"}
          end
        end)

      {:noreply, %{state | task_ref: task.ref}}
    end
  end

  @impl true
  def handle_call(:cancel, _from, state) do
    {:reply, :ok, %{state | cancelled: true}}
  end

  @impl true
  def handle_call(:cancelled?, _from, state) do
    {:reply, state.cancelled, state}
  end

  @impl true
  def handle_info({ref, result}, %{task_ref: ref} = state) do
    Process.demonitor(ref, [:flush])

    case result do
      :ok ->
        ensure_completed(state.ctx)

      {:ok, _} ->
        ensure_completed(state.ctx)

      {:error, error} ->
        fail_run(state.ctx, error)

      {:cancelled, _} ->
        cancel_run(state.ctx)

      other ->
        Experiments.create_log(
          state.ctx.run,
          "warn",
          "Unexpected return value: #{inspect(other)}"
        )

        ensure_completed(state.ctx)
    end

    # Stop the buffer (flushes in terminate/2)
    Athanor.Runtime.RunSupervisor.stop_buffer(state.ctx.run.id)

    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{task_ref: ref} = state) do
    error = "Experiment crashed: #{inspect(reason)}"
    fail_run(state.ctx, error)

    # Stop the buffer
    Athanor.Runtime.RunSupervisor.stop_buffer(state.ctx.run.id)

    {:stop, :normal, state}
  end

  defp ensure_completed(ctx) do
    run = Experiments.get_run!(ctx.run.id)

    if run.status == "running" do
      complete_run(ctx)
    end
  end

  defp complete_run(ctx) do
    alias Athanor.Experiments.Broadcasts
    alias Athanor.Runtime.RunBuffer

    RunBuffer.flush_sync(ctx.run.id)
    {:ok, run} = Experiments.complete_run(ctx.run)
    Broadcasts.run_completed(run)
  end

  defp fail_run(ctx, error) do
    alias Athanor.Experiments.Broadcasts
    alias Athanor.Runtime.RunBuffer

    RunBuffer.flush_sync(ctx.run.id)
    {:ok, run} = Experiments.fail_run(ctx.run, error)
    Broadcasts.run_completed(run)
  end

  defp cancel_run(ctx) do
    alias Athanor.Experiments.Broadcasts
    alias Athanor.Runtime.RunBuffer

    RunBuffer.flush_sync(ctx.run.id)
    {:ok, run} = Experiments.cancel_run(ctx.run)
    Broadcasts.run_completed(run)
  end
end
