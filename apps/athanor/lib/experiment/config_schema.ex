defmodule Athanor.Experiment.ConfigSchema do
  defmacro __using__(_opts) do
    quote do
      alias Athanor.Experiment.ConfigSchema
      import unquote(__MODULE__), only: [field: 3, field: 4, list: 3, list: 4, group: 3, group: 4]
    end
  end

  defstruct [:type, :properties]

  def new() do
    %__MODULE__{
      type: :object,
      properties: []
    }
  end

  def field(%__MODULE__{} = schema, name, type, opts \\ []) do
    default = Keyword.get(opts, :default, nil)
    label = Keyword.get(opts, :label, nil)
    description = Keyword.get(opts, :description, nil)
    required = Keyword.get(opts, :required, false)
    format = Keyword.get(opts, :format, nil)
    min = Keyword.get(opts, :min, nil)
    max = Keyword.get(opts, :max, nil)
    step = Keyword.get(opts, :step, nil)
    options = Keyword.get(opts, :options, nil)

    field_def =
      %{
        type: type,
        default: default,
        label: label,
        description: description,
        required: required,
        format: format,
        min: min,
        max: max,
        step: step,
        options: options
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    %{
      schema
      | properties: schema.properties ++ [{name, field_def}]
    }
  end

  def list(%__MODULE__{} = schema, name, item_schema, opts \\ []) do
    label = Keyword.get(opts, :label, nil)
    description = Keyword.get(opts, :description, nil)

    field_def =
      %{
        type: :list,
        item_schema: item_schema,
        label: label,
        description: description
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    %{
      schema
      | properties: schema.properties ++ [{name, field_def}]
    }
  end

  def group(%__MODULE__{} = schema, name, sub_schema, opts \\ []) do
    label = Keyword.get(opts, :label, nil)
    description = Keyword.get(opts, :description, nil)

    %{
      schema
      | properties: schema.properties ++ [{name, %{
          type: :group,
          label: label,
          description: description,
          sub_schema: sub_schema
        }}]
    }
  end

  def get_property(%__MODULE__{properties: props}, name) do
    Enum.find_value(props, fn {n, def} -> if n == name, do: def end)
  end

  def to_serializable(%__MODULE__{} = schema) do
    %{
      "type" => to_string(schema.type),
      "properties" => Enum.map(schema.properties, fn {name, def} ->
        %{"name" => to_string(name), "definition" => serialize_field_def(def)}
      end)
    }
  end

  defp serialize_field_def(%{type: :group, sub_schema: sub} = def) do
    def
    |> Map.delete(:sub_schema)
    |> Map.put(:sub_schema, to_serializable(sub))
    |> stringify_field_def()
  end

  defp serialize_field_def(%{type: :list, item_schema: item} = def) do
    def
    |> Map.delete(:item_schema)
    |> Map.put(:item_schema, to_serializable(item))
    |> stringify_field_def()
  end

  defp serialize_field_def(def) do
    stringify_field_def(def)
  end

  defp stringify_field_def(def) do
    Map.new(def, fn {k, v} ->
      key = to_string(k)
      val = cond do
        is_atom(v) -> to_string(v)
        is_list(v) -> Enum.map(v, &to_string/1)
        true -> v
      end
      {key, val}
    end)
  end
end
