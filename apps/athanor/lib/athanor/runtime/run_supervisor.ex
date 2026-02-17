defmodule Athanor.Runtime.RunSupervisor do
  @moduledoc """
  Dynamic supervisor for experiment run processes.
  """

  use DynamicSupervisor

  alias Athanor.Runtime.RunServer

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_run(run, opts \\ []) do
    # Start buffer first - creates ETS tables
    buffer_spec = {Athanor.Runtime.RunBuffer, [run: run]}
    {:ok, _buffer_pid} = DynamicSupervisor.start_child(__MODULE__, buffer_spec)

    # Then start server - experiment can now write to tables
    server_spec = {RunServer, [run: run, opts: opts]}
    DynamicSupervisor.start_child(__MODULE__, server_spec)
  end

  def stop_buffer(run_id) do
    case Registry.lookup(Athanor.Runtime.RunBufferRegistry, run_id) do
      [{pid, _}] ->
        # flush_sync is called in terminate, so just stop
        DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] ->
        :ok
    end
  end

  def cancel_run(run_id) do
    case Registry.lookup(Athanor.Runtime.RunRegistry, run_id) do
      [{pid, _}] ->
        RunServer.cancel(pid)

      [] ->
        {:error, :not_running}
    end
  end

  def cancelled?(run_id) do
    case Registry.lookup(Athanor.Runtime.RunRegistry, run_id) do
      [{pid, _}] -> RunServer.cancelled?(pid)
      [] -> true
    end
  end

  def running?(run_id) do
    case Registry.lookup(Athanor.Runtime.RunRegistry, run_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end
end
