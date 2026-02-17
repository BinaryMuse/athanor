defmodule AthanorWeb.Experiments.InstanceLive.New do
  use AthanorWeb, :live_view

  alias Athanor.Experiments
  alias Athanor.Experiments.{Instance, Discovery}

  @impl true
  def mount(_params, _session, socket) do
    experiments = Discovery.experiment_options()
    changeset = Instance.changeset(%Instance{}, %{})

    socket =
      socket
      |> assign(:experiments, experiments)
      |> assign(:selected_experiment, nil)
      |> assign(:config_schema, nil)
      |> assign(:list_items, %{})
      |> assign(:form, to_form(changeset))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      New Experiment Instance
      <:subtitle>
        Configure and create a new experiment instance
      </:subtitle>
    </.header>

    <div class="mt-8 max-w-2xl">
      <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6">
        <div class="form-control">
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

          <div :if={@config_schema} class="space-y-4">
            <div class="divider">Configuration</div>
            <.render_config_fields
              schema={@config_schema}
              form={@form}
              path={[]}
              list_items={@list_items}
            />
          </div>

          <div class="flex gap-4 pt-4">
            <.button type="submit" class="btn-primary">Create Instance</.button>
            <.link navigate={~p"/experiments"} class="btn btn-ghost">Cancel</.link>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  defp render_config_fields(assigns) do
    ~H"""
    <%= for {name, field_def} <- @schema.properties || %{} do %>
      <.render_config_field
        name={name}
        field_def={field_def}
        form={@form}
        path={@path ++ [name]}
        list_items={@list_items}
      />
    <% end %>
    """
  end

  defp render_config_field(%{field_def: %{type: :list, item_schema: item_schema}} = assigns) do
    path_key = path_to_key(assigns.path)
    items = Map.get(assigns.list_items, path_key, [])
    assigns = assign(assigns, :item_schema, item_schema)
    assigns = assign(assigns, :items, items)
    assigns = assign(assigns, :path_key, path_key)

    ~H"""
    <div class="border border-base-300 rounded-lg p-4">
      <div class="flex items-center justify-between mb-4">
        <label class="font-semibold">{humanize(@name)}</label>
        <button
          type="button"
          phx-click="add_list_item"
          phx-value-path={@path_key}
          class="btn btn-sm btn-outline"
        >
          <.icon name="hero-plus" class="size-4" /> Add
        </button>
      </div>

      <div :if={@items == []} class="text-sm text-base-content/60 text-center py-4">
        No items yet. Click "Add" to add one.
      </div>

      <div class="space-y-4">
        <div
          :for={{item, idx} <- Enum.with_index(@items)}
          class="bg-base-200 rounded-lg p-4 relative"
        >
          <button
            type="button"
            phx-click="remove_list_item"
            phx-value-path={@path_key}
            phx-value-index={idx}
            class="btn btn-ghost btn-xs absolute top-2 right-2"
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>

          <div class="pr-8 space-y-3">
            <%= for {field_name, field_def} <- @item_schema.properties || %{} do %>
              <.render_list_item_field
                name={field_name}
                field_def={field_def}
                path={@path}
                index={idx}
                value={Map.get(item, to_string(field_name)) || Map.get(item, field_name)}
              />
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_config_field(%{field_def: %{type: :string}} = assigns) do
    ~H"""
    <div class="form-control">
      <label class="label">
        <span class="label-text">{humanize(@name)}</span>
      </label>
      <input
        type="text"
        name={field_name(@path)}
        value={@field_def[:default]}
        class="input input-bordered w-full"
      />
    </div>
    """
  end

  defp render_config_field(%{field_def: %{type: :integer}} = assigns) do
    ~H"""
    <div class="form-control">
      <label class="label">
        <span class="label-text">{humanize(@name)}</span>
      </label>
      <input
        type="number"
        name={field_name(@path)}
        value={@field_def[:default]}
        class="input input-bordered w-full"
      />
    </div>
    """
  end

  defp render_config_field(%{field_def: %{type: :boolean}} = assigns) do
    ~H"""
    <div class="form-control">
      <label class="label cursor-pointer justify-start gap-4">
        <input
          type="checkbox"
          name={field_name(@path)}
          checked={@field_def[:default] == true}
          class="checkbox"
        />
        <span class="label-text">{humanize(@name)}</span>
      </label>
    </div>
    """
  end

  defp render_config_field(assigns) do
    ~H"""
    <div class="form-control">
      <label class="label">
        <span class="label-text">{humanize(@name)}</span>
      </label>
      <input
        type="text"
        name={field_name(@path)}
        value={@field_def[:default]}
        class="input input-bordered w-full"
      />
    </div>
    """
  end

  defp render_list_item_field(%{field_def: %{type: :string}} = assigns) do
    ~H"""
    <div class="form-control">
      <label class="label py-1">
        <span class="label-text text-sm">{humanize(@name)}</span>
      </label>
      <input
        type="text"
        name={list_item_field_name(@path, @index, @name)}
        value={@value || @field_def[:default]}
        class="input input-bordered input-sm w-full"
      />
    </div>
    """
  end

  defp render_list_item_field(%{field_def: %{type: :integer}} = assigns) do
    ~H"""
    <div class="form-control">
      <label class="label py-1">
        <span class="label-text text-sm">{humanize(@name)}</span>
      </label>
      <input
        type="number"
        name={list_item_field_name(@path, @index, @name)}
        value={@value || @field_def[:default]}
        class="input input-bordered input-sm w-full"
      />
    </div>
    """
  end

  defp render_list_item_field(assigns) do
    ~H"""
    <div class="form-control">
      <label class="label py-1">
        <span class="label-text text-sm">{humanize(@name)}</span>
      </label>
      <input
        type="text"
        name={list_item_field_name(@path, @index, @name)}
        value={@value || @field_def[:default]}
        class="input input-bordered input-sm w-full"
      />
    </div>
    """
  end

  defp field_name(path) do
    base = "instance[configuration]"
    Enum.reduce(path, base, fn key, acc -> "#{acc}[#{key}]" end)
  end

  defp list_item_field_name(path, index, field) do
    base = field_name(path)
    "#{base}[#{index}][#{field}]"
  end

  defp path_to_key(path), do: Enum.join(path, ".")

  defp humanize(atom) when is_atom(atom), do: humanize(to_string(atom))

  defp humanize(string) when is_binary(string) do
    string
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  @impl true
  def handle_event("select_experiment", %{"instance" => %{"experiment_module" => ""}}, socket) do
    {:noreply,
     socket
     |> assign(:selected_experiment, nil)
     |> assign(:config_schema, nil)
     |> assign(:list_items, %{})}
  end

  def handle_event("select_experiment", %{"instance" => %{"experiment_module" => module}}, socket) do
    case Discovery.get_config_schema(module) do
      {:ok, schema} ->
        # Initialize list items with defaults from schema
        list_items = initialize_list_items(schema, [])

        {:noreply,
         socket
         |> assign(:selected_experiment, module)
         |> assign(:config_schema, schema)
         |> assign(:list_items, list_items)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not load experiment configuration")}
    end
  end

  @impl true
  def handle_event("add_list_item", %{"path" => path_key}, socket) do
    schema = socket.assigns.config_schema
    item_schema = get_item_schema_for_path(schema, String.split(path_key, "."))

    # Create new item with defaults
    new_item =
      (item_schema.properties || %{})
      |> Enum.map(fn {name, field_def} ->
        {to_string(name), field_def[:default]}
      end)
      |> Map.new()

    list_items =
      Map.update(socket.assigns.list_items, path_key, [new_item], fn items ->
        items ++ [new_item]
      end)

    {:noreply, assign(socket, :list_items, list_items)}
  end

  @impl true
  def handle_event("remove_list_item", %{"path" => path_key, "index" => index_str}, socket) do
    index = String.to_integer(index_str)

    list_items =
      Map.update(socket.assigns.list_items, path_key, [], fn items ->
        List.delete_at(items, index)
      end)

    {:noreply, assign(socket, :list_items, list_items)}
  end

  @impl true
  def handle_event("validate", %{"instance" => params}, socket) do
    # Update list items from form params
    list_items = extract_list_items(params["configuration"] || %{}, socket.assigns.list_items)

    changeset =
      %Instance{}
      |> Instance.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:list_items, list_items)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"instance" => params}, socket) do
    # Parse configuration from nested params, including list items
    config = parse_configuration(params["configuration"] || %{}, socket.assigns.list_items)
    params = Map.put(params, "configuration", config)

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

  # Initialize list items from schema defaults
  defp initialize_list_items(schema, path) do
    (schema.properties || %{})
    |> Enum.reduce(%{}, fn {name, field_def}, acc ->
      current_path = path ++ [name]

      case field_def do
        %{type: :list, item_schema: _item_schema} ->
          # Start with empty list - user can add items
          Map.put(acc, path_to_key(current_path), [])

        _ ->
          acc
      end
    end)
  end

  defp get_item_schema_for_path(schema, [name]) do
    name_atom = String.to_existing_atom(name)
    schema.properties[name_atom].item_schema
  rescue
    _ -> nil
  end

  defp get_item_schema_for_path(_schema, _path), do: nil

  # Extract list items from form params
  defp extract_list_items(config, existing_list_items) do
    Enum.reduce(existing_list_items, %{}, fn {path_key, _items}, acc ->
      path_parts = String.split(path_key, ".")

      case get_in(config, path_parts) do
        nil ->
          # Keep existing if not in params
          Map.put(acc, path_key, Map.get(existing_list_items, path_key, []))

        list_map when is_map(list_map) ->
          # Convert indexed map to list
          items =
            list_map
            |> Enum.sort_by(fn {k, _v} -> String.to_integer(k) end)
            |> Enum.map(fn {_k, v} -> v end)

          Map.put(acc, path_key, items)

        _ ->
          Map.put(acc, path_key, [])
      end
    end)
  end

  defp parse_configuration(config, list_items) when is_map(config) do
    config
    |> Enum.map(fn {k, v} ->
      path_key = k

      cond do
        # Check if this is a list field
        Map.has_key?(list_items, path_key) ->
          {k, Map.get(list_items, path_key, [])}

        is_map(v) and has_indexed_keys?(v) ->
          # This is a list represented as indexed map
          items =
            v
            |> Enum.sort_by(fn {idx, _} -> String.to_integer(idx) end)
            |> Enum.map(fn {_, item} -> parse_configuration(item, %{}) end)

          {k, items}

        is_map(v) ->
          {k, parse_configuration(v, list_items)}

        true ->
          {k, parse_config_value(v)}
      end
    end)
    |> Map.new()
  end

  defp has_indexed_keys?(map) when is_map(map) do
    keys = Map.keys(map)

    Enum.all?(keys, fn k ->
      case Integer.parse(k) do
        {_, ""} -> true
        _ -> false
      end
    end)
  end

  defp parse_config_value(v) when is_binary(v) do
    case Integer.parse(v) do
      {int, ""} -> int
      _ -> v
    end
  end

  defp parse_config_value(v), do: v
end
