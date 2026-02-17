defmodule Athanor.Experiments.Instance do
  use Ecto.Schema
  import Ecto.Changeset

  alias Athanor.Experiments.Run

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "experiment_instances" do
    field :experiment_module, :string
    field :name, :string
    field :description, :string
    field :configuration, :map, default: %{}

    has_many :runs, Run

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(experiment_module name)a
  @optional_fields ~w(description configuration)a

  def changeset(instance, attrs) do
    instance
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_experiment_module()
  end

  defp validate_experiment_module(changeset) do
    validate_change(changeset, :experiment_module, fn :experiment_module, module_string ->
      check_experiment_module(module_string)
    end)
  end

  defp check_experiment_module(module_string) do
    module = String.to_existing_atom(module_string)

    case Code.ensure_loaded(module) do
      {:module, ^module} ->
        if function_exported?(module, :experiment, 0) do
          []
        else
          [experiment_module: "module does not implement experiment/0"]
        end

      {:error, _} ->
        [experiment_module: "module not found"]
    end
  rescue
    ArgumentError ->
      [experiment_module: "invalid module name"]
  end
end
