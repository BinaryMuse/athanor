defmodule AthanorWeb.Experiments.InstanceLive.Index do
  use AthanorWeb, :live_view

  alias Athanor.Experiments

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Athanor.PubSub, "experiments:instances")
    end

    instances = Experiments.list_instances()

    socket =
      socket
      |> assign(:instance_count, length(instances))
      |> stream(:instances, instances)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Experiments
      <:actions>
        <.link navigate={~p"/experiments/new"} class="btn btn-primary">
          New Experiment
        </.link>
      </:actions>
    </.header>

    <div class="mt-8">
      <div :if={@instance_count == 0} class="text-center py-12 text-base-content/60">
        <p>No experiment instances yet.</p>
        <p class="mt-2">
          <.link navigate={~p"/experiments/new"} class="link link-primary">
            Create your first experiment
          </.link>
        </p>
      </div>

      <div id="instances" phx-update="stream" class="space-y-4">
        <div
          :for={{dom_id, instance} <- @streams.instances}
          id={dom_id}
          class="card bg-base-200 shadow-sm"
        >
          <div class="card-body">
            <div class="flex items-start justify-between">
              <div>
                <h2 class="card-title">
                  <.link navigate={~p"/experiments/#{instance.id}"} class="link link-hover">
                    {instance.name}
                  </.link>
                </h2>
                <p class="text-sm text-base-content/60 mt-1">
                  {instance.experiment_module |> String.replace("Elixir.", "")}
                </p>
                <p :if={instance.description} class="mt-2">
                  {instance.description}
                </p>
              </div>
              <div class="flex gap-2">
                <.link navigate={~p"/experiments/#{instance.id}"} class="btn btn-sm btn-ghost">
                  View
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_info({:instance_created, instance}, socket) do
    socket =
      socket
      |> update(:instance_count, &(&1 + 1))
      |> stream_insert(:instances, instance, at: 0)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:instance_updated, instance}, socket) do
    {:noreply, stream_insert(socket, :instances, instance)}
  end

  @impl true
  def handle_info({:instance_deleted, instance}, socket) do
    socket =
      socket
      |> update(:instance_count, &max(&1 - 1, 0))
      |> stream_delete(:instances, instance)

    {:noreply, socket}
  end
end
