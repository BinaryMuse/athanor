defmodule SubstrateShift do
  @moduledoc """
  Experiment to test if LLMs can detect a change in their underlying model.
  """

  use Athanor.Experiment

  @impl true
  def experiment do
    Experiment.Definition.new()
    |> Experiment.Definition.name("substrate_shift")
    |> Experiment.Definition.description(
      "Testing if LLMs can detect a change in their underlying model"
    )
    |> Experiment.Definition.configuration(config())
  end

  def config do
    model_pair_schema =
      Experiment.ConfigSchema.new()
      |> field(:model_a, :string, default: "gpt-4o")
      |> field(:model_b, :string, default: "gpt-4o-mini")

    Experiment.ConfigSchema.new()
    |> field(:runs_per_pair, :integer, default: 10)
    |> list(:model_pairs, model_pair_schema)
  end

  @impl true
  def run(ctx) do
    SubstrateShift.Runner.run(ctx)
  end
end
