---
phase: 04-run-page-layout-and-status
plan: 01
subsystem: ui
tags: [phoenix-liveview, daisy-ui, tailwind, pubsub, sticky-header, tabs, live-elapsed-time, reconnection]

# Dependency graph
requires:
  - phase: 03-run-page-results-display
    provides: ResultsPanel component, lazy hydration, stream-based results display
  - phase: 02-run-page-log-display
    provides: LogPanel component, AutoScroll hook, stream-based log display

provides:
  - Dedicated wide run layout (no max-w-2xl constraint)
  - Sticky header with status badge, breadcrumb, elapsed time, progress, cancel
  - Tab-based Logs/Results panels with live counts
  - Elapsed time ticker (1s interval, freezes at completion)
  - ReconnectionTracker JS hook for disconnect/reconnect UX
  - Global PubSub run completion toasts on InstanceLive.Show

affects: [05-future-phases, any-liveview-adding-completion-toasts]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Dedicated layout function (run/1) for monitoring pages without navbar constraint"
    - "Process.send_after :tick pattern for live elapsed time ticker"
    - "JS hook disconnected/reconnected lifecycle for custom reconnection UX"
    - "Server-side :active_tab assign for tab switching (enables future conditional subscriptions)"
    - "hidden Tailwind class for tab panels (streams remain in DOM when hidden)"
    - "Global PubSub subscription (experiments:runs:active) for cross-page completion toasts"

key-files:
  created: []
  modified:
    - apps/athanor_web/lib/athanor_web/components/layouts.ex
    - apps/athanor_web/lib/athanor_web/live/experiments/run_live/show.ex
    - apps/athanor_web/lib/athanor_web/live/experiments/components/status_badge.ex
    - apps/athanor_web/lib/athanor_web/live/experiments/components/log_panel.ex
    - apps/athanor_web/lib/athanor_web/live/experiments/components/results_panel.ex
    - apps/athanor_web/live/experiments/instance_live/show.ex
    - apps/athanor_web/assets/js/app.js

key-decisions:
  - "Dedicated run/1 layout function in layouts.ex (not a .heex file) — simpler, avoids embed_templates coupling"
  - "Server-side :active_tab assign for tab switching — enables future conditional subscriptions per tab"
  - "hidden class for inactive tab panels — streams remain in DOM, no duplicate/ordering bugs on switch"
  - "Process.send_after :tick only when run.status == running — stops automatically at terminal state"
  - "ReconnectionTracker hook uses setInterval (not Phoenix socket internals) — approximate count, approach verified as sound"
  - "Global PubSub toast via InstanceLive.Show subscription — run page skips toast (sticky header shows status directly)"

patterns-established:
  - "Pattern: use {layout: {AthanorWeb.Layouts, :run}} in mount opts for wide monitoring views"
  - "Pattern: Process.send_after :tick for server-side live counters that need to stop on state change"
  - "Pattern: JS hook with disconnected/reconnected/destroyed lifecycle for custom reconnection tracking"

# Metrics
duration: 4min
completed: 2026-02-17
---

# Phase 4 Plan 01: Run Page Layout and Status Summary

**Wide run monitoring layout with sticky header, tabbed Logs/Results panels, live elapsed time ticker, reconnection UX, and global PubSub completion toasts**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-17T17:40:40Z
- **Completed:** 2026-02-17T17:44:06Z
- **Tasks:** 4
- **Files modified:** 7

## Accomplishments

- Replaced narrow app layout with a dedicated wide run/1 layout (no max-w-2xl, no navbar) for full-width monitoring dashboard
- Refactored RunLive.Show with sticky header (status badge, breadcrumb, elapsed time, progress, cancel button) and tabbed Logs/Results panels with live counts
- Added live elapsed time ticker updating every second while running, freezing at completion when run transitions to terminal state
- Added ReconnectionTracker JS hook tracking disconnect/reconnect lifecycle with attempt counter and server-side Refresh button UX
- Added global PubSub subscription on InstanceLive.Show for run completion/failure/cancellation toast notifications

## Task Commits

Each task was committed atomically:

1. **Task 1: Add dedicated run layout and update StatusBadge** - `5af184f` (feat)
2. **Task 2: Refactor RunLive.Show with sticky header, tabs, and elapsed ticker** - `4279a53` (feat)
3. **Task 3: Add ReconnectionTracker JS hook** - `d42eaed` (feat)
4. **Task 4: Add global PubSub subscription for run completion toasts** - `c277d7b` (feat)

**Plan metadata:** _(this commit)_ (docs: complete plan)

## Files Created/Modified

- `apps/athanor_web/lib/athanor_web/components/layouts.ex` - Added run/1 layout function with flash_group and full-screen wrapper, no navbar or max-w-2xl
- `apps/athanor_web/lib/athanor_web/live/experiments/run_live/show.ex` - Major refactor: sticky header, tab state, elapsed ticker, reconnection state, refresh_data handler
- `apps/athanor_web/lib/athanor_web/live/experiments/components/status_badge.ex` - Added animate-pulse to running badge class
- `apps/athanor_web/lib/athanor_web/live/experiments/components/log_panel.ex` - Removed card wrapper, content renders directly in tab panel
- `apps/athanor_web/lib/athanor_web/live/experiments/components/results_panel.ex` - Removed card wrapper, content renders directly in tab panel
- `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/show.ex` - Added experiments:runs:active PubSub subscription and :run_completed handler
- `apps/athanor_web/assets/js/app.js` - Added ReconnectionTracker hook with disconnected/reconnected/destroyed lifecycle

## Decisions Made

- Used direct run/1 function in layouts.ex (not a separate run.html.heex file) — simpler and consistent with the app/1 pattern already in use
- Server-side :active_tab assign controls tab visibility rather than pure JS — allows future conditional subscriptions or actions per tab
- Tab panels use hidden Tailwind class, not conditional rendering — ensures phx-update="stream" elements stay in DOM so stream state is preserved across tab switches
- Ticker only schedules next tick when run.status == "running" — naturally self-terminating without needing explicit cancellation

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Run page is now a polished monitoring dashboard with all required UX features
- Layout is extensible: additional tabs can be added without structural changes (the tab pattern supports future Controls tab)
- Ready for Phase 5

## Self-Check: PASSED

All 7 files confirmed present on disk. All 4 task commits confirmed in git log (5af184f, 4279a53, d42eaed, c277d7b).

---
*Phase: 04-run-page-layout-and-status*
*Completed: 2026-02-17*
