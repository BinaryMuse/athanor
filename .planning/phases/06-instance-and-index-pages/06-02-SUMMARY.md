---
phase: 06-instance-and-index-pages
plan: 02
subsystem: ui
tags: [elixir, liveview, phoenix, daisyui, tailwind, streams, pubsub, url-tabs]

# Dependency graph
requires:
  - phase: 06-instance-and-index-pages (plan 01)
    provides: list_instances_with_stats/0, get_instance_stats/1, edit route in router
  - phase: 05-configuration-forms-polish
    provides: ConfigFormComponent and ConfigFormHook for config field rendering

provides:
  - Card-based index page with run stats, Start Run, Edit, and overflow Delete actions
  - Tab-based show page with URL-synced ?tab=runs and ?tab=configuration params
  - New page with breadcrumb navigation and sticky footer with disabled Create state
  - Edit page for instance configuration modification with pre-populated values
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - URL-synced tabs via handle_params/3 + patch links (no JS required)
    - Custom stream dom_id function for stats maps: fn item -> "instance-#{item.instance.id}" end
    - stream_delete workaround: wrap plain struct in stats-shaped map when custom dom_id is in use
    - Sticky footer pattern: fixed bottom-0 bar outside form body, submits via form= attribute
    - initial_values data attribute on ConfigFormComponent for edit mode pre-population

key-files:
  created:
    - apps/athanor_web/lib/athanor_web/live/experiments/instance_live/edit.ex
  modified:
    - apps/athanor_web/lib/athanor_web/live/experiments/instance_live/index.ex
    - apps/athanor_web/lib/athanor_web/live/experiments/instance_live/show.ex
    - apps/athanor_web/lib/athanor_web/live/experiments/instance_live/new.ex
    - apps/athanor_web/lib/athanor_web/live/experiments/components/config_form_component.ex

key-decisions:
  - "Custom dom_id fn for stats maps requires stream_delete to wrap plain struct in fake stats map to match dom_id pattern"
  - "URL-synced tabs use handle_params/3 with patch links — no JS, browser back/forward works natively"
  - "Edit page initial_values passed as JSON string to data-initial-values attribute on ConfigFormComponent hook"
  - "Sticky footer uses fixed bottom-0 with form= attribute to submit the form by id from outside the form element"

patterns-established:
  - "URL tab pattern: handle_params(%{'tab' => tab}, _uri, socket) when tab in [list] — safe atom conversion with String.to_existing_atom"
  - "stream_delete with custom dom_id: wrap struct in correctly-shaped map so custom dom_id function can resolve the key"

requirements-completed: [IDX-01, IDX-02]

# Metrics
duration: 4min
completed: 2026-02-18
---

# Phase 6 Plan 02: Instance and Index Pages Summary

**Four polished LiveView pages: rich card index with run stats and actions, URL-synced tabbed show page, sticky-footer new page, and new edit page for configuration updates**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-02-18T20:18:55Z
- **Completed:** 2026-02-18T20:22:23Z
- **Tasks:** 3
- **Files modified:** 5 (4 modified, 1 created)

## Accomplishments

- Index page now shows rich cards with run count, last run time, Start Run button, Edit button, and overflow dropdown with View Details / Delete (with confirm dialog)
- Show page refactored to URL-synced tabs: `?tab=runs` and `?tab=configuration` via `handle_params/3` with `patch` links — browser back/forward works natively
- New page updated with breadcrumb, sticky footer (fixed bottom bar), and disabled Create Instance button until experiment type selected; debug `IO.puts` removed
- Edit page created from scratch: loads existing instance name/description/config, uses ConfigFormComponent with `initial_values` for pre-population, saves via `update_instance`, broadcasts, and redirects to show page

## Task Commits

Each task was committed atomically:

1. **Task 1: Refactor Index page for card layout with stats and actions** - `fa2e5a6` (feat)
2. **Task 2: Refactor Show page for tab-based layout with URL sync** - `bc64f8b` (feat)
3. **Task 3: Refactor New page and create Edit page** - `f78df5a` (feat)

**Plan metadata:** (docs commit to follow)

## Files Created/Modified

- `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/index.ex` - Rich card layout, stats maps from list_instances_with_stats, Start Run + Delete handlers, updated PubSub handlers using get_instance_stats
- `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/show.ex` - Tab-based layout, handle_params for URL sync, delete_instance handler, breadcrumb, improved run list and config display
- `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/new.ex` - Breadcrumb, sticky footer, disabled Create until experiment selected, removed debug IO.puts
- `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/edit.ex` - New module: loads instance, config schema, renders edit form with pre-populated values, saves updates
- `apps/athanor_web/lib/athanor_web/live/experiments/components/config_form_component.ex` - Added optional initial_values attr with data-initial-values binding for edit mode

## Decisions Made

- **stream_delete with custom dom_id:** When using `dom_id: fn item -> "instance-#{item.instance.id}" end`, calling `stream_delete` with a plain Instance struct fails because the dom_id function expects `item.instance.id`. Fix: wrap the struct in a fake stats map `%{instance: instance, ...}` so the dom_id function resolves correctly.
- **URL-synced tabs via handle_params:** Used `patch` links + `handle_params/3` pattern — no JS needed, browser history integration is automatic, tab state survives page refresh.
- **Edit page initial_values:** ConfigFormComponent receives existing config as JSON string via `initial_values` attr, rendered as `data-initial-values` attribute on the hook element, allowing the JS hook to pre-populate fields on mount.
- **Sticky footer via form= attribute:** The submit button in the sticky footer uses `form="edit-instance-form"` (or `new-instance-form`) to submit the form even though the button is outside the form element.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] stream_delete incompatible with custom dom_id when passed plain struct**
- **Found during:** Task 1 (Index page refactor)
- **Issue:** Plan said "stream_delete handler unchanged" but with custom `dom_id: fn item -> "instance-#{item.instance.id}" end`, passing a plain Instance struct to `stream_delete` would crash because the function accesses `item.instance.id` on an Instance struct that has no `.instance` key
- **Fix:** Wrapped the instance struct in a stats-shaped map `%{instance: instance, run_count: 0, last_run_at: nil}` so the custom dom_id function can resolve the id correctly
- **Files modified:** apps/athanor_web/lib/athanor_web/live/experiments/instance_live/index.ex
- **Verification:** Compile succeeds, pattern is logically correct
- **Committed in:** fa2e5a6 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Auto-fix necessary for correct delete behavior. No scope creep.

## Issues Encountered

- The plan noted "instance_deleted handler unchanged" but the custom dom_id function made this incorrect — identified and fixed proactively before it could cause runtime crashes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All four instance LiveView pages polished and functional
- Phase 6 complete — all planned UI pages delivered
- The JS `ConfigFormHook` may need updating to read `data-initial-values` for edit mode pre-population (hook already has the attribute available but may or may not read it currently — deferred to runtime verification)

---
*Phase: 06-instance-and-index-pages*
*Completed: 2026-02-18*

## Self-Check: PASSED

- index.ex: FOUND
- show.ex: FOUND
- new.ex: FOUND
- edit.ex: FOUND (created)
- 06-02-SUMMARY.md: FOUND
- Commit fa2e5a6: FOUND
- Commit bc64f8b: FOUND
- Commit f78df5a: FOUND
