# Phase 6: Instance and Index Pages - Context

**Gathered:** 2026-02-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Polish the experiment list page (Index), experiment detail page (Show), and experiment creation page (New) to match the established scientific design system. Unify look and feel across all instance-related pages. This phase does NOT add new features — it applies consistent styling and improves the existing UI.

</domain>

<decisions>
## Implementation Decisions

### Index Page (List)
- Card-based layout for experiments (not table)
- Rich card content: name, experiment type, description preview, run count, last run time, status badge, quick actions
- Full actions on each card: Start Run button, Edit Config button, overflow menu with Delete
- Simple empty state: "No experiments yet" message with Create button

### Show Page (Detail)
- Tab-based structure with URL integration via query params (shareable links to specific tabs)
- Tabs: Runs, Configuration (possibly Settings if needed)
- Minimal header above tabs: instance name, experiment type, action group
- Action group in header: primary "Start Run" button + secondary dropdown for Edit/Delete (future-proofed for Clone)
- Runs tab: simple chronological list with status, start time, duration — click row to view run
- Configuration tab: read-only form view (same layout as edit form but disabled)

### New Page Chrome
- Breadcrumb navigation: Experiments > New (with back navigation)
- Sticky footer with Cancel and Create Instance buttons (always visible)
- No unsaved changes warning when navigating away
- No experiment type description — users know what they're selecting

### Global Consistency
- Minimal navigation header on all pages: logo/home link + theme toggle
- Breadcrumbs handle page context (not nav links)
- Primary action buttons: filled teal background, white text (Create, Start Run)
- Status badges: colored pills (green for completed, red for failed, blue/teal for running)

### Claude's Discretion
- Card component styling (shadows vs borders) — match existing theme patterns
- Exact spacing and typography within the design system
- Secondary button styling
- Loading states and skeleton patterns

</decisions>

<specifics>
## Specific Ideas

- Phase 5 polished the config forms but not the surrounding page chrome — this phase unifies everything
- Show page action group should be ready to accommodate "Clone" action in the future
- Index cards should have overflow menu pattern that can grow (Clone would go there too)

</specifics>

<deferred>
## Deferred Ideas

- Clone experiment feature — duplicate an instance with tweaked configuration (future phase)

</deferred>

---

*Phase: 06-instance-and-index-pages*
*Context gathered: 2026-02-18*
