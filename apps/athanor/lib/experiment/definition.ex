defmodule Athanor.Experiment.Definition do
  defstruct [:name, :description, :configuration_schema]

  @type t() :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          configuration_schema: map()
        }

  def new() do
    %__MODULE__{}
  end

  def name(definition, name) do
    %{definition | name: name}
  end

  def description(definition, description) do
    %{definition | description: description}
  end

  def configuration(definition, configuration) do
    %{definition | configuration_schema: configuration}
  end
end
