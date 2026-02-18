defmodule SubstrateShift.Client do
  @moduledoc """
  Thin wrapper around the OpenRouter chat completions API.
  Always requests logprobs.
  """

  @openrouter_url "https://openrouter.ai/api/v1/chat/completions"
  @top_logprobs 10

  defstruct [:model]

  @type message :: %{role: String.t(), content: String.t()}

  @type logprob_token :: %{
          token: String.t(),
          logprob: float(),
          top_logprobs: [%{token: String.t(), logprob: float()}]
        }

  @type chat_result :: %{
          content: String.t(),
          logprobs: [logprob_token()],
          usage: map()
        }

  @spec new(String.t()) :: %__MODULE__{}
  def new(model) do
    %__MODULE__{model: model}
  end

  @doc """
  Send a chat completion request with the given message history.
  Returns `{:ok, result}` with content, logprobs, and usage, or `{:error, reason}`.
  """
  @spec chat(%__MODULE__{}, [message()]) :: {:ok, chat_result()} | {:error, term()}
  def chat(%__MODULE__{model: model}, messages) when is_list(messages) do
    headers = [
      {"content-type", "application/json"},
      {"authorization", "Bearer #{api_key()}"}
    ]

    body = %{
      model: model,
      messages: messages,
      logprobs: true,
      top_logprobs: @top_logprobs
    }

    case Req.post(@openrouter_url, headers: headers, json: body) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, parse_response(body)}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_response(body) do
    choice = get_in(body, ["choices", Access.at(0)])

    %{
      content: get_in(choice, ["message", "content"]),
      logprobs: get_in(choice, ["logprobs", "content"]) || [],
      usage: body["usage"] || %{}
    }
  end

  defp api_key do
    System.get_env("OPENROUTER_API_KEY") ||
      raise "OPENROUTER_API_KEY environment variable is not set"
  end
end
