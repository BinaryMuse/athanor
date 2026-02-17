defmodule Athanor.Experiment.ConfigSchema do
  defmacro __using__(_opts) do
    quote do
      alias Athanor.Experiment.ConfigSchema
      import unquote(__MODULE__), only: [field: 3, field: 4, list: 3, list: 4]
    end
  end

  defstruct [:type, :properties]

  def new() do
    %__MODULE__{
      type: :object,
      properties: %{}
    }
  end

  def field(%__MODULE__{} = schema, name, type, opts \\ []) do
    default = Keyword.get(opts, :default, nil)

    %{
      schema
      | properties:
          Map.put(schema.properties, name, %{
            type: type,
            default: default
          })
    }
  end

  def list(%__MODULE__{} = schema, name, item_schema, opts \\ []) do
    %{
      schema
      | properties:
          Map.put(schema.properties, name, %{
            type: :list,
            item_schema: item_schema
          })
    }
  end
end
