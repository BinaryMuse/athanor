---
phase: 06-instance-and-index-pages
plan: 04
subsystem: ui
tags: [javascript, phoenix-live-view, ecto, daisyui]

# Dependency graph
requires:
  - phase: 06-instance-and-index-pages
    provides: Edit page with ConfigFormComponent that sets data-initial-values; Index page with stats-shaped stream items
  - phase: 05-configuration-forms-polish
    provides: ConfigFormHook in app.js managing JS config form state
provides:
  - ConfigFormHook.deepMerge helper for recursive object merging
  - ConfigFormHook.mounted() reads data-initial-values and merges into state before render
  - list_instances_with_stats/0 returns last_run_status via correlated subquery
  - get_instance_stats/1 returns last_run_status via correlated subquery
  - Index page cards render StatusBadge for instances with at least one run
affects: [06-instance-and-index-pages]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - data-initial-values attribute on hook element for edit-mode pre-population
    - Correlated subquery via fragment/2 for non-aggregate field in GROUP BY query
    - deepMerge: objects recurse, arrays replace entirely (matches hook list state management)

key-files:
  created: []
  modified:
    - apps/athanor_web/assets/js/app.js
    - apps/athanor/lib/athanor/experiments.ex
    - apps/athanor_web/lib/athanor_web/live/experiments/instance_live/index.ex

key-decisions:
  - "deepMerge replaces arrays entirely rather than merging — matches how hook manages list state as indexed arrays"
  - "handleEvent config_schema_changed intentionally unchanged — resets to schema defaults on experiment type switch"
  - "Correlated subquery (SELECT status FROM runs WHERE instance_id = ? ORDER BY inserted_at DESC LIMIT 1) used instead of lateral join — simpler, SQLite-compatible"

patterns-established:
  - "Edit mode pre-population: server sets data-initial-values JSON on hook element; hook reads in mounted() only"
  - "Non-aggregate field in aggregated query: use fragment correlated subquery, not a join"

requirements-completed: [IDX-01, IDX-02]

# Metrics
duration: 1min
completed: 2026-02-18
---

# Phase 6 Plan 04: Gap Closure Summary

**Edit page config pre-population via deepMerge of data-initial-values in ConfigFormHook.mounted(), and index cards showing last-run StatusBadge from correlated subquery stats.**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-02-18T20:50:06Z
- **Completed:** 2026-02-18T20:51:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- ConfigFormHook.mounted() now reads `data-initial-values` from the element dataset and deep-merges into schema-initialized state before rendering — edit page shows existing config values pre-populated
- Added deepMerge helper to ConfigFormHook that recursively merges objects but replaces arrays entirely (matching hook list state model)
- Both `list_instances_with_stats/0` and `get_instance_stats/1` now return `last_run_status` via a correlated subquery fragment
- Index page cards render `StatusBadge` conditionally when `last_run_status` is non-nil, showing green/red/blue/ghost badges for completed/failed/running/pending states

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire ConfigFormHook to read data-initial-values on mount** - `248b947` (feat)
2. **Task 2: Add last_run_status to stats queries and render StatusBadge on index cards** - `eefc2da` (feat)

## Files Created/Modified

- `apps/athanor_web/assets/js/app.js` - Added data-initial-values merge in mounted() and deepMerge helper method
- `apps/athanor/lib/athanor/experiments.ex` - Updated both stats functions to include last_run_status via fragment subquery
- `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/index.ex` - Added StatusBadge alias, conditional badge render in card template, last_run_status: nil in fake_stats

## Decisions Made

- deepMerge replaces arrays entirely rather than merging — edit page saves full list state, so initial values contains complete lists; hook expects arrays not partial merges
- handleEvent("config_schema_changed") intentionally unchanged — when user switches experiment type on New page, full schema reset is correct behavior
- Correlated subquery used for last_run_status instead of lateral join — simpler SQL that works correctly with SQLite and avoids GROUP BY complications

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 6 gap closure complete: edit page pre-population works, index cards show status badges
- All four Phase 6 plans now complete
- Project is feature-complete for Phase 6

---
*Phase: 06-instance-and-index-pages*
*Completed: 2026-02-18*

## Self-Check: PASSED

- FOUND: apps/athanor_web/assets/js/app.js
- FOUND: apps/athanor/lib/athanor/experiments.ex
- FOUND: apps/athanor_web/lib/athanor_web/live/experiments/instance_live/index.ex
- FOUND: .planning/phases/06-instance-and-index-pages/06-04-SUMMARY.md
- FOUND: commit 248b947 (Task 1)
- FOUND: commit eefc2da (Task 2)
