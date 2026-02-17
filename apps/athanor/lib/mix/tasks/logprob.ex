defmodule Mix.Tasks.Logprob do
  @moduledoc "Make a request with logprobs"
  use Mix.Task

  @shortdoc "Make a request with logprobs"
  def run(_) do
    Mix.Task.run("app.start")

    url = "https://openrouter.ai/api/v1/chat/completions"

    headers = [
      "Content-Type": "application/json",
      Authorization: "Bearer #{System.get_env("OPENROUTER_API_KEY")}"
    ]

    prompt =
      "generate an abstract dream. don't think too much, just let your mind wander and let associations form as they will. embrace gaps, non-sequiturs, and the unexpected. just write the dream as it comes to you with as little fitlering as possible."

    # prompt =
    #   "generate an original story"

    # Non-streaming request so we get the full logprobs structure at once
    resp =
      Req.post!(url,
        headers: headers,
        json: %{
          model: "openai/gpt-3.5-turbo",
          messages: [
            %{
              role: "user",
              content: prompt
            }
          ],
          logprobs: true,
          top_logprobs: 10
        }
      )

    body = resp.body

    IO.puts("\n=== Prompt ===")
    IO.puts(prompt)

    # Extract the message content
    message = get_in(body, ["choices", Access.at(0), "message", "content"])
    IO.puts("\n=== Response ===")
    IO.puts(message)

    # Extract logprobs for each token
    token_logprobs = get_in(body, ["choices", Access.at(0), "logprobs", "content"]) || []

    IO.puts("\n=== Token Logprobs ===")

    IO.puts(
      String.pad_trailing("Token", 20) <> String.pad_trailing("Logprob", 12) <> "Probability"
    )

    IO.puts(String.duplicate("-", 50))

    token_logprobs
    |> Enum.each(fn token_info ->
      token = token_info["token"]
      logprob = token_info["logprob"]
      logprob = if logprob == 0, do: 0.0, else: logprob
      logprob = if logprob == -9999, do: -9999.0, else: logprob
      # Linear probability = e^logprob
      probability = :math.exp(logprob)

      IO.puts(
        String.pad_trailing(inspect(token), 20) <>
          String.pad_trailing(:erlang.float_to_binary(logprob, decimals: 4), 12) <>
          :erlang.float_to_binary(probability * 100, decimals: 2) <> "%"
      )

      # Show top alternative tokens
      top_logprobs = token_info["top_logprobs"] || []

      top_logprobs
      |> Enum.take(5)
      |> Enum.each(fn alt ->
        alt_prob = :math.exp(alt["logprob"]) * 100

        IO.puts(
          "  alt: " <>
            String.pad_trailing(inspect(alt["token"]), 15) <>
            :erlang.float_to_binary(alt_prob, decimals: 2) <> "%"
        )
      end)
    end)

    # Summary statistics
    logprobs_list = Enum.map(token_logprobs, & &1["logprob"])

    if length(logprobs_list) > 0 do
      avg_logprob = Enum.sum(logprobs_list) / length(logprobs_list)
      # Perplexity = e^(-average_logprob)
      perplexity = :math.exp(-avg_logprob)

      IO.puts("\n=== Summary ===")
      IO.puts("Tokens: #{length(logprobs_list)}")
      IO.puts("Avg logprob: #{:erlang.float_to_binary(avg_logprob, decimals: 4)}")

      IO.puts(
        "Avg probability: #{:erlang.float_to_binary(:math.exp(avg_logprob) * 100, decimals: 2)}%"
      )

      IO.puts("Perplexity: #{:erlang.float_to_binary(perplexity, decimals: 2)}")
    end
  end
end
