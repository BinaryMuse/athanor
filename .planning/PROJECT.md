# Athanor UI

## What This Is

Athanor is an AI research harness — a Phoenix LiveView application for defining, configuring, and running experiments with real-time monitoring of logs and results. This milestone focuses on establishing a visual identity and polishing the existing UI pages to be attractive, professional, and usable for long experiment sessions.

## Core Value

The run page must display live logs and structured results clearly and performantly, even for experiments that produce thousands of log entries over hours of execution.

## Requirements

### Validated

<!-- Shipped and confirmed working (existing functionality) -->

- Experiment instance CRUD — existing
- Experiment configuration via dynamic schemas — existing
- Run execution with real-time status updates — existing
- Live log streaming via PubSub — existing
- Live result key-value streaming — existing
- Run cancellation — existing

### Active

<!-- Current scope. Building toward these. -->

- [ ] VIS-01: Scientific/technical visual identity with design patterns documented
- [ ] VIS-02: Dark and light theme support with system preference detection
- [ ] LOG-01: Run page: virtualized log display for high-volume output
- [ ] RES-01: Run page: structured results with tree view and JSON toggle
- [ ] CFG-01: Experiment setup: polished configuration forms
- [ ] IDX-01: Experiment show page: basic visual polish
- [ ] IDX-02: Experiment index page: clean list view

### Out of Scope

- Data export from results — deferred to future milestone
- Log level filtering — deferred (backend support needed first)
- Authentication/authorization — not needed for personal research tool
- Mobile-responsive design — desktop-focused tool

## Context

**Existing codebase:** Phoenix 1.8 umbrella app with three applications (Athanor core, AthanorWeb, SubstrateShift example experiment). LiveView pages exist and are functional but visually minimal.

**Tech stack:** Elixir/Phoenix, LiveView 1.1, Tailwind CSS 4.1, DaisyUI (bundled with Phoenix), esbuild, PostgreSQL.

**UI library:** DaisyUI provides component classes and easy theme switching via `data-theme` attribute. Heroicons available for iconography.

**Usage pattern:** Long-running experiments (minutes to hours) that produce heavy log volume (thousands of entries). Users leave the run page open while doing other work, checking back periodically.

**Visual direction:** Scientific/technical aesthetic — clean lines, good data density, muted color palette with accent colors for status indicators. Like a lab dashboard, not a consumer app.

## Constraints

- **Framework**: Phoenix LiveView — all UI is server-rendered with real-time updates
- **Styling**: Tailwind CSS + DaisyUI — no additional CSS frameworks
- **Performance**: Must handle thousands of log entries without degrading — requires virtualization
- **Themes**: Both dark and light mode required, with system preference detection

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| DaisyUI for components | Already bundled with Phoenix, provides good base | — Pending |
| Virtualized logs | Thousands of entries would overwhelm DOM | — Pending |
| Tree + JSON toggle for results | Structured data needs both exploration and raw views | — Pending |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| VIS-01 | Phase 1 | Pending |
| VIS-02 | Phase 1 | Pending |
| LOG-01 | Phase 2 | Pending |
| RES-01 | Phase 3 | Pending |
| CFG-01 | Phase 5 | Pending |
| IDX-01 | Phase 6 | Pending |
| IDX-02 | Phase 6 | Pending |

---
*Last updated: 2026-02-16 after roadmap creation*
