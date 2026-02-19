# Phase 2: Run Page Log Display - Research

**Researched:** 2026-02-16
**Domain:** Phoenix LiveView streams with `stream_insert` limits + auto-scroll JS hook, high-volume log batching
**Confidence:** HIGH

## Summary

The run page already has a working log display in `AthanorWeb.Experiments.RunLive.Show`, but it is not built for high-volume scenarios. The current implementation calls `Experiments.list_logs/1` with no limit on mount (loads all logs), uses `stream_insert/2` with no `:limit` option (unlimited DOM growth), and on batch events does a full DB reload plus stream reset (expensive). At 10,000+ log entries, this causes unbounded DOM growth and potential LiveView process mailbox overload.

The correct solution is entirely within the built-in Phoenix LiveView 1.1.24 stream API: use `stream/4` with `limit: -N` on mount and `stream_insert/4` with the same `limit:` on every individual insert. Pre-load only the last N logs from the database on mount (using the existing `list_logs/2` `:limit` option). For batch inserts (the `{:logs_added, count}` event), issue multiple individual `stream_insert/4` calls (each with the limit) rather than a full DB reload. Auto-scroll is best implemented with a MutationObserver JS hook (already implemented as `AutoScroll` in `assets/js/app.js`), but needs to be refined to avoid scroll-jumping when the user has scrolled up.

The phase plan is a single plan: extract the log panel into a dedicated Phoenix.Component, wire in stream limits, constrain mount DB query, and fix the batch-event handler. No new dependencies are required — every capability needed is already in the project.

**Primary recommendation:** Use `stream(socket, :logs, recent_logs, limit: -1000)` on mount with a DB limit of 1000, and `stream_insert(socket, :logs, log, limit: -1000)` on every individual `{:log_added, log}` event. Handle `{:logs_added, _count}` by querying only the newest N logs since last known ID and inserting them individually with the limit, or by doing a bounded reset.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView | 1.1.24 | Stream with `limit:` option, auto-pruning DOM | Built-in, already in project |
| Phoenix PubSub | 2.2.0 | Real-time log delivery to LiveView | Built-in, already wired |
| Ecto | 3.13.5 | Bounded DB queries with `limit/2` | Already `list_logs/2` accepts `:limit` |
| DaisyUI + Tailwind | vendored | Semantic badge/color classes for log levels | Already established in Phase 1 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phoenix.Component | (part of LiveView 1.1.24) | Extract log panel as reusable component | To isolate log panel rendering |
| MutationObserver (browser built-in) | N/A | Auto-scroll JS hook | Already implemented as `AutoScroll` hook |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `stream/4` with `limit:` | CSS-only virtualization | Stream limit is simpler, built-in, no extra JS |
| `stream/4` with `limit:` | React/JS virtual list (TanStack Virtual) | Overkill — requires full JS frontend for this one feature |
| `stream/4` with `limit:` | LiveView `phx-viewport-top/bottom` infinite scroll | More complex; designed for scrollable history loading, not log tailing |
| MutationObserver hook | `phx-viewport-bottom` | `phx-viewport-bottom` fires on scroll position, not on DOM mutation; wrong tool for auto-scroll-to-bottom |

**Installation:** No new packages required.

## Architecture Patterns

### Recommended Project Structure

```
apps/athanor_web/lib/athanor_web/live/experiments/
├── run_live/
│   └── show.ex                      # Mount + handle_info (existing, modify)
└── components/
    ├── log_panel.ex                  # NEW: extracted LogPanel component
    ├── status_badge.ex               # existing
    └── progress_bar.ex               # existing
```

### Pattern 1: Bounded Stream on Mount

**What:** Load only the last N logs from DB on mount. Pass them into `stream/4` with `limit: -N`. The `limit:` is not enforced on the first (dead) render, so you must pre-limit the DB query yourself.

**When to use:** Always — do not load unbounded logs into the stream at mount.

**Example:**
```elixir
# Source: deps/phoenix_live_view/lib/phoenix_live_view.ex (stream/4 docs)
# In RunLive.Show mount/3:
@log_stream_limit 1_000

def mount(%{"id" => id}, _session, socket) do
  run = Experiments.get_run!(id) |> Repo.preload(:instance)

  if connected?(socket) do
    Phoenix.PubSub.subscribe(Athanor.PubSub, "experiments:run:#{id}")
  end

  # Pre-limit the DB query — stream/4 limit: is NOT enforced on dead render
  logs = Experiments.list_logs(run, limit: @log_stream_limit)

  socket =
    socket
    |> assign(:run, run)
    |> assign(:log_stream_limit, @log_stream_limit)
    |> stream(:logs, logs, limit: -@log_stream_limit)
    # ...

  {:ok, socket}
end
```

### Pattern 2: `stream_insert/4` with limit on Every Individual Log

**What:** Every `{:log_added, log}` PubSub message appends to the stream with the same `limit:` value. The LiveView client-side JS prunes the oldest DOM nodes automatically when the count exceeds the limit.

**When to use:** For the normal single-log-at-a-time path.

**Example:**
```elixir
# Source: deps/phoenix_live_view/lib/phoenix_live_view.ex (stream_insert/4 docs)
# Note: limit MUST be passed here — stream/4's limit: does NOT propagate to stream_insert
@impl true
def handle_info({:log_added, log}, socket) do
  socket =
    socket
    |> update(:log_count, &(&1 + 1))
    |> stream_insert(:logs, log, limit: -socket.assigns.log_stream_limit)

  {:noreply, socket}
end
```

### Pattern 3: Bounded Batch Event Handler

**What:** The `{:logs_added, count}` event currently reloads all logs from DB and resets the stream. With 10,000 logs this is expensive. Instead, query only the last N logs (within the limit) and reset the stream with those.

**When to use:** When `Runtime.log_batch/2` is called by experiments.

**Example:**
```elixir
# Source: Experiments.list_logs/2 supports :limit option (apps/athanor/lib/athanor/experiments.ex)
@impl true
def handle_info({:logs_added, _count}, socket) do
  logs = Experiments.list_logs(socket.assigns.run, limit: socket.assigns.log_stream_limit)

  socket =
    socket
    |> assign(:log_count, length(logs))
    |> stream(:logs, logs, reset: true, limit: -socket.assigns.log_stream_limit)

  {:noreply, socket}
end
```

### Pattern 4: Auto-Scroll Hook — Avoiding Position Jump

**What:** The existing `AutoScroll` hook uses MutationObserver to scroll to bottom on DOM mutation. The current implementation always scrolls when `data-auto-scroll="true"`. The problem: if the user has scrolled up to read history, a new log entry fires the observer and jumps them back to the bottom.

**The correct behavior:** Only auto-scroll if the user is already near the bottom (within a threshold). If the user has manually scrolled up, do not interrupt. When they re-enable auto-scroll via the toggle, jump to bottom.

**Example:**
```javascript
// Refined AutoScroll hook — replaces the one in assets/js/app.js
AutoScroll: {
  mounted() {
    this.scrollToBottom()
    this.observer = new MutationObserver(() => {
      if (this.el.dataset.autoScroll === "true" && this.isNearBottom()) {
        this.scrollToBottom()
      }
    })
    this.observer.observe(this.el, { childList: true, subtree: true })
  },
  updated() {
    // Called when data-auto-scroll attribute changes via server
    if (this.el.dataset.autoScroll === "true") {
      this.scrollToBottom()
    }
  },
  destroyed() {
    if (this.observer) this.observer.disconnect()
  },
  isNearBottom() {
    const threshold = 100 // px from bottom
    return this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight <= threshold
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}
```

### Pattern 5: Log Panel as Phoenix.Component

**What:** Extract the log panel `<div>` from `RunLive.Show.render/1` into a dedicated `AthanorWeb.Experiments.Components.LogPanel` module using `Phoenix.Component`.

**When to use:** Always for components with non-trivial rendering logic. Follows existing project convention — see `StatusBadge` and `ProgressBar` under `live/experiments/components/`.

**Example:**
```elixir
# apps/athanor_web/lib/athanor_web/live/experiments/components/log_panel.ex
defmodule AthanorWeb.Experiments.Components.LogPanel do
  use Phoenix.Component

  attr :streams, :map, required: true
  attr :auto_scroll, :boolean, required: true
  attr :log_count, :integer, required: true

  def log_panel(assigns) do
    ~H"""
    <div class="card bg-base-200">
      <div class="card-body">
        <div class="flex items-center justify-between">
          <h3 class="card-title text-lg">Logs</h3>
          <label class="label cursor-pointer gap-2">
            <span class="label-text text-sm">Auto-scroll</span>
            <input
              type="checkbox"
              class="toggle toggle-sm"
              checked={@auto_scroll}
              phx-click="toggle_auto_scroll"
            />
          </label>
        </div>

        <div
          id="logs-container"
          class="bg-base-300 rounded-box p-3 h-96 overflow-y-auto font-mono text-xs"
          phx-hook="AutoScroll"
          data-auto-scroll={to_string(@auto_scroll)}
        >
          <div :if={@log_count == 0} class="text-base-content/40 text-center py-8">
            No logs yet
          </div>
          <div id="logs" phx-update="stream" class="space-y-1">
            <div :for={{dom_id, log} <- @streams.logs} id={dom_id} class={log_row_class(log.level)}>
              <span class="text-base-content/40">{format_timestamp(log.timestamp)}</span>
              <span class={level_badge(log.level)}>{String.upcase(log.level)}</span>
              <span class="text-base-content">{log.message}</span>
              <span :if={log.metadata} class="text-base-content/40">{inspect(log.metadata)}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp log_row_class("error"), do: "text-error"
  defp log_row_class("warn"), do: "text-warning"
  defp log_row_class(_), do: ""

  defp level_badge("error"), do: "badge badge-error badge-xs mx-1"
  defp level_badge("warn"), do: "badge badge-warning badge-xs mx-1"
  defp level_badge("info"), do: "badge badge-info badge-xs mx-1"
  defp level_badge("debug"), do: "badge badge-ghost badge-xs mx-1"
  defp level_badge(_), do: "badge badge-ghost badge-xs mx-1"

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S.%f") |> String.slice(0, 12)
  end
end
```

### Anti-Patterns to Avoid

- **Unlimited stream on mount:** `stream(:logs, Experiments.list_logs(run))` with no DB limit loads all rows. On a run with 50,000 logs, this sends 50,000 rows to the client on connect. Always pass `limit:` to both `list_logs/2` and `stream/4`.
- **Omitting `limit:` from `stream_insert/4`:** The `:limit` option on `stream/4` does NOT propagate to subsequent `stream_insert/4` calls. Each `stream_insert/4` call must explicitly include `limit: -N`. Forgetting this means DOM grows unbounded after mount.
- **Full DB reload on batch:** The current `{:logs_added, _count}` handler calls `list_logs` with no limit then stream-resets. With 10,000 logs this is an expensive query and sends all rows over WebSocket. Use `limit:` on the query.
- **`text-base-content/50` for debug metadata:** The existing code uses `/50` opacity for metadata. The DESIGN-TOKENS.md convention is `/40` for tertiary (timestamps, metadata). Use `/40`.
- **`text-base-content/50` instead of established tokens:** Use `/60` for secondary labels, `/40` for timestamps/metadata, per Phase 1 design tokens.
- **Blocking auto-scroll when user has scrolled up:** The current hook scrolls to bottom on any mutation when `auto_scroll=true`, even if user is reading history. Check proximity to bottom before auto-scrolling.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| DOM node pruning when list exceeds limit | Custom JS to remove old nodes | `stream_insert/4` with `limit:` | LiveView handles this in morphdom patch cycle; custom JS fights the vdom reconciler |
| Virtual scroll / windowing | Intersection Observer infinite scroll or React-style virtual list | `stream/4` + `limit:` | For a log tail panel (always-at-bottom), DOM pruning is sufficient; true virtualization is only needed for scrollable history |
| Log level color mapping | Custom CSS classes or inline styles | DaisyUI semantic `badge-error`, `badge-warning`, etc. | Already established in Phase 1; use `badge-{level}` and `text-{level}` |
| Colocated JS hook | Separate JS file per component | `ColocatedHook` (`Phoenix.LiveView.ColocatedHook`) | LiveView 1.1 supports colocated hooks; for the `AutoScroll` hook this is optional since it's already in `app.js` |

**Key insight:** Phoenix LiveView's stream `limit:` option already implements the "virtual list" pattern at the DOM level — new items are inserted and old items are pruned client-side with no server round-trip. For a log tailing panel, this is the right level of abstraction. True DOM virtualization (recycling DOM nodes based on scroll position) is unnecessary complexity.

## Common Pitfalls

### Pitfall 1: `stream_insert` Without `limit:` After `stream` With `limit:`

**What goes wrong:** Developer sets `stream(:logs, logs, limit: -1000)` in mount but calls `stream_insert(:logs, log)` without `limit:`. The DOM grows unboundedly after mount because the limit from `stream/4` does not apply to subsequent inserts.

**Why it happens:** The LiveView docs state this explicitly but it's counterintuitive — one would expect the stream to remember its limit.

**How to avoid:** Always pass the same `limit:` to `stream_insert/4` as was used in the initial `stream/4` call. Use a module attribute `@log_stream_limit` so the value is defined once.

**Warning signs:** DevTools shows the `#logs` container accumulating hundreds of children during a long-running experiment.

### Pitfall 2: Unbounded DB Query on Batch Event

**What goes wrong:** `{:logs_added, _count}` handler calls `Experiments.list_logs(run)` with no limit, fetches 10,000 rows, loads them all into the stream. The LiveView process stalls during this DB round-trip; the client receives a massive diff.

**Why it happens:** The current implementation was written before high-volume was a concern. The batch path is designed for correctness (full resync), not performance.

**How to avoid:** Always pass `limit: @log_stream_limit` to `list_logs/2` when calling it from a LiveView `handle_info`.

**Warning signs:** LiveView response latency spikes when `log_batch` is used; browser freezes briefly after batch.

### Pitfall 3: Auto-Scroll Jumps During History Reading

**What goes wrong:** User scrolls up to read earlier logs. A new log arrives, MutationObserver fires, page jumps to bottom even though user did not request it.

**Why it happens:** The current `AutoScroll` hook scrolls unconditionally on any child mutation when `data-auto-scroll="true"`. The user has auto-scroll enabled but is reading history — the intent should be "follow new logs if I'm at the bottom."

**How to avoid:** Add a `isNearBottom()` check in the MutationObserver callback. Only scroll if user is within ~100px of the bottom. The `toggle_auto_scroll` event should still jump to bottom immediately when user re-enables.

**Warning signs:** User reports "the page keeps jumping when I try to read old logs."

### Pitfall 4: `phx-update="stream"` on the Wrong Container

**What goes wrong:** `phx-update="stream"` is placed on the outer card `<div>` rather than the immediate parent of stream items. LiveView loses track of which items are in the stream; inserts and deletes misbehave.

**Why it happens:** The attribute must be on the **immediate parent** of the streamed `<div :for=...>` items. In the current code it is correctly placed on `<div id="logs">`. When extracting to a component, this nesting must be preserved.

**How to avoid:** Keep `<div id="logs" phx-update="stream">` as the immediate parent. The scroll container (`id="logs-container"`) is the grandparent and must NOT have `phx-update`.

**Warning signs:** Logs appear duplicated, or deletes don't remove the correct item.

### Pitfall 5: Semantic Color Violations from Phase 1

**What goes wrong:** Log rows use `text-base-content/50` (not in the design token table) or hardcoded `text-gray-500` for muted text.

**Why it happens:** The existing `run_live/show.ex` was written before Phase 1 established semantic color conventions.

**How to avoid:** Use `/60` for secondary text, `/40` for tertiary (timestamps, metadata). Check DESIGN-TOKENS.md `## Patterns to AVOID` table.

**Warning signs:** Colors break when switching between light/dark themes.

## Code Examples

Verified patterns from official LiveView source and project codebase:

### Bounded Stream Initialization (mount)
```elixir
# Source: deps/phoenix_live_view/lib/phoenix_live_view.ex - stream/4 docs
# The limit: is NOT enforced on dead render, so pre-limit the DB query too.
@log_stream_limit 1_000

logs = Experiments.list_logs(run, limit: @log_stream_limit)
socket = stream(socket, :logs, logs, limit: -@log_stream_limit)
```

### stream_insert with Limit
```elixir
# Source: deps/phoenix_live_view/lib/phoenix_live_view.ex - stream_insert/4 docs
# "A limit passed to stream/4 does not affect subsequent calls to stream_insert/4"
def handle_info({:log_added, log}, socket) do
  {:noreply, stream_insert(socket, :logs, log, limit: -@log_stream_limit)}
end
```

### Batch Handler — Bounded Reset
```elixir
# Source: apps/athanor/lib/athanor/experiments.ex - list_logs/2 accepts :limit
def handle_info({:logs_added, _count}, socket) do
  logs = Experiments.list_logs(socket.assigns.run, limit: @log_stream_limit)
  socket = stream(socket, :logs, logs, reset: true, limit: -@log_stream_limit)
  {:noreply, assign(socket, :log_count, length(logs))}
end
```

### Client-Side DOM Pruning (verified in built JS)
```javascript
// Source: deps/phoenix_live_view/priv/static/phoenix_live_view.esm.js lines 2687-2692
// LiveView prunes from beginning of container when limit < 0:
// children.slice(0, children.length + limit).forEach((child) => this.removeStreamChildElement(child));
// This runs on every stream patch — no custom JS needed.
```

### AutoScroll Hook — Near-Bottom Check
```javascript
// Custom logic (no library source) — isNearBottom threshold is idiomatic
isNearBottom() {
  const threshold = 100
  return this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight <= threshold
}
```

### Log Level — DaisyUI Semantic Badges (Phase 1 compliant)
```heex
<%!-- Source: .planning/phases/01-visual-identity-and-theme-foundation/DESIGN-TOKENS.md --%>
<span class="badge badge-error badge-xs mx-1">ERROR</span>
<span class="badge badge-warning badge-xs mx-1">WARN</span>
<span class="badge badge-info badge-xs mx-1">INFO</span>
<span class="badge badge-ghost badge-xs mx-1">DEBUG</span>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Full list assign (`@logs`) | `stream/4` with `limit:` | LiveView 0.19 | Stream state is freed from socket memory after render; no server-side list |
| Manual JS infinite scroll (IntersectionObserver) | `phx-viewport-top/bottom` | LiveView 0.19 | Server-driven page control; less custom JS |
| Custom JS DOM pruning | `stream_insert/4` with `limit:` | LiveView 0.19 | Built-in client-side pruning via morphdom patch |
| Separate JS hook files | Colocated hooks (`Phoenix.LiveView.ColocatedHook`) | LiveView 1.1 | Hook JS lives next to component HEEX; less context switching |

**Deprecated/outdated:**
- `@logs` assign with `for` comprehension: replaced by streams for dynamic lists; keeps server memory lean (stream items are freed after render).
- Manual scroll-to-bottom with `scrollTop = scrollHeight`: still valid, but should be guarded with near-bottom check to respect user scroll position.

## Open Questions

1. **What limit value to use (1,000 vs 500 vs 2,000)?**
   - What we know: The requirement says "responsive with 10,000+ log entries." Stream limit controls DOM node count, not total log count. 1,000 DOM nodes of simple `<div>` elements is well within browser performance limits.
   - What's unclear: The max rate of logs per second expected in practice (experiments could log thousands/sec).
   - Recommendation: Start with 1,000. This is a module attribute `@log_stream_limit` that can be adjusted without code restructuring.

2. **Should `{:logs_added, count}` carry the actual log entries in the broadcast payload?**
   - What we know: The current `Broadcasts.logs_added/2` only broadcasts the count, not the entries. The handler must re-query DB.
   - What's unclear: Whether to change the broadcast to include the actual logs (would avoid DB round-trip) or keep the current protocol.
   - Recommendation: Keep the current protocol for now. A bounded DB query with LIMIT 1000 is fast. Adding entries to the broadcast complicates the Broadcasts module and increases WebSocket payload per batch. Revisit only if profiling shows this is a bottleneck.

3. **Should the AutoScroll hook become a colocated hook?**
   - What we know: LiveView 1.1 supports colocated hooks via `Phoenix.LiveView.ColocatedHook`. The `AutoScroll` hook is currently in `app.js`.
   - What's unclear: No strong reason to migrate existing working hook to colocated.
   - Recommendation: Keep `AutoScroll` in `app.js` — it's shared infrastructure for any auto-scrolling panel. Only use colocated hooks for component-specific logic not used elsewhere.

## Sources

### Primary (HIGH confidence)
- `deps/phoenix_live_view/lib/phoenix_live_view.ex` — `stream/4`, `stream_insert/4` API with `:limit` option documentation, dead-render limit note (lines 1763-1817)
- `deps/phoenix_live_view/priv/static/phoenix_live_view.esm.js` — Client-side DOM pruning implementation (lines 2687-2692), confirms negative limit prunes from beginning of container
- `deps/phoenix_live_view/lib/phoenix_live_view/live_stream.ex` — Stream internals, `insert_item/5` signature confirms limit is per-insert
- `apps/athanor/lib/athanor/experiments.ex` — `list_logs/2` already supports `limit:` option (line 115)
- `apps/athanor_web/assets/js/app.js` — Existing `AutoScroll` hook implementation
- `apps/athanor_web/lib/athanor_web/live/experiments/run_live/show.ex` — Current log display implementation, confirmed issues (no limit on stream, no limit on DB query at mount, batch handler reloads all logs)
- `.planning/phases/01-visual-identity-and-theme-foundation/DESIGN-TOKENS.md` — Phase 1 semantic color conventions that must be followed

### Secondary (MEDIUM confidence)
- [Phoenix LiveView v1.1.22 hexdocs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html) — stream/4 and stream_insert/4 public docs confirming limit behavior
- [Phoenix LiveView 1.1 released blog](https://www.phoenixframework.org/blog/phoenix-liveview-1-1-released) — Confirmed colocated hooks are new in 1.1
- [Elixir Forum: Batching pubsub events to throttle socket updates](https://elixirforum.com/t/batching-pubsub-events-to-throttle-socket-updates/64658) — Confirms `Process.send_after` pattern for throttling; not needed for this phase given bounded stream approach

### Tertiary (LOW confidence)
- [HexShift Medium: Leveraging Phoenix LiveView's live_stream for Efficient Rendering](https://hexshift.medium.com/leveraging-phoenix-liveviews-live-stream-for-efficient-rendering-of-large-datasets-62360ecaa810) — General stream batching guidance, unverified specifics
- [Failing Big with Elixir and LiveView post-mortem](https://pentacent.com/blog/failing-big-elixir-liveview/) — Real-world PubSub mailbox overflow case study; confirms risk is real, solution is rate-limiting at broadcast level (not needed for this phase's scope)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all capabilities verified in installed `deps/phoenix_live_view` source
- Architecture: HIGH — existing `RunLive.Show` and component pattern are directly readable in codebase
- Pitfalls: HIGH (DOM pruning, DB limit) — confirmed in LiveView source; MEDIUM (auto-scroll threshold) — idiomatic but threshold value is a judgment call

**Research date:** 2026-02-16
**Valid until:** 2026-03-16 (LiveView stream API is stable; DaisyUI semantic conventions locked by Phase 1)
