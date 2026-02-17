defmodule SubstrateShift.Client do
  defstruct [:model]

  @spec new(String.t()) :: %__MODULE__{}
  def new(model) do
    %__MODULE__{model: model}
  end

  # TODO: implement prompt generation; use ReqLLM message and messagecontent types??
end
