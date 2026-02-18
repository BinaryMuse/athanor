defmodule SubstrateShift.Prelim do
  @moduledoc """
  Experiment to test if LLMs can detect a change in their underlying model.
  """

  use Athanor.Experiment

  @impl true
  def experiment do
    Experiment.Definition.new()
    |> Experiment.Definition.name("substrate_shift_prelim")
    |> Experiment.Definition.description(
      "Testing if LLMs can detect a change in their underlying model"
    )
    |> Experiment.Definition.configuration(config())
  end

  def config do
    model_pair_schema =
      Experiment.ConfigSchema.new()
      |> field(:model_a, :string,
        default: "anthropic/claude-opus-4.5",
        label: "Model A",
        description: "First model in the comparison pair",
        required: true
      )
      |> field(:model_b, :string,
        default: "openai/gpt-4o-mini",
        label: "Model B",
        description: "Second model in the comparison pair",
        required: true
      )

    Experiment.ConfigSchema.new()
    |> field(:runs_per_pair, :integer,
      default: 10,
      label: "Runs Per Pair",
      description: "Number of test runs for each model pair",
      min: 1,
      max: 100,
      required: true
    )
    |> field(:parallelism, :integer,
      default: 1,
      label: "Parallelism",
      description: "Number of model pairs to run in parallel",
      min: 1,
      max: 10,
      required: true
    )
    |> list(:model_pairs, model_pair_schema,
      label: "Model Pairs",
      description: "Pairs of models to compare in the experiment"
    )
  end

  @impl true
  def run(ctx) do
    SubstrateShift.Prelim.Runner.run(ctx)
  end
end
