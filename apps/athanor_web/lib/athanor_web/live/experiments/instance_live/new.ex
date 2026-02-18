defmodule AthanorWeb.Experiments.InstanceLive.New do
  use AthanorWeb, :live_view

  alias Athanor.Experiments
  alias Athanor.Experiments.{Instance, Discovery}
  alias Athanor.Experiment.ConfigSchema
  alias AthanorWeb.Experiments.Components.ConfigFormComponent

  @impl true
  def mount(_params, _session, socket) do
    experiments = Discovery.experiment_options()
    changeset = Instance.changeset(%Instance{}, %{})

    socket =
      socket
      |> assign(:experiments, experiments)
      |> assign(:selected_experiment, nil)
      |> assign(:config_schema_json, nil)
      |> assign(:form, to_form(changeset))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="text-sm text-base-content/60 mb-4 flex items-center gap-2">
      <.link navigate={~p"/experiments"} class="hover:text-base-content">Experiments</.link>
      <span>/</span>
      <span class="text-base-content">New</span>
    </div>

    <h1 class="text-2xl font-semibold mb-6">New Experiment</h1>

    <div class="pb-24">
      <.form for={@form} id="new-instance-form" phx-submit="save" class="space-y-6">
        <div class="fieldset mb-2">
          <label class="label">
            <span class="label-text">Experiment Type</span>
          </label>
          <select
            name="instance[experiment_module]"
            class="select select-bordered w-full"
            phx-change="select_experiment"
          >
            <option value="">Select an experiment...</option>
            <option
              :for={{name, module} <- @experiments}
              value={module}
              selected={@form[:experiment_module].value == module}
            >
              {name}
            </option>
          </select>
        </div>

        <div :if={@selected_experiment} class="space-y-6">
          <div class="divider">Instance Details</div>

          <.input field={@form[:name]} label="Name" placeholder="My experiment run" />

          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
            placeholder="Optional description..."
          />

          <div :if={@config_schema_json} class="space-y-4">
            <div class="divider">Configuration</div>
            <ConfigFormComponent.config_form schema_json={@config_schema_json} />
          </div>
        </div>
      </.form>
    </div>

    <div class="fixed bottom-0 left-0 right-0 bg-base-100 border-t border-base-300 px-4 py-3">
      <div class="mx-auto max-w-4xl flex justify-end gap-3">
        <.link navigate={~p"/experiments"} class="btn btn-ghost">Cancel</.link>
        <button type="submit" form="new-instance-form" class="btn btn-primary" disabled={is_nil(@selected_experiment)}>
          Create Instance
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_experiment", %{"instance" => %{"experiment_module" => ""}}, socket) do
    {:noreply,
     socket
     |> assign(:selected_experiment, nil)
     |> assign(:config_schema_json, nil)}
  end

  def handle_event("select_experiment", %{"instance" => %{"experiment_module" => module}}, socket) do
    case Discovery.get_config_schema(module) do
      {:ok, schema} ->
        schema_json = schema |> ConfigSchema.to_serializable() |> Jason.encode!()

        {:noreply,
         socket
         |> assign(:selected_experiment, module)
         |> assign(:config_schema_json, schema_json)
         |> push_event("config_schema_changed", %{schema_json: schema_json})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not load experiment configuration")}
    end
  end

  @impl true
  def handle_event("save", %{"instance" => params}, socket) do
    config =
      case params["configuration_json"] do
        nil ->
          %{}

        "" ->
          %{}

        json ->
          case Jason.decode(json) do
            {:ok, decoded} -> decoded
            {:error, _} -> %{}
          end
      end

    params =
      params
      |> Map.put("configuration", config)
      |> Map.delete("configuration_json")

    case Experiments.create_instance(params) do
      {:ok, instance} ->
        Athanor.Experiments.Broadcasts.instance_created(instance)

        {:noreply,
         socket
         |> put_flash(:info, "Experiment instance created")
         |> push_navigate(to: ~p"/experiments/#{instance.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
