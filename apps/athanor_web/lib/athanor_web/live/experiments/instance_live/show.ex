defmodule AthanorWeb.Experiments.InstanceLive.Show do
  use AthanorWeb, :live_view

  alias Athanor.Experiments
  alias Athanor.Runtime
  alias AthanorWeb.Experiments.Components.StatusBadge

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    instance = Experiments.get_instance!(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Athanor.PubSub, "experiments:instance:#{id}")
      Phoenix.PubSub.subscribe(Athanor.PubSub, "experiments:runs:active")
    end

    runs = Experiments.list_runs(instance)

    socket =
      socket
      |> assign(:instance, instance)
      |> assign(:run_count, length(runs))
      |> assign(:active_tab, :runs)
      |> stream(:runs, runs)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"tab" => tab}, _uri, socket) when tab in ["runs", "configuration"] do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :active_tab, :runs)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Breadcrumb --%>
    <div class="text-sm text-base-content/60 mb-4 flex items-center gap-2">
      <.link navigate={~p"/experiments"} class="hover:text-base-content">Experiments</.link>
      <span>/</span>
      <span class="text-base-content">{@instance.name}</span>
    </div>

    <%!-- Header with actions --%>
    <div class="flex items-start justify-between gap-4 mb-6">
      <div>
        <h1 class="text-2xl font-semibold">{@instance.name}</h1>
        <p class="text-base-content/60 mt-1">{module_name(@instance.experiment_module)}</p>
      </div>

      <div class="flex items-center gap-2">
        <.button phx-click="start_run" class="btn-primary">
          <.icon name="hero-play" class="size-4 mr-1" /> Start Run
        </.button>

        <div class="dropdown dropdown-end">
          <div tabindex="0" role="button" class="btn btn-ghost btn-sm">
            <.icon name="hero-ellipsis-vertical" class="size-5" />
          </div>
          <ul tabindex="0" class="dropdown-content menu bg-base-200 rounded-box z-10 w-48 p-2 shadow-lg border border-base-300">
            <li>
              <.link navigate={~p"/experiments/#{@instance.id}/edit"}>
                Edit Configuration
              </.link>
            </li>
            <li>
              <button phx-click="delete_instance" data-confirm="Delete this experiment and all its runs?">
                <span class="text-error">Delete</span>
              </button>
            </li>
          </ul>
        </div>
      </div>
    </div>

    <%!-- Description (if exists) --%>
    <p :if={@instance.description} class="text-base-content/80 mb-6">{@instance.description}</p>

    <%!-- Tabs --%>
    <div role="tablist" class="tabs tabs-bordered border-b border-base-300 mb-6">
      <.link
        patch={~p"/experiments/#{@instance.id}?tab=runs"}
        role="tab"
        class={["tab", @active_tab == :runs && "tab-active"]}
      >
        Runs ({@run_count})
      </.link>
      <.link
        patch={~p"/experiments/#{@instance.id}?tab=configuration"}
        role="tab"
        class={["tab", @active_tab == :configuration && "tab-active"]}
      >
        Configuration
      </.link>
    </div>

    <%!-- Runs tab panel --%>
    <div class={[@active_tab != :runs && "hidden"]}>
      <div :if={@run_count == 0} class="text-center py-8 text-base-content/60">
        No runs yet. Click "Start Run" to begin.
      </div>

      <div id="runs" phx-update="stream" class="space-y-3">
        <.link
          :for={{dom_id, run} <- @streams.runs}
          id={dom_id}
          navigate={~p"/runs/#{run.id}"}
          class="flex items-center justify-between p-4 bg-base-200 rounded-lg hover:bg-base-300 transition-colors"
        >
          <div class="flex items-center gap-4">
            <StatusBadge.status_badge status={run.status} />
            <div>
              <span class="font-medium">Run {short_id(run.id)}</span>
              <p class="text-sm text-base-content/60">{format_time(run.inserted_at)}</p>
            </div>
          </div>
          <div class="flex items-center gap-4 text-sm text-base-content/60">
            <span :if={run.completed_at}>{format_duration(run.started_at, run.completed_at)}</span>
            <.icon name="hero-chevron-right-micro" class="size-4" />
          </div>
        </.link>
      </div>
    </div>

    <%!-- Configuration tab panel --%>
    <div class={[@active_tab != :configuration && "hidden"]}>
      <div class="card bg-base-200">
        <div class="card-body">
          <.render_config config={@instance.configuration} />
          <div :if={@instance.configuration == %{} or is_nil(@instance.configuration)}
               class="text-base-content/60 italic">
            No configuration set
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_config(assigns) do
    ~H"""
    <div class="space-y-3">
      <%= for {key, value} <- @config || %{} do %>
        <div class="flex items-start gap-4 py-2 border-b border-base-300 last:border-0">
          <span class="text-sm text-base-content/60 w-1/3 font-medium">{humanize(key)}</span>
          <span class="text-sm font-mono text-base-content flex-1">{format_value(value)}</span>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_value(value) when is_list(value), do: "#{length(value)} items"
  defp format_value(value) when is_map(value), do: inspect(value)
  defp format_value(value), do: to_string(value)

  defp module_name(module_string) do
    module_string
    |> String.replace("Elixir.", "")
  end

  defp short_id(id) do
    id |> String.slice(0, 8)
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %H:%M")
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

  defp humanize(key) when is_atom(key), do: humanize(to_string(key))

  defp humanize(key) when is_binary(key) do
    key
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  @impl true
  def handle_event("start_run", _params, socket) do
    case Runtime.start_run(socket.assigns.instance) do
      {:ok, run} ->
        socket =
          socket
          |> update(:run_count, &(&1 + 1))
          |> stream_insert(:runs, run, at: 0)
          |> put_flash(:info, "Run started")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("delete_instance", _params, socket) do
    {:ok, _} = Experiments.delete_instance(socket.assigns.instance)
    Athanor.Experiments.Broadcasts.instance_deleted(socket.assigns.instance)

    {:noreply,
     socket
     |> put_flash(:info, "Experiment deleted")
     |> push_navigate(to: ~p"/experiments")}
  end

  @impl true
  def handle_info({:run_created, run}, socket) do
    socket =
      socket
      |> update(:run_count, &(&1 + 1))
      |> stream_insert(:runs, run, at: 0)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:run_started, _run}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:run_updated, run}, socket) do
    {:noreply, stream_insert(socket, :runs, run)}
  end

  @impl true
  def handle_info({:instance_updated, instance}, socket) do
    {:noreply, assign(socket, :instance, instance)}
  end

  @impl true
  def handle_info({:run_completed, run}, socket) do
    msg =
      case run.status do
        "completed" -> "Run completed successfully"
        "failed" -> "Run failed"
        "cancelled" -> "Run cancelled"
        _ -> nil
      end

    socket = if msg, do: put_flash(socket, :info, msg), else: socket
    {:noreply, socket}
  end
end
