defmodule SubstrateShift do
  @moduledoc """
  Experiment to test if LLMs can detect a change in their underlying model.
  """

  alias Athanor.Experiment
  alias Athanor.Runtime

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

  @impl Experiment.Schema
  def run(ctx) do
    config = Runtime.config(ctx)
    runs_per_pair = config["runs_per_pair"] || 10
    model_pairs = config["model_pairs"] || default_model_pairs()

    Runtime.log(ctx, :info, "Starting substrate shift experiment")
    Runtime.log(ctx, :info, "Model pairs: #{length(model_pairs)}, runs per pair: #{runs_per_pair}")

    total = length(model_pairs) * runs_per_pair

    if total == 0 do
      Runtime.log(ctx, :warn, "No model pairs configured, using defaults")
      run_with_defaults(ctx, runs_per_pair)
    else
      run_experiment(ctx, model_pairs, runs_per_pair, total)
    end
  end

  defp default_model_pairs do
    [
      %{"model_a" => "gpt-4o", "model_b" => "gpt-4o-mini"}
    ]
  end

  defp run_with_defaults(ctx, runs_per_pair) do
    run_experiment(ctx, default_model_pairs(), runs_per_pair, runs_per_pair)
  end

  defp run_experiment(ctx, model_pairs, runs_per_pair, total) do
    for {pair, pair_idx} <- Enum.with_index(model_pairs),
        run_num <- 1..runs_per_pair do
      # Check for cancellation
      if Runtime.cancelled?(ctx) do
        Runtime.log(ctx, :warn, "Experiment cancelled by user")
        throw(:cancelled)
      end

      current = pair_idx * runs_per_pair + run_num
      Runtime.progress(ctx, current, total, "Testing pair #{pair_idx + 1}, run #{run_num}")

      # Simulate experiment work (replace with actual LLM calls)
      result = run_single_test(pair["model_a"], pair["model_b"])

      Runtime.result(ctx, "pair_#{pair_idx}_run_#{run_num}", %{
        model_a: pair["model_a"],
        model_b: pair["model_b"],
        detected: result.detected,
        confidence: result.confidence
      })

      Runtime.log(ctx, :debug, "Completed run #{run_num} for pair #{pair_idx + 1}")
    end

    Runtime.log(ctx, :info, "Experiment completed successfully")
    Runtime.complete(ctx)
  catch
    :cancelled ->
      {:error, "Cancelled by user"}
  end

  defp run_single_test(_model_a, _model_b) do
    # Placeholder implementation - would actually call LLM APIs
    # Simulate some work
    Process.sleep(100 + :rand.uniform(200))

    %{
      detected: :rand.uniform() > 0.5,
      confidence: Float.round(:rand.uniform(), 3)
    }
  end
end
