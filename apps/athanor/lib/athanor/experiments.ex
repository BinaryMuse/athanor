defmodule Athanor.Experiments do
  @moduledoc """
  Context for managing experiments, runs, results, and logs.
  """

  import Ecto.Query
  alias Athanor.Repo
  alias Athanor.Experiments.{Instance, Run, Result, Log}

  # --- Instances ---

  def list_instances do
    Repo.all(Instance)
  end

  def get_instance(id) do
    Repo.get(Instance, id)
  end

  def get_instance!(id) do
    Repo.get!(Instance, id)
  end

  def create_instance(attrs) do
    %Instance{}
    |> Instance.changeset(attrs)
    |> Repo.insert()
  end

  def update_instance(%Instance{} = instance, attrs) do
    instance
    |> Instance.changeset(attrs)
    |> Repo.update()
  end

  def delete_instance(%Instance{} = instance) do
    Repo.delete(instance)
  end

  # --- Runs ---

  def list_runs(%Instance{} = instance) do
    Run
    |> where([r], r.instance_id == ^instance.id)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  def get_run(id) do
    Repo.get(Run, id)
  end

  def get_run!(id) do
    Repo.get!(Run, id)
  end

  def create_run(%Instance{} = instance, attrs \\ %{}) do
    attrs = Map.put(attrs, :instance_id, instance.id)

    %Run{}
    |> Run.changeset(attrs)
    |> Repo.insert()
  end

  def start_run(%Run{} = run) do
    run
    |> Run.start_changeset()
    |> Repo.update()
  end

  def complete_run(%Run{} = run) do
    run
    |> Run.complete_changeset()
    |> Repo.update()
  end

  def fail_run(%Run{} = run, error) do
    run
    |> Run.fail_changeset(error)
    |> Repo.update()
  end

  def cancel_run(%Run{} = run) do
    run
    |> Run.cancel_changeset()
    |> Repo.update()
  end

  # --- Results ---

  def list_results(%Run{} = run) do
    Result
    |> where([r], r.run_id == ^run.id)
    |> order_by([r], asc: r.inserted_at)
    |> Repo.all()
  end

  def get_results_by_key(%Run{} = run, key) do
    Result
    |> where([r], r.run_id == ^run.id and r.key == ^key)
    |> order_by([r], asc: r.inserted_at)
    |> Repo.all()
  end

  def create_result(%Run{} = run, key, value) do
    %Result{}
    |> Result.changeset(%{run_id: run.id, key: key, value: value})
    |> Repo.insert()
  end

  # --- Logs ---

  def list_logs(%Run{} = run, opts \\ []) do
    level = Keyword.get(opts, :level)
    limit = Keyword.get(opts, :limit)

    query =
      Log
      |> where([l], l.run_id == ^run.id)

    query = if level, do: where(query, [l], l.level == ^level), else: query

    # When limit specified, get newest N logs then reverse for chronological display
    if limit do
      query
      |> order_by([l], desc: l.timestamp)
      |> limit(^limit)
      |> Repo.all()
      |> Enum.reverse()
    else
      query
      |> order_by([l], asc: l.timestamp)
      |> Repo.all()
    end
  end

  def create_log(%Run{} = run, level, message, metadata \\ nil) do
    %Log{}
    |> Log.changeset(%{run_id: run.id, level: level, message: message, metadata: metadata})
    |> Repo.insert()
  end

  @doc """
  Batch insert multiple log entries efficiently.
  """
  def create_logs(%Run{} = run, entries) when is_list(entries) do
    now = DateTime.utc_now()

    logs =
      Enum.map(entries, fn entry ->
        %{
          id: Ecto.UUID.generate(),
          run_id: run.id,
          level: entry.level,
          message: entry.message,
          metadata: Map.get(entry, :metadata),
          timestamp: Map.get(entry, :timestamp, now),
          inserted_at: now
        }
      end)

    Repo.insert_all(Log, logs)
  end
end
