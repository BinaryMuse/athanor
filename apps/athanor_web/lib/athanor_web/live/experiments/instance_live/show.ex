defmodule AthanorWeb.Experiments.InstanceLive.Show do
  use AthanorWeb, :live_view

  alias Athanor.Experiments
  alias Athanor.Experiments.Discovery
  alias Athanor.Runtime
  alias AthanorWeb.Experiments.Components.StatusBadge

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    instance = Experiments.get_instance!(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Athanor.PubSub, "experiments:instance:#{id}")
    end

    runs = Experiments.list_runs(instance)
    experiment_def = get_experiment_definition(instance)

    socket =
      socket
      |> assign(:instance, instance)
      |> assign(:experiment_def, experiment_def)
      |> assign(:run_count, length(runs))
      |> stream(:runs, runs)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      {instance_title(@instance, @experiment_def)}
      <:subtitle>
        {module_name(@instance.experiment_module)}
      </:subtitle>
      <:actions>
        <.button phx-click="start_run" class="btn-primary">
          <.icon name="hero-play" class="size-4 mr-1" />
          Start Run
        </.button>
        <.link navigate={~p"/experiments"} class="btn btn-ghost">
          Back
        </.link>
      </:actions>
    </.header>

    <div class="mt-8 grid grid-cols-1 lg:grid-cols-3 gap-8">
      <div class="lg:col-span-2 space-y-6">
        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-lg">Runs</h3>

            <div :if={@run_count == 0} class="text-center py-8 text-base-content/60">
              No runs yet. Click "Start Run" to begin.
            </div>

            <div id="runs" phx-update="stream" class="space-y-3">
              <div
                :for={{dom_id, run} <- @streams.runs}
                id={dom_id}
                class="flex items-center justify-between p-3 bg-base-100 rounded-lg"
              >
                <div class="flex items-center gap-4">
                  <StatusBadge.status_badge status={run.status} />
                  <div>
                    <.link navigate={~p"/runs/#{run.id}"} class="font-medium link link-hover">
                      Run {short_id(run.id)}
                    </.link>
                    <p class="text-sm text-base-content/60">
                      {format_time(run.inserted_at)}
                    </p>
                  </div>
                </div>
                <div class="flex items-center gap-2">
                  <span :if={run.completed_at} class="text-sm text-base-content/60">
                    {format_duration(run.started_at, run.completed_at)}
                  </span>
                  <.link navigate={~p"/runs/#{run.id}"} class="btn btn-sm btn-ghost">
                    View
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="space-y-6">
        <div :if={@instance.description} class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-lg">Description</h3>
            <p>{@instance.description}</p>
          </div>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-lg">Configuration</h3>
            <div class="space-y-2">
              <.render_config config={@instance.configuration} />
            </div>
          </div>
        </div>

        <div :if={@experiment_def} class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-lg">About</h3>
            <p class="text-sm text-base-content/70">
              {@experiment_def.description}
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_config(assigns) do
    ~H"""
    <%= for {key, value} <- @config || %{} do %>
      <div class="flex justify-between text-sm">
        <span class="text-base-content/70">{humanize(key)}</span>
        <span class="font-mono">{format_value(value)}</span>
      </div>
    <% end %>
    """
  end

  defp format_value(value) when is_list(value), do: "#{length(value)} items"
  defp format_value(value) when is_map(value), do: inspect(value)
  defp format_value(value), do: to_string(value)

  defp instance_title(instance, nil), do: instance.name
  defp instance_title(instance, _def), do: instance.name

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

  defp get_experiment_definition(instance) do
    case Discovery.get_definition(instance.experiment_module) do
      {:ok, def} -> def
      _ -> nil
    end
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
  def handle_info({:run_created, run}, socket) do
    socket =
      socket
      |> update(:run_count, &(&1 + 1))
      |> stream_insert(:runs, run, at: 0)

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
end
