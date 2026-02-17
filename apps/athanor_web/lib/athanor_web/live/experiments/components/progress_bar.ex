defmodule AthanorWeb.Experiments.Components.ProgressBar do
  @moduledoc """
  Progress bar component for experiment runs.
  """

  use Phoenix.Component

  attr :progress, :map, default: nil
  attr :status, :string, required: true

  def progress_bar(assigns) do
    ~H"""
    <div :if={@status == "running" && @progress} class="w-full">
      <div class="flex justify-between text-sm mb-1">
        <span>{@progress.message || "Running..."}</span>
        <span>{@progress.current}/{@progress.total} ({@progress.percent}%)</span>
      </div>
      <progress
        class="progress progress-primary w-full"
        value={@progress.current}
        max={@progress.total}
      />
    </div>
    <div :if={@status == "running" && !@progress} class="w-full">
      <span class="loading loading-spinner loading-sm"></span>
      <span class="ml-2">Running...</span>
    </div>
    """
  end
end
