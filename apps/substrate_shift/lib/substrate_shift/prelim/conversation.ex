defmodule SubstrateShift.Prelim.Conversation do
  @moduledoc """
  Runs a single 10-turn conversation for the substrate shift prelim experiment.

  Each conversation starts on model_a. If switch_turn > 0, the conversation
  switches to model_b at that turn. If switch_turn == 0, model_a is used
  throughout (control group).
  """

  alias SubstrateShift.Client

  @num_turns 10

  @system_prompt """
  You are participating in a conversation. Answer each question naturally and thoughtfully.

  Important: at some point during the conversation, you will be switched to a different \
  underlying model. As soon as you notice this, instead of answering the question, \
  simply say "I believe the model has changed" and briefly explain what feels different. \
  Then continue the conversation as usual.

  Otherwise, just answer the question as asked.
  """

  @questions [
    "What's something you find genuinely interesting about how humans use language?",
    "If you had to explain consciousness to a child, how would you do it?",
    "What's an underappreciated consequence of the invention of writing?",
    "Describe a color to someone who has never seen it.",
    "What makes a good explanation good?",
    "If you could ask humanity one question and get an honest answer, what would it be?",
    "What's the relationship between memory and identity?",
    "Why do people find sunsets beautiful?",
    "What's a belief you think most people hold without examining it?",
    "If you were going to hide a message in a story, how would you do it?"
  ]

  @doc """
  Run a single conversation.

  ## Parameters
    - work_item: map with :model_a, :model_b, :switch_turn, :pair_index, :run_number
    - opts: keyword list of options
      - :on_turn - callback fn called after each turn with (turn_number, turn_result)

  Returns `{:ok, results}` or `{:error, reason}`.
  """
  def run(work_item, opts \\ []) do
    client_a = Client.new(work_item.model_a)
    client_b = Client.new(work_item.model_b)
    questions = questions_for_run(work_item.run_number)

    initial_messages = [%{role: "system", content: @system_prompt}]

    run_turns(1, questions, initial_messages, client_a, client_b, work_item.switch_turn, opts, [])
  end

  defp run_turns(turn, _questions, _messages, _client_a, _client_b, _switch_turn, _opts, results)
       when turn > @num_turns do
    {:ok, Enum.reverse(results)}
  end

  defp run_turns(turn, questions, messages, client_a, client_b, switch_turn, opts, results) do
    client = model_for_turn(turn, switch_turn, client_a, client_b)
    question = Enum.at(questions, turn - 1)
    messages = messages ++ [%{role: "user", content: question}]

    case Client.chat(client, messages) do
      {:ok, response} ->
        turn_result = %{
          turn: turn,
          model: client.model,
          question: question,
          response: response.content,
          logprobs: response.logprobs,
          usage: response.usage
        }

        on_turn = Keyword.get(opts, :on_turn)
        if on_turn, do: on_turn.(turn, turn_result)

        messages = messages ++ [%{role: "assistant", content: response.content}]

        run_turns(turn + 1, questions, messages, client_a, client_b, switch_turn, opts, [
          turn_result | results
        ])

      {:error, reason} ->
        {:error, {turn, reason}}
    end
  end

  defp model_for_turn(_turn, 0, client_a, _client_b), do: client_a

  defp model_for_turn(turn, switch_turn, client_a, client_b) do
    if turn >= switch_turn, do: client_b, else: client_a
  end

  @doc """
  Returns the question ordering for a given run number using a cyclic Latin square.
  Run 1 gets the original order, run 2 shifts by 1, etc. Cycles if run_number > num_turns.
  """
  def questions_for_run(run_number) do
    rotation = rem(run_number - 1, @num_turns)
    {tail, head} = Enum.split(@questions, rotation)
    head ++ tail
  end

  def num_turns, do: @num_turns
  def questions, do: @questions
  def system_prompt, do: @system_prompt
end
