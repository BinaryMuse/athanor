defmodule Athanor.Experiments.Discovery do
  @moduledoc """
  Discovers available experiment modules that implement the Experiment.Schema behavior.
  """

  alias Athanor.Experiment.Schema

  @doc """
  Lists all available experiment modules.
  Returns a list of {module, definition} tuples.
  """
  def list_experiments do
    discover_modules()
    |> Enum.filter(&implements_schema?/1)
    |> Enum.map(fn module ->
      {module, module.experiment()}
    end)
    |> Enum.sort_by(fn {_module, def} -> def.name end)
  end

  # Discover modules from all loaded applications
  defp discover_modules do
    for {app, _, _} <- Application.loaded_applications(),
        module <- get_app_modules(app),
        do: module
  end

  defp get_app_modules(app) do
    case Application.spec(app, :modules) do
      nil -> []
      modules -> modules
    end
  end

  @doc """
  Lists experiment modules as options for a select input.
  Returns list of {display_name, module_string} tuples.
  """
  def experiment_options do
    list_experiments()
    |> Enum.map(fn {module, definition} ->
      {definition.name, to_string(module)}
    end)
  end

  @doc """
  Get definition for a specific module.
  """
  def get_definition(module) when is_atom(module) do
    if implements_schema?(module) do
      {:ok, module.experiment()}
    else
      {:error, :not_an_experiment}
    end
  end

  def get_definition(module_string) when is_binary(module_string) do
    module = String.to_existing_atom(module_string)
    get_definition(module)
  rescue
    ArgumentError -> {:error, :module_not_found}
  end

  @doc """
  Get the configuration schema for an experiment module.
  """
  def get_config_schema(module) when is_atom(module) do
    case get_definition(module) do
      {:ok, definition} -> {:ok, definition.configuration_schema}
      error -> error
    end
  end

  def get_config_schema(module_string) when is_binary(module_string) do
    module = String.to_existing_atom(module_string)
    get_config_schema(module)
  rescue
    ArgumentError -> {:error, :module_not_found}
  end

  defp implements_schema?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and
      function_exported?(module, :experiment, 0) and
      has_behaviour?(module, Schema)
  end

  defp has_behaviour?(module, behaviour) do
    behaviours = module.module_info(:attributes)[:behaviour] || []
    behaviour in behaviours
  end
end
