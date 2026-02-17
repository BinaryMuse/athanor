# Phase 5: Configuration Forms Polish - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Schema-driven configuration forms for experiment setup. Users can configure experiments through clear, well-organized forms with appropriate input types, validation feedback, and support for nested schemas. Includes a small schema enhancement to support field grouping (enabling card-based layout).

</domain>

<decisions>
## Implementation Decisions

### Field layout & grouping
- Card-based sections: each group renders in its own card with header, ungrouped fields in a default card
- Add `group/4` function to ConfigSchema for logical field grouping (non-repeating sections)
- Stacked labels: label on its own line, full-width input below
- Inline repeater for list fields: items stacked vertically with add/remove buttons, all visible
- Help text support: both groups and individual fields can have optional description/help text via schema

### Input type rendering
- Format hints for strings: schema supports `format:` option (`:text`, `:textarea`, `:url`, `:email`, etc.)
- Enum as a new type: `field(:level, :enum, options: [:low, :medium, :high])`
- Checkbox for boolean fields (not toggle switch)
- Number constraints: schema supports `min:`, `max:`, `step:` options for integer/number fields

### Validation & error display
- Validate on blur + submit: check when user leaves field, and again on form submission
- Inline errors with highlight: error text below field AND red border on input
- Required fields marked with red asterisk (*) on label
- Errors clear on blur after fix: stays until user leaves field with valid value

### Nested schema handling
- Collapsible mini-cards for list items: each item can collapse to a summary line
- Generic index for collapsed summary: "Item 1", "Item 2", etc.
- Unlimited nesting depth with visual indentation
- Drag handles preferred for reordering, fall back to up/down buttons if implementation proves complex

### Claude's Discretion
- List reordering implementation approach (drag-and-drop vs button-based)
- Exact visual styling within established design system
- Performance optimizations for large schemas
- Specific indentation/spacing for nested levels

</decisions>

<specifics>
## Specific Ideas

- Schema enhancement should follow existing pattern: `group/4` similar to `list/4` signature
- Current schema is in `apps/athanor/lib/experiment/config_schema.ex` (~40 lines, simple)
- Example usage in `apps/substrate_shift/lib/substrate_shift.ex` shows nested schemas via `list/4`

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-configuration-forms-polish*
*Context gathered: 2026-02-17*
