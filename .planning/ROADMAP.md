# Roadmap: Athanor UI

## Overview

This milestone transforms Athanor from a functional but minimal research harness into a polished, performant tool for monitoring long-running AI experiments. The journey establishes visual identity first (affecting all pages), then tackles the run page as the core value target (log virtualization, results display, layout), followed by configuration forms, and finally the experiment list/detail pages. Each phase delivers a complete, verifiable capability.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Visual Identity and Theme Foundation** - Establish design system and theme switching ✓
- [ ] **Phase 2: Run Page Log Display** - Virtualized log rendering for high-volume output
- [ ] **Phase 3: Run Page Results Display** - Structured results with tree view and JSON toggle
- [ ] **Phase 4: Run Page Layout and Status** - Complete run page assembly with sticky header
- [ ] **Phase 5: Configuration Forms Polish** - Schema-driven form components
- [ ] **Phase 6: Instance and Index Pages** - Experiment list and detail page polish

## Phase Details

### Phase 1: Visual Identity and Theme Foundation
**Goal**: Users see a consistent, professional scientific aesthetic across all pages with working theme switching
**Depends on**: Nothing (first phase)
**Requirements**: VIS-01, VIS-02
**Success Criteria** (what must be TRUE):
  1. All pages display with consistent typography, spacing, and color palette
  2. User can toggle between dark and light themes via UI control
  3. Theme persists across browser sessions
  4. System theme preference is detected on first visit
  5. No flash of unstyled content (FOUC) on page load
**Plans:** 1 plan

Plans:
- [x] 01-01-PLAN.md — FOUC fix, scientific themes, and design token documentation ✓

### Phase 2: Run Page Log Display
**Goal**: Users can monitor high-volume experiment logs without browser performance degradation
**Depends on**: Phase 1
**Requirements**: LOG-01
**Success Criteria** (what must be TRUE):
  1. Log panel displays new entries as they arrive in real-time
  2. Page remains responsive with 10,000+ log entries
  3. Auto-scroll follows new entries when enabled
  4. User can scroll up through log history without losing position
  5. Log levels (debug/info/warn/error) are visually distinct
**Plans:** 2 plans

Plans:
- [x] 02-01-PLAN.md — LogPanel component with bounded stream limits and auto-scroll refinement
- [ ] 02-02-PLAN.md — Gap closure: consumer-side batching and scroll position sync

### Phase 3: Run Page Results Display
**Goal**: Users can explore structured experiment results through both tree navigation and raw JSON
**Depends on**: Phase 2
**Requirements**: RES-01
**Success Criteria** (what must be TRUE):
  1. Results display as collapsible tree with expandable nodes
  2. User can toggle between tree view and raw JSON view
  3. New results appear in real-time as experiment produces them
  4. Nested data structures are navigable without horizontal scrolling
**Plans**: TBD

Plans:
- [ ] 03-01: ResultsPanelComponent with tree view and JSON toggle

### Phase 4: Run Page Layout and Status
**Goal**: Users have a complete, polished run monitoring experience with status always visible
**Depends on**: Phase 3
**Requirements**: (integrates LOG-01, RES-01)
**Success Criteria** (what must be TRUE):
  1. Run status and progress are visible without scrolling (sticky header)
  2. Log and results panels are arranged for efficient monitoring
  3. Reconnection after socket disconnect recovers state correctly
  4. Run completion/failure/cancellation states display clearly
**Plans**: TBD

Plans:
- [ ] 04-01: RunLive.Show layout refactor with sticky header

### Phase 5: Configuration Forms Polish
**Goal**: Users can configure experiments through clear, well-organized forms
**Depends on**: Phase 1
**Requirements**: CFG-01
**Success Criteria** (what must be TRUE):
  1. Configuration fields render with consistent styling
  2. Schema-driven fields display appropriate input types
  3. Validation errors appear inline with clear messaging
  4. Form state persists correctly during editing
**Plans**: TBD

Plans:
- [ ] 05-01: ConfigFormComponent and ConfigField extraction

### Phase 6: Instance and Index Pages
**Goal**: Users can browse and view experiments through polished list and detail pages
**Depends on**: Phase 5
**Requirements**: IDX-01, IDX-02
**Success Criteria** (what must be TRUE):
  1. Experiment index displays as clean, scannable list
  2. Experiment detail (show) page displays instance information clearly
  3. Navigation between pages is intuitive
  4. Visual styling matches established design system
**Plans**: TBD

Plans:
- [ ] 06-01: InstanceLive.Index and InstanceLive.Show polish

## Requirements Mapping

| Requirement | Description | Phase |
|-------------|-------------|-------|
| VIS-01 | Scientific/technical visual identity with design patterns documented | Phase 1 |
| VIS-02 | Dark and light theme support with system preference detection | Phase 1 |
| LOG-01 | Run page: virtualized log display for high-volume output | Phase 2 |
| RES-01 | Run page: structured results with tree view and JSON toggle | Phase 3 |
| CFG-01 | Experiment setup: polished configuration forms | Phase 5 |
| IDX-01 | Experiment show page: basic visual polish | Phase 6 |
| IDX-02 | Experiment index page: clean list view | Phase 6 |

**Coverage:** 7/7 requirements mapped

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Visual Identity | 1/1 | ✓ Complete | 2026-02-17 |
| 2. Log Display | 0/1 | Planned | - |
| 3. Results Display | 0/1 | Not started | - |
| 4. Run Layout | 0/1 | Not started | - |
| 5. Config Forms | 0/1 | Not started | - |
| 6. Instance Pages | 0/1 | Not started | - |

---
*Roadmap created: 2026-02-16*
