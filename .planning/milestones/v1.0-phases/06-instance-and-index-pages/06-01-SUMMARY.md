---
phase: 06-instance-and-index-pages
plan: 01
subsystem: ui
tags: [elixir, ecto, liveview, phoenix, navbar, routing]

# Dependency graph
requires:
  - phase: 05-configuration-forms-polish
    provides: Instance context and forms that this builds upon
provides:
  - Experiments.list_instances_with_stats/0 for Index page run stats
  - Experiments.get_instance_stats/1 for PubSub-driven stat updates
  - Minimal Athanor navbar (sticky, border-b, theme toggle only)
  - /experiments/:id/edit route pointing to InstanceLive.Edit
affects: [06-02-instance-and-index-pages]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Ecto aggregate query pattern: left_join + group_by returning enriched maps (not structs) for stream compatibility

key-files:
  created: []
  modified:
    - apps/athanor/lib/athanor/experiments.ex
    - apps/athanor_web/lib/athanor_web/components/layouts.ex
    - apps/athanor_web/lib/athanor_web/router.ex

key-decisions:
  - "list_instances_with_stats/0 returns maps (not structs) so Index stream can use dom_id on item.instance.id"
  - "Edit route defined in Plan 01 separately from Edit module (Plan 02) to verify route pattern independently"
  - "Minimal nav: Athanor text link to /experiments + theme toggle only — no logo image, no external links"
  - "max-w-4xl for app layout main content to support experiment card grid"

patterns-established:
  - "Aggregate query pattern: from(i in Instance, left_join: r in assoc(i, :runs), group_by: i.id, select: %{instance: i, run_count: count(r.id), last_run_at: max(r.inserted_at)})"

requirements-completed: [IDX-01, IDX-02]

# Metrics
duration: 2min
completed: 2026-02-18
---

# Phase 6 Plan 01: Instance and Index Pages Backend Prep Summary

**Ecto aggregate stats queries for index run counts, minimal Athanor sticky navbar replacing Phoenix boilerplate, and edit route added to router**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-02-18T20:15:04Z
- **Completed:** 2026-02-18T20:17:02Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Added `list_instances_with_stats/0` and `get_instance_stats/1` to Experiments context using Ecto left join + group_by aggregate queries
- Replaced Phoenix boilerplate navbar (Website/GitHub/Get Started links) with minimal Athanor nav: sticky header with "Athanor" text link and theme toggle
- Added `/experiments/:id/edit` route pointing to `InstanceLive.Edit` (module to be created in Plan 02)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add aggregate stats queries to Experiments context** - `9e83372` (feat)
2. **Task 2: Replace Phoenix boilerplate navbar with Athanor minimal nav** - `953b39c` (feat)
3. **Task 3: Add edit route to router** - `15ce0da` (feat)

**Plan metadata:** (docs commit to follow)

## Files Created/Modified

- `apps/athanor/lib/athanor/experiments.ex` - Added list_instances_with_stats/0 and get_instance_stats/1 aggregate queries
- `apps/athanor_web/lib/athanor_web/components/layouts.ex` - Replaced Phoenix boilerplate header with minimal Athanor sticky nav, widened content to max-w-4xl
- `apps/athanor_web/lib/athanor_web/router.ex` - Added /experiments/:id/edit route

## Decisions Made

- `list_instances_with_stats/0` returns maps (not structs) so the Index page stream can use `dom_id: fn item -> item.instance.id end` pattern
- Edit route defined in this plan separately from the Edit LiveView module (Plan 02) — route pattern verified independently
- Minimal nav uses text "Athanor" linking to `/experiments`, no logo image, no external links
- `max-w-4xl` for main content area (was `max-w-2xl`) to better support card layouts

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Expected warning about `InstanceLive.Edit` module not yet defined appeared as planned; all other warnings are pre-existing in the codebase.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Experiments context ready for Index page to call `list_instances_with_stats/0`
- App navbar clean — shows Athanor branding + theme toggle
- Edit route ready — Plan 02 creates the `InstanceLive.Edit` module to back it

## Self-Check: PASSED

- experiments.ex: FOUND
- layouts.ex: FOUND
- router.ex: FOUND
- 06-01-SUMMARY.md: FOUND
- Commit 9e83372: FOUND
- Commit 953b39c: FOUND
- Commit 15ce0da: FOUND

---
*Phase: 06-instance-and-index-pages*
*Completed: 2026-02-18*
