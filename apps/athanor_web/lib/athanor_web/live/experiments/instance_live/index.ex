defmodule AthanorWeb.Experiments.InstanceLive.Index do
  use AthanorWeb, :live_view

  alias Athanor.Experiments
  alias Athanor.Runtime
  alias AthanorWeb.Experiments.Components.StatusBadge

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Athanor.PubSub, "experiments:instances")
    end

    stats = Experiments.list_instances_with_stats()

    socket =
      socket
      |> assign(:instance_count, length(stats))
      |> stream(:instances, stats, dom_id: fn item -> "instance-#{item.instance.id}" end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="text-sm text-base-content/60 mb-4 flex items-center gap-2">
      <span class="text-base-content font-medium">Experiments</span>
    </div>

    <div class="flex items-center justify-between mb-6">
      <h1 class="text-2xl font-semibold">All Experiments</h1>
      <.link navigate={~p"/experiments/new"} class="btn btn-primary">
        <.icon name="hero-plus-micro" class="size-4 mr-1" /> New Experiment
      </.link>
    </div>

    <div :if={@instance_count == 0} class="text-center py-12 text-base-content/60">
      <p class="text-lg">No experiments yet.</p>
      <p class="mt-2">
        <.link navigate={~p"/experiments/new"} class="link link-primary">
          Create your first experiment
        </.link>
      </p>
    </div>

    <div id="instances" phx-update="stream" class="space-y-4">
      <div
        :for={{dom_id, item} <- @streams.instances}
        id={dom_id}
        class="card bg-base-200 shadow-sm"
      >
        <div class="card-body p-4">
          <div class="flex items-start justify-between gap-4">
            <%!-- Card content --%>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 mb-1">
                <h2 class="card-title text-base">
                  <.link navigate={~p"/experiments/#{item.instance.id}"} class="link link-hover">
                    {item.instance.name}
                  </.link>
                </h2>
                <StatusBadge.status_badge :if={item.last_run_status} status={item.last_run_status} />
              </div>
              <p class="text-sm text-base-content/60">{module_name(item.instance.experiment_module)}</p>
              <p :if={item.instance.description} class="text-sm mt-1 line-clamp-2 text-base-content/80">
                {item.instance.description}
              </p>
              <div class="flex items-center gap-4 mt-2 text-xs text-base-content/50">
                <span>{item.run_count} runs</span>
                <span :if={item.last_run_at}>Last: {format_relative_time(item.last_run_at)}</span>
              </div>
            </div>

            <%!-- Action column --%>
            <div class="flex items-center gap-2 shrink-0">
              <button phx-click="start_run" phx-value-id={item.instance.id} class="btn btn-sm btn-primary">
                <.icon name="hero-play-micro" class="size-3 mr-1" /> Run
              </button>
              <.link navigate={~p"/experiments/#{item.instance.id}/edit"} class="btn btn-sm btn-ghost">
                Edit
              </.link>
              <div class="dropdown dropdown-end">
                <div tabindex="0" role="button" class="btn btn-ghost btn-sm btn-square">
                  <.icon name="hero-ellipsis-vertical" class="size-4" />
                </div>
                <ul tabindex="0" class="dropdown-content menu bg-base-200 rounded-box z-10 w-44 p-2 shadow-lg border border-base-300">
                  <li>
                    <.link navigate={~p"/experiments/#{item.instance.id}"}>View Details</.link>
                  </li>
                  <li>
                    <button phx-click="delete_instance" phx-value-id={item.instance.id}
                            data-confirm="Delete this experiment and all its runs?">
                      <span class="text-error">Delete</span>
                    </button>
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("start_run", %{"id" => id}, socket) do
    instance = Experiments.get_instance!(id)

    case Runtime.start_run(instance) do
      {:ok, _run} ->
        {:noreply, put_flash(socket, :info, "Run started")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("delete_instance", %{"id" => id}, socket) do
    instance = Experiments.get_instance!(id)
    {:ok, _} = Experiments.delete_instance(instance)
    Athanor.Experiments.Broadcasts.instance_deleted(instance)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:instance_created, instance}, socket) do
    stats = Experiments.get_instance_stats(instance.id)

    socket =
      socket
      |> update(:instance_count, &(&1 + 1))
      |> stream_insert(:instances, stats, at: 0)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:instance_updated, instance}, socket) do
    stats = Experiments.get_instance_stats(instance.id)
    {:noreply, stream_insert(socket, :instances, stats)}
  end

  @impl true
  def handle_info({:instance_deleted, instance}, socket) do
    # Wrap in stats-shaped map so the custom dom_id fn (item.instance.id) works correctly
    fake_stats = %{instance: instance, run_count: 0, last_run_at: nil, last_run_status: nil}

    socket =
      socket
      |> update(:instance_count, &max(&1 - 1, 0))
      |> stream_delete(:instances, fake_stats)

    {:noreply, socket}
  end

  defp module_name(module_string) do
    module_string
    |> String.replace("Elixir.", "")
  end

  defp format_relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604_800 -> "#{div(diff, 86400)} days ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end
end
