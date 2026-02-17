defmodule SubstrateShift do
  alias Athanor.Experiment

  use Athanor.Experiment.ConfigSchema

  @behaviour Experiment.Schema

  @impl Experiment.Schema
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

  def output() do
    IO.inspect(experiment())
  end
end
