defmodule AthanorWeb.Experiments.Components.ResultsPanel do
  @moduledoc """
  Results panel component displaying experiment run results
  as a collapsible tree with a raw JSON view toggle.

  Result cards are lazy-hydrated: they render as lightweight stubs
  initially, and full tree content is loaded on demand when the user
  clicks to expand.

  Renders without card wrapper — intended for use inside a tab panel.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :streams, :map, required: true
  attr :result_count, :integer, required: true

  def results_panel(assigns) do
    ~H"""
    <div :if={@result_count == 0} class="text-base-content/40 text-center py-8">
      No results yet
    </div>

    <div id="results" phx-update="stream" class="space-y-3">
      <div
        :for={{dom_id, result} <- @streams.results}
        id={dom_id}
        class="bg-base-300 rounded-box p-3"
      >
        <.result_card result={result} />
      </div>
    </div>
    """
  end

  attr :result, :map, required: true

  defp result_card(%{result: %{hydrated: true}} = assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-2">
        <span class="font-medium text-sm font-mono text-base-content">{@result.key}</span>
        <button
          class="btn btn-ghost btn-xs"
          phx-click={
            JS.toggle_class("hidden", to: "#result-tree-#{@result.id}")
            |> JS.toggle_class("hidden", to: "#result-json-#{@result.id}")
          }
        >
          Toggle JSON
        </button>
      </div>

      <%!-- Tree view (shown by default) --%>
      <div id={"result-tree-#{@result.id}"} class="overflow-hidden">
        <.json_tree value={@result.value} node_id={@result.id} depth={0} />
      </div>

      <%!-- Raw JSON view (hidden by default) --%>
      <div id={"result-json-#{@result.id}"} class="hidden">
        <pre class="font-mono text-xs text-base-content/80 whitespace-pre-wrap break-words">{encode_json(@result.value)}</pre>
      </div>
    </div>
    """
  end

  defp result_card(assigns) do
    ~H"""
    <div
      class="flex items-center gap-2 cursor-pointer hover:text-primary"
      phx-click="hydrate_result"
      phx-value-id={@result.id}
    >
      <span class="text-base-content/40 text-xs">></span>
      <span class="font-medium text-sm font-mono text-base-content">{@result.key}</span>
      <span class="text-base-content/40 text-xs ml-auto">Click to expand</span>
    </div>
    """
  end

  attr :value, :any, required: true
  attr :node_id, :string, default: "root"
  attr :depth, :integer, default: 0

  defp json_tree(%{value: value} = assigns) when is_map(value) and map_size(value) > 0 do
    assigns = assign(assigns, :entries, Map.to_list(value))

    ~H"""
    <ul class="space-y-0.5">
      <li :for={{key, val} <- @entries}>
        <div
          class="flex items-start gap-1 cursor-pointer hover:text-primary select-none"
          phx-click={
            JS.toggle_class("hidden", to: "##{@node_id}-#{key}-children")
            |> JS.toggle_class("rotate-90", to: "##{@node_id}-#{key}-chevron")
          }
        >
          <span
            :if={!is_scalar(val)}
            id={"#{@node_id}-#{key}-chevron"}
            class="text-base-content/40 text-xs mt-0.5 select-none transition-transform"
          >
            >
          </span>
          <span :if={is_scalar(val)} class="text-base-content/40 text-xs mt-0.5 select-none">
            -
          </span>
          <span class="font-mono text-xs font-medium text-base-content">{key}</span>
          <span :if={is_scalar(val)} class="font-mono text-xs text-base-content/60 ml-1">
            {format_scalar(val)}
          </span>
        </div>
        <div
          :if={!is_scalar(val)}
          id={"#{@node_id}-#{key}-children"}
          class={["ml-4 border-l border-neutral pl-2", if(@depth > 0, do: "hidden")]}
        >
          <.json_tree value={val} node_id={"#{@node_id}-#{key}"} depth={@depth + 1} />
        </div>
      </li>
    </ul>
    """
  end

  defp json_tree(%{value: value} = assigns) when is_list(value) do
    assigns = assign(assigns, :indexed, Enum.with_index(value))

    ~H"""
    <ul class="space-y-0.5">
      <li :for={{item, idx} <- @indexed}>
        <div :if={is_scalar(item)} class="font-mono text-xs text-base-content/60 ml-4">
          [{idx}] {format_scalar(item)}
        </div>
        <div :if={!is_scalar(item)}>
          <div
            class="flex items-center gap-1 cursor-pointer hover:text-primary select-none"
            phx-click={
              JS.toggle_class("hidden", to: "##{@node_id}-#{idx}-children")
              |> JS.toggle_class("rotate-90", to: "##{@node_id}-#{idx}-chevron")
            }
          >
            <span
              id={"#{@node_id}-#{idx}-chevron"}
              class="text-base-content/40 text-xs select-none transition-transform"
            >
              >
            </span>
            <span class="font-mono text-xs text-base-content/60">[{idx}]</span>
          </div>
          <div
            id={"#{@node_id}-#{idx}-children"}
            class={["ml-4 border-l border-neutral pl-2", if(@depth > 0, do: "hidden")]}
          >
            <.json_tree value={item} node_id={"#{@node_id}-#{idx}"} depth={@depth + 1} />
          </div>
        </div>
      </li>
    </ul>
    """
  end

  defp json_tree(assigns) do
    ~H"""
    <span class="font-mono text-xs text-base-content/60">{format_scalar(@value)}</span>
    """
  end

  defp is_scalar(v), do: not (is_map(v) or is_list(v))

  defp format_scalar(nil), do: "null"
  defp format_scalar(v) when is_boolean(v), do: to_string(v)
  defp format_scalar(v) when is_number(v), do: to_string(v)
  defp format_scalar(v) when is_binary(v), do: ~s("#{v}")

  defp encode_json(value) do
    case Jason.encode(value, pretty: true) do
      {:ok, json} -> json
      {:error, _} -> "[encoding error]"
    end
  end
end
