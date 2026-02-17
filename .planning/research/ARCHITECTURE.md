# Architecture Research

**Domain:** Phoenix LiveView UI Components — Data-heavy dashboard
**Researched:** 2026-02-16
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     LiveView Pages (Routed)                      │
├──────────────────────┬──────────────────────┬───────────────────┤
│  InstanceLive.Index  │  InstanceLive.Show   │  RunLive.Show     │
│  (list + live count) │  (runs + config)     │  (logs + results) │
└──────────┬───────────┴──────────┬───────────┴──────────┬────────┘
           │                      │                      │
           ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│               LiveComponents (stateful sub-sections)             │
├──────────────────────┬──────────────────────┬───────────────────┤
│  ConfigFormComponent │  LogPanelComponent   │  ResultsPanelComp │
│  (schema → fields)   │  (stream + scroll)   │  (stream + display│
└──────────┬───────────┴──────────┬───────────┴──────────┬────────┘
           │                      │                      │
           ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│             Function Components (stateless, reusable)            │
├──────────┬───────────┬──────────┬────────────┬──────────────────┤
│ Status   │ Progress  │ Config   │ Log Entry  │ Result Card      │
│ Badge    │ Bar       │ Field    │ Row        │                  │
└──────────┴───────────┴──────────┴────────────┴──────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────┐
│              JS Hooks (client-side behavior)                     │
├──────────────┬───────────────────┬──────────────────────────────┤
│  AutoScroll  │  VirtualScroll    │  ThemeToggle                 │
│  (existing)  │  (new — for logs) │  (phx:set-theme dispatch)    │
└──────────────┴───────────────────┴──────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `RunLive.Show` (LiveView) | Owns run state, PubSub subscription, log/result stream coordination | Full LiveView — mounts, handles_info, delegates sub-sections to LiveComponents |
| `LogPanelComponent` (LiveComponent) | Owns log stream, auto-scroll toggle state, log-level filtering | `live_component` with its own `handle_event` for scroll toggle; receives new logs via `send_update` or parent `stream_insert` |
| `ResultsPanelComponent` (LiveComponent) | Owns results stream display | `live_component`; receives new results from parent via stream |
| `ConfigFormComponent` (LiveComponent) | Owns schema-driven form state: list_items, selected_experiment, validation | `live_component` with its own `handle_event` for add/remove list items; keeps form state out of parent LiveView |
| `StatusBadge` (function component) | Render-only status display | Existing — keep as-is |
| `ProgressBar` (function component) | Render-only progress display | Existing — keep as-is |
| `ConfigField` (function component) | Render a single schema field (string/integer/boolean/list) | Extract from current `render_config_field` private functions in `InstanceLive.New` |
| `ThemeToggle` (function component + JS) | Render toggle; JS hook dispatches `phx:set-theme` | Root layout already handles the event — just need the toggle UI and a hook to push it |

## Recommended Project Structure

```
apps/athanor_web/lib/athanor_web/
├── live/
│   └── experiments/
│       ├── instance_live/
│       │   ├── index.ex          # Lists instances
│       │   ├── show.ex           # Instance detail + run list
│       │   └── new.ex            # Create instance form (delegates to ConfigFormComponent)
│       ├── run_live/
│       │   └── show.ex           # Run detail (delegates to LogPanel + ResultsPanel)
│       └── components/
│           ├── status_badge.ex           # Existing function component
│           ├── progress_bar.ex           # Existing function component
│           ├── config_field.ex           # New: schema-driven field rendering
│           ├── config_form_component.ex  # New: LiveComponent wrapping dynamic config form
│           ├── log_panel_component.ex    # New: LiveComponent for log stream + auto-scroll
│           └── results_panel_component.ex # New: LiveComponent for results stream
├── components/
│   ├── core_components.ex  # Existing — input, button, table, header, flash
│   ├── layouts.ex          # Existing
│   └── theme_toggle.ex     # New: function component + phx:set-theme dispatch
└── assets/
    └── js/
        ├── app.js                  # Existing — register hooks
        └── hooks/
            ├── auto_scroll.js      # Extract from app.js (or keep colocated)
            ├── virtual_scroll.js   # New: windowed rendering for 10k+ log entries
            └── theme_toggle.js     # New: dispatches phx:set-theme on click
```

### Structure Rationale

- **`live/experiments/components/`:** Components that are experiment-domain-specific live here, co-located with the LiveViews that use them. This keeps the `core_components.ex` clean for app-wide primitives.
- **`components/theme_toggle.ex`:** Theme switching is app-wide (not experiment-specific) so it belongs in the shared components folder.
- **LiveComponent vs function component boundary:** Use `LiveComponent` when the component needs its own `handle_event` or `handle_info` callbacks (log panel scroll toggle, config form list item mutations). Use function components for pure rendering.
- **`hooks/` subfolder:** Once there are more than two hooks, splitting them into individual files and importing them into `app.js` improves maintainability. `phoenix-colocated` is already in use for colocated hooks — the hooks subfolder is for hooks that cannot be meaningfully colocated with a HEEx template.

## Architectural Patterns

### Pattern 1: LiveComponent for Sub-Page State Isolation

**What:** Extract a dashboard section (logs, results, config form) into a `Phoenix.LiveComponent` so its local state and event handlers are isolated from the parent LiveView.

**When to use:** When a section has its own interactive state (scroll toggle, list-item add/remove, filter state) that should not pollute the parent LiveView's assigns.

**Trade-offs:** Slightly more indirection; `send_update/3` is needed when the parent wants to push data into the component. Worth it when the parent LiveView is otherwise growing too large.

**Example:**

```elixir
# In RunLive.Show render/1:
<.live_component
  module={AthanorWeb.Experiments.Components.LogPanelComponent}
  id="log-panel"
  run={@run}
  log_count={@log_count}
/>

# LogPanelComponent handles its own auto_scroll state:
defmodule AthanorWeb.Experiments.Components.LogPanelComponent do
  use AthanorWeb, :live_component

  def mount(socket) do
    {:ok, assign(socket, :auto_scroll, true)}
  end

  def handle_event("toggle_auto_scroll", _params, socket) do
    {:noreply, assign(socket, :auto_scroll, !socket.assigns.auto_scroll)}
  end
end
```

### Pattern 2: Parent LiveView Owns the Stream, Component Renders It

**What:** The parent LiveView subscribes to PubSub and owns `stream(:logs, ...)` in its socket. It passes stream data to a LiveComponent via assigns. New items are inserted by the parent with `stream_insert`, and the component re-renders the changed rows only.

**When to use:** When multiple components need the same stream, or when PubSub subscription logic belongs at the page level.

**Trade-offs:** The parent must still `stream_insert` on each new item. The component cannot independently scroll-to-bottom without a JS hook. This is the right split: LiveView owns data lifecycle, component owns presentation behavior.

**Example:**

```elixir
# Parent: handle_info drives stream updates
def handle_info({:log_added, log}, socket) do
  socket =
    socket
    |> update(:log_count, &(&1 + 1))
    |> stream_insert(:logs, log)
  {:noreply, socket}
end

# Component render uses @streams.logs passed from parent
# (streams are accessible in child components when defined in parent)
```

### Pattern 3: Schema-Driven Field Rendering via Function Components

**What:** Replace the private `defp render_config_field/1` clause chain in `InstanceLive.New` with a public function component that pattern-matches on `field_def.type`.

**When to use:** When the same field-rendering logic is needed in multiple contexts (create form, edit form, config display).

**Trade-offs:** Small upfront refactor; enables field rendering to be reused in show pages without duplicating the clause chain.

**Example:**

```elixir
# config_field.ex
defmodule AthanorWeb.Experiments.Components.ConfigField do
  use Phoenix.Component

  attr :name, :atom, required: true
  attr :field_def, :map, required: true
  attr :path, :list, default: []
  attr :index, :integer, default: nil  # nil = not inside a list

  def config_field(%{field_def: %{type: :string}} = assigns) do
    ~H"""
    <div class="form-control">
      <label class="label"><span class="label-text">{humanize(@name)}</span></label>
      <input type="text" name={field_name(@path)} value={@field_def[:default]} class="input input-bordered w-full" />
    </div>
    """
  end

  # ... additional clauses for :integer, :boolean, :list
end
```

### Pattern 4: JS Hook for Virtual Scrolling (Log Panel)

**What:** When logs exceed ~2,000 entries, DOM size causes scroll jank. A virtual scroll hook renders only the visible window of entries, replacing the full DOM list with a fixed-height container and a positioned inner div.

**When to use:** When Phoenix streams will accumulate thousands of entries within a single browser session (streaming logs from long-running experiments).

**Trade-offs:** Significantly more complex JS than `AutoScroll`. The hook must intercept LiveView stream DOM mutations (via MutationObserver) to maintain its virtual window. Consider this only if testing confirms jank — the existing `AutoScroll` + stream approach handles hundreds of items fine.

**Example (hook structure):**

```javascript
// hooks/virtual_scroll.js
const VirtualScroll = {
  mounted() {
    this.rowHeight = parseInt(this.el.dataset.rowHeight) || 24
    this.visibleCount = Math.ceil(this.el.clientHeight / this.rowHeight) + 5
    this.scrollOffset = 0
    this.allItems = []

    this.observer = new MutationObserver((mutations) => {
      this.collectItems()
      this.render()
    })
    this.observer.observe(this.el.querySelector("#logs"), {
      childList: true,
      subtree: false
    })

    this.el.addEventListener("scroll", () => {
      this.scrollOffset = Math.floor(this.el.scrollTop / this.rowHeight)
      this.render()
    })
  },
  collectItems() {
    // Snapshot current DOM children from stream container
    this.allItems = Array.from(this.el.querySelectorAll("#logs > [id]"))
  },
  render() {
    const start = this.scrollOffset
    const end = Math.min(start + this.visibleCount, this.allItems.length)
    // Show only start..end, hide the rest via display:none or translate
  },
  destroyed() {
    this.observer?.disconnect()
  }
}
export default VirtualScroll
```

**Note:** An easier alternative to full virtualization is **log truncation on the server**: cap the stream at a maximum length (e.g., 1,000 entries) using `stream(:logs, logs, limit: 1000)`. Phoenix will automatically remove oldest DOM nodes. This is the recommended first step before investing in a virtual scroll hook.

### Pattern 5: Theme Toggle via phx:set-theme Event

**What:** The root layout already handles the `phx:set-theme` custom DOM event and stores the preference in `localStorage`. A theme toggle component only needs to dispatch this event.

**When to use:** Any time a user-facing theme switcher is needed. The infrastructure is already in place.

**Trade-offs:** None significant. The event is dispatched client-side, so no server roundtrip is needed. Theme preference persists across page loads via `localStorage`.

**Example:**

```javascript
// hooks/theme_toggle.js
const ThemeToggle = {
  mounted() {
    this.el.addEventListener("change", (e) => {
      const theme = e.target.value  // e.g. "light", "dark", "system"
      this.el.dispatchEvent(
        new CustomEvent("phx:set-theme", {
          bubbles: true,
          detail: {},
          target: this.el  // root.html.heex listener reads data-phx-theme from the element
        })
      )
    })
  }
}
```

```elixir
# theme_toggle.ex function component
attr :current_theme, :string, default: "system"

def theme_toggle(assigns) do
  ~H"""
  <select
    phx-hook="ThemeToggle"
    id="theme-toggle"
    data-phx-theme={@current_theme}
    class="select select-sm"
  >
    <option value="system">System</option>
    <option value="light">Light</option>
    <option value="dark">Dark</option>
  </select>
  """
end
```

## Data Flow

### Run Page Data Flow

```
PubSub: "experiments:run:{id}"
    │
    ▼
RunLive.Show (handle_info)
    │
    ├─ {:run_updated, run}       → assign(:run, run)         → StatusBadge re-renders
    ├─ {:log_added, log}         → stream_insert(:logs, log) → LogPanelComponent re-renders row
    ├─ {:logs_added, count}      → stream(:logs, ..., reset)  → LogPanelComponent full refresh
    ├─ {:result_added, result}   → stream_insert(:results)   → ResultsPanelComponent re-renders
    └─ {:progress_updated, pct}  → assign(:progress, pct)    → ProgressBar re-renders
```

### Config Form Data Flow

```
User selects experiment type
    │
    ▼
handle_event("select_experiment") in ConfigFormComponent
    │
    ▼
Discovery.get_config_schema(module) → config_schema assign
    │
    ▼
render/1 → ConfigField components (one per schema property)
    │
User fills fields / adds list items
    │
    ▼
handle_event("validate") → changeset → form assign
    │
handle_event("save") → parse_configuration → Experiments.create_instance
    │
    ▼
push_navigate to InstanceLive.Show
```

### Theme Data Flow (client-only)

```
User selects theme in ThemeToggle component
    │
    ▼
ThemeToggle JS hook dispatches "phx:set-theme" DOM event
    │
    ▼
root.html.heex inline script listener catches event
    │
    ├─ localStorage.setItem("phx:theme", theme)
    └─ document.documentElement.setAttribute("data-theme", theme)
         │
         ▼
    DaisyUI picks up data-theme → CSS variables update → page re-styles
    (no server roundtrip, no LiveView handle_event needed)
```

### State Management Summary

LiveView serves as the single source of truth for server-side state. There is no client-side state store (no Redux, no signals). The mapping is:

| State | Owner | Update mechanism |
|-------|-------|-----------------|
| Run status, timestamps, error | `RunLive.Show` assigns | PubSub `handle_info` |
| Log entries | `RunLive.Show` stream | `stream_insert` on PubSub message |
| Result entries | `RunLive.Show` stream | `stream_insert` on PubSub message |
| Auto-scroll toggle | `LogPanelComponent` assigns | `handle_event` in component |
| Log level filter | `LogPanelComponent` assigns | `handle_event` in component |
| Config form list items | `ConfigFormComponent` assigns | `handle_event` in component |
| Theme preference | Browser `localStorage` | JS only — never hits server |

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Runs with < 1,000 log entries | Current `phx-update="stream"` approach is fine |
| Runs with 1,000–10,000 log entries | Use `stream(:logs, logs, limit: 1000)` server-side cap; newest entries push out oldest DOM nodes |
| Runs with > 10,000 log entries | Implement virtual scroll JS hook; or paginate with server-driven cursor ("load more" button sending offset to server) |
| Many concurrent viewers of same run | Existing PubSub broadcast pattern scales horizontally; each LiveView process independently subscribes |

### Scaling Priorities

1. **First bottleneck:** DOM size from unbounded log stream. Fix with `stream` limit option before adding JS complexity.
2. **Second bottleneck:** If result values contain large JSON blobs, `Jason.encode!(result.value, pretty: true)` on every re-render becomes expensive. Fix by moving the encode to the backend context layer and storing the pre-formatted string, or truncating display.

## Anti-Patterns

### Anti-Pattern 1: Inlining All Component State in the Parent LiveView

**What people do:** Keep `auto_scroll`, `log_filter`, `list_items`, `selected_experiment`, and form state all as flat assigns on the parent LiveView.

**Why it's wrong:** The parent LiveView's `mount/3` and `handle_event/3` become crowded with concerns from multiple sub-sections. It also means every event for the log panel triggers a full LiveView diff for the entire page.

**Do this instead:** Move interactive sub-sections to `LiveComponent`. Each component owns its local state and handles its own events. The parent LiveView only coordinates PubSub subscriptions and stream data.

### Anti-Pattern 2: Using `stream` for Config Schema Fields

**What people do:** Treat the config schema fields as a stream for dynamic forms.

**Why it's wrong:** Config schema properties are not independently updateable rows — they are a cohesive form. Streams are optimized for append-only lists of independent items (logs, results). Schema-driven forms update holistically when the selected experiment changes.

**Do this instead:** Keep config schema as a plain assign (`config_schema`) and render it with function component pattern-matching on field types.

### Anti-Pattern 3: Calling Discovery / Repo from Inside Component render/1

**What people do:** Call `Discovery.get_config_schema/1` or `Experiments.list_logs/1` inside a function component or inside a `render/1` callback.

**Why it's wrong:** `render/1` is called on every diff cycle. Database calls inside render create N+1 style performance problems.

**Do this instead:** All data fetching happens in `mount/1`, `handle_event/3`, or `handle_info/2`. Components receive data via assigns, never fetch it themselves.

### Anti-Pattern 4: Dispatching `phx:set-theme` to the Server

**What people do:** Wire up a `phx-click="set_theme"` event that sends theme preference to the server, which then pushes a JS command back.

**Why it's wrong:** Theme switching is entirely a CSS-variable / localStorage concern. The server has no need to know the current theme. Adding a server roundtrip for this adds latency and unnecessary state to the LiveView.

**Do this instead:** The root layout's inline script already handles `phx:set-theme`. The toggle only needs to dispatch that DOM event client-side via a JS hook. No `handle_event` needed.

### Anti-Pattern 5: Rendering Log Metadata with `inspect/1` in the Template

**What people do:** Output `{inspect(log.metadata)}` in the HEEx template (which is already present in the current run page).

**Why it's wrong:** `inspect/1` is for debugging and produces Elixir term syntax, not user-friendly output. For complex metadata maps this will also produce verbose strings on every render.

**Do this instead:** Either use `Jason.encode!(log.metadata)` for JSON output, or format the metadata fields explicitly. Move formatting to a private helper or to the backend context so the template stays clean.

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `RunLive.Show` LiveView ↔ `LogPanelComponent` | Assigns + stream; parent calls `stream_insert` | Component does not independently subscribe to PubSub; parent owns the subscription |
| `RunLive.Show` LiveView ↔ `ResultsPanelComponent` | Same pattern as log panel | |
| `InstanceLive.New` ↔ `ConfigFormComponent` | Component handles all form events; parent receives `save` result via `handle_info({:config_form_saved, params}, ...)` or component calls `notify_parent/1` | Use `send(self(), {:config_saved, params})` from component to notify parent |
| `ConfigFormComponent` ↔ `ConfigField` function components | Direct assigns pass-through | Function components are purely presentational |
| JS ThemeToggle hook ↔ root.html.heex | DOM custom event `phx:set-theme` | No LiveView server involvement |
| `AutoScroll` / `VirtualScroll` hook ↔ `LogPanelComponent` | `phx-hook` attribute; hook reads `data-auto-scroll` dataset | Hook observes DOM mutations from stream updates |

## Build Order

The components have the following dependency structure. Build leaf nodes first:

```
1. ConfigField (function component)
   — no dependencies

2. StatusBadge, ProgressBar (function components, existing)
   — keep as-is

3. ThemeToggle (function component + ThemeToggle JS hook)
   — depends on: existing root layout phx:set-theme infrastructure

4. ConfigFormComponent (LiveComponent)
   — depends on: ConfigField components

5. LogPanelComponent (LiveComponent)
   — depends on: AutoScroll hook (existing); optionally VirtualScroll hook

6. ResultsPanelComponent (LiveComponent)
   — depends on: nothing beyond core components

7. RunLive.Show refactor
   — depends on: LogPanelComponent, ResultsPanelComponent, ProgressBar, StatusBadge

8. InstanceLive.New refactor
   — depends on: ConfigFormComponent

9. VirtualScroll JS hook (optional)
   — depends on: LogPanelComponent being in place; add only if DOM size is measured to be a problem
```

## Sources

- Phoenix LiveView documentation: `Phoenix.LiveComponent` for stateful components, `Phoenix.LiveView.stream/4` for stream management
- DaisyUI theming: `data-theme` attribute on `<html>` element controls CSS variable cascade
- LiveView stream `limit` option: documented in `Phoenix.LiveView.stream/4` — drops oldest DOM nodes when stream exceeds limit
- Virtual scroll pattern: established UI pattern adapted for MutationObserver + LiveView stream interop
- `phoenix-colocated` dependency is already present in the project for colocated hook definitions

---
*Architecture research for: Phoenix LiveView UI component architecture — data-heavy dashboard*
*Researched: 2026-02-16*
