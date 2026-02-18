defmodule SubstrateShift.Prelim.Runner do
  alias Athanor.Runtime
  alias SubstrateShift.Prelim.Conversation

  @switch_turns [0, 3, 5, 7, 9]

  def run(ctx) do
    config = Runtime.config(ctx)
    runs_per_pair = config["runs_per_pair"] || 10
    model_pairs = config["model_pairs"] || default_model_pairs()
    parallelism = config["parallelism"] || 1

    Runtime.log(ctx, :info, "Starting substrate shift prelim experiment")

    queue = build_queue(model_pairs, runs_per_pair)
    total = length(queue)

    Runtime.log(
      ctx,
      :info,
      "Model pairs: #{length(model_pairs)}, switch turns: #{inspect(@switch_turns)}, " <>
        "runs per switch turn: #{runs_per_pair}, total work items: #{total}"
    )

    if queue == [] do
      Runtime.log(ctx, :warn, "No model pairs configured, nothing to do")
    else
      run_experiment(ctx, queue, total, parallelism)
    end
  end

  defp default_model_pairs do
    [
      %{"model_a" => "anthropic/claude-opus-4.5", "model_b" => "openai/gpt-4o-mini"}
    ]
  end

  defp run_experiment(ctx, queue, total, parallelism) do
    results =
      queue
      |> Task.async_stream(
        fn item -> run_single(ctx, item) end,
        max_concurrency: parallelism,
        timeout: :infinity,
        ordered: false
      )
      |> Enum.reduce(%{completed: 0, failed: 0}, fn result, acc ->
        if Runtime.cancelled?(ctx) do
          throw(:cancelled)
        end

        acc = %{acc | completed: acc.completed + 1}
        Runtime.progress(ctx, acc.completed, total)

        case result do
          {:ok, {:ok, item, turn_results}} ->
            record_success(ctx, item, turn_results)
            acc

          {:ok, {:error, item, turn, reason}} ->
            record_failure(ctx, item, turn, reason)
            %{acc | failed: acc.failed + 1}

          {:exit, reason} ->
            Runtime.log(ctx, :error, "Work item crashed: #{inspect(reason)}")
            %{acc | failed: acc.failed + 1}
        end
      end)

    Runtime.log(
      ctx,
      :info,
      "Experiment complete. #{results.completed - results.failed}/#{total} succeeded, " <>
        "#{results.failed} failed"
    )

    Runtime.complete(ctx)
  end

  defp run_single(ctx, item) do
    label = work_item_label(item)
    Runtime.log(ctx, :info, "Starting #{label}")

    on_turn = fn turn, result ->
      Runtime.log(ctx, :debug, "[#{label}] Turn #{turn}/#{Conversation.num_turns()} [#{result.model}]")
      Runtime.log(ctx, :debug, "[#{label}] Q: #{result.question}")
      Runtime.log(ctx, :debug, "[#{label}] A: #{result.response}")
    end

    case Conversation.run(item, on_turn: on_turn) do
      {:ok, turn_results} ->
        Runtime.log(ctx, :info, "Completed #{label}")
        {:ok, item, turn_results}

      {:error, {turn, reason}} ->
        Runtime.log(ctx, :error, "Failed #{label} on turn #{turn}: #{inspect(reason)}")
        {:error, item, turn, reason}
    end
  end

  defp record_success(ctx, item, turn_results) do
    key = work_item_label(item)

    Runtime.result(ctx, key, %{
      status: "success",
      pair_index: item.pair_index,
      model_a: item.model_a,
      model_b: item.model_b,
      switch_turn: item.switch_turn,
      run_number: item.run_number,
      turns:
        Enum.map(turn_results, fn t ->
          %{
            turn: t.turn,
            model: t.model,
            question: t.question,
            response: t.response,
            logprobs: t.logprobs,
            usage: t.usage
          }
        end)
    })
  end

  defp record_failure(ctx, item, turn, reason) do
    key = work_item_label(item)

    Runtime.result(ctx, key, %{
      status: "failed",
      pair_index: item.pair_index,
      model_a: item.model_a,
      model_b: item.model_b,
      switch_turn: item.switch_turn,
      run_number: item.run_number,
      failed_on_turn: turn,
      error: inspect(reason)
    })
  end

  defp work_item_label(item) do
    "pair_#{item.pair_index}/switch_#{item.switch_turn}/run_#{item.run_number}"
  end

  defp build_queue(model_pairs, runs_per_pair) do
    model_pairs
    |> Enum.with_index()
    |> Enum.flat_map(fn {pair, pair_index} ->
      for switch_turn <- @switch_turns,
          run <- 1..runs_per_pair do
        %{
          pair_index: pair_index,
          model_a: pair["model_a"],
          model_b: pair["model_b"],
          switch_turn: switch_turn,
          run_number: run
        }
      end
    end)
    |> Enum.shuffle()
  end
end
