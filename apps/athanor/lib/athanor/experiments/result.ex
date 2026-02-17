defmodule Athanor.Experiments.Result do
  use Ecto.Schema
  import Ecto.Changeset

  alias Athanor.Experiments.Run

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "run_results" do
    field :key, :string
    field :value, :map

    belongs_to :run, Run

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(result, attrs) do
    result
    |> cast(attrs, ~w(run_id key value)a)
    |> validate_required(~w(run_id key value)a)
    |> foreign_key_constraint(:run_id)
  end
end
