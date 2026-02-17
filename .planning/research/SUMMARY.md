# Project Research Summary

**Project:** Athanor UI
**Domain:** Phoenix LiveView dashboard — real-time log streaming with DaisyUI theming
**Researched:** 2026-02-16
**Confidence:** HIGH

## Executive Summary

Athanor is a Phoenix LiveView research harness that needs UI polish to handle long-running AI experiments producing thousands of log entries. The existing stack (Phoenix 1.8, LiveView 1.1, DaisyUI 5, Tailwind 4) is correct and modern — no framework changes are needed. The primary technical challenge is making the run page performant for high-volume log output without degrading over multi-hour sessions.

The recommended approach is to establish visual identity and theme infrastructure first (which affects all pages), then tackle the run page as the highest-value target. Phoenix's native `stream` with `:limit` option provides server-side memory management, and the existing `phx-viewport` bindings enable paginated virtualization without external JS libraries. For JSON results, use `json-formatter-js` as a lightweight hook-based tree viewer. Theme switching infrastructure is already complete in the codebase — only the UI toggle component needs to be added.

The critical risks are all performance-related: unbounded log streams causing socket memory bloat, per-log PubSub messages flooding the LiveView mailbox at high throughput, and unlimited database queries in batch handlers. All three must be addressed with explicit limits in the run page implementation. A secondary risk is DaisyUI/Tailwind class conflicts causing illegible text in dark mode — this requires dual-theme review on every component.

## Key Findings

### Recommended Stack

The existing Phoenix 1.8 stack is the correct 2026 choice. No new frameworks, CSS systems, or major dependencies are needed.

**Core technologies:**
- **Phoenix 1.8 + LiveView 1.1:** Already installed; provides native stream virtualization via `phx-viewport-top`/`phx-viewport-bottom` with no JS libraries required
- **DaisyUI 5.5 + Tailwind CSS 4:** Already installed via vendor JS; 75% smaller than DaisyUI 4, built for Tailwind 4's CSS variable system
- **json-formatter-js:** Add via npm; pure JS collapsible tree view that integrates cleanly with LiveView hooks; dark theme support

**What NOT to use:**
- tanstack-virtual / react-window — conflicts with LiveView DOM ownership
- daisy_ui_components hex package — outdated vs built-in Phoenix 1.8 DaisyUI integration
- Alpine.js for theme toggling — the existing `phx:set-theme` infrastructure is sufficient

### Expected Features

**Must have (table stakes):**
- Live log display with auto-scroll — already functional but needs virtualization
- Log level visual differentiation — partially implemented; needs stronger visual weight
- Run status indicator with progress — StatusBadge and ProgressBar exist
- Structured result display — currently raw JSON; needs tree view
- Dark mode — infrastructure exists; needs UI toggle

**Should have (differentiators):**
- Virtualized log rendering for 1000+ entries — essential for real experiments
- Scientific/technical visual aesthetic — sets the tone for a research tool
- Sticky header with run status always visible — ergonomic for long sessions
- Result tree view with JSON toggle — explores nested data without scrolling JSON

**Defer (v2+):**
- Run comparison view — needs usage patterns to inform design
- Live result aggregation stats — needs schema knowledge from real experiments
- Post-run log filtering and search — better as post-hoc analysis feature

### Architecture Approach

The architecture uses LiveView pages with LiveComponent sub-sections for state isolation. Parent LiveViews own PubSub subscriptions and stream data; child LiveComponents handle local interactive state (auto-scroll toggle, filter state). Function components handle pure rendering (StatusBadge, ProgressBar, ConfigField). JS hooks handle client-side behavior that cannot be expressed in LiveView (theme persistence, auto-scroll, eventual virtual scroll).

**Major components:**
1. **RunLive.Show** — owns run state, PubSub subscription, stream coordination
2. **LogPanelComponent** — owns log stream display, auto-scroll toggle, receives logs from parent via stream
3. **ResultsPanelComponent** — owns results stream display with tree/JSON toggle
4. **ConfigFormComponent** — owns schema-driven form state for list items, validation
5. **ThemeToggle** — function component + hook for `phx:set-theme` dispatch

**Build order:** Leaf function components first (ConfigField), then LiveComponents (LogPanelComponent, ResultsPanelComponent, ConfigFormComponent), then LiveView refactors (RunLive.Show, InstanceLive.New), then optional VirtualScroll hook if needed.

### Critical Pitfalls

1. **Unbounded log stream server memory** — Use `stream_insert(:logs, log, limit: 2000)` always; socket memory will grow indefinitely without this
2. **Per-log PubSub message flooding** — Batch logs at producer (RunServer) and/or coalesce at consumer (LiveView) with `send_after`; per-log broadcasts saturate the socket at high throughput
3. **Unlimited `list_logs` in batch handler** — Always pass `limit:` to `list_logs`; a 50k-row query on every batch notification combines DB load with socket memory explosion
4. **Theme FOUC** — Move inline theme script before CSS `<link>` in root.html.heex; script must block paint to prevent white flash
5. **DaisyUI + Tailwind color class conflicts** — Never use `text-white`, `text-black` next to DaisyUI semantic classes; use DaisyUI's CSS variable-based content colors instead

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Visual Identity and Theme Foundation

**Rationale:** All UI pages depend on the visual system. Establishing color palette, typography, spacing, and theme switching first creates a foundation that all subsequent work builds on. Theme FOUC and class conflict pitfalls must be addressed here before they propagate.

**Delivers:** Design tokens documented, both themes verified across all existing pages, theme toggle component in layout

**Addresses:** Dark mode, scientific aesthetic, theme FOUC prevention

**Avoids:** DaisyUI class conflicts (dual-theme review becomes standard practice)

### Phase 2: Run Page Log Display (Virtualized)

**Rationale:** The run page is the core value of the tool — it is where users spend hours monitoring experiments. Log virtualization is the single highest-value technical feature. This phase must address all three critical log-related pitfalls or the page becomes unusable for real experiments.

**Delivers:** LogPanelComponent with stream limits, batched log handling, auto-scroll that does not thrash, 10k-log capability

**Uses:** Native LiveView streams with `:limit`, `phx-viewport-bottom` for pagination

**Avoids:** Unbounded stream memory, per-log PubSub flooding, unlimited `list_logs` queries

### Phase 3: Run Page Results Display

**Rationale:** Results display is less performance-critical than logs (fewer entries, larger per-item) but equally important for usability. Tree view with JSON toggle transforms the results panel from a wall of text into an exploration tool.

**Delivers:** ResultsPanelComponent with json-formatter-js tree view, raw JSON toggle, safe encoding wrapper

**Uses:** json-formatter-js via LiveView hook

**Avoids:** `Jason.encode!` crash on non-serializable values

### Phase 4: Run Page Layout and Status

**Rationale:** With log and results panels working, this phase assembles them into a polished run page layout with sticky header, progress always visible, and proper error/completion states.

**Delivers:** Complete RunLive.Show refactor with LiveComponent delegation, sticky run status header, reconnect/staleness detection

**Addresses:** Sticky header with run status, socket disconnect handling

### Phase 5: Configuration Forms Polish

**Rationale:** Configuration forms are the entry point for experiments. Extracting ConfigFormComponent and ConfigField components improves code organization and enables future features like instance cloning.

**Delivers:** ConfigFormComponent, ConfigField function components, schema-driven field rendering

**Uses:** LiveComponent state isolation pattern

### Phase 6: Instance and Index Pages

**Rationale:** Lower priority than run page but needed for complete polish. Simpler scope — mostly applying the visual system established in Phase 1.

**Delivers:** Polished InstanceLive.Index, InstanceLive.Show with consistent styling

### Phase Ordering Rationale

- **Phase 1 first:** Visual identity affects all pages; doing it first prevents rework
- **Phases 2-4 sequential:** Log display depends on stream infrastructure, results display is independent but similar complexity, layout integrates both
- **Phase 5 after run page:** Config forms are simpler and less time-sensitive than run monitoring
- **Phase 6 last:** Index/show pages are polish on top of existing functional pages

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Log Display):** The `phx-viewport-bottom` pagination pattern with `_overran` handling is well-documented but has edge cases. May need experimentation to get scroll position management correct.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Visual Identity):** DaisyUI theming is well-documented; existing infrastructure is already correct
- **Phase 3 (Results Display):** json-formatter-js has straightforward API; LiveView hook pattern is standard
- **Phase 5 (Config Forms):** Pure LiveComponent refactoring; no external dependencies

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Phoenix 1.8 + DaisyUI 5 is the current standard; verified against official release notes |
| Features | HIGH | Feature set derived from codebase analysis + W&B/MLflow comparison |
| Architecture | HIGH | LiveView component patterns well-documented; existing code provides concrete structure |
| Pitfalls | HIGH | Based on direct codebase analysis; performance risks are measurable |

**Overall confidence:** HIGH

### Gaps to Address

- **High-volume stress testing:** Research identified thresholds (5k logs, 50 logs/sec) but actual performance needs measurement on target hardware during implementation
- **Log metadata expansion:** Feature identified but deliberately deferred due to interaction with virtualization; needs design once log panel is stable
- **Instance cloning:** Identified as a future feature; implementation details not researched

## Sources

### Primary (HIGH confidence)
- Phoenix 1.8.0 release blog — DaisyUI integration, theme toggle, Tailwind 4
- DaisyUI 5 release notes — Tailwind 4 dependency, CSS variable architecture
- LiveView 1.1 changelog — ColocatedHook, phx-viewport bindings
- LiveView bindings documentation — stream limits, `_overran` param
- Existing codebase: `apps/athanor_web/lib/athanor_web/`

### Secondary (MEDIUM confidence)
- json-formatter-js GitHub — API, dark theme support
- Elixir Forum TreeView thread (Jan 2025) — community consensus on JS hook approach
- W&B/MLflow UI analysis — feature comparison

### Tertiary (LOW confidence)
- Virtual scroll pattern details — needs validation during implementation

---
*Research completed: 2026-02-16*
*Ready for roadmap: yes*
