# Athanor UI

## What This Is

Athanor is an AI research harness — a Phoenix LiveView application for defining, configuring, and running experiments with real-time monitoring of logs and results. The UI is polished with a scientific aesthetic, theme switching, and performance optimizations for long experiment sessions.

## Core Value

The run page must display live logs and structured results clearly and performantly, even for experiments that produce thousands of log entries over hours of execution.

## Current State

**v1.0 shipped:** 2026-02-18
**Codebase:** ~5,200 LOC Elixir/HEEx, ~11,500 LOC JS
**Tech stack:** Phoenix 1.8, LiveView 1.1, Tailwind CSS 4.1, DaisyUI, PostgreSQL

## Requirements

### Validated

- ✓ Experiment instance CRUD — existing
- ✓ Experiment configuration via dynamic schemas — existing
- ✓ Run execution with real-time status updates — existing
- ✓ Live log streaming via PubSub — existing
- ✓ Live result key-value streaming — existing
- ✓ Run cancellation — existing
- ✓ VIS-01: Scientific/technical visual identity with design patterns documented — v1.0
- ✓ VIS-02: Dark and light theme support with system preference detection — v1.0
- ✓ LOG-01: Run page: virtualized log display for high-volume output — v1.0
- ✓ RES-01: Run page: structured results with tree view and JSON toggle — v1.0
- ✓ CFG-01: Experiment setup: polished configuration forms — v1.0
- ✓ IDX-01: Experiment show page: basic visual polish — v1.0
- ✓ IDX-02: Experiment index page: clean list view — v1.0

### Active

(None — planning next milestone)

### Out of Scope

- Data export from results — deferred to future milestone
- Log level filtering — deferred (backend support needed first)
- Authentication/authorization — not needed for personal research tool
- Mobile-responsive design — desktop-focused tool

## Context

**Usage pattern:** Long-running experiments (minutes to hours) that produce heavy log volume (thousands of entries). Users leave the run page open while doing other work, checking back periodically.

**Visual direction:** Scientific/technical aesthetic — clean lines, good data density, muted color palette with accent colors for status indicators. Like a lab dashboard, not a consumer app.

## Constraints

- **Framework**: Phoenix LiveView — all UI is server-rendered with real-time updates
- **Styling**: Tailwind CSS + DaisyUI — no additional CSS frameworks
- **Performance**: Must handle thousands of log entries without degrading — bounded streams handle this
- **Themes**: Both dark and light mode supported, with system preference detection

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| DaisyUI for components | Already bundled with Phoenix, provides good base | ✓ Good — semantic classes work well |
| Bounded streams (1000 nodes) | Thousands of entries would overwhelm DOM | ✓ Good — page stays responsive at 10k+ logs |
| ETS producer-side batching | DB writes on every log would bottleneck | ✓ Good — 100ms flush interval performs well |
| Tree + JSON toggle for results | Structured data needs both exploration and raw views | ✓ Good — users can drill down or copy raw |
| Lazy tree hydration | Large result trees would slow initial render | ✓ Good — click-to-expand keeps page fast |
| Client-side config forms | LiveView can't efficiently manage nested dynamic lists | ✓ Good — JS hook handles state cleanly |
| live_session layout | Multiple LiveViews need shared layout | ✓ Good — single router line applies to all |

---
*Last updated: 2026-02-18 after v1.0 milestone*
