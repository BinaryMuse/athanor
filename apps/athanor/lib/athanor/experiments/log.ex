defmodule Athanor.Experiments.Log do
  use Ecto.Schema
  import Ecto.Changeset

  alias Athanor.Experiments.Run

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @levels ~w(debug info warn error)

  schema "run_logs" do
    field :level, :string
    field :message, :string
    field :metadata, :map
    field :timestamp, :utc_datetime_usec

    belongs_to :run, Run

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def levels, do: @levels

  def changeset(log, attrs) do
    attrs = Map.put_new(attrs, :timestamp, DateTime.utc_now())

    log
    |> cast(attrs, ~w(run_id level message metadata timestamp)a)
    |> validate_required(~w(run_id level message timestamp)a)
    |> validate_inclusion(:level, @levels)
    |> foreign_key_constraint(:run_id)
  end
end
