# Phase 6: Instance and Index Pages - Research

**Researched:** 2026-02-18
**Domain:** Phoenix LiveView UI polish, daisyUI components, Ecto aggregate queries, query params for tab state
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Index Page (List)
- Card-based layout for experiments (not table)
- Rich card content: name, experiment type, description preview, run count, last run time, status badge, quick actions
- Full actions on each card: Start Run button, Edit Config button, overflow menu with Delete
- Simple empty state: "No experiments yet" message with Create button

#### Show Page (Detail)
- Tab-based structure with URL integration via query params (shareable links to specific tabs)
- Tabs: Runs, Configuration (possibly Settings if needed)
- Minimal header above tabs: instance name, experiment type, action group
- Action group in header: primary "Start Run" button + secondary dropdown for Edit/Delete (future-proofed for Clone)
- Runs tab: simple chronological list with status, start time, duration — click row to view run
- Configuration tab: read-only form view (same layout as edit form but disabled)

#### New Page Chrome
- Breadcrumb navigation: Experiments > New (with back navigation)
- Sticky footer with Cancel and Create Instance buttons (always visible)
- No unsaved changes warning when navigating away
- No experiment type description — users know what they're selecting

#### Global Consistency
- Minimal navigation header on all pages: logo/home link + theme toggle
- Breadcrumbs handle page context (not nav links)
- Primary action buttons: filled teal background, white text (Create, Start Run)
- Status badges: colored pills (green for completed, red for failed, blue/teal for running)

### Claude's Discretion
- Card component styling (shadows vs borders) — match existing theme patterns
- Exact spacing and typography within the design system
- Secondary button styling
- Loading states and skeleton patterns

### Deferred Ideas (OUT OF SCOPE)
- Clone experiment feature — duplicate an instance with tweaked configuration (future phase)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| IDX-01 | Experiment show page: basic visual polish | Architecture Pattern 2 (tab-based Show page with URL integration), Pattern 3 (read-only config view), Pattern 4 (action group dropdown) |
| IDX-02 | Experiment index page: clean list view | Architecture Pattern 1 (card-based index with run stats), Pattern 5 (aggregate query for run counts), Code Examples section |
</phase_requirements>

---

## Summary

Phase 6 is a UI polish phase with no new backend features. All three pages (Index, Show, New) need visual chrome improvements: the Index gets card-based layout with run statistics, the Show page gets a tab structure with URL-synced active tab and a polished header with action dropdown, and the New page gets breadcrumb navigation and a sticky footer. The existing LiveView structure is sound — this phase is primarily template refactoring.

The most significant technical work is (1) adding a `list_instances_with_stats/0` context function that returns run counts and last-run timestamps via a single efficient JOIN query rather than N+1 per-card queries, and (2) implementing URL-synced tab state on the Show page using `handle_params/3` and `live_patch` so the active tab is part of the URL. Both are established Phoenix LiveView patterns.

The app layout (`layouts.ex`) currently uses Phoenix default boilerplate navbar (showing phoenix.org, github links, "Get Started"). This needs to be replaced with the application's own minimal nav: logo/home link + theme toggle. The same layout `app/1` function is used by all three instance pages via the default layout pipeline, so updating it once covers all pages in this phase.

**Primary recommendation:** Update `layouts.ex` app/1 to replace the Phoenix boilerplate navbar with an Athanor-specific minimal nav. Then refactor each LiveView template separately: Index for card layout with aggregate stats, Show for tab/URL state and action dropdown, New for breadcrumbs and sticky footer.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView | ~1.1.0 | Reactive UI, handle_params for URL tab state | Already in use — `handle_params/3` is built-in for query param handling |
| daisyUI | 5.x (bundled vendor) | Card, dropdown, tab, badge components | Already in use — dropdown confirmed in vendor bundle |
| Tailwind CSS | bundled via tailwind dep | Layout utilities (sticky, flex, grid) | Already in use |
| Ecto | ~3.x | Aggregate query for run stats (count, max inserted_at) | Already in use |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phoenix.LiveView.JS | built-in | Client-side dropdown toggle, tab switching | Pure UI interactions that don't need server state |
| Athanor.Experiments.Broadcasts | existing module | Broadcast instance deleted event after delete | Already used for create/update — add delete broadcast |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `handle_params/3` for URL tab state | `phx-click` server-side assign only | `handle_params/3` makes URLs shareable and supports browser back/forward; required by decision |
| Single JOIN query for run stats | Separate `Experiments.list_runs/1` per card | N+1 queries on index page — unacceptable at scale |
| daisyUI `dropdown` for overflow menu | Custom JS popover | daisyUI dropdown is already in vendor bundle, uses CSS-only focus-within for open state |

**Installation:** No new packages needed. All libraries already present in the project.

---

## Architecture Patterns

### Recommended File Changes

```
apps/athanor_web/lib/athanor_web/
├── components/
│   └── layouts.ex                     # Replace boilerplate navbar in app/1 with Athanor nav
└── live/experiments/
    ├── instance_live/
    │   ├── index.ex                   # Add aggregate stats query, card template, delete handler
    │   ├── show.ex                    # Add handle_params for tab URL, dropdown, read-only config tab
    │   └── new.ex                     # Add breadcrumb, sticky footer layout
    └── components/
        └── (no new components needed for this phase)

apps/athanor/lib/athanor/
└── experiments.ex                     # Add list_instances_with_stats/0
```

### Pattern 1: Card-Based Index with Aggregate Run Stats

The current `list_instances/0` returns plain instances with no run data. For the card to show run count and last run time, we need a JOIN query in the Experiments context:

```elixir
# In Athanor.Experiments — new function:
def list_instances_with_stats do
  from(i in Instance,
    left_join: r in assoc(i, :runs),
    group_by: i.id,
    select: %{
      instance: i,
      run_count: count(r.id),
      last_run_at: max(r.inserted_at)
    },
    order_by: [desc: max(r.inserted_at), asc: i.name]
  )
  |> Repo.all()
end
```

This returns a list of maps with `:instance`, `:run_count`, `:last_run_at`. In the LiveView, stream the instances map, not the Instance struct directly, so each stream item carries its stats.

**Important:** The existing PubSub handlers (`handle_info({:instance_created, ...})`, `handle_info({:instance_updated, ...})`) insert plain Instance structs into the stream. After adopting `list_instances_with_stats`, the PubSub handlers need to either (a) re-query for the specific instance's stats and insert the enriched map, or (b) accept that live updates show zero/stale counts and only show accurate counts on initial page load. Option (a) is recommended — a targeted query for one instance's stats is cheap.

**Confidence:** HIGH — standard Ecto `group_by` + `select` aggregate, no library-specific API.

### Pattern 2: URL-Synced Tab State on Show Page

The tab active state must be in the URL via query params so tabs are shareable (e.g., `/experiments/abc?tab=configuration`). Use `handle_params/3` — it fires on initial mount and on every `live_patch` navigation:

```elixir
# In InstanceLive.Show:
@impl true
def handle_params(%{"tab" => tab}, _uri, socket) when tab in ["runs", "configuration"] do
  {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
end

def handle_params(_params, _uri, socket) do
  {:noreply, assign(socket, :active_tab, :runs)}
end
```

Tab buttons use `live_patch` (not `phx-click`) so the URL updates without full navigation:

```heex
<div role="tablist" class="tabs tabs-border border-b border-base-300">
  <.link
    role="tab"
    patch={~p"/experiments/#{@instance.id}?tab=runs"}
    class={["tab", @active_tab == :runs && "tab-active"]}
  >
    Runs ({@run_count})
  </.link>
  <.link
    role="tab"
    patch={~p"/experiments/#{@instance.id}?tab=configuration"}
    class={["tab", @active_tab == :configuration && "tab-active"]}
  >
    Configuration
  </.link>
</div>
```

Tab panel visibility uses the same `hidden` class pattern established in RunLive.Show (Phase 4):

```heex
<div class={["py-4", @active_tab != :runs && "hidden"]}>
  <%!-- runs list --%>
</div>
<div class={["py-4", @active_tab != :configuration && "hidden"]}>
  <%!-- config view --%>
</div>
```

**Confidence:** HIGH — `handle_params/3` is standard Phoenix LiveView. The `live_patch` + query param pattern is documented and used in generated Phoenix scaffolding.

### Pattern 3: Read-Only Configuration Tab

The Configuration tab shows the instance's current configuration as a read-only view. The existing `render_config/1` private function in `show.ex` already renders key-value pairs from the configuration map. It needs visual polish to match the design system but the logic is there.

The decision says "same layout as edit form but disabled." In practice, rendering the raw config map as a styled key-value list is simpler and sufficient — the config form (from Phase 5) is a dynamic schema-driven JS-managed component; showing it in read-only mode would require significant work. The simpler approach: render the configuration map as styled key-value rows using the design system.

```heex
<%!-- Configuration tab panel --%>
<div class="space-y-2">
  <%= for {key, value} <- @instance.configuration || %{} do %>
    <div class="flex items-start gap-4 py-2 border-b border-base-300 last:border-0">
      <span class="text-sm text-base-content/60 w-1/3 font-medium">{humanize(key)}</span>
      <span class="text-sm font-mono text-base-content flex-1">{format_config_value(value)}</span>
    </div>
  <% end %>
  <div :if={@instance.configuration == %{} or is_nil(@instance.configuration)}
       class="text-sm text-base-content/60 italic">
    No configuration
  </div>
</div>
```

**Note on "same layout as edit form":** If the requirement is interpreted strictly as using ConfigFormComponent in read-only mode, this requires adding a `disabled` prop to the JS hook and component. This is out of scope for a polish phase — the read-only key-value view is the appropriate interpretation.

**Confidence:** HIGH — the pattern is straightforward data rendering, no novel APIs.

### Pattern 4: Action Dropdown (Edit/Delete) on Show Page

The daisyUI `dropdown` component is confirmed in the vendor bundle. It uses CSS `:focus-within` to show the dropdown content without JavaScript, which works correctly with LiveView's DOM patching:

```heex
<%!-- Action group in show page header --%>
<div class="flex items-center gap-2">
  <.button phx-click="start_run" variant="primary">
    <.icon name="hero-play-micro" class="size-4 mr-1" /> Start Run
  </.button>

  <div class="dropdown dropdown-end">
    <div tabindex="0" role="button" class="btn btn-ghost btn-sm">
      <.icon name="hero-ellipsis-vertical" class="size-5" />
    </div>
    <ul tabindex="0" class="dropdown-content menu bg-base-200 rounded-box z-10 w-48 p-2 shadow-sm">
      <li>
        <.link navigate={~p"/experiments/#{@instance.id}/edit"}>
          Edit Configuration
        </.link>
      </li>
      <li>
        <button phx-click="delete_instance" data-confirm="Delete this experiment?">
          <span class="text-error">Delete</span>
        </button>
      </li>
    </ul>
  </div>
</div>
```

**Note on routing:** There is no `/experiments/:id/edit` route currently. The edit action could be a modal on the show page or a new route. Given phase scope is polish (not new features), the simplest approach is to reuse the New page pattern or link to a future edit page. For now, "Edit Configuration" can link to the same Show page with a query param that opens the config tab — or we can add a dedicated edit route. Flag this as an open question.

**Confidence:** HIGH for daisyUI dropdown CSS mechanics (verified in vendor). MEDIUM for the edit routing decision — needs resolution.

### Pattern 5: Overflow Menu on Index Cards

Each index card also needs the overflow menu pattern (Start Run, Edit, Delete via overflow):

```heex
<div class="card bg-base-200 shadow-sm" id={dom_id}>
  <div class="card-body p-4">
    <div class="flex items-start justify-between gap-4">
      <%!-- Card content --%>
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2 mb-1">
          <h2 class="card-title text-base">
            <.link navigate={~p"/experiments/#{instance.id}"} class="link link-hover">
              {instance.name}
            </.link>
          </h2>
          <%!-- StatusBadge for last run status if available --%>
        </div>
        <p class="text-sm text-base-content/60">{module_name(instance.experiment_module)}</p>
        <p :if={instance.description} class="text-sm mt-1 truncate text-base-content/80">
          {instance.description}
        </p>
        <div class="flex items-center gap-4 mt-2 text-xs text-base-content/50">
          <span>{instance.run_count} runs</span>
          <span :if={instance.last_run_at}>Last: {format_time(instance.last_run_at)}</span>
        </div>
      </div>

      <%!-- Action column --%>
      <div class="flex items-center gap-2 shrink-0">
        <button phx-click="start_run" phx-value-id={instance.id} class="btn btn-sm btn-primary">
          <.icon name="hero-play-micro" class="size-3 mr-1" /> Run
        </button>
        <div class="dropdown dropdown-end">
          <div tabindex="0" role="button" class="btn btn-ghost btn-sm btn-square">
            <.icon name="hero-ellipsis-vertical" class="size-4" />
          </div>
          <ul tabindex="0" class="dropdown-content menu bg-base-200 rounded-box z-10 w-44 p-2 shadow-sm">
            <li>
              <.link navigate={~p"/experiments/#{instance.id}"}>View</.link>
            </li>
            <li>
              <button phx-click="delete_instance" phx-value-id={instance.id}
                      data-confirm="Delete this experiment?">
                <span class="text-error">Delete</span>
              </button>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </div>
</div>
```

The `start_run` event on the index page requires adding `Runtime.start_run` logic to `InstanceLive.Index` — same logic as in `InstanceLive.Show`. The delete event calls `Experiments.delete_instance/1` and broadcasts via `Broadcasts.instance_deleted/1`.

**Confidence:** HIGH — all utilities already in use. The daisyUI dropdown is verified in vendor bundle.

### Pattern 6: Minimal App Navbar (layouts.ex)

The current `app/1` layout renders a Phoenix boilerplate navbar with links to phoenixframework.org, GitHub, and a "Get Started" button. This needs to be replaced with Athanor's own nav:

```elixir
# In layouts.ex — replace the header in app/1:
def app(assigns) do
  ~H"""
  <header class="sticky top-0 z-10 bg-base-100 border-b border-base-300">
    <div class="flex items-center justify-between px-4 sm:px-6 lg:px-8 py-3">
      <.link navigate={~p"/experiments"} class="flex items-center gap-2 font-semibold text-base-content">
        Athanor
      </.link>
      <.theme_toggle />
    </div>
  </header>

  <main class="px-4 py-8 sm:px-6 lg:px-8">
    <div class="mx-auto max-w-4xl">
      {render_slot(@inner_block)}
    </div>
  </main>

  <.flash_group flash={@flash} />
  """
end
```

**Note on max-width:** The current `max-w-2xl` (672px) is narrow for the card grid layout the decisions call for. `max-w-4xl` (896px) gives more room for rich cards. This is within Claude's discretion on exact spacing.

**Note on stickiness:** Making the app navbar sticky (same as the run page header) creates consistency — all pages have a fixed navbar. The run page uses its own dedicated layout that omits the navbar entirely (it has a full-width sticky header instead). No conflict.

**Confidence:** HIGH — pure HEEx/CSS change, no novel APIs. The `max-w-4xl` choice is discretion-area.

### Pattern 7: New Page Breadcrumb + Sticky Footer

The New page needs breadcrumb at top and sticky footer for actions:

```heex
<%!-- Top of New page render --%>
<div class="text-sm text-base-content/60 mb-4 flex items-center gap-2">
  <.link navigate={~p"/experiments"} class="hover:text-base-content">Experiments</.link>
  <span>/</span>
  <span class="text-base-content">New</span>
</div>

<div class="pb-20">  <%!-- bottom padding so sticky footer doesn't overlap content --%>
  <%!-- form content --%>
</div>

<%!-- Sticky footer --%>
<div class="fixed bottom-0 left-0 right-0 bg-base-100 border-t border-base-300 px-4 py-3 flex justify-end gap-3">
  <.link navigate={~p"/experiments"} class="btn btn-ghost">Cancel</.link>
  <.button type="submit" form="new-instance-form" variant="primary">
    Create Instance
  </.button>
</div>
```

**Technical note:** The submit button in the sticky footer needs to reference the form by ID (`form="new-instance-form"`). The `<.form>` tag needs an `id` attribute. This is standard HTML — a submit button can live outside its form element using the `form` attribute.

Alternatively, move the form action buttons into the sticky footer by restructuring the form's action slot. Either approach works; the `form=` attribute is simpler as it avoids restructuring the form hierarchy.

**Confidence:** HIGH — standard HTML `form` attribute for external submit buttons, no framework-specific API needed.

### Anti-Patterns to Avoid

- **N+1 queries for run stats:** Never call `Experiments.list_runs(instance)` inside a loop per card. Use `list_instances_with_stats/0` (single JOIN query) from the start.
- **Using hardcoded colors:** The design system rule is strict — no `text-white`, `text-gray-*`, `bg-white`, etc. All colors must use semantic DaisyUI tokens (`text-base-content`, `bg-base-200`, etc.).
- **Radio-input daisyUI tabs:** DaisyUI offers a radio-button tab variant — do not use it. It doesn't work with LiveView's DOM patching and doesn't support URL-synced state. Use `role="tab"` + `live_patch` + `handle_params/3`.
- **Putting sticky footer inside the scrollable main content:** The `fixed bottom-0` approach for the New page footer means it's positioned relative to the viewport, not the content. If using `position: sticky` instead of `position: fixed`, the sticky element must be outside the scrollable ancestor. `fixed` is simpler here.
- **Using `push_navigate` for tab switching:** Tab changes must use `live_patch` (not `push_navigate`) to keep the page mounted and avoid full remount, which would reset the runs stream.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Overflow/action menu | Custom JS popover | daisyUI `dropdown` (confirmed in vendor) | CSS-only `:focus-within` open state, already handles positioning, z-index, animation |
| Status badge | New badge component | Existing `StatusBadge` in `status_badge.ex` | Already handles all run statuses with correct colors; reuse for index card last-run status |
| Tab component | Custom tab implementation | daisyUI `tabs` classes + `live_patch` + `handle_params/3` | Same pattern established in RunLive.Show (Phase 4), extended with URL state |
| Run count per instance | Per-card DB queries | Single `list_instances_with_stats/0` Ecto query | Ecto `group_by` + `count` is efficient; per-card queries cause N+1 at scale |
| Theme toggle | New toggle implementation | Existing `theme_toggle/1` in `layouts.ex` | Already implemented, tested, fully functional |

**Key insight:** Everything needed for this phase already exists in the codebase — the work is assembling existing pieces (daisyUI components, established patterns, existing context functions) into new templates, not building new primitives.

---

## Common Pitfalls

### Pitfall 1: Stream Items Are Plain Instance Structs After Stats Query

**What goes wrong:** The `phx-update="stream"` container for instances receives initial items as `%{instance: %Instance{}, run_count: N, last_run_at: ...}` maps. But PubSub `handle_info({:instance_created, instance})` sends a plain `%Instance{}` struct. Calling `stream_insert` with a struct when the stream expects maps will cause a KeyError in the template.

**Why it happens:** The stream's initial items are maps from `list_instances_with_stats/0`, but PubSub broadcast events carry the raw Instance struct from the context functions.

**How to avoid:** In PubSub handlers for instance events on the Index page, after receiving an `:instance_created` or `:instance_updated` event, do a targeted stats query for that specific instance rather than inserting the plain struct:

```elixir
def handle_info({:instance_created, instance}, socket) do
  stats = get_instance_stats(instance.id)  # single-row version of the aggregate query
  socket =
    socket
    |> update(:instance_count, &(&1 + 1))
    |> stream_insert(:instances, stats, at: 0)
  {:noreply, socket}
end
```

**Warning signs:** Template crashes with "key :run_count not found in %Athanor.Experiments.Instance{}".

### Pitfall 2: `handle_params/3` Not Called on Initial Mount if Route Has No Params

**What goes wrong:** If a user navigates to `/experiments/abc` (no `?tab=` query param), `handle_params/3` is still called with an empty map. The catch-all clause `handle_params(_params, _uri, socket)` sets `:active_tab` to `:runs` — this is correct. But if only the `%{"tab" => tab}` clause is defined, navigation without a tab param will crash with a function clause error.

**Why it happens:** `handle_params/3` is always called, even with empty params.

**How to avoid:** Always define the catch-all clause that sets the default tab.

**Warning signs:** FunctionClauseError on navigating to `/experiments/:id` without a tab query param.

### Pitfall 3: Dropdown Stays Open After Click (Focus Management)

**What goes wrong:** The daisyUI dropdown uses CSS `:focus-within` to stay open. After clicking a menu item (e.g., "Delete"), the dropdown stays open because the `button` element inside the list retains focus until the phx-click roundtrip completes and the DOM updates.

**Why it happens:** `:focus-within` on the parent `.dropdown` div remains true while any child holds focus.

**How to avoid:** Add `tabindex="-1"` to the dropdown content div to remove it from focus order after action. Alternatively, call `document.activeElement.blur()` in a phx JS command. In practice, for destructive actions behind `data-confirm`, the confirm dialog dismisses the dropdown naturally. For non-destructive clicks, this is a minor UX issue acceptable for this phase.

**Warning signs:** Dropdown stays visible after clicking Delete and dismissing the confirm dialog.

### Pitfall 4: Sticky Footer Overlaps Form Content Without Bottom Padding

**What goes wrong:** The `fixed bottom-0` sticky footer sits on top of the last form element, making it unclickable.

**Why it happens:** `position: fixed` removes the element from normal flow — the content underneath doesn't know the footer exists.

**How to avoid:** Add `pb-24` (or similar) to the main content wrapper to ensure content scrolls above the footer height. The footer height is approximately 64px (3rem padding on each side + button height), so `pb-20` is sufficient.

**Warning signs:** The "Create Instance" button inside the form is overlapped by the sticky footer at the bottom of the page.

### Pitfall 5: `live_patch` for Tab Navigation Triggers Full Re-render Without Optimization

**What goes wrong:** Every tab click triggers `handle_params/3`, which re-assigns `:active_tab`. This causes LiveView to diff and patch the template. If the Runs stream is large, this doesn't cause data re-fetching, but does cause a render cycle. This is fine — `phx-update="stream"` containers don't reset on re-render unless `stream/4` is called again.

**Why it happens:** `live_patch` triggers `handle_params/3`, which calls `{:noreply, assign(socket, :active_tab, ...)}`, which triggers re-render.

**How to avoid:** No special handling needed — this is expected LiveView behavior. The `hidden` class approach means DOM elements aren't removed/re-added on tab switch.

**Warning signs:** None — this is not actually a problem, just awareness that `live_patch` causes a server roundtrip (unlike pure client JS tab switching).

---

## Code Examples

Verified patterns from project codebase and Phoenix LiveView conventions:

### Aggregate Stats Query

```elixir
# In Athanor.Experiments:
def list_instances_with_stats do
  from(i in Instance,
    left_join: r in assoc(i, :runs),
    group_by: i.id,
    select: %{
      instance: i,
      run_count: count(r.id),
      last_run_at: max(r.inserted_at)
    },
    order_by: [desc: max(r.inserted_at), asc: i.name]
  )
  |> Repo.all()
end

def get_instance_stats(instance_id) do
  from(i in Instance,
    left_join: r in assoc(i, :runs),
    where: i.id == ^instance_id,
    group_by: i.id,
    select: %{
      instance: i,
      run_count: count(r.id),
      last_run_at: max(r.inserted_at)
    }
  )
  |> Repo.one()
end
```

### URL-Synced Tab (handle_params)

```elixir
# In InstanceLive.Show:
@impl true
def handle_params(%{"tab" => tab}, _uri, socket) when tab in ["runs", "configuration"] do
  {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
end

def handle_params(_params, _uri, socket) do
  {:noreply, assign(socket, :active_tab, :runs)}
end
```

### daisyUI Dropdown (confirmed CSS in vendor)

```heex
<div class="dropdown dropdown-end">
  <div tabindex="0" role="button" class="btn btn-ghost btn-sm btn-square">
    <.icon name="hero-ellipsis-vertical" class="size-5" />
  </div>
  <ul tabindex="0" class="dropdown-content menu bg-base-200 rounded-box z-10 w-48 p-2 shadow-sm">
    <li><a phx-click="some_action">Action</a></li>
  </ul>
</div>
```

### External Submit Button (form attribute)

```heex
<%!-- Form with id --%>
<.form for={@form} id="new-instance-form" phx-submit="save">
  <%!-- fields --%>
</.form>

<%!-- Submit button outside form, in sticky footer --%>
<button type="submit" form="new-instance-form" class="btn btn-primary">
  Create Instance
</button>
```

### Delete Instance Handler

```elixir
# In InstanceLive.Index:
@impl true
def handle_event("delete_instance", %{"id" => id}, socket) do
  instance = Experiments.get_instance!(id)
  {:ok, _} = Experiments.delete_instance(instance)
  Athanor.Experiments.Broadcasts.instance_deleted(instance)
  {:noreply, socket}
  # stream_delete handled by handle_info({:instance_deleted, ...}) which is already implemented
end
```

### Start Run from Index Page

```elixir
# In InstanceLive.Index — mirrors InstanceLive.Show:
@impl true
def handle_event("start_run", %{"id" => id}, socket) do
  instance = Experiments.get_instance!(id)
  case Runtime.start_run(instance) do
    {:ok, _run} ->
      {:noreply, put_flash(socket, :info, "Run started")}
    {:error, reason} ->
      {:noreply, put_flash(socket, :error, "Failed to start: #{inspect(reason)}")}
  end
end
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Phoenix boilerplate navbar | Athanor-specific minimal nav (logo + theme toggle) | layouts.ex app/1 header replacement required |
| Simple instance list with "View" button | Rich cards with run stats + action menu | Needs aggregate query + template refactor |
| Show page: single scrollable view with sidebar | Show page: tab-based with URL-synced active tab | handle_params/3 + live_patch pattern |
| New page: actions inline in form body | New page: sticky footer with Cancel/Create | Fixed-position footer + form attribute pattern |
| Config displayed as raw key-value list | Config tab: styled key-value rows per design system | Template polish only |

**Deprecated/outdated in this codebase:**

- `app/1` layout with `max-w-2xl`: this was Phoenix default; needs widening to `max-w-4xl` for card layouts.
- `<.header>` component usage in Index/Show: the `<.header>` component from `core_components.ex` produces a simple flex row. The Show page needs a richer header (breadcrumb + action group). The Index page may keep `<.header>` or replace it with a custom layout. Either is fine — `<.header>` is a simple component, not a framework constraint.

---

## Open Questions

1. **Edit Configuration routing: modal or dedicated route?**
   - What we know: No edit route exists. The "Edit Config" button in the action dropdown on both Index and Show needs a destination.
   - What's unclear: Whether to add `/experiments/:id/edit` as a new LiveView, or open a modal on the Show page, or link to the Show page's Configuration tab (which is currently read-only).
   - Recommendation: Add an edit route (`/experiments/:id/edit`) that reuses the New page form structure. This is simple, follows REST conventions, and avoids modal complexity. The New page form already has all the needed logic — extract shared logic into a shared function component or module. Alternatively, if the scope is truly "polish only" with no new routes, the Edit button can be deferred (greyed out / tooltip "coming soon"). The decision was to include "Edit Config button" in card actions, so an edit route is likely intended.

2. **Index page stream items: maps vs structs**
   - What we know: `stream/3` requires items with a stable `:id` key for DOM diffing. If items are maps `%{instance: %Instance{}, ...}`, LiveView needs to know which field is the ID.
   - What's unclear: Whether `stream_insert` works with arbitrary maps or requires Ecto structs. The stream identifies elements by `item.id` by default.
   - Recommendation: Pass the full stats map to `stream` with the instance embedded, and use `dom_id` from the stream as the HTML `id`. The `:instance` key provides the ID via `item.instance.id`. Set the stream's `dom_id` option: `stream(:instances, stats_list, dom_id: fn item -> "instance-#{item.instance.id}" end)`. Alternatively, flatten the map to include `id: instance.id` at the top level.

3. **Start Run from index: navigation or stay on index?**
   - What we know: Clicking "Run" on an index card starts a run. The Show page navigates to the run page after start. Index page is a list — does it navigate to the show page, the run page, or stay?
   - What's unclear: The decision says "Start Run button" is a full action — unclear if it navigates.
   - Recommendation: For index page "Start Run": start the run, show a flash ("Run started"), and stay on the index page. Navigation to the run page from the index would be confusing for bulk scenarios. The flash message suffices.

---

## Sources

### Primary (HIGH confidence)

- Codebase: `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/index.ex` — current Index implementation, existing PubSub handlers
- Codebase: `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/show.ex` — current Show implementation, existing tab pattern
- Codebase: `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/new.ex` — current New implementation
- Codebase: `apps/athanor_web/lib/athanor_web/components/layouts.ex` — current app/1 layout (confirmed boilerplate navbar)
- Codebase: `apps/athanor_web/lib/athanor_web/components/core_components.ex` — `header/1`, `button/1`, `flash/1` components
- Codebase: `apps/athanor_web/lib/athanor_web/live/experiments/components/status_badge.ex` — all run statuses handled
- Codebase: `apps/athanor_web/assets/vendor/daisyui.js:431-436` — dropdown component confirmed in bundle
- Codebase: `apps/athanor_web/assets/vendor/daisyui.js` — card component with `.card`, `.card-body`, `.card-title` classes
- Codebase: `apps/athanor/lib/athanor/experiments.ex` — `list_instances/0` returns plain structs (no run stats), `delete_instance/1` exists
- Codebase: `apps/athanor/lib/athanor/experiments/broadcasts.ex` — `instance_deleted/1` broadcast exists
- Codebase: `.planning/phases/01-visual-identity-and-theme-foundation/DESIGN-TOKENS.md` — semantic color rules, layout patterns
- Codebase: `apps/athanor_web/lib/athanor_web/live/experiments/run_live/show.ex` — tab + `hidden` class pattern already working (Phase 4)
- Codebase: `apps/athanor_web/router.ex` — no edit route exists currently

### Secondary (MEDIUM confidence)

- Phase 4 RESEARCH.md — tab pattern, sticky header pattern, `hidden` class stream compatibility — verified implemented and working in RunLive.Show
- Phoenix LiveView documentation pattern: `handle_params/3` for query param handling and `live_patch` for URL updates without full mount

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all libraries already in use, verified from codebase
- Architecture: HIGH — all patterns established in Phase 4 (tabs, sticky, hidden class), aggregate query is standard Ecto
- Pitfalls: HIGH — identified from direct code analysis (stream type mismatch, handle_params catch-all, focus management)
- Open questions: LOW — routing and stream ID questions require a decision, not research

**Research date:** 2026-02-18
**Valid until:** 2026-03-18 (stable stack — Phoenix/LiveView/daisyUI versions fixed in vendor)
