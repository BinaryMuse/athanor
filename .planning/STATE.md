# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-16)

**Core value:** The run page must display live logs and structured results clearly and performantly, even for experiments that produce thousands of log entries over hours of execution.
**Current focus:** Phase 6 - Instance and Index Pages - Gap closure plans in progress

## Current Position

Phase: 6 of 6 (Instance and Index Pages)
Plan: 3 of 4
Status: Plan 06-03 complete (wired live_session :experiments with Layouts.app layout for sticky header and padding on all instance pages). Plan 06-04 remaining.
Last activity: 2026-02-18 - Completed 06-03

Progress: [#########.] 90%

## Performance Metrics

**Velocity:**
- Total plans completed: 7
- Average duration: ~2 min
- Total execution time: ~20 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-visual-identity-and-theme-foundation | 1/1 done | ~2 min | ~2 min |
| 02-run-page-log-display | 2/2 done | ~5 min | ~2.5 min |
| 03-run-page-results-display | 2/2 done | ~4 min | ~2 min |
| 04-run-page-layout-and-status | 1/1 done | ~4 min | ~4 min |
| 05-configuration-forms-polish | 3/3 done | ~12 min | ~4 min |

**Recent Trend:**
- Last 5 plans: -
- Trend: -

*Updated after each plan completion*
| Phase 06 P01 | 2 | 3 tasks | 3 files |
| Phase 06 P02 | 4 | 3 tasks | 5 files |
| Phase 06 P03 | 1 | 1 task | 1 file |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Init]: project initialized
- [Phase 01-visual-identity-and-theme-foundation]: Move theme init script before CSS link tag to prevent FOUC in dark mode
- [Phase 01-visual-identity-and-theme-foundation]: Scientific teal primary (hue 190-220) replacing Phoenix orange (hue 47) for professional aesthetic
- [Phase 01-visual-identity-and-theme-foundation]: Semantic-only color rule established: no text-white, text-gray-*, bg-white in templates
- [Phase 02-run-page-log-display]: Stream limit of 1000 DOM nodes — balances visibility with browser performance at 10k+ log entries
- [Phase 02-run-page-log-display]: Bounded reset on batch events (list_logs with limit) rather than carrying log entries in broadcast payload
- [Phase 02-run-page-log-display]: AutoScroll hook stays in app.js (shared infrastructure) rather than colocated hook
- [Phase 02-run-page-log-display]: stream/4 limit: does NOT propagate to stream_insert/4 — must pass limit: on every insert
- [Phase 02-run-page-log-display]: ETS tables are :public so Runtime can write directly without message passing to RunBuffer
- [Phase 02-run-page-log-display]: RunBuffer started before RunServer per-run so ETS tables exist before experiment begins
- [Phase 02-run-page-log-display]: flush_sync called in both Runtime.complete/fail and RunServer helpers - safe due to idempotent flush
- [Phase 03-run-page-results-display]: Recursive defp json_tree/1 with three pattern-matched clauses (map/list/scalar) for arbitrary JSON rendering
- [Phase 03-run-page-results-display]: assigns = assign(assigns, :entries, ...) pattern to avoid HEEx external-variable warnings in recursive component
- [Phase 03-run-page-results-display]: encode_json/1 helper using Jason.encode/2 (not bang) with [encoding error] fallback
- [Phase 03-run-page-results-display]: First-level keys (depth=0) start expanded; depth > 0 starts collapsed
- [Phase 03-run-page-results-display]: JS.toggle_class for client-side tree expand/collapse survives LiveView DOM patches
- [Phase 03-run-page-results-display]: Function head pattern matching for lazy hydration: hydrated: true head renders full tree, fallback renders clickable stub
- [Phase 03-run-page-results-display]: Map.put virtual hydrated field on Ecto struct: augmented before stream_insert, no schema change needed
- [Phase 03-run-page-results-display]: stream_insert with same ID replaces stream item in-place: lazy hydration update mechanism
- [Phase 04-run-page-layout-and-status]: Dedicated run/1 layout function in layouts.ex (not .heex file) — simpler, avoids embed_templates coupling
- [Phase 04-run-page-layout-and-status]: Server-side :active_tab assign for tab switching — enables future conditional subscriptions per tab
- [Phase 04-run-page-layout-and-status]: hidden class for inactive tab panels — streams remain in DOM, no duplicate/ordering bugs on switch
- [Phase 04-run-page-layout-and-status]: Process.send_after :tick only when run.status == running — stops automatically at terminal state
- [Phase 04-run-page-layout-and-status]: ReconnectionTracker hook uses setInterval (not Phoenix socket internals) — approximate count, approach verified as sound
- [Phase 04-run-page-layout-and-status]: Global PubSub toast via InstanceLive.Show — run page skips toast (sticky header shows status directly)
- [Phase 05-configuration-forms-polish]: Properties changed from map to ordered list of tuples to preserve definition sequence for form rendering
- [Phase 05-configuration-forms-polish]: Nil opts stripped from field maps via Enum.reject to keep schema maps clean
- [Phase 05-configuration-forms-polish]: Client-side form management — JS form library handles state, LiveView only validates/saves on submit (server-side sync proved problematic for nested dynamic lists)
- [Phase 05-configuration-forms-polish]: ConfigFormHook manages DOM with phx-update=ignore — LiveView cannot overwrite JS-rendered fields
- [Phase 05-configuration-forms-polish]: push_event config_schema_changed sent alongside assign so hook re-initializes on experiment type change
- [Phase 05-configuration-forms-polish]: JS hook + hidden JSON input pattern — hook manages state/DOM, submits via single hidden field decoded by Jason on server
- [Phase 05-configuration-forms-polish]: List rendering via renderListField/renderListItem with dataset attributes for event delegation via closest()
- [Phase 05-configuration-forms-polish]: Full re-render on every list mutation (add/remove/move) — keeps state/DOM in sync without per-item listener rebinding
- [Phase 05-configuration-forms-polish]: Touch-tracked validation — touched Set + errors Map, blur adds to touched, validateAll runs on submit to block if errors exist
- [Phase 06]: list_instances_with_stats/0 returns maps not structs so Index stream can use dom_id on item.instance.id
- [Phase 06]: Minimal Athanor nav: text link to /experiments + theme toggle only, no Phoenix boilerplate links
- [Phase 06]: max-w-4xl for app layout main content (was max-w-2xl) to support experiment card grid
- [Phase 06]: stream_delete with custom dom_id requires wrapping plain struct in stats-shaped map so dom_id fn resolves correctly
- [Phase 06]: URL-synced tabs via handle_params/3 + patch links — no JS needed, browser history integration automatic
- [Phase 06]: Edit page initial_values passed as JSON string to data-initial-values on ConfigFormComponent hook element
- [Phase 06]: Sticky footer uses fixed bottom-0 bar with form= attribute to submit form from outside the form element
- [Phase 06-03]: live_session :experiments with layout option is the clean router-level fix for all four instance pages simultaneously rather than per-LiveView mount overrides

### Pending Todos

None yet.

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-02-18
Stopped at: Completed 06-03-PLAN.md
Resume file: .planning/phases/06-instance-and-index-pages/06-04-PLAN.md
