---
phase: 05-configuration-forms-polish
plan: 02
subsystem: ui
tags: [phoenix-live-view, javascript, hooks, json, elixir, forms]

# Dependency graph
requires:
  - phase: 05-01
    provides: ConfigSchema struct with ordered properties list and field type support
provides:
  - ConfigSchema.to_serializable/1 converting struct to JSON-safe map with string keys
  - ConfigFormComponent rendering JS hook container with phx-update=ignore
  - ConfigFormHook rendering scalar fields (string, integer, boolean, enum, textarea) client-side
  - Form submission via hidden JSON input decoded server-side
  - Removed all obsolete server-side list management code from InstanceLive.New
affects: [05-03-configuration-forms-polish, experiments-new-page]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - JS hook owns DOM for dynamic form rendering (phx-update=ignore prevents LiveView overwrite)
    - Schema serialized to JSON data attribute; hook reads on mount and config_schema_changed event
    - Hidden input carries JSON state to server on form submit; server decodes with Jason
    - data-field-path JSON array on inputs enables nested state updates in JS

key-files:
  created:
    - apps/athanor_web/lib/athanor_web/live/experiments/components/config_form_component.ex
  modified:
    - apps/athanor/lib/experiment/config_schema.ex
    - apps/athanor_web/assets/js/app.js
    - apps/athanor_web/lib/athanor_web/live/experiments/instance_live/new.ex

key-decisions:
  - "ConfigFormHook manages all form DOM - phx-update=ignore on container prevents LiveView from clobbering hook-rendered fields"
  - "Schema serialized via to_serializable/1 to data attribute; push_event config_schema_changed sent on experiment type change so hook can re-init without page reload"
  - "List fields render placeholder in Plan 02; full list management is Plan 03 scope"
  - "form-control class replaced with fieldset mb-2 on experiment type select wrapper for DaisyUI v5 compatibility"

patterns-established:
  - "JS hook + hidden JSON input pattern: hook manages state/DOM, submits via single hidden field"
  - "to_serializable/1 pattern: convert Elixir structs with atoms to JSON-safe string-keyed maps for JS consumption"

requirements-completed: [CFG-01]

# Metrics
duration: 8min
completed: 2026-02-17
---

# Phase 5 Plan 02: ConfigFormComponent and ConfigFormHook for Client-Side Scalar Field Rendering Summary

**JS hook renders scalar config fields from JSON schema with client-side state management, replacing server-side form rendering and list management code**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-17T17:06:28Z
- **Completed:** 2026-02-17T17:14:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Added ConfigSchema.to_serializable/1 that recursively converts the schema struct to a JSON-safe map with string keys (handles groups, lists, enums, atoms)
- Created ConfigFormComponent with config_form/1 rendering minimal hook container (phx-update=ignore)
- Added ConfigFormHook to app.js: mounts from data-schema attribute, renders string/integer/number/boolean/enum/textarea fields, serializes state to hidden input on form submit
- Rewrote InstanceLive.New to use ConfigFormComponent; removed phx-change=validate and all obsolete server-side form management helpers

## Task Commits

Each task was committed atomically:

1. **Task 1: Add ConfigSchema.to_serializable/1 and ConfigFormComponent** - `cf1bf45` (feat)
2. **Task 2: Create ConfigFormHook for scalar fields and update InstanceLive.New** - `ca2a344` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `apps/athanor/lib/experiment/config_schema.ex` - Added to_serializable/1, serialize_field_def/1, stringify_field_def/1
- `apps/athanor_web/lib/athanor_web/live/experiments/components/config_form_component.ex` - New: ConfigFormComponent with config_form/1 function component
- `apps/athanor_web/assets/js/app.js` - Added ConfigFormHook with full scalar field rendering, state management, and form submission
- `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/new.ex` - Rewrote to use ConfigFormComponent; removed ~350 lines of obsolete server-side code

## Decisions Made
- Used phx-update=ignore on the hook container so LiveView does not overwrite JS-managed DOM after re-renders
- push_event("config_schema_changed") sent alongside assign on experiment type change, enabling the hook to re-initialize even when already mounted
- List fields show a placeholder in this plan ("List fields will be enabled in the next update") - Plan 03 will add full list support
- Removed phx-change="validate" from form since config inputs are now client-side only; form validation only happens on submit

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None - all files compiled cleanly with no warnings.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Client-side scalar field rendering is complete and working
- Plan 03 can now implement full list field management in ConfigFormHook (add/remove items, nested item schemas)
- The placeholder list rendering in ConfigFormHook (`createListPlaceholder`) provides the extension point for Plan 03

---
*Phase: 05-configuration-forms-polish*
*Completed: 2026-02-17*
