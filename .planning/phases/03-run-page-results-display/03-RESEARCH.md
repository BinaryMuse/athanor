# Phase 3: Run Page Results Display - Research

**Researched:** 2026-02-16
**Domain:** Phoenix LiveView recursive HEEx components, client-side JS toggle, stream-based real-time updates, nested JSON rendering
**Confidence:** HIGH

## Summary

Phase 2 left a basic result display inline in `RunLive.Show` that renders each result's `value` as a pretty-printed JSON `<pre>` block. Phase 3 replaces this with a proper `ResultsPanelComponent` that provides: (1) a collapsible tree view of nested result values, (2) a raw JSON toggle, and (3) real-time streaming of new results. The PubSub broadcast and stream infrastructure is already complete — `{:result_added, result}` and `{:results_added, results}` events are handled in `show.ex` with `stream_insert(:results, result)`.

The core technical challenge is rendering arbitrary JSON (Elixir maps with string keys, from the `Result.value :map` Ecto field) as an interactive collapsible tree. The recommended approach is server-side recursive HEEx component for the tree structure, with client-side `JS.toggle_class("hidden")` for expand/collapse — entirely client-side, no server roundtrip. The JSON/tree view switch is also pure client-side using `JS.toggle_class("hidden")` on sibling panel `<div>`s. This means zero new JS hooks, zero new backend changes.

Results are typically few per run (unlike logs which can be 10,000+). The existing stream for results has no limit, which is appropriate. The component follows the same `Phoenix.Component` extraction pattern as `LogPanel`.

**Primary recommendation:** Build `ResultsPanelComponent` as a pure `Phoenix.Component` using server-side recursive HEEx for tree rendering and `JS.toggle_class("hidden")` for all client-side interactions (tree expand/collapse and tree/JSON view toggle). No new JS hooks, no new backend changes.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView | 1.1.24 | Streams for real-time result updates, `JS` module for client-side toggle | Built-in, already in project |
| Phoenix.Component | (part of LiveView 1.1.24) | Recursive function component for tree node rendering | Already used for LogPanel, StatusBadge, ProgressBar |
| Phoenix.LiveView.JS | (part of LiveView 1.1.24) | `JS.toggle_class("hidden")` for expand/collapse and view switch | No custom JS required |
| Jason | 1.4.4 | Encode result value to pretty JSON for raw view | Already in project, already used in show.ex |
| DaisyUI + Tailwind | vendored | Semantic classes for card, inset panels, tabs | Established in Phase 1 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `overflow-wrap: break-word` (`break-words` Tailwind) | N/A (CSS) | Prevent horizontal scroll on long string values | Always — JSON values can have very long strings |
| `truncate` + `title` attribute | N/A (Tailwind) | Long key names in tree header | When key is too long to display in full |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Server-side recursive HEEx component | Client-side JS tree renderer (custom hook) | JS hook adds complexity, breaks LiveView update semantics; HEEx tree is simpler and maintainable |
| Server-side recursive HEEx component | JS library (e.g., `react-json-view`, `json-tree`) | Would require adding JS bundler or npm packages; unnecessary for a LiveView app |
| `JS.toggle_class("hidden")` for expand/collapse | Server-side `phx-click` event handler updating assigns | Server roundtrip is unnecessary for pure UI state; `JS.toggle_class` is instant, persists across LiveView patches |
| Inline results in `show.ex` | Extracted `ResultsPanelComponent` | Inline violates single-responsibility; existing `LogPanel` pattern proves extraction is correct |

**Installation:** No new packages required.

## Architecture Patterns

### Recommended Project Structure

```
apps/athanor_web/lib/athanor_web/live/experiments/
├── run_live/
│   └── show.ex                              # Existing — only change: replace inline results with <ResultsPanel.results_panel ...>
└── components/
    ├── results_panel.ex                     # NEW: ResultsPanelComponent
    ├── log_panel.ex                         # Existing (Phase 2)
    ├── status_badge.ex                      # Existing
    └── progress_bar.ex                      # Existing
```

### Pattern 1: ResultsPanelComponent as Phoenix.Component

**What:** Extract the results `<div>` from `RunLive.Show.render/1` into a dedicated `AthanorWeb.Experiments.Components.ResultsPanel` module. Follows the exact same pattern as `LogPanel`.

**When to use:** Always — single responsibility, follows project convention.

**Example:**
```elixir
# apps/athanor_web/lib/athanor_web/live/experiments/components/results_panel.ex
defmodule AthanorWeb.Experiments.Components.ResultsPanel do
  @moduledoc """
  Results panel component displaying experiment run results
  as a collapsible tree with a raw JSON view toggle.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :streams, :map, required: true
  attr :result_count, :integer, required: true

  def results_panel(assigns) do
    ~H"""
    <div class="card bg-base-200">
      <div class="card-body">
        <div class="flex items-center justify-between">
          <h3 class="card-title text-lg">Results</h3>
          <span class="text-sm text-base-content/60">{@result_count} result{if @result_count != 1, do: "s"}</span>
        </div>

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
      </div>
    </div>
    """
  end

  # ...
end
```

### Pattern 2: Tree/JSON View Toggle (Client-Side Only)

**What:** Two sibling `<div>`s inside each result card — one for tree view, one for raw JSON. A toggle button uses `JS.toggle_class("hidden")` to show/hide each panel. Both panels contain the same data rendered differently.

**When to use:** For the view-mode switch. No server event needed — purely client-side DOM manipulation.

**Example:**
```elixir
# Source: Phoenix.LiveView.JS docs - JS.toggle_class verified in project
defp result_card(assigns) do
  ~H"""
  <div>
    <div class="flex items-center justify-between mb-2">
      <span class="font-medium text-sm font-mono">{@result.key}</span>
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
    <div id={"result-tree-#{@result.id}"}>
      <.json_tree value={@result.value} depth={0} />
    </div>

    <%!-- Raw JSON view (hidden by default) --%>
    <div id={"result-json-#{@result.id}"} class="hidden">
      <pre class="font-mono text-xs text-base-content/80 overflow-x-auto whitespace-pre-wrap break-words">
        {Jason.encode!(@result.value, pretty: true)}
      </pre>
    </div>
  </div>
  """
end
```

### Pattern 3: Recursive JSON Tree Component

**What:** A recursive `Phoenix.Component` function (`json_tree/1`) that renders arbitrary JSON values as a collapsible tree. Each object/map key becomes a clickable header; clicking toggles visibility of its children using `JS.toggle_class("hidden")`. Uses `depth` attribute to generate unique DOM IDs.

**Key constraint:** Phoenix.Component functions **can** call themselves in HEEx templates — there is no compile-time restriction against recursive function components. The warning about external variables only applies to LiveView change tracking, not to static function components. Recursive components work by passing assigns down on each recursive call.

**When to use:** For any nested JSON value (maps, lists). Scalar values (strings, numbers, booleans, null) render inline without expand/collapse.

**Example:**
```elixir
# Source: Verified — JS.toggle_class uses dynamic CSS selector with unique ID
# Pattern: unique ID = "#{result.id}-#{depth}-#{index}" to avoid DOM collisions

attr :value, :any, required: true
attr :depth, :integer, default: 0
attr :node_id, :string, default: "root"

defp json_tree(%{value: value} = assigns) when is_map(value) do
  assigns = assign(assigns, :entries, Map.to_list(value))
  ~H"""
  <ul class="space-y-1">
    <li :for={{key, val} <- @entries} class="ml-0">
      <div
        class="flex items-start gap-1 cursor-pointer hover:text-primary"
        phx-click={JS.toggle_class("hidden", to: "##{@node_id}-#{key}-children")}
      >
        <span class="text-base-content/40 text-xs mt-0.5 select-none">▶</span>
        <span class="font-mono text-xs font-medium text-base-content">{key}</span>
        <span :if={is_scalar(val)} class="font-mono text-xs text-base-content/60 ml-1">{format_scalar(val)}</span>
      </div>
      <div
        :if={!is_scalar(val)}
        id={"#{@node_id}-#{key}-children"}
        class="ml-4 border-l border-neutral pl-2"
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
  <ul class="space-y-1">
    <li :for={{item, idx} <- @indexed}>
      <div
        :if={is_scalar(item)}
        class="font-mono text-xs text-base-content/60 ml-4"
      >
        [{idx}] {format_scalar(item)}
      </div>
      <div :if={!is_scalar(item)}>
        <div
          class="flex items-center gap-1 cursor-pointer hover:text-primary"
          phx-click={JS.toggle_class("hidden", to: "##{@node_id}-#{idx}-children")}
        >
          <span class="text-base-content/40 text-xs select-none">▶</span>
          <span class="font-mono text-xs text-base-content/60">[{idx}]</span>
        </div>
        <div id={"#{@node_id}-#{idx}-children"} class="ml-4 border-l border-neutral pl-2">
          <.json_tree value={item} node_id={"#{@node_id}-#{idx}"} depth={@depth + 1} />
        </div>
      </div>
    </li>
  </ul>
  """
end

defp json_tree(assigns) do
  # Scalar fallback
  ~H"""
  <span class="font-mono text-xs text-base-content/60">{format_scalar(@value)}</span>
  """
end

defp is_scalar(v), do: not (is_map(v) or is_list(v))

defp format_scalar(nil), do: "null"
defp format_scalar(v) when is_boolean(v), do: to_string(v)
defp format_scalar(v) when is_number(v), do: to_string(v)
defp format_scalar(v) when is_binary(v), do: ~s("#{v}")
```

### Pattern 4: Unique Node IDs for Stream Items

**What:** Each result item in the stream has an Ecto UUID (`result.id`). Use this as the root of all DOM IDs within that result's tree to guarantee no collisions between different result cards in the stream.

**When to use:** Any time `JS.toggle_class(to: "#some-id")` is used inside a stream item. Always qualify with the stream item's `id`.

**Example:**
```elixir
# node_id for root of tree = result.id (UUID)
# Nested path: "#{result.id}-fieldname-subfieldname-0"
# This guarantees uniqueness even with 100 results in the stream

<.json_tree value={result.value} node_id={result.id} depth={0} />
```

### Pattern 5: No Horizontal Scroll

**What:** The "no horizontal scroll" requirement applies to the tree view AND the raw JSON view. Use CSS `break-words` (`overflow-wrap: break-word`) rather than `overflow-x: auto` on the container. For tree nodes, deeply nested content is managed by indentation (`ml-4`) rather than expanding width.

**When to use:** On all text containers in the panel.

**Example:**
```elixir
# For raw JSON pre block — wrap not scroll:
<pre class="font-mono text-xs text-base-content/80 whitespace-pre-wrap break-words">
  {Jason.encode!(@result.value, pretty: true)}
</pre>

# For tree view container:
<div class="overflow-hidden">
  <.json_tree value={@result.value} node_id={result.id} depth={0} />
</div>
```

### Anti-Patterns to Avoid

- **`overflow-x-auto` on tree panel:** This creates horizontal scroll, violating success criterion 4. Use `overflow-hidden` + `break-words` instead.
- **Server-side expand/collapse via `phx-click` events updating assigns:** Tree node expand/collapse is pure UI state — no data changes, no server needed. `JS.toggle_class` handles it instantly without server roundtrip.
- **Reusing the same DOM IDs for tree nodes across stream items:** If two result cards both have a node called `"scores"`, `#result-tree-scores-children` would point to the wrong element. Always prefix with `result.id`.
- **Using `Jason.encode!` in the tree view:** The tree view must iterate the actual map, not parse JSON strings. Only use `Jason.encode!` in the raw JSON panel.
- **Hardcoded colors on tree values:** Use `text-base-content/60` for scalar values, `text-base-content` for keys, `text-primary` for hover. Never use `text-gray-*`.
- **Adding a stream limit to results:** Results are typically few per experiment (unlike logs). Do not add a limit to the results stream — users need to see all results.
- **`phx-update="stream"` on wrong container:** Must be on the immediate parent of the `:for` items. The card container (`bg-base-200`) must NOT have `phx-update="stream"`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Expand/collapse tree nodes | Custom JS hook with state tracking | `JS.toggle_class("hidden")` | LiveView JS commands are DOM-patch aware — they survive LiveView updates; custom hooks would need to re-implement the same logic |
| JSON syntax highlighting | Custom regex-based highlighter | None needed — monospace + semantic colors is sufficient | Syntax highlighting adds significant complexity (JS parser or Elixir tokenizer); `text-base-content/60` on scalars provides visual differentiation |
| View mode (tree vs JSON) state persistence | `assign(:view_mode, :tree)` + server event | `JS.toggle_class("hidden")` on sibling panels | Server-side view mode is redundant state — toggle is instant client-side, survives LiveView patches |
| Pretty JSON encoding | Custom encoder | `Jason.encode!(value, pretty: true)` | Jason is already in the project, already used in the existing result display |
| Tree serialization | Custom Elixir tree structure | Use `Result.value` map directly | The map IS the tree — no transformation needed |

**Key insight:** `JS.toggle_class` commands are "DOM-patch aware" — they survive LiveView updates. The state lives in the DOM (`hidden` class presence), not in the socket assigns. This means the expanded/collapsed state of a tree node will persist as the server streams new results into the panel. No server roundtrip, no assign overhead.

## Common Pitfalls

### Pitfall 1: Non-Unique DOM IDs for Tree Nodes Across Stream Items

**What goes wrong:** Two result cards both have a key named `"accuracy"`. The tree uses DOM ID `#accuracy-children` for both. `JS.toggle_class("hidden", to: "#accuracy-children")` matches the first one in the DOM, toggling the wrong card's subtree.

**Why it happens:** Forgetting that stream renders multiple result cards on the same page, all potentially with the same JSON keys.

**How to avoid:** Always prefix tree node IDs with the result's UUID: `"#{result.id}-accuracy-children"`.

**Warning signs:** Clicking expand on one result card collapses a different one.

### Pitfall 2: `JS.toggle_class` Breaking After LiveView Patch

**What goes wrong:** User expands a tree node. A new result streams in, causing a LiveView DOM patch. The tree node collapses (loses the `hidden` class toggle).

**Why it happens:** If the tree node's parent element (`phx-update="stream"`) is re-rendered by LiveView, the DOM node is replaced and `hidden` class state is lost.

**How to avoid:** Verify that `phx-update="stream"` is ONLY on the immediate parent of stream items (`<div id="results" phx-update="stream">`). The tree nodes within each stream item are NOT re-rendered when NEW items are streamed in — only when their own item is updated. Since `stream_insert` only appends (doesn't update existing items unless the same ID is inserted again), tree state is preserved.

**Warning signs:** Expanded tree nodes collapse when a new result arrives.

### Pitfall 3: Deeply Nested Values Causing Layout Overflow

**What goes wrong:** A result has a deeply nested map (5+ levels). At 4px `ml-4` per level, 5 levels = 20px of indentation — that is fine. But at 8 levels and `ml-8` per level, the tree content overflows the card width.

**Why it happens:** Indentation accumulates multiplicatively. Without an `overflow-hidden` container, the tree pushes the card wider.

**How to avoid:** Set `overflow-hidden` on the tree container. Use `ml-4` (not `ml-8`) per depth level. Consider truncating keys that are very long using `truncate` + the full key as a `title` attribute for tooltip.

**Warning signs:** Card is wider than the grid column; horizontal scrollbar appears on the page.

### Pitfall 4: `Jason.encode!` on Non-Encodable Values

**What goes wrong:** `Jason.encode!(result.value, pretty: true)` raises `Jason.EncodeError` because `result.value` contains an atom key or non-standard Elixir term.

**Why it happens:** Ecto deserializes `:map` columns with string keys (JSON has no atom keys). However, if the map was constructed in Elixir with atom keys before being stored, it could theoretically still have atoms in memory. Additionally, `create_results` converts map inserts to structs — these are fine, but defensive coding matters.

**How to avoid:** Wrap with a `try/rescue` or use `Jason.encode(result.value, pretty: true)` (not bang) and handle `{:error, _}` — display `"[encoding error]"` as the JSON view fallback.

**Warning signs:** Result panel crashes on one result, showing LiveView error.

### Pitfall 5: Recursive Component Hitting HEEx Change-Tracking Warning

**What goes wrong:** The Elixir compiler emits a warning about "variables used within component blocks" in the recursive `json_tree` component.

**Why it happens:** LiveView's change tracking requires all values used in a HEEx template to come from `assigns`. If a value is computed inside the component function but used in the HEEx template via a local variable (not via `@var`), the compiler warns.

**How to avoid:** Always reassign computed values back into assigns before using them in HEEx: `assigns = assign(assigns, :entries, Map.to_list(value))`. Access via `@entries`, not the local `entries` variable.

**Warning signs:** `warning: variable "entries" is unused` or LiveView change tracking warning about external variables.

### Pitfall 6: Semantic Color Violations

**What goes wrong:** Tree node values use `text-gray-400` or `text-gray-600` instead of `text-base-content/40` or `text-base-content/60`. These break in light/dark theme.

**Why it happens:** Temptation to use gray for "muted" colors — but the project convention since Phase 1 is DaisyUI semantic tokens only.

**How to avoid:** Follow DESIGN-TOKENS.md: tertiary = `text-base-content/40`, secondary = `text-base-content/60`. Never use `text-gray-*`.

**Warning signs:** Colors look wrong in light theme; `text-gray-*` classes appear in the component.

## Code Examples

Verified patterns from official LiveView source and existing project codebase:

### JS.toggle_class for View Switch (Tree/JSON)

```elixir
# Source: deps/phoenix_live_view/lib/phoenix_live_view/js.ex - JS.toggle_class/2
# JS commands are DOM-patch aware per docs: "operations applied by the JS APIs will
# stick to elements across patches from the server"
defp toggle_view_button(result_id) do
  JS.toggle_class("hidden", to: "#result-tree-#{result_id}")
  |> JS.toggle_class("hidden", to: "#result-json-#{result_id}")
end
```

Usage in HEEx:
```heex
<button class="btn btn-ghost btn-xs" phx-click={toggle_view_button(@result.id)}>
  Toggle JSON
</button>
```

### JS.toggle_class for Tree Node Expand/Collapse

```elixir
# Source: deps/phoenix_live_view/lib/phoenix_live_view/js.ex - JS.toggle_class/2
# Using dynamic selector built from node_id to avoid cross-result collisions
defp toggle_node(node_id) do
  JS.toggle_class("hidden", to: "##{node_id}-children")
  |> JS.toggle_class("rotate-90", to: "##{node_id}-chevron")
end
```

Usage in HEEx:
```heex
<div
  class="flex items-center gap-1 cursor-pointer hover:text-primary"
  phx-click={toggle_node(node_id)}
>
  <span id={"#{node_id}-chevron"} class="text-base-content/40 text-xs transition-transform select-none">▶</span>
  <span class="font-mono text-xs font-medium">{key}</span>
</div>
<div id={"#{node_id}-children"} class="ml-4 border-l border-neutral pl-2">
  <%!-- recursive children rendered here --%>
</div>
```

### Recursive Component with Proper Assigns Usage

```elixir
# Source: Phoenix.Component docs, davidbishai.com recursive Phoenix components (2024-12)
# Key: reassign computed values into assigns map before using in HEEx
attr :value, :any, required: true
attr :node_id, :string, default: "root"
attr :depth, :integer, default: 0

defp json_tree(%{value: value} = assigns) when is_map(value) and map_size(value) > 0 do
  # Reassign — NOT a local variable — to avoid HEEx change-tracking warnings
  assigns = assign(assigns, :entries, Map.to_list(value))

  ~H"""
  <ul class="space-y-0.5">
    <li :for={{key, val} <- @entries}>
      <!-- ... recursive call ... -->
      <.json_tree :if={!is_scalar(val)} value={val} node_id={"#{@node_id}-#{key}"} depth={@depth + 1} />
    </li>
  </ul>
  """
end
```

### Stream Insert for Real-Time Results (Already Working in show.ex)

```elixir
# Source: apps/athanor_web/lib/athanor_web/live/experiments/run_live/show.ex
# These handlers are ALREADY implemented — ResultsPanelComponent consumes @streams.results
@impl true
def handle_info({:result_added, result}, socket) do
  socket =
    socket
    |> update(:result_count, &(&1 + 1))
    |> stream_insert(:results, result)
  {:noreply, socket}
end

@impl true
def handle_info({:results_added, results}, socket) when is_list(results) do
  socket =
    Enum.reduce(results, socket, fn result, acc ->
      acc
      |> update(:result_count, &(&1 + 1))
      |> stream_insert(:results, result)
    end)
  {:noreply, socket}
end
```

### Pretty JSON for Raw View (Already Used in show.ex)

```elixir
# Source: apps/athanor_web/lib/athanor_web/live/experiments/run_live/show.ex line 101
# Already using Jason.encode! — use Jason.encode/2 (no bang) for defensive coding
{:ok, json} = Jason.encode(result.value, pretty: true)
```

Or in HEEx with rescue:
```heex
<pre class="font-mono text-xs whitespace-pre-wrap break-words text-base-content/80">
  {case Jason.encode(@result.value, pretty: true) do
    {:ok, json} -> json
    {:error, _} -> "[encoding error]"
  end}
</pre>
```

### Wiring in show.ex (Minimal Change)

```elixir
# Source: apps/athanor_web/lib/athanor_web/live/experiments/run_live/show.ex
# Add alias at top:
alias AthanorWeb.Experiments.Components.{StatusBadge, ProgressBar, LogPanel, ResultsPanel}

# Replace inline results div in render/1:
<ResultsPanel.results_panel streams={@streams} result_count={@result_count} />
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Server-side toggle (assigns + `phx-click`) | `JS.toggle_class("hidden")` | LiveView 0.20+ | Pure client-side, no WebSocket roundtrip, survives DOM patches |
| Custom JS hook for expand/collapse | `JS.toggle_class` + dynamic selectors | LiveView 0.20+ | No custom JS needed for UI-only interactions |
| Static JSON `<pre>` block | Dual panel (tree + JSON toggle) | This phase | Users can navigate nested data without reading raw JSON |
| Inline HEEx in LiveView show module | Extracted `Phoenix.Component` | LiveView 0.18+ component pattern | Testable, reusable, isolated rendering logic |

**Deprecated/outdated:**
- Direct `@logs` / `@results` assigns for lists: replaced by streams (`stream/4` + `stream_insert/4`) since LiveView 0.19. The current `show.ex` already uses streams correctly.
- `Jason.encode!` (bang variant) in production templates: prefer `Jason.encode/2` + `{:ok, json}` pattern to avoid crashing on malformed data.

## Open Questions

1. **Should tree nodes start expanded or collapsed by default?**
   - What we know: The success criterion says "collapsible tree with expandable nodes" — implies collapsed is the default state (hidden children visible on click).
   - What's unclear: Whether top-level keys should be expanded by default to provide orientation, with only second-level+ collapsed.
   - Recommendation: Render first-level map keys expanded (children visible, no `hidden` class initially). Nested objects/arrays start collapsed (`class="hidden"`). This provides context while limiting initial visual noise.

2. **What happens to tree expand state when a result is updated via stream_insert?**
   - What we know: `stream_insert` without a `reset: true` only appends new items or updates items with the same ID. Results do not update in place — they are append-only (one-directional writes via RunBuffer). So existing result cards are never re-rendered.
   - What's unclear: The RunBuffer flushes results via `Broadcasts.results_added` — these are always new results, never updates to existing ones. So expand state is safe.
   - Recommendation: No action needed — expand state is preserved by design.

3. **Result count display — should it show total or streaming count?**
   - What we know: `result_count` is maintained as an assign in `show.ex` via `update(:result_count, &(&1 + 1))`. This is accurate.
   - What's unclear: Whether to display it in the panel header or omit it.
   - Recommendation: Display `@result_count` as a secondary label (e.g., "3 results") in the panel header, using `text-base-content/60`. Follows the same pattern as log count display in LogPanel.

4. **How deep can result values nest before performance degrades?**
   - What we know: The recursive component renders synchronously on the server. Very deeply nested maps (20+ levels) would produce large HTML. However, experiment results are typically shallow scientific data (scores, metrics, config snapshots) — not arbitrary depth trees.
   - What's unclear: Whether any real experiment in the codebase produces very deep nesting.
   - Recommendation: Cap depth at rendering level if needed with a `@depth >= 10` guard that falls back to raw `Jason.encode!`. For now, implement without cap and add one if profiling reveals an issue.

## Sources

### Primary (HIGH confidence)
- `deps/phoenix_live_view/lib/phoenix_live_view/js.ex` — `JS.toggle_class/2` API with `:to` selector option; DOM-patch-aware guarantee documented
- `apps/athanor_web/lib/athanor_web/live/experiments/run_live/show.ex` — existing result stream infrastructure (`:result_added`, `:results_added` handlers), existing `Jason.encode!` usage
- `apps/athanor/lib/athanor/experiments/result.ex` — `Result.value :map` field confirmed; stream item has `.id`, `.key`, `.value`
- `apps/athanor/lib/athanor/experiments.ex` — `list_results/2` accepts `:limit` (already available, not needed for results)
- `apps/athanor/lib/athanor/experiments/broadcasts.ex` — `results_added(run_id, results)` broadcasts actual result structs (not just count)
- `apps/athanor_web/lib/athanor_web/live/experiments/components/log_panel.ex` — LogPanel extraction pattern to follow exactly
- `.planning/phases/01-visual-identity-and-theme-foundation/DESIGN-TOKENS.md` — semantic color rules, `text-base-content/60`, `text-base-content/40`

### Secondary (MEDIUM confidence)
- [Phoenix.LiveView.JS docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.JS.html) — `JS.toggle_class` DOM-patch-aware behavior confirmed in official docs
- [fly.io: My Favorite new LiveView Feature (JS.toggle_class)](https://fly.io/phoenix-files/my-favorite-new-liveview-feature/) — Dynamic ID pattern `to: "#item-#{item.id} > .child"`, chevron rotation with `toggle_class("rotate-180")`
- [davidbishai.com: Recursive Phoenix Components (Dec 2024)](https://davidbishai.com/elixir/phoenix/2024/12/14/recursive-phoenix-components.html) — Confirmed workaround: reassign to `assigns` map before using in HEEx template; avoids change-tracking compiler warnings

### Tertiary (LOW confidence)
- [Elixir Forum: Tree explorer with LiveView](https://elixirforum.com/t/using-liveview-to-implement-a-tree-explorer-will-expanding-nested-nodes-work-with-temporary-assigns/43335) — Confirms client-side JS toggle is preferred over server-side state for tree expand/collapse; not verified against current LiveView version
- [Elixir Forum: Streams with recursive schemas (Jan 2025)](https://elixirforum.com/t/using-streams-with-recursive-and-or-deeply-nested-schemas/69023) — Confirms nested streams are inadvisable; for results panel, results are streamed (not their nested values), which is correct

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified in installed deps source and existing project code
- Architecture: HIGH — recursive Phoenix.Component is confirmed working pattern; `JS.toggle_class` API verified in LiveView 1.1.24 source; LogPanel extraction pattern is directly observable
- Pitfalls: HIGH (DOM ID uniqueness, `phx-update` placement) — derived from existing code analysis; MEDIUM (recursive component compiler warning) — confirmed from secondary source, not tested in this specific codebase

**Research date:** 2026-02-16
**Valid until:** 2026-03-16 (LiveView JS API is stable; DaisyUI semantic conventions locked by Phase 1)
