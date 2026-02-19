# Roadmap: Athanor

## Milestones

- ✅ **v1.0 Athanor UI** — Phases 1-6 (shipped 2026-02-18)
- 🚧 **v1.1 Results Performance** — Phases 7-9 (in progress)

## Phases

<details>
<summary>✅ v1.0 Athanor UI (Phases 1-6) — SHIPPED 2026-02-18</summary>

Polished research harness UI with real-time monitoring, theme switching, and schema-driven configuration.

- [x] Phase 1: Visual Identity and Theme Foundation (1/1 plans) — 2026-02-17
- [x] Phase 2: Run Page Log Display (2/2 plans) — 2026-02-17
- [x] Phase 3: Run Page Results Display (2/2 plans) — 2026-02-17
- [x] Phase 4: Run Page Layout and Status (1/1 plan) — 2026-02-17
- [x] Phase 5: Configuration Forms Polish (3/3 plans) — 2026-02-18
- [x] Phase 6: Instance and Index Pages (4/4 plans) — 2026-02-18

**Full archive:** `.planning/milestones/v1.0-ROADMAP.md`

</details>

### 🚧 v1.1 Results Performance (In Progress)

**Milestone Goal:** Make the results tab performant for large experiments with deeply nested data, and fix inaccurate log count display.

- [ ] **Phase 7: Tree Rendering Performance** - Conditional tree rendering and depth limiting eliminate DOM explosion
- [ ] **Phase 8: Results Pagination** - Card-level pagination keeps result list fast regardless of experiment size
- [ ] **Phase 9: Display Accuracy** - Log count reflects true total, not bounded stream length

## Phase Details

### Phase 7: Tree Rendering Performance
**Goal**: Users can expand any result tree without browser freeze, even for 10,000+ node structures
**Depends on**: Nothing (first phase of v1.1)
**Requirements**: PERF-01, PERF-03
**Success Criteria** (what must be TRUE):
  1. User can expand a deeply nested result (e.g., logprob data) without the page becoming unresponsive
  2. Collapsed tree nodes produce no DOM children — children only appear when the parent is expanded
  3. User sees a "show more" control at depth limit rather than an unbounded expansion
  4. Expanding a "show more" reveals the next N levels without freezing
**Plans**: TBD

### Phase 8: Results Pagination
**Goal**: Users can browse experiments with hundreds or thousands of result entries without page lag
**Depends on**: Phase 7
**Requirements**: PERF-02
**Success Criteria** (what must be TRUE):
  1. User sees a bounded initial set of result cards on page load, not all results at once
  2. User can navigate to subsequent pages (or load more) to reach any result
  3. Page remains responsive while browsing experiments with 1000+ result entries
**Plans**: TBD

### Phase 9: Display Accuracy
**Goal**: Users see accurate log counts that reflect reality, not the bounded stream limit
**Depends on**: Phase 7
**Requirements**: DISP-01
**Success Criteria** (what must be TRUE):
  1. Log count shown in the UI matches the actual number of log entries in the database
  2. When an experiment produces more than 1,000 logs, the count reads the true total (not 1,000)
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Visual Identity and Theme Foundation | v1.0 | 1/1 | Complete | 2026-02-17 |
| 2. Run Page Log Display | v1.0 | 2/2 | Complete | 2026-02-17 |
| 3. Run Page Results Display | v1.0 | 2/2 | Complete | 2026-02-17 |
| 4. Run Page Layout and Status | v1.0 | 1/1 | Complete | 2026-02-17 |
| 5. Configuration Forms Polish | v1.0 | 3/3 | Complete | 2026-02-18 |
| 6. Instance and Index Pages | v1.0 | 4/4 | Complete | 2026-02-18 |
| 7. Tree Rendering Performance | v1.1 | 0/? | Not started | - |
| 8. Results Pagination | v1.1 | 0/? | Not started | - |
| 9. Display Accuracy | v1.1 | 0/? | Not started | - |

---
*Roadmap created: 2026-02-16*
*v1.0 shipped: 2026-02-18*
*v1.1 roadmap added: 2026-02-18*
