defmodule Athanor.Experiment.Schema do
  alias Athanor.Experiment

  @callback experiment() :: Experiment.Definition.t()
end
