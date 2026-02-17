defmodule Athanor.Runtime.RunBuffer do
  @moduledoc """
  ETS-based buffer for experiment output.

  Owns three ETS tables per run:
  - Logs: ordered_set, append-only, batch inserted on flush
  - Results: ordered_set, append-only, batch inserted on flush
  - Progress: set with single :current key, broadcasts latest on flush

  Flushes every 100ms to DB and broadcasts batched events.
  """

  use GenServer

  alias Athanor.Experiments
  alias Athanor.Experiments.Broadcasts

  @flush_interval_ms 100
  # PostgreSQL has a 65535 parameter limit. Each log has ~7 fields.
  # 1000 logs * 7 fields = 7000 params, well under the limit.
  @max_logs_per_insert 1000

  defstruct [:run_id, :run, :logs_table, :results_table, :progress_table]

  # --- Client API ---

  def start_link(args) do
    run = Keyword.fetch!(args, :run)
    GenServer.start_link(__MODULE__, args,
      name: {:via, Registry, {Athanor.Runtime.RunBufferRegistry, run.id}}
    )
  end

  @doc """
  Get the ETS table names for a run. Used by Runtime module for direct writes.
  """
  def table_names(run_id) do
    %{
      logs: :"run_#{run_id}_logs",
      results: :"run_#{run_id}_results",
      progress: :"run_#{run_id}_progress"
    }
  end

  @doc """
  Synchronously flush all pending data. Called before run completion.
  """
  def flush_sync(run_id) do
    case Registry.lookup(Athanor.Runtime.RunBufferRegistry, run_id) do
      [{pid, _}] -> GenServer.call(pid, :flush_sync, 30_000)
      [] -> :ok
    end
  end

  # --- Server Callbacks ---

  @impl true
  def init(args) do
    run = Keyword.fetch!(args, :run)
    tables = table_names(run.id)

    # Create ETS tables - public so Runtime can write directly
    logs_table = :ets.new(tables.logs, [:ordered_set, :public, :named_table])
    results_table = :ets.new(tables.results, [:ordered_set, :public, :named_table])
    progress_table = :ets.new(tables.progress, [:set, :public, :named_table])

    state = %__MODULE__{
      run_id: run.id,
      run: run,
      logs_table: logs_table,
      results_table: results_table,
      progress_table: progress_table
    }

    schedule_flush()
    {:ok, state}
  end

  @impl true
  def handle_call(:flush_sync, _from, state) do
    do_flush(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:flush, state) do
    do_flush(state)
    schedule_flush()
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Final flush on shutdown
    do_flush(state)

    # Clean up ETS tables
    safe_delete_table(state.logs_table)
    safe_delete_table(state.results_table)
    safe_delete_table(state.progress_table)

    :ok
  end

  # --- Private ---

  defp schedule_flush do
    Process.send_after(self(), :flush, @flush_interval_ms)
  end

  defp do_flush(state) do
    flush_logs(state)
    flush_results(state)
    flush_progress(state)
  end

  defp flush_logs(state) do
    entries = :ets.tab2list(state.logs_table)
    :ets.delete_all_objects(state.logs_table)

    if entries != [] do
      # entries are {mono_time, log_data} tuples, sorted by time
      log_entries = Enum.map(entries, fn {_key, data} -> data end)

      # Chunk to avoid PostgreSQL parameter limit (65535 max)
      total_count =
        log_entries
        |> Enum.chunk_every(@max_logs_per_insert)
        |> Enum.reduce(0, fn chunk, acc ->
          {count, _} = Experiments.create_logs(state.run, chunk)
          acc + count
        end)

      Broadcasts.logs_added(state.run_id, total_count)
    end
  end

  defp flush_results(state) do
    entries = :ets.tab2list(state.results_table)
    :ets.delete_all_objects(state.results_table)

    # Insert results one by one (they have unique keys)
    Enum.each(entries, fn {_mono_time, %{key: key, value: value}} ->
      case Experiments.create_result(state.run, key, value) do
        {:ok, result} -> Broadcasts.result_added(state.run_id, result)
        _ -> :ok
      end
    end)
  end

  defp flush_progress(state) do
    case :ets.lookup(state.progress_table, :current) do
      [{:current, progress}] ->
        :ets.delete_all_objects(state.progress_table)
        Broadcasts.progress_updated(state.run_id, progress)
      [] ->
        :ok
    end
  end

  defp safe_delete_table(table) do
    try do
      :ets.delete(table)
    rescue
      ArgumentError -> :ok
    end
  end
end
