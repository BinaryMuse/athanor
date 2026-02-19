---
phase: 02-run-page-log-display
plan: 01
subsystem: ui
tags: [phoenix-liveview, streams, auto-scroll, log-panel, daisy-ui, mutation-observer]

# Dependency graph
requires:
  - phase: 01-visual-identity-and-theme-foundation
    provides: DESIGN-TOKENS.md semantic color conventions (text-base-content/40 for tertiary, badge-* for status)
provides:
  - LogPanel Phoenix.Component with bounded stream rendering (1000 DOM nodes max)
  - Bounded stream initialization with limit: -1000 on mount and all inserts
  - Bounded DB queries (limit: 1000) on mount and batch event handler
  - AutoScroll JS hook with isNearBottom() near-bottom detection (100px threshold)
affects: [future log-heavy views, any LiveView using stream with high-volume data]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@log_stream_limit module attribute as single source of truth for stream cap"
    - "stream/4 limit: and stream_insert/4 limit: must match — limit does NOT propagate"
    - "Pre-limit DB query on mount (limit: not enforced on dead render)"
    - "isNearBottom() MutationObserver guard prevents scroll-jump during history reading"
    - "Phoenix.Component extraction following StatusBadge/ProgressBar pattern"

key-files:
  created:
    - apps/athanor_web/lib/athanor_web/live/experiments/components/log_panel.ex
  modified:
    - apps/athanor_web/lib/athanor_web/live/experiments/run_live/show.ex
    - apps/athanor_web/assets/js/app.js

key-decisions:
  - "Stream limit of 1000 DOM nodes — balances visibility with browser performance at 10k+ log entries"
  - "Bounded reset on batch events (list_logs with limit) rather than carrying log entries in broadcast payload"
  - "AutoScroll hook stays in app.js (shared infrastructure) rather than colocated hook"
  - "Text opacity /40 for timestamps and metadata per DESIGN-TOKENS.md tertiary convention"

patterns-established:
  - "Pattern: @log_stream_limit 1_000 — define limit once, use in stream/4, stream_insert/4, and list_logs/2 calls"
  - "Pattern: isNearBottom() guard in MutationObserver — respects user scroll intent during active logging"

# Metrics
duration: ~2min
completed: 2026-02-17
---

# Phase 2 Plan 1: Run Page Log Display Summary

**Bounded LiveView log stream (1000 DOM nodes) with extracted LogPanel component and isNearBottom() auto-scroll hook preventing history-reading interruption**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-02-17T04:11:00Z
- **Completed:** 2026-02-17T04:12:36Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Extracted LogPanel Phoenix.Component from RunLive.Show inline log card, following the StatusBadge/ProgressBar pattern
- Wired bounded streams (limit: -1000) on mount, log_added inserts, and logs_added batch resets — DOM now capped at 1000 nodes
- Constrained DB queries to limit: 1000 on both mount and batch handler to prevent expensive unbounded queries
- Added isNearBottom() to AutoScroll MutationObserver: new logs no longer interrupt users reading scroll history
- Updated all text opacity to /40 for timestamps and metadata (DESIGN-TOKENS.md compliance, was /50)

## Task Commits

Each task was committed atomically:

1. **Task 1: Extract LogPanel component and wire bounded streams** - `1003655` (feat)
2. **Task 2: Refine AutoScroll hook with near-bottom detection** - `d122af7` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `apps/athanor_web/lib/athanor_web/live/experiments/components/log_panel.ex` - New LogPanel Phoenix.Component with log_panel/1, level badges, row coloring, format_timestamp/1
- `apps/athanor_web/lib/athanor_web/live/experiments/run_live/show.ex` - Added @log_stream_limit 1_000, bounded stream/stream_insert, bounded list_logs calls, replaced inline log card with LogPanel.log_panel call
- `apps/athanor_web/assets/js/app.js` - AutoScroll hook: added isNearBottom() with 100px threshold, MutationObserver now guards scroll with proximity check

## Decisions Made

- **Stream limit 1000:** Module attribute `@log_stream_limit 1_000` defines it once. Negative value (`-@log_stream_limit`) pruning from front (oldest) is correct for log tailing.
- **Batch handler keeps bounded DB query:** `{:logs_added, _count}` does a bounded `list_logs(run, limit: @log_stream_limit)` + stream reset. This avoids adding log entries to broadcast payload (would complicate Broadcasts module).
- **AutoScroll stays in app.js:** Shared infrastructure not worth colocating — used for any future auto-scroll panel.
- **/40 opacity for tertiary text:** Updated from existing /50 to match DESIGN-TOKENS.md. Affects timestamps, metadata, empty-state text.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Pre-existing compiler warning in `lib/experiment/config_schema.ex:31` (unused `opts` variable) is unrelated to these changes and was not introduced by this plan.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- LogPanel component ready for reuse in any future log-displaying view
- AutoScroll hook pattern established for near-bottom detection in other scrollable panels
- Run page ready for visual/functional verification: visit a run page, start an experiment, confirm bounded log streaming and auto-scroll behavior

---
*Phase: 02-run-page-log-display*
*Completed: 2026-02-17*

## Self-Check: PASSED

- FOUND: apps/athanor_web/lib/athanor_web/live/experiments/components/log_panel.ex
- FOUND: apps/athanor_web/lib/athanor_web/live/experiments/run_live/show.ex
- FOUND: apps/athanor_web/assets/js/app.js
- FOUND: .planning/phases/02-run-page-log-display/02-01-SUMMARY.md
- FOUND commit: 1003655 (feat(02-01): extract LogPanel component and wire bounded streams)
- FOUND commit: d122af7 (feat(02-01): refine AutoScroll hook with near-bottom detection)
