defmodule AthanorWeb.Experiments.InstanceLive.Edit do
  use AthanorWeb, :live_view

  alias Athanor.Experiments
  alias Athanor.Experiments.{Instance, Discovery}
  alias Athanor.Experiment.ConfigSchema
  alias AthanorWeb.Experiments.Components.ConfigFormComponent

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    instance = Experiments.get_instance!(id)
    changeset = Instance.changeset(instance, %{})

    config_schema_json =
      case Discovery.get_config_schema(instance.experiment_module) do
        {:ok, schema} -> schema |> ConfigSchema.to_serializable() |> Jason.encode!()
        {:error, _} -> nil
      end

    socket =
      socket
      |> assign(:instance, instance)
      |> assign(:config_schema_json, config_schema_json)
      |> assign(:form, to_form(changeset))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="text-sm text-base-content/60 mb-4 flex items-center gap-2">
      <.link navigate={~p"/experiments"} class="hover:text-base-content">Experiments</.link>
      <span>/</span>
      <.link navigate={~p"/experiments/#{@instance.id}"} class="hover:text-base-content">{@instance.name}</.link>
      <span>/</span>
      <span class="text-base-content">Edit</span>
    </div>

    <h1 class="text-2xl font-semibold mb-6">Edit Configuration</h1>

    <div class="pb-24">
      <.form for={@form} id="edit-instance-form" phx-submit="save" class="space-y-6">
        <.input field={@form[:name]} label="Name" placeholder="Experiment name" />

        <.input
          field={@form[:description]}
          type="textarea"
          label="Description"
          placeholder="Optional description..."
        />

        <div :if={@config_schema_json} class="space-y-4">
          <div class="divider">Configuration</div>
          <ConfigFormComponent.config_form
            schema_json={@config_schema_json}
            initial_values={Jason.encode!(@instance.configuration || %{})}
          />
        </div>
      </.form>
    </div>

    <div class="fixed bottom-0 left-0 right-0 bg-base-100 border-t border-base-300 px-4 py-3">
      <div class="mx-auto max-w-4xl flex justify-end gap-3">
        <.link navigate={~p"/experiments/#{@instance.id}"} class="btn btn-ghost">Cancel</.link>
        <button type="submit" form="edit-instance-form" class="btn btn-primary">
          Save Changes
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("save", %{"instance" => params}, socket) do
    config =
      case params["configuration_json"] do
        nil -> socket.assigns.instance.configuration || %{}
        "" -> socket.assigns.instance.configuration || %{}
        json ->
          case Jason.decode(json) do
            {:ok, decoded} -> decoded
            {:error, _} -> socket.assigns.instance.configuration || %{}
          end
      end

    params =
      params
      |> Map.put("configuration", config)
      |> Map.delete("configuration_json")

    case Experiments.update_instance(socket.assigns.instance, params) do
      {:ok, instance} ->
        Athanor.Experiments.Broadcasts.instance_updated(instance)

        {:noreply,
         socket
         |> put_flash(:info, "Configuration updated")
         |> push_navigate(to: ~p"/experiments/#{instance.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
