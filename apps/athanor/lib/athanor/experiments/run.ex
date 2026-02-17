defmodule Athanor.Experiments.Run do
  use Ecto.Schema
  import Ecto.Changeset

  alias Athanor.Experiments.{Instance, Result, Log}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending running completed failed cancelled)

  schema "experiment_runs" do
    field :status, :string, default: "pending"
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
    field :error, :string
    field :metadata, :map, default: %{}

    belongs_to :instance, Instance
    has_many :results, Result
    has_many :logs, Log

    timestamps(type: :utc_datetime_usec)
  end

  def statuses, do: @statuses

  def changeset(run, attrs) do
    run
    |> cast(attrs, ~w(instance_id status started_at completed_at error metadata)a)
    |> validate_required(~w(instance_id)a)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:instance_id)
  end

  def start_changeset(run) do
    run
    |> change(%{status: "running", started_at: DateTime.utc_now()})
  end

  def complete_changeset(run) do
    run
    |> change(%{status: "completed", completed_at: DateTime.utc_now()})
  end

  def fail_changeset(run, error) do
    run
    |> change(%{status: "failed", completed_at: DateTime.utc_now(), error: error})
  end

  def cancel_changeset(run) do
    run
    |> change(%{status: "cancelled", completed_at: DateTime.utc_now()})
  end
end
