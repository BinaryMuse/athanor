defmodule AthanorWeb.Experiments.RunLive.Show do
  use AthanorWeb, :live_view

  alias Athanor.Experiments
  alias Athanor.Runtime
  alias AthanorWeb.Experiments.Components.{StatusBadge, ProgressBar}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    run = Experiments.get_run!(id) |> Athanor.Repo.preload(:instance)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Athanor.PubSub, "experiments:run:#{id}")
    end

    logs = Experiments.list_logs(run)
    results = Experiments.list_results(run)

    socket =
      socket
      |> assign(:run, run)
      |> assign(:instance, run.instance)
      |> assign(:progress, nil)
      |> assign(:auto_scroll, true)
      |> assign(:log_count, length(logs))
      |> assign(:result_count, length(results))
      |> stream(:logs, logs)
      |> stream(:results, results)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Run {short_id(@run.id)}
      <:subtitle>
        <.link navigate={~p"/experiments/#{@instance.id}"} class="link link-hover">
          {@instance.name}
        </.link>
      </:subtitle>
      <:actions>
        <.button
          :if={@run.status == "running"}
          phx-click="cancel_run"
          class="btn-warning"
          data-confirm="Are you sure you want to cancel this run?"
        >
          <.icon name="hero-stop" class="size-4 mr-1" />
          Cancel
        </.button>
        <.link navigate={~p"/experiments/#{@instance.id}"} class="btn btn-ghost">
          Back to Instance
        </.link>
      </:actions>
    </.header>

    <div class="mt-6 flex items-center gap-4">
      <StatusBadge.status_badge status={@run.status} />
      <span :if={@run.started_at} class="text-sm text-base-content/60">
        Started {format_time(@run.started_at)}
      </span>
      <span :if={@run.completed_at} class="text-sm text-base-content/60">
        · Completed in {format_duration(@run.started_at, @run.completed_at)}
      </span>
    </div>

    <div :if={@run.status == "running"} class="mt-4">
      <ProgressBar.progress_bar status={@run.status} progress={@progress} />
    </div>

    <div :if={@run.error} class="alert alert-error mt-4">
      <.icon name="hero-exclamation-circle" class="size-5" />
      <span>{@run.error}</span>
    </div>

    <div class="mt-8 grid grid-cols-1 lg:grid-cols-2 gap-8">
      <div class="card bg-base-200">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h3 class="card-title text-lg">Logs</h3>
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
            class="bg-base-300 rounded-lg p-4 h-96 overflow-y-auto font-mono text-sm"
            phx-hook="AutoScroll"
            data-auto-scroll={to_string(@auto_scroll)}
          >
            <div :if={@log_count == 0} class="text-base-content/50 text-center py-8">
              No logs yet
            </div>
            <div id="logs" phx-update="stream" class="space-y-1">
              <div :for={{dom_id, log} <- @streams.logs} id={dom_id} class={log_class(log.level)}>
                <span class="text-base-content/50">
                  {format_timestamp(log.timestamp)}
                </span>
                <span class={level_badge(log.level)}>{String.upcase(log.level)}</span>
                <span>{log.message}</span>
                <span :if={log.metadata} class="text-base-content/50">
                  {inspect(log.metadata)}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="card bg-base-200">
        <div class="card-body">
          <h3 class="card-title text-lg">Results</h3>

          <div :if={@result_count == 0} class="text-base-content/50 text-center py-8">
            No results yet
          </div>

          <div id="results" phx-update="stream" class="space-y-3 max-h-96 overflow-y-auto">
            <div
              :for={{dom_id, result} <- @streams.results}
              id={dom_id}
              class="p-3 bg-base-300 rounded-lg"
            >
              <div class="font-medium text-sm">{result.key}</div>
              <div class="mt-1 font-mono text-xs text-base-content/70 overflow-x-auto">
                <pre>{Jason.encode!(result.value, pretty: true)}</pre>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp short_id(id) do
    id |> String.slice(0, 8)
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %H:%M:%S")
  end

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S.%f") |> String.slice(0, 12)
  end

  defp format_duration(nil, _), do: ""
  defp format_duration(_, nil), do: ""

  defp format_duration(started_at, completed_at) do
    diff = DateTime.diff(completed_at, started_at, :millisecond)

    cond do
      diff < 1000 -> "#{diff}ms"
      diff < 60_000 -> "#{Float.round(diff / 1000, 1)}s"
      true -> "#{div(diff, 60_000)}m #{rem(div(diff, 1000), 60)}s"
    end
  end

  defp log_class("error"), do: "text-error"
  defp log_class("warn"), do: "text-warning"
  defp log_class(_), do: ""

  defp level_badge("error"), do: "badge badge-error badge-xs mx-1"
  defp level_badge("warn"), do: "badge badge-warning badge-xs mx-1"
  defp level_badge("info"), do: "badge badge-info badge-xs mx-1"
  defp level_badge("debug"), do: "badge badge-ghost badge-xs mx-1"
  defp level_badge(_), do: "badge badge-ghost badge-xs mx-1"

  @impl true
  def handle_event("cancel_run", _params, socket) do
    case Runtime.cancel_run(socket.assigns.run) do
      {:ok, _run} ->
        {:noreply, put_flash(socket, :info, "Run cancelled")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Cannot cancel: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("toggle_auto_scroll", _params, socket) do
    {:noreply, assign(socket, :auto_scroll, !socket.assigns.auto_scroll)}
  end

  @impl true
  def handle_info({:run_updated, run}, socket) do
    {:noreply, assign(socket, :run, run)}
  end

  @impl true
  def handle_info({:log_added, log}, socket) do
    socket =
      socket
      |> update(:log_count, &(&1 + 1))
      |> stream_insert(:logs, log)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:logs_added, _count}, socket) do
    # Refresh logs when batch added
    logs = Experiments.list_logs(socket.assigns.run)

    socket =
      socket
      |> assign(:log_count, length(logs))
      |> stream(:logs, logs, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:result_added, result}, socket) do
    socket =
      socket
      |> update(:result_count, &(&1 + 1))
      |> stream_insert(:results, result)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:progress_updated, progress}, socket) do
    {:noreply, assign(socket, :progress, progress)}
  end
end
