---
phase: 06-instance-and-index-pages
plan: "03"
subsystem: ui
tags: [phoenix, liveview, router, live_session, layout]

# Dependency graph
requires:
  - phase: 06-instance-and-index-pages
    provides: "Layouts.app/1 function component with sticky header and padded main"
provides:
  - "live_session :experiments wrapping all four experiment instance routes with AthanorWeb.Layouts app layout"
  - "Sticky header and padded content area on all experiment instance pages (Index, Show, New, Edit)"
affects: [future-phases-using-experiment-routes]

# Tech tracking
tech-stack:
  added: []
  patterns: [live_session layout option for per-session layout configuration in Phoenix LiveView router]

key-files:
  created: []
  modified:
    - apps/athanor_web/lib/athanor_web/router.ex

key-decisions:
  - "live_session :experiments with layout option is the clean router-level fix for all four instance pages simultaneously rather than per-LiveView mount overrides"

patterns-established:
  - "Pattern: Use live_session layout: option in router to apply shared layout across a group of LiveViews instead of per-mount layout tuples"

requirements-completed: [IDX-01, IDX-02]

# Metrics
duration: 1min
completed: 2026-02-18
---

# Phase 6 Plan 03: Instance and Index Pages - App Layout Wiring Summary

**Router-level live_session :experiments block wires Layouts.app/1 to all four experiment LiveViews, fixing missing sticky header and padding in a single one-line change**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-02-18T20:50:06Z
- **Completed:** 2026-02-18T20:50:39Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Wrapped all four experiment instance routes (`/experiments`, `/experiments/new`, `/experiments/:id`, `/experiments/:id/edit`) in a `live_session :experiments` block with `layout: {AthanorWeb.Layouts, :app}`
- Fixed both Gap 2 (missing padding) and Gap 3 (non-functional sticky nav) simultaneously at the router level
- Left `/runs/:id` route outside the live_session so it continues managing its own `:run` layout via mount

## Task Commits

Each task was committed atomically:

1. **Task 1: Wrap experiment instance routes in live_session with app layout** - `9c8bea5` (feat)

**Plan metadata:** `3330899` (docs: complete live_session app layout wiring plan)

## Files Created/Modified
- `apps/athanor_web/lib/athanor_web/router.ex` - Added live_session :experiments block with layout: {AthanorWeb.Layouts, :app} around the four experiment instance routes

## Decisions Made
- Used `live_session` layout option in router (not per-LiveView mount tuples) — this is the idiomatic Phoenix LiveView approach for applying a shared layout to a group of LiveViews. Single point of configuration, applies uniformly to all four pages, no per-page boilerplate required.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None. The `mix compile` passed cleanly and `mix phx.routes AthanorWeb.Router` confirmed all four experiment routes remain correctly defined.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All experiment instance pages (Index, Show, New, Edit) now have the sticky Athanor nav and padded content area via Layouts.app/1
- Gap 2 (padding) and Gap 3 (sticky nav) are both resolved
- Ready for Phase 06 Plan 04 (remaining gap closure work)

---
*Phase: 06-instance-and-index-pages*
*Completed: 2026-02-18*

## Self-Check: PASSED

- FOUND: `apps/athanor_web/lib/athanor_web/router.ex`
- FOUND: `.planning/phases/06-instance-and-index-pages/06-03-SUMMARY.md`
- FOUND commit: `9c8bea5` (feat(06-03): wrap experiment routes in live_session with app layout)
- FOUND commit: `3330899` (docs(06-03): complete live_session app layout wiring plan)
