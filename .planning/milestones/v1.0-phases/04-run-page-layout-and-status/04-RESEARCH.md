# Phase 4: Run Page Layout and Status - Research

**Researched:** 2026-02-16
**Domain:** Phoenix LiveView layout, daisyUI tabs, sticky headers, reconnection handling, PubSub toasts
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Sticky Header Content
- Full dashboard: status badge + experiment name + elapsed time + progress indicator
- Stop/cancel button in header — primary action always visible
- Indeterminate spinner when experiment doesn't report progress
- Breadcrumb navigation: Experiment > Run #N — clear path back

#### Panel Arrangement
- Tabs all the time (not split view) — Logs | Results
- Logs tab is default when viewing a run
- Tabs show counts: "Logs (1,234)" and "Results (5)"
- Tab architecture designed for extensibility (future Controls tab)

#### State Presentation
- Running state: pulsing badge (subtle pulse animation, no spinner icon)
- End states: color-coded badges — green (success), red (failure), yellow (cancelled)
- Completion/failure notification: brief toast, delivered via global PubSub (visible on any page, not just run page)
- Elapsed time freezes at completion — shows final duration

#### Reconnection Behavior
- Subtle inline indicator in header: "Reconnecting (attempt 3)..."
- Keep retrying with exponential backoff — never give up
- After reconnection: show "Refresh" button for user to manually catch up on missed data
- No auto-refresh — user controls when to sync

### Claude's Discretion
- Exact header layout and spacing
- Tab component implementation details
- Specific backoff timing for reconnection
- Toast notification styling and duration

### Deferred Ideas (OUT OF SCOPE)
- Custom controls defined by experiment module (phases, steps, manual triggers) — next project, but tab architecture should accommodate a future "Controls" tab
</user_constraints>

---

## Summary

Phase 4 is a substantial layout refactor of the existing `RunLive.Show` LiveView. The current layout uses a simple `<.header>` + status info + side-by-side cards pattern that doesn't meet the "sticky header, always visible" requirement. The core work is restructuring the page into two zones: a sticky header (outside scroll) with all critical run status, and a full-height tab panel below for logs/results.

The current app layout (`layouts.ex`) uses `max-w-2xl` with `py-20` padding, which constrains content to a narrow column and adds excessive top space — both wrong for a monitoring dashboard. The run page needs a wider container and a different vertical structure. The cleanest approach is a dedicated `run` layout template that strips the narrow container, or modifying the existing `app` layout function to be more flexible via layout slots.

Reconnection detection is built into Phoenix LiveView via CSS classes (`phx-client-error`, `phx-server-error`, `phx-connected`) and JS hook callbacks (`disconnected`, `reconnected`). The reconnection attempt counter and "Reconnecting (attempt N)..." text require a custom JS hook that intercepts the Phoenix Socket reconnect timer and tracks attempts. Global PubSub toasts for run completion are straightforward: any LiveView can subscribe to `experiments:runs:active` and respond to `{:run_completed, run}` by emitting a flash message — but a true global toast (visible from any page) needs either a `LiveView.on_mount` hook on the root layout, or subscribing all live views via a shared module.

**Primary recommendation:** Refactor `RunLive.Show` with a dedicated wide layout, implement the sticky header as a `position: sticky; top: 0` element wrapping the run header card, use daisyUI `tabs` with `phx-click`-controlled active tab in assigns, add a JS hook for reconnection tracking, and use a global PubSub subscription (via `on_mount` or a shared `handle_info` in the root layout) for completion toasts.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView | ~1.1.0 | Reactive UI, socket lifecycle | Already in use — disconnect/reconnected hooks built-in |
| daisyUI | bundled in vendor | Tab, badge, toast components | Already in use — semantic classes for status badges |
| Tailwind CSS | bundled via tailwind dep | Layout utilities (sticky, flex, h-screen) | Already in use — sticky/overflow utilities needed |
| Phoenix.PubSub | bundled with Phoenix | Global run completion broadcasts | Already in use — `experiments:runs:active` topic exists |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phoenix.LiveView.JS | built-in | Client-side tab switching, CSS class toggling | Switching active tab without server round-trip |
| Process.send_after | Elixir stdlib | Elapsed time ticker (send `:tick` every 1s) | Only when run is in `running` state |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom JS hook for reconnection counter | phx-disconnected attribute | `phx-disconnected` runs JS once on disconnect, doesn't count attempts — hook gives access to `reconnected()` lifecycle and can count |
| `Process.send_after` tick for elapsed time | Client-side JS timer | Server-side tick is simpler, accurate, no drift, syncs with server state — JS timer fine too but adds hook complexity |
| Dedicated `run` layout | Slot-based flexible `app` layout | Dedicated layout is cleaner, less coupling, consistent with Phoenix conventions |

---

## Architecture Patterns

### Recommended Project Structure

The phase primarily modifies existing files. New files are minimal:

```
apps/athanor_web/lib/athanor_web/
├── components/
│   └── layouts.ex                        # Add run/1 layout function + run layout template
│       layouts/
│       └── run.html.heex                 # New: wide layout for run page (no max-w-2xl)
└── live/experiments/
    └── run_live/
        └── show.ex                       # Major refactor: sticky header + tab state
    └── components/
        ├── log_panel.ex                  # Refactor: remove card wrapper, accept active tab assign
        └── results_panel.ex             # Refactor: remove card wrapper, accept active tab assign

apps/athanor_web/assets/js/
└── app.js                               # Add ReconnectionTracker hook
```

### Pattern 1: Dedicated Run Layout

The current `app` layout in `layouts.ex` wraps content in `max-w-2xl`:

```elixir
# CURRENT (too narrow for monitoring dashboard):
<main class="px-4 py-20 sm:px-6 lg:px-8">
  <div class="mx-auto max-w-2xl space-y-4">
    {render_slot(@inner_block)}
  </div>
</main>
```

Add a `run/1` layout function and matching `run.html.heex` template:

```elixir
# In layouts.ex — add alongside app/1:
attr :flash, :map, required: true
slot :inner_block, required: true

def run(assigns) do
  ~H"""
  <.flash_group flash={@flash} />
  {render_slot(@inner_block)}
  """
end
```

```heex
<%# run.html.heex — minimal chrome, full viewport height %>
<div class="flex flex-col min-h-screen">
  {render_slot(@inner_block)}
</div>
```

Override layout in `RunLive.Show.mount/3`:

```elixir
# Source: Phoenix LiveView docs — mount opts
def mount(%{"id" => id}, _session, socket) do
  # ...
  {:ok, socket, layout: {AthanorWeb.Layouts, :run}}
end
```

**Confidence:** HIGH — verified in LV source: `phoenix_live_view/lib/phoenix_live_view/utils.ex:9` shows `:layout` is a valid mount option. `phoenix_live_view.ex:511` shows example usage.

### Pattern 2: Sticky Header

The sticky header sits at the top of the page viewport, not inside a scrollable container:

```heex
<div class="flex flex-col min-h-screen">
  <%# Sticky header — outside scroll container %>
  <div class="sticky top-0 z-10 bg-base-100 border-b border-base-300 shadow-sm px-4 sm:px-6 lg:px-8">
    <div class="max-w-7xl mx-auto py-3">
      <%# Breadcrumb, status badge, elapsed time, progress, cancel button %>
    </div>
  </div>

  <%# Tab bar and content — fills remaining height %>
  <div class="flex-1 flex flex-col overflow-hidden max-w-7xl mx-auto w-full px-4 sm:px-6 lg:px-8">
    <%# Tabs %>
    <%# Tab content panels — h-full overflow-y-auto %>
  </div>
</div>
```

Key CSS: `sticky top-0 z-10` on the header div. The tab content panels use `overflow-y-auto` with `flex-1` to fill remaining viewport height.

**Confidence:** HIGH — standard CSS sticky positioning, no framework-specific API.

### Pattern 3: Tab Switching via Server-Side Assigns

The tabs are controlled by a `:active_tab` assign on the LiveView. Clicking a tab sends a `phx-click` event:

```elixir
# In RunLive.Show:
|> assign(:active_tab, :logs)  # :logs | :results | :controls (future)

def handle_event("switch_tab", %{"tab" => tab}, socket) do
  {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
end
```

```heex
<div role="tablist" class="tabs tabs-border">
  <button
    role="tab"
    class={["tab", @active_tab == :logs && "tab-active"]}
    phx-click="switch_tab"
    phx-value-tab="logs"
  >
    Logs ({@log_count})
  </button>
  <button
    role="tab"
    class={["tab", @active_tab == :results && "tab-active"]}
    phx-click="switch_tab"
    phx-value-tab="results"
  >
    Results ({@result_count})
  </button>
</div>

<div class={["tab-content-panel flex-1 overflow-y-auto", @active_tab != :logs && "hidden"]}>
  <LogPanel.log_panel ... />
</div>
<div class={["tab-content-panel flex-1 overflow-y-auto", @active_tab != :results && "hidden"]}>
  <ResultsPanel.results_panel ... />
</div>
```

**Alternative:** Pure client-side tab switching with `JS.toggle_class`. This avoids server round-trips but doesn't let the server know which tab is active (matters if future tabs need conditional subscriptions). Server-side is simpler and consistent with existing patterns.

**Confidence:** HIGH — matches existing `phx-click` event patterns already in use in this codebase.

### Pattern 4: Pulsing Running Badge

The `StatusBadge` component needs to be extended for the `running` state to use a CSS `animate-pulse` class:

```elixir
# Update status_badge_class in StatusBadge:
defp badge_class("running"), do: "badge badge-info animate-pulse"
```

Tailwind's `animate-pulse` class produces a subtle fade in/out animation (opacity 1 → 0.5 → 1, 2s cycle). This is already available — Tailwind bundles `animate-pulse` by default.

**Confidence:** HIGH — `animate-pulse` is a standard Tailwind utility.

### Pattern 5: Elapsed Time Ticker

For a live elapsed time counter, use `Process.send_after` to tick every 1 second while running:

```elixir
# In mount:
socket = if run.status == "running" do
  Process.send_after(self(), :tick, 1_000)
  assign(socket, :elapsed_seconds, elapsed_since(run.started_at))
else
  assign(socket, :elapsed_seconds, final_elapsed(run))
end

# Handle tick:
def handle_info(:tick, socket) do
  if socket.assigns.run.status == "running" do
    Process.send_after(self(), :tick, 1_000)
    {:noreply, assign(socket, :elapsed_seconds, elapsed_since(socket.assigns.run.started_at))}
  else
    {:noreply, socket}  # Stop ticking when run ends
  end
end

# When run_updated changes status to terminal:
def handle_info({:run_updated, run}, socket) do
  socket = assign(socket, :run, run)
  socket = if run.status != "running" do
    assign(socket, :elapsed_seconds, final_elapsed(run))
  else
    socket
  end
  {:noreply, socket}
end
```

Elapsed time display: when `run.completed_at` is set, show frozen final duration. When running, show live `elapsed_seconds` formatted as `MM:SS` or `Xs`.

**Confidence:** HIGH — standard LiveView pattern, verified by existing `format_duration` helper already in `show.ex`.

### Pattern 6: Reconnection Hook (JS)

Phoenix LiveView exposes hook lifecycle callbacks `disconnected()` and `reconnected()`. A custom hook can track attempt count by counting how many times `disconnected()` fires without a `reconnected()`:

```javascript
// In app.js Hooks:
ReconnectionTracker: {
  mounted() {
    this.attempts = 0
    this.reconnecting = false
  },
  disconnected() {
    this.reconnecting = true
    this.attempts = 0

    // Poll Phoenix socket for reconnect attempts
    // Phoenix socket's reconnectTimer fires with exponential backoff:
    // [10, 50, 100, 150, 200, 250, 500, 1000, 2000] ms then 5000ms
    this.attemptInterval = setInterval(() => {
      this.attempts += 1
      this.pushEvent("reconnecting", { attempt: this.attempts })
    }, 2000)  // Check every 2s — rough attempt counter
  },
  reconnected() {
    this.reconnecting = false
    clearInterval(this.attemptInterval)
    this.pushEvent("reconnected", {})
  }
}
```

The server maintains `:reconnecting` and `:reconnect_attempts` assigns, rendered in the sticky header:

```elixir
# In RunLive.Show assigns:
|> assign(:reconnecting, false)
|> assign(:reconnect_attempts, 0)
|> assign(:needs_refresh, false)

def handle_event("reconnecting", %{"attempt" => n}, socket) do
  {:noreply, assign(socket, reconnecting: true, reconnect_attempts: n)}
end

def handle_event("reconnected", _params, socket) do
  {:noreply, assign(socket, reconnecting: false, needs_refresh: true)}
end
```

```heex
<%# In sticky header: %>
<span :if={@reconnecting} class="text-sm text-warning">
  Reconnecting (attempt {@reconnect_attempts})...
</span>
<button :if={@needs_refresh} phx-click="refresh_data" class="btn btn-sm btn-ghost">
  Refresh
</button>
```

The hook element needs a stable DOM ID; attach it to the sticky header wrapper div with `phx-hook="ReconnectionTracker"`.

**Confidence:** HIGH for hook lifecycle (verified in LV source). MEDIUM for the attempt-counting approach — Phoenix socket doesn't expose attempt count directly, so interval-based polling is an approximation.

### Pattern 7: Global Run Completion Toast

The `experiments:runs:active` PubSub topic already exists and broadcasts `{:run_completed, run}`. To show a toast on any page:

**Option A: Subscribe in each relevant LiveView's mount.**
Simple but requires code in every LiveView.

**Option B: Use `on_mount` in a shared module subscribed at the root layout level.**
Cleaner — add to the router's `live_session` or as an `on_mount` hook.

Given the project doesn't currently use `live_session`, Option A with a shared helper module is the pragmatic approach. Create a module that provides `subscribe_to_run_events/1` and a matching `handle_run_events/2`:

```elixir
defmodule AthanorWeb.RunEventSubscriber do
  def subscribe_to_active_runs(socket) do
    if Phoenix.LiveView.connected?(socket) do
      Phoenix.PubSub.subscribe(Athanor.PubSub, "experiments:runs:active")
    end
    socket
  end

  def handle_run_completion({:run_completed, run}, socket) do
    msg = case run.status do
      "completed" -> "Run completed successfully"
      "failed" -> "Run failed: #{run.error}"
      "cancelled" -> "Run was cancelled"
      _ -> nil
    end
    if msg, do: Phoenix.LiveView.put_flash(socket, :info, msg), else: socket
  end
end
```

The existing `CoreComponents.flash/1` component already renders as a `toast toast-top toast-end` daisyUI toast. Flash messages automatically display via the layout's `<.flash_group flash={@flash} />`.

**Confidence:** HIGH — the existing flash component IS a toast. No additional toast library needed.

### Anti-Patterns to Avoid

- **Nesting sticky header inside a scrollable container:** `position: sticky` only works relative to the nearest scrollable ancestor. The header must be a sibling of (not child of) the scrolling panel.
- **Using daisyUI's built-in tab radio-input pattern:** DaisyUI tabs can use radio inputs for pure-CSS switching, but this won't work with LiveView's DOM patching. Use `phx-click` + server-side `:active_tab` assign instead.
- **Auto-refresh on reconnect:** The decision is explicit — no auto-refresh. Show the "Refresh" button. Don't `push_navigate` or call `mount` logic again automatically.
- **Overusing JS.toggle_class for tab switching:** JS.toggle_class survives DOM patches (used successfully in Phase 3 for tree expand/collapse), but for tabs the server needs to know which tab is active for count display and potential future functionality.
- **Using `put_flash` from `handle_info` for run completion on run page:** The run page already shows the run's terminal state visually. Only non-run-page LiveViews need the toast. Add logic to skip the flash when `socket.assigns[:run]&.id == run.id`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Toast notifications | Custom toast component | `CoreComponents.flash/1` (already renders as daisyUI toast toast-top toast-end) | Already implemented, auto-renders via flash_group in layout |
| Tab component | Custom tab implementation | daisyUI `tabs` classes + server assigns | daisyUI handles styling, accessibility attributes (role="tab") |
| Status badges | Re-implement StatusBadge | Extend existing `StatusBadge` in `status_badge.ex` | It's already pattern-matched per status — just add `animate-pulse` to running |
| Reconnection backoff | Custom exponential backoff in JS | Phoenix Socket handles backoff natively: `[10, 50, 100, 150, 200, 250, 500, 1000, 2000]ms then 5000ms` | Just count disconnect/reconnect events in hook |

**Key insight:** The existing flash/toast infrastructure is already correct for the global completion notification requirement. No new toast library or custom JS needed.

---

## Common Pitfalls

### Pitfall 1: max-w-2xl Layout Constraint

**What goes wrong:** Implementing the new layout inside the existing `app` layout function leaves the `max-w-2xl` container active, making a full-width monitoring dashboard impossible.

**Why it happens:** The current `layouts.ex` `app/1` function unconditionally wraps content in `<div class="mx-auto max-w-2xl space-y-4">`.

**How to avoid:** Add a separate `run/1` layout function (and `run.html.heex` template) without the width constraint. In `RunLive.Show.mount/3`, return `{:ok, socket, layout: {AthanorWeb.Layouts, :run}}`.

**Warning signs:** If the run page looks narrow or the sticky header doesn't span full width, the layout override isn't working.

### Pitfall 2: Sticky Header Inside Overflow Container

**What goes wrong:** The sticky header scrolls away with the page content instead of staying fixed.

**Why it happens:** `position: sticky` only works when the element's scroll container allows it. If the header's parent has `overflow: hidden` or `overflow: auto`, sticky won't work.

**How to avoid:** Structure as: body > [sticky header] + [flex-1 overflow-y-auto panel]. The sticky element must be a direct or near-direct child of the viewport scroll container (the `<body>` or a `min-h-screen` element without overflow hidden).

**Warning signs:** `sticky top-0` class present but header scrolls with content. Check parent elements for `overflow` CSS properties.

### Pitfall 3: Elapsed Time Not Freezing at Completion

**What goes wrong:** The elapsed time keeps incrementing after the run completes because the tick loop isn't stopped.

**Why it happens:** `Process.send_after` fires even after run completion if the condition check in `handle_info(:tick, socket)` doesn't stop recursion.

**How to avoid:** In `handle_info(:tick, socket)`, only call `Process.send_after(self(), :tick, 1_000)` when `socket.assigns.run.status == "running"`. When `handle_info({:run_updated, run}, socket)` receives a terminal status, set the frozen elapsed time and ensure no new tick is scheduled.

**Warning signs:** Elapsed time increments past when `completed_at` was set.

### Pitfall 4: Reconnection Hook Pushes Events After Destroy

**What goes wrong:** `pushEvent` called in `setInterval` callback after the hook's element is destroyed (navigation away), causing errors.

**Why it happens:** The interval keeps firing after the LiveView is destroyed.

**How to avoid:** Implement `destroyed()` in the hook:
```javascript
destroyed() {
  clearInterval(this.attemptInterval)
}
```

**Warning signs:** Console errors like "cannot push event, view is destroyed" after navigating away from the run page.

### Pitfall 5: Flash from `handle_info` on Run Page Itself

**What goes wrong:** The run page LiveView shows "Run completed successfully" toast even though the terminal status badge is clearly visible in the sticky header.

**Why it happens:** If the run page subscribes to `experiments:runs:active` AND handles the completion event with `put_flash`, the user gets redundant notification.

**How to avoid:** In the global completion handler, check if the current socket's run is the completed run and skip the flash in that case:
```elixir
def handle_info({:run_completed, run}, socket) do
  if socket.assigns[:run] && socket.assigns.run.id == run.id do
    {:noreply, socket}  # Run page already shows status — skip toast
  else
    {:noreply, put_flash(socket, :info, completion_message(run))}
  end
end
```

### Pitfall 6: Tab `hidden` Class Not Compatible with Stream

**What goes wrong:** The log stream's DOM elements become orphaned or lose their IDs when the logs panel is hidden/shown via `hidden` class + LiveView DOM patches.

**Why it happens:** LiveView streams track DOM elements by ID. If the parent container is `hidden`, LiveView still patches the DOM — elements don't disappear from the DOM, just from view. This should be fine.

**How to avoid:** Use `hidden` Tailwind class (CSS `display: none`) rather than removing elements from the template. Streams with `phx-update="stream"` work correctly in hidden containers.

**Warning signs:** Log entries appear duplicated or in wrong order after tab switch. Test by switching tabs multiple times while logs are streaming.

---

## Code Examples

### Run Layout Template

```elixir
# In layouts.ex — add alongside app/1:
attr :flash, :map, required: true
slot :inner_block, required: true

def run(assigns) do
  ~H"""
  <.flash_group flash={@flash} />
  <div class="flex flex-col min-h-screen bg-base-100">
    {render_slot(@inner_block)}
  </div>
  """
end
```

```heex
<%# run.html.heex — strips the max-w-2xl navbar chrome, keeps flash %>
<%# Note: flash_group is rendered in the run/1 function above %>
{@inner_content}
```

Actually, in Phoenix LiveView, the `run.html.heex` template corresponds to the function component. The simplest approach: don't use a `.heex` template — define `run/1` directly in `layouts.ex` as a function component (as shown above).

### Sticky Header Structure

```heex
<%# RunLive.Show render/1 — top level: %>
<div class="flex flex-col min-h-screen">

  <%# Sticky header zone %>
  <header class="sticky top-0 z-10 bg-base-100 border-b border-base-300 shadow-sm">
    <div class="px-4 sm:px-6 lg:px-8 py-3">
      <%# Breadcrumb row %>
      <div class="flex items-center gap-2 text-sm text-base-content/60 mb-2">
        <.link navigate={~p"/experiments"} class="hover:text-base-content">Experiments</.link>
        <span>/</span>
        <.link navigate={~p"/experiments/#{@instance.id}"} class="hover:text-base-content">
          {@instance.name}
        </.link>
        <span>/</span>
        <span class="text-base-content">Run {short_id(@run.id)}</span>
      </div>

      <%# Status row %>
      <div class="flex items-center gap-4 flex-wrap">
        <StatusBadge.status_badge status={@run.status} />

        <span class="font-medium">{@instance.name}</span>

        <span class="text-sm text-base-content/60">
          {format_elapsed(@run, @elapsed_seconds)}
        </span>

        <%# Progress: indeterminate spinner or bar %>
        <div :if={@run.status == "running"} class="flex items-center gap-2">
          <ProgressBar.progress_bar status={@run.status} progress={@progress} compact={true} />
        </div>

        <%# Reconnection indicator %>
        <span :if={@reconnecting} class="text-sm text-warning ml-2">
          Reconnecting (attempt {@reconnect_attempts})...
        </span>

        <%# Spacer + actions %>
        <div class="ml-auto flex items-center gap-2">
          <button
            :if={@needs_refresh}
            phx-click="dismiss_refresh"
            class="btn btn-sm btn-ghost"
          >
            Refresh
          </button>
          <button
            :if={@run.status == "running"}
            phx-click="cancel_run"
            class="btn btn-sm btn-warning"
            data-confirm="Cancel this run?"
          >
            <.icon name="hero-stop" class="size-4 mr-1" /> Cancel
          </button>
        </div>
      </div>

      <%# Error display %>
      <div :if={@run.error} class="mt-2 text-sm text-error flex items-center gap-1">
        <.icon name="hero-exclamation-circle" class="size-4" />
        {@run.error}
      </div>
    </div>
  </header>

  <%# Tab bar + content zone %>
  <div class="flex-1 flex flex-col overflow-hidden px-4 sm:px-6 lg:px-8">
    ...
  </div>
</div>
```

### Tab Panel with Server-Side Active State

```heex
<div class="flex-1 flex flex-col overflow-hidden">
  <%# Tab bar %>
  <div role="tablist" class="tabs tabs-border border-b border-base-300 mt-4">
    <button
      role="tab"
      class={["tab", @active_tab == :logs && "tab-active"]}
      phx-click="switch_tab"
      phx-value-tab="logs"
    >
      Logs ({@log_count})
    </button>
    <button
      role="tab"
      class={["tab", @active_tab == :results && "tab-active"]}
      phx-click="switch_tab"
      phx-value-tab="results"
    >
      Results ({@result_count})
    </button>
  </div>

  <%# Tab panels — flex-1 + overflow-y-auto makes each fill remaining height %>
  <div class={["flex-1 overflow-y-auto py-4", @active_tab != :logs && "hidden"]}>
    <LogPanel.log_panel streams={@streams} auto_scroll={@auto_scroll} log_count={@log_count} />
  </div>
  <div class={["flex-1 overflow-y-auto py-4", @active_tab != :results && "hidden"]}>
    <ResultsPanel.results_panel streams={@streams} result_count={@result_count} />
  </div>
</div>
```

### Extended Status Badge for Pulsing Running State

```elixir
# In status_badge.ex — replace running clause:
defp badge_class("running"), do: "badge badge-info animate-pulse"
defp badge_class("completed"), do: "badge badge-success"
defp badge_class("failed"), do: "badge badge-error"
defp badge_class("cancelled"), do: "badge badge-warning"
defp badge_class("pending"), do: "badge badge-ghost"
defp badge_class(_), do: "badge"
```

### Elapsed Time Helpers

```elixir
# In RunLive.Show:
defp format_elapsed(%{completed_at: completed_at, started_at: started_at}, _)
    when not is_nil(completed_at) and not is_nil(started_at) do
  format_duration(started_at, completed_at)
end

defp format_elapsed(%{status: "running", started_at: started_at}, elapsed_seconds)
    when not is_nil(started_at) do
  format_seconds(elapsed_seconds)
end

defp format_elapsed(_, _), do: ""

defp elapsed_since(nil), do: 0
defp elapsed_since(started_at) do
  DateTime.diff(DateTime.utc_now(), started_at, :second)
end

defp format_seconds(s) when s < 60, do: "#{s}s"
defp format_seconds(s) do
  m = div(s, 60)
  sec = rem(s, 60)
  "#{m}m #{sec}s"
end
```

### Mount with Layout Override and Tick

```elixir
def mount(%{"id" => id}, _session, socket) do
  run =
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Athanor.PubSub, "experiments:run:#{id}")
      # Subscribe to global run events for toast on OTHER pages — skip on run page
      # (not needed here since run page shows status directly)
      Experiments.get_run!(id) |> Athanor.Repo.preload(:instance)
    else
      Experiments.get_run!(id) |> Athanor.Repo.preload(:instance)
    end

  # Start tick only if running
  if connected?(socket) && run.status == "running" do
    Process.send_after(self(), :tick, 1_000)
  end

  elapsed = if run.status == "running", do: elapsed_since(run.started_at), else: 0

  socket =
    socket
    |> assign(:run, run)
    |> assign(:instance, run.instance)
    |> assign(:progress, nil)
    |> assign(:active_tab, :logs)
    |> assign(:auto_scroll, true)
    |> assign(:log_count, length(logs))
    |> assign(:result_count, length(results))
    |> assign(:elapsed_seconds, elapsed)
    |> assign(:reconnecting, false)
    |> assign(:reconnect_attempts, 0)
    |> assign(:needs_refresh, false)
    |> stream(:logs, logs, limit: -@log_stream_limit)
    |> stream(:results, hydrated_results)

  {:ok, socket, layout: {AthanorWeb.Layouts, :run}}
end
```

### Reconnection JS Hook

```javascript
// In app.js Hooks:
ReconnectionTracker: {
  mounted() {
    this.attempts = 0
    this.attemptInterval = null
  },
  disconnected() {
    this.attempts = 0
    // Count attempts roughly — Phoenix reconnects at ~2s+ intervals after initial fast retries
    this.attemptInterval = setInterval(() => {
      this.attempts += 1
      this.pushEvent("reconnecting", { attempt: this.attempts })
    }, 2000)
  },
  reconnected() {
    clearInterval(this.attemptInterval)
    this.attemptInterval = null
    this.pushEvent("reconnected", {})
  },
  destroyed() {
    clearInterval(this.attemptInterval)
  }
}
```

### Global Run Completion Toast (for other pages)

```elixir
# In InstanceLive.Show (and any other page that should show completion toasts):
def mount(%{"id" => id}, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Athanor.PubSub, "experiments:instance:#{id}")
    Phoenix.PubSub.subscribe(Athanor.PubSub, "experiments:runs:active")
  end
  # ...
end

def handle_info({:run_completed, run}, socket) do
  msg = case run.status do
    "completed" -> "Run completed successfully"
    "failed" -> "Run failed"
    "cancelled" -> "Run cancelled"
    _ -> nil
  end
  socket = if msg, do: put_flash(socket, :info, msg), else: socket
  {:noreply, socket}
end
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Simple `<.header>` + side-by-side cards | Sticky header + tabs | Must refactor show.ex layout; cards become tab content |
| `badge badge-info` for running (static) | `badge badge-info animate-pulse` | One-line change to StatusBadge |
| Full app layout (max-w-2xl) | Dedicated run layout | Needs new layout function + mount option |
| No elapsed time display (only completed duration) | Live tick + frozen final | Needs `Process.send_after` tick pattern |
| No reconnection UX | JS hook + server assigns | New hook in app.js + new assigns/events in show.ex |
| No global completion toast | PubSub subscribe on other pages | Other live views subscribe to `experiments:runs:active` |

---

## Open Questions

1. **Refresh behavior after reconnection: what data needs catching up?**
   - What we know: After socket reconnect, LiveView remounts automatically — `mount/3` runs again, loading fresh data from DB. So there may be no actual data gap.
   - What's unclear: Does LiveView remount fully on reconnect, or does it attempt to restore state? If it remounts, the "Refresh" button may be unnecessary.
   - Recommendation: Test actual reconnect behavior. If LiveView remounts cleanly, the "Refresh" button becomes "you're now up to date" — show it briefly then auto-hide. If it doesn't remount (state restoration), manually re-fetch missed data in `reconnected()` hook by pushing an event that triggers a re-query.

2. **Layout: function component or embed_templates?**
   - What we know: `embed_templates "layouts/*"` in `layouts.ex` auto-generates a function for each `.html.heex` file. Adding `run.html.heex` would generate `run/1` automatically. Alternatively, define `run/1` directly in `layouts.ex` as a HEEx function.
   - What's unclear: Whether `embed_templates` is required or if direct function definition in `layouts.ex` is sufficient.
   - Recommendation: Direct function definition in `layouts.ex` (no new `.heex` file) is simpler and avoids a new file. The `app/1` function shows this pattern is already used. The `run/1` function can just wrap content without the navbar chrome.

3. **Where should the Refresh button handler live?**
   - What we know: The "Refresh" button needs to re-fetch fresh data after reconnect. For logs, re-querying would send 1000 entries via stream reset. For results, same.
   - What's unclear: Whether re-querying is expensive enough to require optimization.
   - Recommendation: On "refresh_data" event, re-query and `stream` reset logs/results (same as initial mount). This is safe and consistent. If performance is a concern, timestamp-based differential catch-up could be added later.

---

## Sources

### Primary (HIGH confidence)
- Phoenix LiveView source: `deps/phoenix_live_view/lib/phoenix_live_view/utils.ex:9` — `:layout` is a valid mount option
- Phoenix LiveView source: `deps/phoenix_live_view/lib/phoenix_live_view.ex:511` — `layout:` usage example in `on_mount`
- Phoenix LiveView source: `deps/phoenix_live_view/assets/js/phoenix_live_view/view_hook.ts:376-386` — `disconnected()` and `reconnected()` hook lifecycle
- Phoenix Socket source: `deps/phoenix/priv/static/phoenix.js:1117-1123` — reconnection backoff array `[10, 50, 100, 150, 200, 250, 500, 1000, 2000]ms then 5000ms`
- daisyUI vendor: `assets/vendor/daisyui.js:723` — tab classes: `tabs`, `tab`, `tab-active`, `tabs-border`, `tab-content`
- Codebase: `apps/athanor_web/lib/athanor_web/components/layouts.ex:65-67` — confirmed `max-w-2xl` constraint
- Codebase: `apps/athanor_web/lib/athanor_web/components/core_components.ex:49-78` — flash component renders as `toast toast-top toast-end`
- Codebase: `apps/athanor_web/lib/athanor_web/live/experiments/run_live/show.ex` — full current state
- Codebase: `apps/athanor_web/assets/js/app.js` — existing AutoScroll hook pattern

### Secondary (MEDIUM confidence)
- Phoenix LiveView docs pattern for on_mount layout override (seen in LV source line 511)
- Tailwind CSS `animate-pulse` — standard utility (in use across many Tailwind projects)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in use, verified from source
- Architecture: HIGH — layout override, sticky CSS, tab pattern, all verified
- Pitfalls: HIGH — most identified from existing codebase patterns + LV internals
- Reconnection hook: MEDIUM — approach is sound but reconnect attempt counting is approximate (Phoenix doesn't expose attempt number directly)

**Research date:** 2026-02-16
**Valid until:** 2026-03-16 (stable stack — Phoenix 1.8/LV 1.1 unlikely to change soon)
