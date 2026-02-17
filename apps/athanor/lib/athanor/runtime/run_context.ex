defmodule Athanor.Runtime.RunContext do
  @moduledoc """
  Context passed to experiments during execution.
  Contains the run information and configuration.
  """

  alias Athanor.Experiments.{Run, Instance}

  @type t :: %__MODULE__{
          run: Run.t(),
          instance: Instance.t(),
          configuration: map(),
          experiment_module: atom()
        }

  defstruct [:run, :instance, :configuration, :experiment_module]

  alias Athanor.Repo

  def new(%Run{} = run) do
    run = Repo.preload(run, :instance)
    instance = run.instance

    %__MODULE__{
      run: run,
      instance: instance,
      configuration: instance.configuration,
      experiment_module: String.to_existing_atom(instance.experiment_module)
    }
  end
end
