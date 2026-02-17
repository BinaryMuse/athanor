defmodule AthanorWeb.Experiments.Components.LogPanel do
  @moduledoc """
  Log panel component for displaying bounded experiment run logs.
  Renders without card wrapper — intended for use inside a tab panel.
  """

  use Phoenix.Component

  attr :streams, :map, required: true
  attr :auto_scroll, :boolean, required: true
  attr :log_count, :integer, required: true

  def log_panel(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-3">
      <label class="label cursor-pointer gap-2">
        <span class="label-text text-sm">Auto-scroll</span>
        <input
          type="checkbox"
          class="toggle toggle-sm"
          checked={@auto_scroll}
          phx-click="toggle_auto_scroll"
        />
      </label>
    </div>

    <div
      id="logs-container"
      class="bg-base-300 rounded-box p-3 h-[calc(100vh-220px)] overflow-y-auto font-mono text-xs"
      phx-hook="AutoScroll"
      data-auto-scroll={to_string(@auto_scroll)}
    >
      <div :if={@log_count == 0} class="text-base-content/40 text-center py-8">
        No logs yet
      </div>
      <div id="logs" phx-update="stream" class="space-y-1">
        <div :for={{dom_id, log} <- @streams.logs} id={dom_id} class={log_row_class(log.level)}>
          <span class="text-base-content/40">{format_timestamp(log.timestamp)}</span>
          <span class={level_badge(log.level)}>{String.upcase(log.level)}</span>
          <span class="text-base-content">{log.message}</span>
          <span :if={log.metadata} class="text-base-content/40">{inspect(log.metadata)}</span>
        </div>
      </div>
    </div>
    """
  end

  defp log_row_class("error"), do: "text-error"
  defp log_row_class("warn"), do: "text-warning"
  defp log_row_class(_), do: ""

  defp level_badge("error"), do: "badge badge-error badge-xs mx-1"
  defp level_badge("warn"), do: "badge badge-warning badge-xs mx-1"
  defp level_badge("info"), do: "badge badge-info badge-xs mx-1"
  defp level_badge("debug"), do: "badge badge-ghost badge-xs mx-1"
  defp level_badge(_), do: "badge badge-ghost badge-xs mx-1"

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S.%f") |> String.slice(0, 12)
  end
end
