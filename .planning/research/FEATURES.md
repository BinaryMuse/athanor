# Feature Research

**Domain:** Research/monitoring dashboard UI — live log streaming and structured results for long-running AI experiments
**Researched:** 2026-02-16
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete or broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Live log display with auto-scroll | A monitoring tool that requires manual refresh is broken; users leave the page open for hours | MEDIUM | Already exists functionally; needs virtualization for high-volume runs (thousands of entries). Auto-scroll toggle already implemented. |
| Log level visual differentiation | color-coded levels (debug/info/warn/error) let eyes scan fast without reading every line | LOW | Partially implemented via badge colors; needs stronger visual weight for errors/warnings |
| Run status indicator | Users need to know at a glance if a run is pending / running / done / failed / cancelled | LOW | StatusBadge component exists; needs clear visual hierarchy |
| Progress display for running experiments | Without progress, users can't tell if the experiment is stuck or just slow | LOW | ProgressBar component exists; progress is ephemeral (not persisted), only shown while running |
| Structured result display | Results are key-value JSONB blobs; a raw JSON dump is hard to scan | MEDIUM | Currently renders Jason.encode! into a pre tag — readable but not explorable |
| Timestamps on log entries | Experiments run for hours; sub-second timestamps let users correlate events | LOW | Implemented; displays HH:MM:SS.mmm already |
| Run duration display | Users need to know how long runs take to calibrate expectations | LOW | Implemented on both instance show and run show pages |
| Error display | When a run fails, the error must be visible without hunting | LOW | Implemented via alert-error div; needs to stay prominent in polished layout |
| Cancel running experiment | Long experiments can go wrong; users need an escape hatch | LOW | Implemented; needs clear visual placement |
| Run history list per instance | Repeated runs for reproducibility is a core use case; users need to compare | LOW | Implemented as stream on instance show page |
| Navigate between instance and run | Users move back and forth; broken navigation feels broken | LOW | Implemented via back link and breadcrumb-style subtitle |

### Differentiators (Competitive Advantage)

Features that set the product apart for the specific use case of long-running AI research experiments.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Virtualized log rendering | Experiments produce thousands of entries; without virtualization the page degrades or crashes the tab after minutes | HIGH | This is the single most important differentiating feature for the run page. Requires a LiveView hook or JS interop approach. Standard DOM streams become slow above ~2000 entries. |
| Scientific/technical visual aesthetic | Researchers trust tools that look like lab equipment, not consumer apps; visual seriousness signals technical credibility | MEDIUM | Requires deliberate design: dense information layout, muted palette, accent colors for status only, monospace fonts for data. Achievable with Tailwind + DaisyUI theming. |
| Dark mode with system preference detection | Long experiment sessions (hours) at night; dark mode is ergonomic necessity not preference | LOW | DaisyUI supports `data-theme` attribute; system preference detection via CSS `prefers-color-scheme` + a JS hook to write the attribute |
| Log metadata display with collapsible expansion | Logs often carry structured metadata (model params, token counts, run context); inline display clutters, hiding it loses value | MEDIUM | Currently: inline inspect() dump. Better: collapsed by default, expand on click. Requires a JS hook or LiveView event. |
| Result tree view with JSON toggle | Structured JSONB results need both a human-scannable tree and the raw JSON for copy-paste | MEDIUM | Currently only raw JSON in a pre tag. A collapsible tree view (like browser devtools) would let users explore nested results without scrolling through JSON |
| Run comparison view | AI experiments are inherently comparative; same config run N times to check variance, or different configs to find the best | HIGH | Not yet built. Would need a side-by-side or diff view across runs. Significant but foundational for research use. |
| Live result aggregation stats | When a key is emitted per-item (e.g., confidence score per model pair), users want to see min/max/mean without leaving the page | HIGH | Not yet built. Requires computing stats client-side or server-side as results stream in. Valuable for quantitative experiments. |
| Sticky header with run status always visible | During long experiments, users scroll through logs; the run status (progress, elapsed time, cancel button) should always be visible | MEDIUM | Currently status is at top, scrolls away. A sticky header or sidebar panel would require layout restructuring. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems for this specific tool.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Real-time log filtering by level | "I only want to see errors" feels useful | During a live run, filtering discards context — the error makes sense next to the preceding info logs. Filtering also interacts badly with virtualization (changing the visible set while auto-scrolling). Post-run analysis is a better fit. | Add a level filter only on completed runs, where the full log is available and scrolling is intentional. |
| Log search during active run | Obvious request from users used to `grep` | A search index over a streaming dataset during an active run is complex and fragile. Matches jump around as new entries arrive. | Defer to post-run view. The database already supports queried logs via `Experiments.list_logs/2` with level filter. |
| WebSocket push notifications to browser | "Notify me when the experiment finishes" seems easy | Adds auth surface, browser permission UX, and user model complexity. This is a personal research tool, not a team dashboard. | Tab title update (document.title) with status change is simpler and cross-platform — already achievable with a small LiveView hook. |
| Editable configuration on the run page | "Let me tweak a param and re-run" is natural | The Instance+Run separation exists specifically to prevent this. Configuration is snapshotted at instance creation so runs are reproducible. Editing on the run page would undermine that guarantee. | Create a new Instance with different configuration. The new-instance flow should support cloning an existing instance. |
| Auto-retry on failure | "Retry the failed run automatically" is appealing | Silent auto-retry hides failure modes. In research, you need to know and understand failures, not paper over them. | Make failure states loud and clear. Let users manually retry after inspecting the error. |
| Export to CSV | "I want to analyze results in Excel" | Results are JSONB — arbitrary nested structure. Flattening to CSV requires knowing the schema ahead of time, which experiments don't expose. | Export as JSON or JSONL. Better long-term: a notebook/REPL integration that queries the DB directly (Livebook for Elixir). |
| Rich text / Markdown in log messages | "Let me format log output" | Increases rendering complexity, creates XSS surface, and makes logs inconsistent (some formatted, some not). | Syntax highlight JSON metadata in log messages. That covers 90% of the "readable structure" use case. |

## Feature Dependencies

```
[Virtualized Log Display]
    └──requires──> [JS Hook (AutoScroll + VirtualList)]
                       └──requires──> [Stable DOM IDs from LiveView streams] (already exists)

[Dark Mode]
    └──requires──> [DaisyUI Theme System] (already exists)
    └──requires──> [JS Hook for prefers-color-scheme detection]

[Log Metadata Expansion]
    └──requires──> [JS Hook or phx-click toggle]
    └──enhances──> [Virtualized Log Display] (expanded rows change row height)

[Result Tree View]
    └──requires──> [JSON parsing in client or server-rendered tree component]
    └──conflicts──> [Raw JSON pre-render] (replace, don't complement)

[Run Comparison View]
    └──requires──> [Run History List] (already exists)
    └──requires──> [Result query by key across runs] (Experiments.get_results_by_key/2 exists)

[Live Result Aggregation Stats]
    └──requires──> [Result stream] (already exists)
    └──requires──> [Client-side or server-side accumulator]
    └──enhances──> [Result Tree View]

[Sticky Run Status Header]
    └──requires──> [Layout restructure on run page]
    └──conflicts──> [Current top-of-page header] (needs to become sticky)

[Instance Clone]
    └──requires──> [Instance CRUD] (create_instance already exists)
    └──enhances──> [Configuration forms] (pre-populate from source instance)
```

### Dependency Notes

- **Virtualized Log Display requires JS Hook:** Phoenix LiveView streams manage DOM insertions server-side, but virtualization (rendering only visible rows) requires JavaScript that intercepts the stream and manages a virtual viewport. This is the highest-complexity feature and must be designed carefully to not break stream ordering.
- **Dark Mode requires JS Hook:** DaisyUI theming is CSS-based via `data-theme` on the `<html>` element. A small JS hook on mount reads `prefers-color-scheme`, sets the attribute, and listens for changes. Persistence via `localStorage` prevents flash-of-wrong-theme on reload.
- **Log Metadata Expansion conflicts with Virtualization:** If rows expand when clicked, the virtual scroller needs to know row heights. This creates coupling between two otherwise independent features. Implement virtualization first, then add expansion with fixed-height rows initially.
- **Result Tree View conflicts with current raw JSON render:** The existing `<pre>` display should be replaced entirely. A hybrid approach (tree by default, raw toggle) is the right end state but builds on the tree component existing first.

## MVP Definition

### Launch With (v1)

Minimum viable polish — what makes the existing functional UI feel professional and usable for a long experiment session.

- [ ] Scientific/technical visual identity — sets the tone for all other pages; must be done first as a design foundation
- [ ] Dark mode with system preference detection — ergonomic necessity for long sessions; DaisyUI makes this low-effort
- [ ] Virtualized log rendering — the run page is unusable for real experiments without this; 1000+ log entries break the current implementation
- [ ] Log level visual differentiation — stronger visual weight for errors and warnings; scan speed for high-volume logs
- [ ] Progress/status always visible while scrolling — users scroll through logs; losing the progress bar and cancel button breaks the monitoring experience
- [ ] Structured result display with JSON toggle — current raw `<pre>` is functional but not usable for complex nested results

### Add After Validation (v1.x)

Features to add once the core run monitoring experience is solid.

- [ ] Log metadata collapsible expansion — add once virtualization is stable, since expansion changes row geometry
- [ ] Instance clone — add when users start creating many similar configurations; triggered by observing repeated new-instance creation
- [ ] Tab title update with run status — low-effort quality of life; add when users report losing track of runs across tabs

### Future Consideration (v2+)

Features to defer until the tool sees regular use and patterns emerge.

- [ ] Run comparison view — requires usage patterns to reveal what comparisons matter (same config repeated? different models? different prompts?)
- [ ] Live result aggregation stats — requires knowing which result keys are quantitative vs qualitative; better designed against real experiment output
- [ ] Post-run log filtering and search — requires understanding actual debugging workflows from real research sessions

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Visual identity / design foundation | HIGH | MEDIUM | P1 |
| Dark mode | HIGH | LOW | P1 |
| Virtualized log rendering | HIGH | HIGH | P1 |
| Log level visual differentiation | HIGH | LOW | P1 |
| Sticky/always-visible run status | HIGH | MEDIUM | P1 |
| Structured result display (tree + JSON) | HIGH | MEDIUM | P1 |
| Log metadata collapsible expansion | MEDIUM | MEDIUM | P2 |
| Instance clone | MEDIUM | LOW | P2 |
| Tab title status update | LOW | LOW | P2 |
| Run comparison view | HIGH | HIGH | P3 |
| Live result aggregation stats | MEDIUM | HIGH | P3 |
| Post-run log filtering | MEDIUM | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch (this milestone)
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

The closest comparable tools are Weights & Biases (wandb), MLflow, and general-purpose log viewers like Kibana/Grafana. Athanor is closer to a personal lab notebook than a team MLOps platform.

| Feature | Weights & Biases | MLflow | Athanor Approach |
|---------|------------------|--------|------------------|
| Log display | Real-time streamed output panel, no level differentiation | Static artifact viewer, no live streaming | Live streaming via PubSub; level badges; virtualization needed |
| Result display | Rich charts, tables, metric panels auto-generated from logged keys | Table view for metrics, artifact browser for files | Key-value JSONB with tree view; no auto-charting (schema unknown) |
| Progress tracking | Step-based progress with live curves | Not real-time | Ephemeral progress bar; no historical progress curves |
| Dark mode | Yes | Partial | Yes (DaisyUI) |
| Configuration display | Tracked as hyperparameters with comparison table | Tracked as params | Rendered from config schema; no cross-run comparison yet |
| Run comparison | First-class feature — side-by-side metrics, diff | Comparison UI for runs | Not yet built |
| Data density | High — dashboards are information-dense | Medium | Target: high density, lab dashboard aesthetic |

**Key differentiation for Athanor:** W&B and MLflow assume structured numeric metrics that can be auto-charted. Athanor's results are arbitrary JSONB — the experiment defines the schema. This means Athanor cannot auto-generate charts but must provide good generic exploration tools (tree view, JSON toggle, raw query access).

## Sources

- Existing Athanor codebase: `apps/athanor_web/lib/athanor_web/live/experiments/`
- Architecture documentation: `docs/architecture.md`
- Project scope: `.planning/PROJECT.md`
- Comparable tools analyzed: Weights & Biases UI, MLflow UI, Kibana log viewer, Grafana dashboard patterns
- DaisyUI theme documentation for dark mode implementation approach

---
*Feature research for: Research/monitoring dashboard UI — live logs and structured results*
*Researched: 2026-02-16*
