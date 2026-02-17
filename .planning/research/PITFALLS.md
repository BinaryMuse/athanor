# Pitfalls Research

**Domain:** LiveView UI development — heavy real-time log streaming, DaisyUI theming, long-running experiment sessions
**Researched:** 2026-02-16
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Unbounded LiveView Stream Memory Growth

**What goes wrong:**
The run page uses `stream(:logs, logs)` and appends with `stream_insert` on every `{:log_added, log}` message. LiveView streams are memory-efficient on the client (DOM nodes can be pruned), but stream items accumulate in the *server-side socket state* (`socket.assigns.streams`) without any limit. After thousands of log entries over hours, the socket process balloons in memory. Multiply by open browser tabs and connected users, and the BEAM node runs out of memory or the socket process hits scheduler pressure.

**Why it happens:**
Developers see that streams don't re-render the full list (only diffs) and conclude the problem is solved. They don't realize the server state is still growing. The LiveView docs prominently explain DOM efficiency but less prominently explain server-side stream state. The current code in `run_live/show.ex` has no stream limit configured.

**How to avoid:**
Use `stream_insert(:logs, log, limit: N)` with a hard cap (e.g., `limit: 2000`). This keeps only the N most recent items in the server's stream state. Pair this with a `{:logs_added, count}` batch handler that resets the stream from a paginated DB query (`list_logs(run, limit: 2000)`) rather than doing a full reload on every batch event. Also consider a JS-side virtual scroll that renders only visible log rows from the DOM, but the server limit is the critical server-memory fix.

**Warning signs:**
- Socket process memory climbing over time (check `:erlang.process_info(pid, :memory)` or Phoenix LiveDashboard)
- Response latency on the run page increasing as log count grows
- BEAM memory trending upward during long runs without leveling off

**Phase to address:** Phase implementing the run page log display (virtualized log display feature)

---

### Pitfall 2: Per-Log PubSub Message Flooding the Socket Mailbox

**What goes wrong:**
The current architecture broadcasts one `{:log_added, log}` PubSub message per log entry via `Broadcasts.log_added/2`. At high throughput (hundreds of logs per second from a hot experiment loop), the LiveView process mailbox fills with pending messages faster than it can process them. Each `handle_info` call triggers a diff computation and socket push. The socket falls behind, memory spikes, and the browser either receives stale data or disconnects.

**Why it happens:**
The naive approach maps naturally to Elixir's message-passing model and works fine at low volume. No throttling is visible in the current `run_server.ex` or `run_live/show.ex`. The `{:logs_added, count}` broadcast path exists as an escape hatch but isn't wired to any rate-limiting on the producer side.

**How to avoid:**
Two complementary strategies:
1. **Producer-side batching**: In `RunServer` or `RunContext`, buffer log writes and flush on an interval (e.g., every 100ms) rather than on every `Runtime.log/3` call. Broadcast `{:logs_added, count}` after a batch insert. This is more appropriate for batch experiment workloads.
2. **Consumer-side throttling**: In the LiveView, use `Process.send_after(self(), :flush_logs, 100)` to coalesce incoming log messages into a single stream reset per interval rather than a stream insert per log. Track pending log IDs in assigns and batch-resolve them.

The current `{:logs_added, count}` handler already does a full `list_logs` reset — this is the right approach for batch paths, but the per-log path needs to be eliminated for high-throughput experiments.

**Warning signs:**
- LiveView process mailbox depth > 50 messages (check with `:erlang.process_info(pid, :message_queue_len)`)
- Browser console showing rapid Phoenix channel push events
- UI appearing to "jump" as multiple updates land at once
- Log display falling visibly behind real time during high-volume runs

**Phase to address:** Phase implementing run page real-time log display; must be addressed before any high-volume experiment testing

---

### Pitfall 3: Full Log Reload on `{:logs_added}` Loading All Rows

**What goes wrong:**
The `handle_info({:logs_added, _count}, socket)` handler calls `Experiments.list_logs(socket.assigns.run)` with no limit, fetching all logs for the run from the database. On a run with 50,000 log entries, this is a 50k-row query on every batch notification. This is worse than the per-log approach at high volume — it combines DB load with socket memory explosion.

**Why it happens:**
The batch path was added as a safer alternative to per-log inserts, but the underlying query has no limit. `list_logs/2` accepts a `limit:` option but it isn't used here.

**How to avoid:**
Always pass `limit:` to `list_logs` in LiveView handlers. Reset the stream with only the tail of logs the UI will actually display:
```elixir
logs = Experiments.list_logs(run, limit: 2000, order: :desc)
|> Enum.reverse()
socket |> stream(:logs, logs, reset: true)
```
Show a "N older entries not shown" banner in the UI when `log_count > display_limit`.

**Warning signs:**
- Slow page response when opening a run with many existing logs
- Database slow query logs showing large sequential scans on `run_logs` table during active runs
- `mount/3` latency increasing proportionally to run age

**Phase to address:** Phase implementing run page (log display and virtualization); also affects initial mount performance

---

### Pitfall 4: Theme Flash (FOUC) on Page Load

**What goes wrong:**
The app uses a `data-theme` attribute on `<html>` to switch between DaisyUI's `light` and `dark` themes, with the value stored in `localStorage`. If the theme-reading script runs after initial CSS paint, users see the default theme (light) briefly before the correct theme is applied. This is especially noticeable on page navigations in a LiveView app where the root layout re-renders.

**Why it happens:**
The current `root.html.heex` has the theme-reading script in `<head>` inline (good), but it runs after the stylesheet `<link>` tag. The key issue is that `daisyui-theme` in `app.css` configures `default: true` on the `light` theme, so the browser always paints light first. LiveView navigations also re-execute the root layout heex, re-triggering the FOUC.

**How to avoid:**
The existing theme script in `root.html.heex` is on the right track. Ensure it is:
1. The *first* script in `<head>`, before the stylesheet `<link>` (or at minimum, inline before any DaisyUI styles can paint)
2. Synchronous (no `defer`, no `async`) so it blocks paint
3. Sets `data-theme` on `<html>` before any CSS rules evaluate

The current placement after the `<link>` tag is the problem. Move the inline script *before* the CSS link. For LiveView soft navigations (patch/navigate), the `<html>` attribute persists, so FOUC only affects hard reloads.

**Warning signs:**
- Visible light flash when loading the app with dark mode preference
- Reproducible by throttling CPU in browser DevTools
- The `phx:set-theme` event listener works fine post-load but can't prevent the initial flash

**Phase to address:** Phase establishing visual identity and theme support (early, foundational phase)

---

### Pitfall 5: DaisyUI Component Class Conflicts with Custom Tailwind Classes

**What goes wrong:**
DaisyUI components use semantic class names (`btn`, `card`, `badge`, etc.) that apply multiple Tailwind utilities internally. When developers add raw Tailwind utilities alongside DaisyUI classes (e.g., `class="badge badge-error badge-xs mx-1 text-white"`), DaisyUI's internal color variables may conflict with explicit utility classes. In dark mode, this often manifests as text becoming illegible — e.g., `text-white` forcing white text on a light theme's error badge that already has a high-contrast content color via CSS variables.

**Why it happens:**
DaisyUI 5 (bundled with Phoenix 1.8) uses CSS custom properties (`--color-error-content`) for component styling. Adding Tailwind color utilities bypasses these variables. Developers used to raw Tailwind CSS apply utilities habitually without checking whether the DaisyUI component's CSS already handles that property.

**How to avoid:**
- Use DaisyUI's semantic content color classes (e.g., `badge-error` already applies `error-content` text via CSS variables; do not add `text-white`)
- Use `base-content/70` opacity modifiers for muted text rather than hardcoded colors
- When overriding a DaisyUI component property, use the CSS variable name (`[--color-primary:...]`) rather than a utility class
- Audit every DaisyUI component against both themes using browser DevTools before considering it done

**Warning signs:**
- Text illegible in one theme but fine in the other
- Hardcoded `text-white`, `text-black`, `text-gray-*` classes appearing next to DaisyUI semantic classes
- Colors that look fine in light mode but appear washed out or invisible in dark mode

**Phase to address:** Visual identity / component system phase; needs a dual-theme review checklist in each component's acceptance criteria

---

### Pitfall 6: DaisyUI `themes: false` Means No Built-in Theme — Forgetting to Handle "System" Preference

**What goes wrong:**
The app sets `themes: false` in the DaisyUI plugin config and defines custom `light` and `dark` themes via `daisyui-theme`. This is correct for custom themes, but means the browser's `prefers-color-scheme` media query is not automatically honored — it only works because `prefersdark: true` is set on the `dark` theme plugin. The current JavaScript theme handler in `root.html.heex` stores `"system"` in localStorage to mean "remove the attribute and let CSS handle it," but the CSS only applies `prefersdark` if no `data-theme` attribute is present. If a user previously set a theme then cleared it, they may land on the wrong theme if any residual localStorage state exists.

**Why it happens:**
The `prefersdark: true` DaisyUI option applies the theme when `@media (prefers-color-scheme: dark)` AND there is no explicit `data-theme` override. The interaction between JS-controlled `data-theme` and CSS-controlled `prefersdark` requires exactly the right logic to cooperate. The current implementation removes `data-theme` for "system" — which is correct — but the `storage` event listener (`window.addEventListener("storage", ...)`) fires only for *other* tabs, not the current one, so a tab switching from explicit theme to system preference may not re-evaluate correctly in all edge cases.

**How to avoid:**
- Explicitly test the three states: explicit light, explicit dark, system preference (dark OS, light OS)
- When setting "system" preference, remove the `data-theme` attribute AND also use `window.matchMedia` to detect current OS preference and set the right theme immediately (for the current tab), while still removing the stored key so system preference resumes control on future loads
- Add a theme switcher component that cycles through `light | dark | system` and shows the current state clearly

**Warning signs:**
- User reports theme being wrong on fresh load after changing preferences
- Theme toggle working in the current tab but not persisting to new tabs
- Discrepancy between what the toggle UI shows and the actual rendered theme

**Phase to address:** Theme support phase (foundational); must be verified with actual OS preference toggling in both Chromium and Safari

---

### Pitfall 7: AutoScroll Hook Using MutationObserver on Large DOM Trees

**What goes wrong:**
The existing `AutoScroll` hook observes the entire `#logs-container` element with `{ childList: true, subtree: true }`. As log entries accumulate in the DOM (even with a stream limit on the server, the DOM accumulates unless also virtualized), the MutationObserver fires on every DOM change — including LiveView's internal dom-patching operations — and calls `scrollToBottom()` synchronously. At thousands of DOM nodes, this causes layout thrashing: `scrollTop = scrollHeight` forces a reflow on a large tree on every mutation, causing visible scroll jank or frame drops.

**Why it happens:**
The hook was written for correctness at low volume. The `subtree: true` option catches deeply nested mutations but fires extremely frequently. Calling `scrollTop = scrollHeight` is a write that forces a synchronous layout (it reads `scrollHeight`, which requires layout to be up to date).

**How to avoid:**
- Replace the MutationObserver with a `requestAnimationFrame`-throttled scroll: schedule a `scrollToBottom` via `requestAnimationFrame` rather than calling it synchronously in the observer callback
- Or drop the MutationObserver entirely and rely on the LiveView hook's `updated()` callback (already present) to trigger scroll — this fires once per diff application, not once per DOM node added
- The `updated()` callback is sufficient when using LiveView streams, since LiveView batches DOM updates per render cycle

**Warning signs:**
- Chrome DevTools Performance trace showing frequent "forced reflow" warnings on the logs panel
- Scrolling feeling sticky or jumpy during active log streaming
- `scrollToBottom` appearing many times per second in a flame chart

**Phase to address:** Run page log display phase; the MutationObserver can be simplified to rely on `updated()` alone for most use cases

---

### Pitfall 8: `Jason.encode!` in HEEx Template Crashing on Non-Serializable Result Values

**What goes wrong:**
The run page renders results with `Jason.encode!(result.value, pretty: true)` inline in the HEEx template. If `result.value` contains a value that Jason cannot serialize (atoms stored as keys via Ecto JSONB with atom keys, `Decimal` types, or any value that slips through unexpected), this raises an exception in the render function, crashing the LiveView process and showing a 500 error to the user — even if only one result has bad data.

**Why it happens:**
Results are stored as JSONB, so `result.value` comes back from Postgres as a map with string keys. However, if any code path passes a non-JSON-serializable value and it gets persisted (Ecto JSONB serialization may or may not guard this), the deserialized value might decode to something that re-serialization fails on. More commonly, developers testing locally pass Elixir structs or atoms as result values.

**How to avoid:**
Wrap result encoding defensively:
```elixir
defp encode_result_value(value) do
  case Jason.encode(value, pretty: true) do
    {:ok, json} -> json
    {:error, _} -> inspect(value)
  end
end
```
Use this helper instead of `Jason.encode!` in the template. This ensures the LiveView never crashes due to a single bad result value.

**Warning signs:**
- LiveView process crashing and reconnecting when a specific result is displayed
- `Jason.EncodeError` appearing in server logs
- Run page working during the run but crashing on reload (when results are loaded from DB on mount)

**Phase to address:** Run page results display phase

---

### Pitfall 9: Socket Disconnect Not Detected — User Unaware of Stale State

**What goes wrong:**
When a LiveView socket disconnects (network blip, server restart, long tab idle), the page silently stops receiving real-time updates. In a monitoring-focused tool where users "leave the run page open while doing other work and check back periodically," this means the user may return to see a page showing "running" for an experiment that completed or failed hours ago, with no visible indicator that real-time connection was lost.

**Why it happens:**
Phoenix's JavaScript client does reconnect automatically, but there is a gap period. More critically, if the server restarts during a run, the LiveView remounts but the run's GenServer process is gone (runs are ephemeral per architecture decision 3), and the socket will never receive a completion event. The UI stays frozen at whatever state it was before the disconnect.

**How to avoid:**
- Use the `phx:page-loading-start` / `phx:page-loading-stop` events (already connected to topbar) to show a "reconnecting" banner
- On reconnect (LiveView remount), refetch the run status from the database in `mount/3` — the current code does this correctly since it calls `Experiments.get_run!(id)` on every mount
- Add a visible "Last updated: X seconds ago" timestamp that updates on a client-side timer, so users can detect staleness even without a full disconnect
- Consider using the `handle_info(:check_stale, socket)` pattern with `Process.send_after` to periodically re-query run status for runs in "running" state

**Warning signs:**
- Run page showing "running" status for a run that the database shows as completed
- After server restart, no completion events arriving for previously-running runs

**Phase to address:** Run page implementation; the reconnect/remount behavior is already partially correct but staleness detection needs to be explicit

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| No stream limit on logs | Simpler code, all logs visible | Socket memory grows without bound in long runs | Never — hard-code a limit from day one |
| `Jason.encode!` in template | One-liner | Crashes LiveView on any bad result value | Never in templates — always use safe wrapper |
| Per-log PubSub broadcast for all experiments | Simple to implement | Saturates socket at high log volume | Only acceptable for experiments known to log rarely (< 1/sec) |
| Hardcoded Tailwind color utilities next to DaisyUI classes | Works in light mode | Breaks dark mode consistency | Only for elements explicitly outside the DaisyUI theme system |
| MutationObserver with `subtree: true` on logs container | Catches all DOM changes | Layout thrashing at high log volume | Acceptable for < 100 total DOM nodes; remove at scale |
| No log count cap in `mount/3` initial load | All historical logs visible | Slow mount for runs with thousands of existing logs | Never — always limit initial load |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| DaisyUI + Tailwind CSS 4 (`@plugin` syntax) | Importing DaisyUI and adding raw Tailwind color classes that fight DaisyUI's CSS variables | Use DaisyUI semantic color classes; only add utilities for layout/spacing, not color |
| DaisyUI themes + Phoenix `data-theme` | Setting `themes: true` (enables all built-in DaisyUI themes) when using custom themes | Set `themes: false` and define themes with `daisyui-theme` plugin; manage theme persistence entirely in JS |
| LiveView streams + initial log load | Loading unbounded logs into stream on `mount/3` | Always use `limit:` when loading logs for streams; show "truncated" notice |
| PubSub + LiveView `handle_info` | Sending one PubSub message per log line from experiment | Batch logs at the producer; use `{:logs_added, count}` for high-frequency sources |
| `phx-hook` AutoScroll + LiveView streams | Using MutationObserver to trigger scroll instead of `updated()` hook callback | Rely on `updated()` for post-diff scroll; MutationObserver is redundant and slower |
| DaisyUI `data-theme` + Tailwind `dark:` variant | Using Tailwind's `dark:` variant (which checks `prefers-color-scheme` or a `dark` class) alongside DaisyUI's `data-theme` attribute | The CSS already defines `@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *))` — use this variant, not Tailwind's built-in `dark:` |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Unbounded log stream (server state) | Socket process memory > 100MB; BEAM memory climbing | `stream_insert(:logs, log, limit: 2000)` | Starts mattering at ~5,000 log entries |
| `list_logs` without limit on reconnect | Mount latency > 2s for active runs; DB slow queries | `list_logs(run, limit: 2000)` in mount and batch handlers | > 10,000 log entries |
| Per-log `stream_insert` + LiveView diff at high frequency | Socket falls behind; browser shows stale data | Consumer-side coalescing via `send_after` or producer-side batching | > 10 logs/second sustained |
| `Jason.encode!(value, pretty: true)` in HEEx on every render | Slow results panel rendering with many results | Precompute or cache encoded values; use `Phoenix.HTML.raw/1` | > 100 result entries or deeply nested values |
| MutationObserver on large DOM | Frame drops (< 30fps) in browser during active scrolling + log streaming | Use `updated()` hook callback only | > 500 DOM nodes in logs container |
| `phx-update="stream"` container with no `max-height` | Results panel grows indefinitely, pushing logs out of view | Cap containers with `max-h-*` and `overflow-y-auto` | Any run producing > ~20 results |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Rendering `log.message` without HEEx escaping | XSS if experiment logs user-controlled strings | HEEx auto-escapes in `{log.message}` — safe; only risk if switching to `Phoenix.HTML.raw/1` |
| Rendering `result.value` via `Jason.encode!` output through `raw/1` | XSS if result contains `</script>` or similar in JSON | Use `{Jason.encode!(...)}` (escaped), not `raw(Jason.encode!(...))` |
| Experiment module discovery without allowlist | Arbitrary module execution if experiment_module is user-supplied | `Experiments.Discovery` resolves modules from code only; not a current risk since this is a personal tool |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Auto-scroll toggle state lost on page reload | User disables auto-scroll to read a specific log, reloads page, scroll re-enables and jumps to bottom | Persist auto-scroll preference to `localStorage` via JS hook |
| Log level badges all the same size and position | Hard to scan log level at a glance in a mono-spaced stream | Use fixed-width level labels (pad to 5 chars: `DEBUG`, `INFO `, `WARN `, `ERROR`) for alignment |
| Results panel showing raw JSON by default | Nested experiment results are unreadable walls of JSON | Provide collapsible tree view as default; JSON as an opt-in toggle |
| No "run ended" visual signal when page is open | User checking back doesn't notice run completed | Flash the document title or show a toast on `{:run_updated, run}` when status transitions to completed/failed |
| Long experiment module names truncated without tooltip | Module identity unclear in list views | Truncate with CSS ellipsis + `title` attribute showing full name |
| "No logs yet" empty state persisting when first log arrives | `@log_count == 0` check prevents empty state removal until next render, but stream_insert updates DOM before count assign updates | Always update `log_count` and `stream_insert` in the same socket pipeline (current code does this correctly) |

## "Looks Done But Isn't" Checklist

- [ ] **Log stream memory limit:** Verify `stream_insert` calls use `limit:` option — check that socket memory stabilizes after N logs, not grows indefinitely
- [ ] **Initial log load capped:** Verify `mount/3` calls `list_logs` with a limit; load a run with 10,000 logs and confirm mount completes in < 500ms
- [ ] **Dark mode, all pages:** Open every LiveView page with `data-theme="dark"` and verify no text is invisible, no backgrounds conflict, no hardcoded colors leak
- [ ] **Dark mode, all DaisyUI badge variants:** `badge-error`, `badge-warning`, `badge-info`, `badge-ghost` in both themes — check that content color is legible
- [ ] **Theme FOUC:** Throttle CPU in DevTools, hard-reload with dark preference set, and confirm no white flash before dark theme applies
- [ ] **Reconnect / stale state:** Start a run, disconnect network, reconnect after 10 seconds, verify page shows current state after remount
- [ ] **Socket disconnect banner:** Verify topbar/connection indicator shows during socket reconnect attempt
- [ ] **Auto-scroll toggle:** Toggle off, scroll to middle of logs, wait for new logs, verify scroll position is preserved
- [ ] **Result encode safety:** Pass a non-JSON-serializable value (atom-keyed map) as a result and verify the run page does not crash
- [ ] **Run page with 0 logs:** Confirm "No logs yet" empty state renders and correctly disappears on first log arrival
- [ ] **High-throughput stress:** Simulate 50 logs/second for 60 seconds, verify UI remains responsive and socket does not fall behind

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Socket memory bloat (no stream limit) | MEDIUM | Add `limit:` to `stream_insert` and `list_logs` calls; existing live sessions will fix themselves on next reconnect/remount |
| FOUC on theme load | LOW | Move inline theme script before the CSS `<link>` in `root.html.heex`; takes 1 line change |
| `Jason.encode!` crash in template | LOW | Replace with safe encode helper; isolated to one function |
| MutationObserver layout thrashing | LOW | Remove MutationObserver from AutoScroll hook; rely on `updated()` callback |
| Per-log PubSub flooding | HIGH | Requires batching changes in both producer (RunServer/RunContext) and consumer (LiveView); affects data pipeline |
| DaisyUI + Tailwind color conflicts | MEDIUM | Audit all HEEx templates for hardcoded color utilities; requires per-component review |
| Stale run state after server restart | MEDIUM | Implement periodic status polling in LiveView for "running" runs; requires new `handle_info` timer pattern |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Unbounded log stream server memory | Run page log display phase | Socket memory monitoring during 10k-log stress test |
| Per-log PubSub flooding | Run page log display phase | Stress test at 50 logs/sec; measure socket mailbox depth |
| Unlimited `list_logs` in batch handler | Run page log display phase | Run with 10k existing logs; measure mount time |
| Theme FOUC | Visual identity / theme foundation phase | Hard reload with dark OS preference; CPU throttled |
| DaisyUI class conflicts | Visual identity / component system phase | Dual-theme review pass on every component |
| DaisyUI "system" preference edge cases | Visual identity / theme foundation phase | Manual test: light OS, dark OS, explicit light, explicit dark |
| AutoScroll layout thrashing | Run page log display phase | Chrome DevTools Performance trace during active run |
| `Jason.encode!` crash in template | Run page results display phase | Unit test with non-serializable result value |
| Socket disconnect / stale state | Run page implementation phase | Network disconnect test; server restart during active run |

## Sources

- Direct codebase analysis: `run_live/show.ex`, `broadcasts.ex`, `experiments.ex`, `app.js`, `app.css`, `root.html.heex`
- Architecture document: `docs/architecture.md` (ephemeral runs, PubSub design, stream usage)
- LiveView stream documentation: server-side state behavior and `limit:` option for `stream_insert`
- DaisyUI v5 documentation: CSS custom property (`oklch` variable) architecture, `themes: false` behavior, `prefersdark` interaction
- Phoenix 1.8 + Tailwind CSS 4 `@plugin` configuration behavior
- Known BEAM/OTP pattern: process mailbox saturation under high message rates
- Known browser behavior: MutationObserver + synchronous layout read/write causing reflow

---
*Pitfalls research for: LiveView UI — real-time log streaming, DaisyUI theming, long-running experiment sessions*
*Researched: 2026-02-16*
