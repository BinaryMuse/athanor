# Phase 7: Tree Rendering Performance - Context

**Gathered:** 2026-02-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Conditional tree rendering and depth limiting to eliminate DOM explosion. Users can expand any result tree without browser freeze, even for 10,000+ node structures. Collapsed tree nodes produce no DOM children — children only appear when the parent is expanded.

</domain>

<decisions>
## Implementation Decisions

### Depth Limit Behavior
- Default depth limit: 5 levels from any expanded node
- Local depth counting — each expansion resets the counter, so users can always drill 5 levels from current position
- "Show more" control appears at depth limit

### Loading States
- Skeleton placeholder shown while children render during expansion
- No animation on expand/collapse — instant show/hide for snappy feel
- 5 second timeout (configurable in code, not user settings) — if render exceeds timeout, show error with retry link

### Expand/Collapse UX
- Collapse All control at tree root (no Expand All — too dangerous for large trees)
- No state persistence — all nodes reset to collapsed when switching between result cards
- No keyboard navigation — mouse only
- Chevron-only click target — clicking the chevron toggles, row click does not

### Node Display
- Collapsed arrays/objects show count only: `Array(42)` or `Object{12 keys}`
- Long strings always display in full (may wrap multiple lines)
- Raw numbers — no thousands separators or precision limits
- Syntax highlighting — different colors for different value types (strings, numbers, booleans)

### Claude's Discretion
- "Show more" expansion increment (how many levels to reveal on click)
- Visual design of "show more" control (inline text link vs button)

</decisions>

<specifics>
## Specific Ideas

- Timeout should be a code constant that's easy to find and adjust, not buried in config

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-tree-rendering-performance*
*Context gathered: 2026-02-18*
