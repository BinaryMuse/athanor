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

    logs = Experiments.list_logs(run, limit: @log_stream_limit)
    results = Experiments.list_results(run)
    hydrated_results = Enum.map(results, &Map.put(&1, :hydrated, false))

    socket =
      socket
      |> assign(:run, run)
      |> assign(:instance, run.instance)
      |> assign(:progress, nil)
      |> assign(:auto_scroll, true)
      |> assign(:log_count, length(logs))
      |> assign(:result_count, length(results))
      |> stream(:logs, logs, limit: -@log_stream_limit)
      |> stream(:results, hydrated_results)

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
      <LogPanel.log_panel streams={@streams} auto_scroll={@auto_scroll} log_count={@log_count} />

      <ResultsPanel.results_panel streams={@streams} result_count={@result_count} />
    </div>
    """
  end

  defp short_id(id) do
    id |> String.slice(0, 8)
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %H:%M:%S")
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
  def handle_info({:run_updated, run}, socket) do
    {:noreply, assign(socket, :run, run)}
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
end
