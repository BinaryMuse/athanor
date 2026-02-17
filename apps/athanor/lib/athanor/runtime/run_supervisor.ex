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
    spec = {RunServer, [run: run, opts: opts]}
    DynamicSupervisor.start_child(__MODULE__, spec)
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
