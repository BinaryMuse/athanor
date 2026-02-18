---
phase: 06-instance-and-index-pages
verified: 2026-02-18T22:30:00Z
status: human_needed
score: 10/10 must-haves verified
re_verification:
  previous_status: gaps_found
  previous_score: 6/10
  gaps_closed:
    - "Edit page config form pre-populates with existing instance configuration values"
    - "Experiments pages (Index, Show, New, Edit) have padding and spacing around content"
    - "All instance pages show a sticky top bar with the minimal Athanor nav"
    - "Index page experiment cards display a status badge showing the status of the last run"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Visit /experiments and verify clean scannable card list"
    expected: "Each experiment shows name, module name, run count, relative last run time, Start Run button, Edit button, overflow menu, and a status badge (for experiments with runs)"
    why_human: "Visual layout quality and scannability require visual inspection"
  - test: "Visit /experiments/:id and switch between Runs and Configuration tabs"
    expected: "URL updates to ?tab=runs and ?tab=configuration; browser back/forward preserves tab state"
    why_human: "Real-time browser navigation behavior cannot be verified statically"
  - test: "Visit /experiments/:id/edit for an instance with existing configuration"
    expected: "Configuration form fields show existing values, not schema defaults"
    why_human: "JavaScript hook runtime behavior requires browser interaction to confirm"
  - test: "Visual styling consistency across Index, Show, New, and Edit pages"
    expected: "Pages share consistent typography, spacing, card styles, daisyUI component usage, sticky header, and padded content area"
    why_human: "Design system adherence and sticky nav behavior require visual browser testing"
---

# Phase 6: Instance and Index Pages Verification Report

**Phase Goal:** Users can browse and view experiments through polished list and detail pages
**Verified:** 2026-02-18T22:30:00Z
**Status:** human_needed (all automated checks passed; 4 items require browser confirmation)
**Re-verification:** Yes — after gap closure (Plans 03 and 04)

## Re-verification Summary

Previous status: `gaps_found` (6/10, 3 blockers + 1 warning)
Current status: `human_needed` (10/10)

All four gaps from the initial verification are closed:

| Gap | Was | Now |
|-----|-----|-----|
| Edit config pre-population | FAILED — hook ignored data-initial-values | CLOSED — mounted() reads and deepMerges |
| Page padding missing | FAILED — routes bypassed Layouts.app | CLOSED — live_session :experiments wires Layouts.app |
| Sticky nav not working | FAILED — routes bypassed Layouts.app | CLOSED — same live_session fix |
| Status badge absent from index cards | PARTIAL — badge missing, plan inconsistency | CLOSED — StatusBadge rendered conditionally |

No regressions found in previously-passing items.

---

## Goal Achievement

### Observable Truths

#### Plan 01 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Index page can display run count and last run time per experiment card | VERIFIED | `index.ex:69-71` renders `item.run_count` and `format_relative_time(item.last_run_at)` |
| 2 | All instance pages show minimal nav (logo + theme toggle, no Phoenix boilerplate) | VERIFIED | `layouts.ex:38-45`: sticky header with "Athanor" link and `<.theme_toggle />` |
| 3 | Edit route exists for configuration editing | VERIFIED | `router.ex:27`: `live "/experiments/:id/edit", Experiments.InstanceLive.Edit, :edit` |

#### Plan 02 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 4 | Index page shows card grid with run count, last run time, status badge per experiment | VERIFIED | `index.ex:63`: `<StatusBadge.status_badge :if={item.last_run_status} status={item.last_run_status} />`; run stats at lines 70-71 |
| 5 | Index cards have Start Run button, Edit button, and overflow menu with Delete | VERIFIED | `index.ex:77-98`: Run button (phx-click="start_run"), Edit link, dropdown with View Details and Delete |
| 6 | Show page has URL-synced tabs (Runs, Configuration) via query params | VERIFIED | `show.ex:30-36`: `handle_params(%{"tab" => tab}, ...)` with String.to_existing_atom |
| 7 | Show page header has Start Run button and dropdown menu (Edit/Delete) | VERIFIED | `show.ex:55-77`: Start Run button + dropdown with Edit Configuration link and Delete |
| 8 | New page has breadcrumb navigation and sticky footer with Cancel/Create | VERIFIED | `new.ex:27-84`: breadcrumb at top, fixed bottom-0 footer with Cancel/Create Instance |
| 9 | Edit page allows modifying experiment configuration with pre-populated values | VERIFIED | `app.js:42-49`: mounted() reads `this.el.dataset.initialValues`, parses it, and calls `this.deepMerge()`; `app.js:761-781`: deepMerge helper exists |

#### Plan 03 Truths (Gap Closure)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 10 | Experiments pages have proper padding and spacing | VERIFIED | `router.ex:23-28`: `live_session :experiments, layout: {AthanorWeb.Layouts, :app}` wraps all four routes; `layouts.ex:47`: `<main class="px-4 py-8 sm:px-6 lg:px-8">` |
| 11 | All instance pages show sticky top bar with minimal Athanor nav | VERIFIED | Same live_session fix; `layouts.ex:38`: `<header class="sticky top-0 z-10 bg-base-100 border-b border-base-300">` |

**Score:** 10/10 truths verified (including 2 gap-closure truths from Plans 03/04)

### Required Artifacts

| Artifact | Provided | Status | Details |
|----------|----------|--------|---------|
| `apps/athanor/lib/athanor/experiments.ex` | `list_instances_with_stats/0` and `get_instance_stats/1` with `last_run_status` | VERIFIED | Lines 40-74: both functions include `last_run_status: fragment("(SELECT status FROM runs WHERE instance_id = ? ORDER BY inserted_at DESC LIMIT 1)", i.id)` |
| `apps/athanor_web/lib/athanor_web/components/layouts.ex` | Minimal Athanor nav replacing Phoenix boilerplate | VERIFIED | Lines 38-55: sticky header, "Athanor" link to /experiments, theme_toggle, max-w-4xl main content |
| `apps/athanor_web/lib/athanor_web/router.ex` | live_session :experiments with app layout + edit route | VERIFIED | Lines 23-28: `live_session :experiments, layout: {AthanorWeb.Layouts, :app}` wrapping all four experiment routes |
| `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/index.ex` | Card-based index with rich content, actions, and status badge | VERIFIED | 175 lines: stream with dom_id fn, card grid, StatusBadge alias + conditional render, stats display, event handlers, PubSub handlers with `last_run_status: nil` in fake_stats |
| `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/show.ex` | Tab-based show page with URL integration | VERIFIED | 261 lines: handle_params, tabs with patch links, runs stream, config display, delete handler |
| `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/new.ex` | New page with breadcrumb and sticky footer | VERIFIED | 147 lines: breadcrumb, pb-24 form wrapper, fixed bottom-0 footer with disabled state |
| `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/edit.ex` | Edit page for instance configuration with initial_values | VERIFIED | 105 lines: loads instance, renders form with `initial_values={Jason.encode!(@instance.configuration || %{})}`, calls `update_instance` on save |
| `apps/athanor_web/assets/js/app.js` (ConfigFormHook) | Hook with `data-initial-values` support and `deepMerge` helper | VERIFIED | Lines 42-49: reads `this.el.dataset.initialValues` in mounted(); lines 761-781: `deepMerge` method; `handleEvent("config_schema_changed")` unchanged (lines 56-63) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `index.ex` | `experiments.ex` | `list_instances_with_stats/0` | WIRED | Line 14: `stats = Experiments.list_instances_with_stats()` |
| `index.ex` | `experiments.ex` | `get_instance_stats/1` in PubSub handlers | WIRED | Lines 130, 142: `Experiments.get_instance_stats(instance.id)` |
| `index.ex` | `status_badge.ex` | `StatusBadge.status_badge` component | WIRED | Line 6: alias; Line 63: `<StatusBadge.status_badge :if={item.last_run_status} status={item.last_run_status} />` |
| `show.ex` | URL query params | `handle_params/3` for tab state | WIRED | `show.ex:30-36`: `handle_params(%{"tab" => tab}, _uri, socket) when tab in ["runs", "configuration"]` |
| `edit.ex` | `ConfigFormComponent` | `initial_values` attr | WIRED | `edit.ex` passes `initial_values={Jason.encode!(@instance.configuration || %{})}`; `app.js:42-49` reads `dataset.initialValues` in mounted() |
| `edit.ex` | `experiments.ex` | `update_instance/2` | WIRED | `edit.ex:92`: `Experiments.update_instance(socket.assigns.instance, params)` |
| `router.ex` | `layouts.ex` | `live_session layout: {AthanorWeb.Layouts, :app}` | WIRED | `router.ex:23`: `live_session :experiments, layout: {AthanorWeb.Layouts, :app}` |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| IDX-01 | 06-01-PLAN, 06-02-PLAN | Experiment show page: basic visual polish | SATISFIED | Show page has breadcrumb, tab layout, header with actions, URL-synced tab state, run list with StatusBadge, sticky nav via live_session |
| IDX-02 | 06-01-PLAN, 06-02-PLAN | Experiment index page: clean list view | SATISFIED | Index page has clean card layout with run stats, status badge, action buttons, stream-based updates, sticky nav via live_session |

No REQUIREMENTS.md file exists in this project — requirements are defined in ROADMAP.md only. Both IDX-01 and IDX-02 declared in Plans 01 and 02 are fully accounted for. Plans 03 and 04 also declare `[IDX-01, IDX-02]` as their requirements — these gap-closure plans are directly supporting the same two requirements. No orphaned requirements.

### Anti-Patterns Found

No anti-patterns found in gap-closure files. No TODO/FIXME/placeholder comments, no empty handlers, no stub implementations in:
- `apps/athanor_web/assets/js/app.js`
- `apps/athanor/lib/athanor/experiments.ex`
- `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/index.ex`
- `apps/athanor_web/lib/athanor_web/router.ex`

### Human Verification Required

All automated checks pass. The following items require browser verification to confirm the goal is fully achieved:

#### 1. Edit Page Config Pre-Population (Confirm Gap Closure)

**Test:** Create an instance with non-default configuration values, then visit `/experiments/:id/edit`
**Expected:** Configuration form fields show the existing saved values, not schema defaults
**Why human:** JavaScript hook behavior (`deepMerge` of `data-initial-values` into state) can only be confirmed at runtime in a browser

#### 2. Visual Layout Quality — Index Page

**Test:** Visit `/experiments` in a browser
**Expected:** Cards display cleanly — name prominently, module name in secondary text, run count and relative timestamp visible, status badge for experiments with runs, action buttons well-spaced, sticky header visible and stays fixed on scroll
**Why human:** Visual scannability, sticky behavior, and spacing cannot be verified programmatically

#### 3. URL-Synced Tab Navigation — Show Page

**Test:** Visit `/experiments/:id`, click the Configuration tab, use the browser back button
**Expected:** URL shows `?tab=configuration`, browser back returns to `?tab=runs`, tab state preserved through navigation
**Why human:** Real-time browser navigation behavior requires browser interaction

#### 4. Design System Consistency

**Test:** Navigate through Index, Show, New, and Edit pages
**Expected:** Consistent use of daisyUI classes, semantic color tokens (base-100/200/300, primary, error), consistent typography and spacing, sticky nav with theme toggle visible on all four pages
**Why human:** Visual design consistency and sticky nav rendering require cross-page visual comparison

---

_Verified: 2026-02-18T22:30:00Z_
_Verifier: Claude (gsd-verifier)_
