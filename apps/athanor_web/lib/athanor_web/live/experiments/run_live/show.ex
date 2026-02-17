defmodule AthanorWeb.Experiments.RunLive.Show do
  use AthanorWeb, :live_view

  alias Athanor.Experiments
  alias Athanor.Runtime
  alias AthanorWeb.Experiments.Components.{StatusBadge, ProgressBar, LogPanel, ResultsPanel}

  @log_stream_limit 1_000

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Subscribe first, then fetch to avoid race with completion broadcast
    run =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Athanor.PubSub, "experiments:run:#{id}")
        Experiments.get_run!(id) |> Athanor.Repo.preload(:instance)
      else
        Experiments.get_run!(id) |> Athanor.Repo.preload(:instance)
      end

    # Start elapsed time ticker if running and connected
    if connected?(socket) && run.status == "running" do
      Process.send_after(self(), :tick, 1_000)
    end

    elapsed = if run.status == "running", do: elapsed_since(run.started_at), else: 0

    logs = Experiments.list_logs(run, limit: @log_stream_limit)
    results = Experiments.list_results(run)
    hydrated_results = Enum.map(results, &Map.put(&1, :hydrated, false))

    socket =
      socket
      |> assign(:run, run)
      |> assign(:instance, run.instance)
      |> assign(:progress, nil)
      |> assign(:active_tab, :logs)
      |> assign(:auto_scroll, true)
      |> assign(:log_count, length(logs))
      |> assign(:result_count, length(results))
      |> assign(:elapsed_seconds, elapsed)
      |> assign(:reconnecting, false)
      |> assign(:reconnect_attempts, 0)
      |> assign(:needs_refresh, false)
      |> stream(:logs, logs, limit: -@log_stream_limit)
      |> stream(:results, hydrated_results)

    {:ok, socket, layout: {AthanorWeb.Layouts, :run}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col min-h-screen" id="run-page" phx-hook="ReconnectionTracker">

      <%!-- Sticky header --%>
      <header class="sticky top-0 z-10 bg-base-100 border-b border-base-300 shadow-sm">
        <div class="px-4 sm:px-6 lg:px-8 py-3">

          <%!-- Breadcrumb row --%>
          <div class="flex items-center gap-2 text-sm text-base-content/60 mb-2">
            <.link navigate={~p"/experiments"} class="hover:text-base-content">Experiments</.link>
            <span>/</span>
            <.link navigate={~p"/experiments/#{@instance.id}"} class="hover:text-base-content">
              {@instance.name}
            </.link>
            <span>/</span>
            <span class="text-base-content">Run {short_id(@run.id)}</span>
          </div>

          <%!-- Status row --%>
          <div class="flex items-center gap-4 flex-wrap">
            <StatusBadge.status_badge status={@run.status} />

            <span class="font-medium">{@instance.name}</span>

            <span :if={format_elapsed(@run, @elapsed_seconds) != ""} class="text-sm text-base-content/60">
              {format_elapsed(@run, @elapsed_seconds)}
            </span>

            <%!-- Progress indicator --%>
            <div :if={@run.status == "running"} class="flex items-center gap-2">
              <ProgressBar.progress_bar status={@run.status} progress={@progress} />
            </div>

            <%!-- Reconnection indicator --%>
            <span :if={@reconnecting} class="text-sm text-warning ml-2">
              Reconnecting (attempt {@reconnect_attempts})...
            </span>

            <%!-- Spacer + actions --%>
            <div class="ml-auto flex items-center gap-2">
              <button
                :if={@needs_refresh}
                phx-click="refresh_data"
                class="btn btn-sm btn-ghost"
              >
                Refresh
              </button>
              <button
                :if={@run.status == "running"}
                phx-click="cancel_run"
                class="btn btn-sm btn-warning"
                data-confirm="Cancel this run?"
              >
                <.icon name="hero-stop" class="size-4 mr-1" /> Cancel
              </button>
            </div>
          </div>

          <%!-- Error display --%>
          <div :if={@run.error} class="mt-2 text-sm text-error flex items-center gap-1">
            <.icon name="hero-exclamation-circle" class="size-4" />
            {@run.error}
          </div>
        </div>
      </header>

      <%!-- Tab bar + content --%>
      <div class="flex-1 flex flex-col overflow-hidden px-4 sm:px-6 lg:px-8">

        <%!-- Tab bar with daisyUI tabs --%>
        <div role="tablist" class="tabs tabs-border border-b border-base-300 mt-4">
          <button
            role="tab"
            class={["tab", @active_tab == :logs && "tab-active"]}
            phx-click="switch_tab"
            phx-value-tab="logs"
          >
            Logs ({@log_count})
          </button>
          <button
            role="tab"
            class={["tab", @active_tab == :results && "tab-active"]}
            phx-click="switch_tab"
            phx-value-tab="results"
          >
            Results ({@result_count})
          </button>
        </div>

        <%!-- Tab panels: use hidden class for inactive --%>
        <div class={["flex-1 overflow-y-auto py-4", @active_tab != :logs && "hidden"]}>
          <LogPanel.log_panel streams={@streams} auto_scroll={@auto_scroll} log_count={@log_count} />
        </div>
        <div class={["flex-1 overflow-y-auto py-4", @active_tab != :results && "hidden"]}>
          <ResultsPanel.results_panel streams={@streams} result_count={@result_count} />
        </div>
      </div>
    </div>
    """
  end

  # --- Elapsed time ticker ---

  @impl true
  def handle_info(:tick, socket) do
    if socket.assigns.run.status == "running" do
      Process.send_after(self(), :tick, 1_000)
      {:noreply, assign(socket, :elapsed_seconds, elapsed_since(socket.assigns.run.started_at))}
    else
      # Stop ticking when run has ended
      {:noreply, socket}
    end
  end

  # --- Run events ---

  @impl true
  def handle_info({:run_updated, run}, socket) do
    socket = assign(socket, :run, run)

    # Freeze elapsed time when run transitions to terminal state
    socket =
      if run.status != "running" do
        assign(socket, :elapsed_seconds, final_elapsed(run))
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:log_added, log}, socket) do
    socket =
      socket
      |> update(:log_count, &(&1 + 1))
      |> stream_insert(:logs, log, limit: -@log_stream_limit)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:logs_added, logs}, socket) when is_list(logs) do
    # Stream insert the new logs directly - no DB round-trip
    socket =
      Enum.reduce(logs, socket, fn log, acc ->
        acc
        |> update(:log_count, &(&1 + 1))
        |> stream_insert(:logs, log, limit: -@log_stream_limit)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:result_added, result}, socket) do
    result = Map.put(result, :hydrated, false)

    socket =
      socket
      |> update(:result_count, &(&1 + 1))
      |> stream_insert(:results, result)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:results_added, results}, socket) when is_list(results) do
    # Stream insert the new results directly - no DB round-trip
    socket =
      Enum.reduce(results, socket, fn result, acc ->
        result = Map.put(result, :hydrated, false)

        acc
        |> update(:result_count, &(&1 + 1))
        |> stream_insert(:results, result)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:progress_updated, progress}, socket) do
    {:noreply, assign(socket, :progress, progress)}
  end

  # --- User events ---

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

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
  def handle_event("disable_auto_scroll", _params, socket) do
    # User scrolled away from bottom — disable auto-scroll to respect their intent
    {:noreply, assign(socket, :auto_scroll, false)}
  end

  @impl true
  def handle_event("hydrate_result", %{"id" => id}, socket) do
    result = Experiments.get_result!(id)
    result = Map.put(result, :hydrated, true)
    {:noreply, stream_insert(socket, :results, result)}
  end

  @impl true
  def handle_event("reconnecting", %{"attempt" => n}, socket) do
    {:noreply, assign(socket, reconnecting: true, reconnect_attempts: n)}
  end

  @impl true
  def handle_event("reconnected", _params, socket) do
    {:noreply, assign(socket, reconnecting: false, needs_refresh: true)}
  end

  @impl true
  def handle_event("refresh_data", _params, socket) do
    run = socket.assigns.run
    logs = Experiments.list_logs(run, limit: @log_stream_limit)
    results = Experiments.list_results(run)
    hydrated_results = Enum.map(results, &Map.put(&1, :hydrated, false))

    socket =
      socket
      |> assign(:log_count, length(logs))
      |> assign(:result_count, length(results))
      |> assign(:needs_refresh, false)
      |> stream(:logs, logs, reset: true, limit: -@log_stream_limit)
      |> stream(:results, hydrated_results, reset: true)

    {:noreply, socket}
  end

  # --- Helpers ---

  defp short_id(id) do
    id |> String.slice(0, 8)
  end

  defp elapsed_since(nil), do: 0

  defp elapsed_since(started_at) do
    DateTime.diff(DateTime.utc_now(), started_at, :second)
  end

  defp final_elapsed(%{completed_at: completed_at, started_at: started_at})
       when not is_nil(completed_at) and not is_nil(started_at) do
    DateTime.diff(completed_at, started_at, :second)
  end

  defp final_elapsed(_), do: 0

  defp format_elapsed(%{completed_at: completed_at, started_at: started_at}, _)
       when not is_nil(completed_at) and not is_nil(started_at) do
    format_duration(started_at, completed_at)
  end

  defp format_elapsed(%{status: "running", started_at: started_at}, elapsed_seconds)
       when not is_nil(started_at) do
    format_seconds(elapsed_seconds)
  end

  defp format_elapsed(_, _), do: ""

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

  defp format_seconds(s) when s < 60, do: "#{s}s"

  defp format_seconds(s) do
    m = div(s, 60)
    sec = rem(s, 60)
    "#{m}m #{sec}s"
  end
end
