defmodule Athanor.Experiment.Schema do
  @moduledoc """
  Behavior for experiment modules.

  ## Example

      defmodule MyExperiment do
        @behaviour Athanor.Experiment.Schema

        @impl true
        def experiment do
          Experiment.Definition.new()
          |> Experiment.Definition.name("my_experiment")
          |> Experiment.Definition.description("Does something interesting")
          |> Experiment.Definition.configuration(config())
        end

        @impl true
        def run(ctx) do
          Athanor.Runtime.log(ctx, :info, "Running!")
          # ... do work ...
          Athanor.Runtime.complete(ctx)
        end
      end
  """

  alias Athanor.Experiment
  alias Athanor.Runtime.RunContext

  @callback experiment() :: Experiment.Definition.t()

  @callback run(RunContext.t()) :: :ok | {:ok, any()} | {:error, String.t()}

  @optional_callbacks [run: 1]
end
