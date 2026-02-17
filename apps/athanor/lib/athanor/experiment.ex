defmodule Athanor.Experiment do
  defmacro __using__(_opts) do
    quote do
      alias Athanor.Experiment
      use Athanor.Experiment.ConfigSchema

      @behaviour Experiment.Schema
    end
  end
end
