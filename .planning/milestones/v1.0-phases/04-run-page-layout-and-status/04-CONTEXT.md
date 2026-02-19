# Phase 4: Run Page Layout and Status - Context

**Gathered:** 2026-02-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Complete run page assembly with sticky header, tabbed log/results panels, clear status presentation, and reconnection handling. Custom experiment controls are a future project — but tab architecture should accommodate a future Controls tab.

</domain>

<decisions>
## Implementation Decisions

### Sticky Header Content
- Full dashboard: status badge + experiment name + elapsed time + progress indicator
- Stop/cancel button in header — primary action always visible
- Indeterminate spinner when experiment doesn't report progress
- Breadcrumb navigation: Experiment > Run #N — clear path back

### Panel Arrangement
- Tabs all the time (not split view) — Logs | Results
- Logs tab is default when viewing a run
- Tabs show counts: "Logs (1,234)" and "Results (5)"
- Tab architecture designed for extensibility (future Controls tab)

### State Presentation
- Running state: pulsing badge (subtle pulse animation, no spinner icon)
- End states: color-coded badges — green (success), red (failure), yellow (cancelled)
- Completion/failure notification: brief toast, delivered via global PubSub (visible on any page, not just run page)
- Elapsed time freezes at completion — shows final duration

### Reconnection Behavior
- Subtle inline indicator in header: "Reconnecting (attempt 3)..."
- Keep retrying with exponential backoff — never give up
- After reconnection: show "Refresh" button for user to manually catch up on missed data
- No auto-refresh — user controls when to sync

### Claude's Discretion
- Exact header layout and spacing
- Tab component implementation details
- Specific backoff timing for reconnection
- Toast notification styling and duration

</decisions>

<specifics>
## Specific Ideas

- Global PubSub for run completion events — important for monitoring long-running experiments from other pages
- Tab counts give at-a-glance volume understanding without switching tabs

</specifics>

<deferred>
## Deferred Ideas

- Custom controls defined by experiment module (phases, steps, manual triggers) — next project, but tab architecture should accommodate a future "Controls" tab

</deferred>

---

*Phase: 04-run-page-layout-and-status*
*Context gathered: 2026-02-16*
