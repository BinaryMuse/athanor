# Phase 5: Configuration Forms Polish - Research

**Researched:** 2026-02-17
**Domain:** Phoenix LiveView schema-driven forms, daisyUI 5 components, ConfigSchema extension
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Field layout & grouping
- Card-based sections: each group renders in its own card with header, ungrouped fields in a default card
- Add `group/4` function to ConfigSchema for logical field grouping (non-repeating sections)
- Stacked labels: label on its own line, full-width input below
- Inline repeater for list fields: items stacked vertically with add/remove buttons, all visible
- Help text support: both groups and individual fields can have optional description/help text via schema

#### Input type rendering
- Format hints for strings: schema supports `format:` option (`:text`, `:textarea`, `:url`, `:email`, etc.)
- Enum as a new type: `field(:level, :enum, options: [:low, :medium, :high])`
- Checkbox for boolean fields (not toggle switch)
- Number constraints: schema supports `min:`, `max:`, `step:` options for integer/number fields

#### Validation & error display
- Validate on blur + submit: check when user leaves field, and again on form submission
- Inline errors with highlight: error text below field AND red border on input
- Required fields marked with red asterisk (*) on label
- Errors clear on blur after fix: stays until user leaves field with valid value

#### Nested schema handling
- Collapsible mini-cards for list items: each item can collapse to a summary line
- Generic index for collapsed summary: "Item 1", "Item 2", etc.
- Unlimited nesting depth with visual indentation
- Drag handles preferred for reordering, fall back to up/down buttons if implementation proves complex

### Claude's Discretion
- List reordering implementation approach (drag-and-drop vs button-based)
- Exact visual styling within established design system
- Performance optimizations for large schemas
- Specific indentation/spacing for nested levels

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

## Summary

This phase polishes the configuration form in `InstanceLive.New`. The current implementation is a self-contained `defp`-based rendering system inside a single LiveView module. It handles string, integer, boolean, and list field types but lacks grouping, format hints, enum support, validation, or collapsible list items. The code must be extracted into a proper component module and the `ConfigSchema` must be extended.

The two primary technical tracks are: (1) extend `Athanor.Experiment.ConfigSchema` with `group/4`, `format:` opts, `min:/max:/step:` opts, and `:enum` type; and (2) extract all form rendering into a dedicated `ConfigFormComponent` (`use Phoenix.Component`) with proper validation wiring. Validation uses LiveView's built-in `phx-debounce="blur"` on each input combined with `used_input?/1` to suppress premature errors — entirely server-side, no custom JS needed.

For list item reordering, SortableJS via a LiveView hook is the standard Phoenix ecosystem approach and is recommended over up/down buttons. SortableJS is not yet in the vendor folder and must be added. The entire implementation uses daisyUI 5 components (card, fieldset, input, select, checkbox, textarea) already in the project.

**Primary recommendation:** Extract all config form rendering into `AthanorWeb.Experiments.Components.ConfigFormComponent`, extend `ConfigSchema` with `group/4` and new field opts, wire validation with `phx-debounce="blur"` + `used_input?/1`, and add SortableJS to vendor for list reordering.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView | 1.1.24 | Form bindings, validation, component system | Already in project; used throughout |
| daisyUI | 5.x (vendor bundle) | UI components: card, fieldset, input, select | Already in project; established design system |
| Phoenix.Component | (part of PLV 1.1.24) | Functional component extraction with `attr/3`, `slot/3` | The correct abstraction for stateless rendering |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SortableJS | Latest (vendor copy) | Drag-and-drop list reordering | List field reordering — discretion area |
| Phoenix.LiveView.JS | (part of PLV 1.1.24) | Client-side collapse/expand of list items | Collapsible mini-cards without server round-trips |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SortableJS (vendor copy) | Up/down buttons | Buttons are simpler to implement, no JS library needed — valid fallback per user decision |
| `Phoenix.Component` module | LiveComponent | Function components are correct here: no independent state or event handling needed |
| phx-debounce="blur" | phx-blur event binding | `phx-debounce="blur"` is the standard way; `phx-blur` fires immediately and requires explicit handler |

**Installation (SortableJS only — new addition):**
```bash
# Download sortable.js to vendor directory
curl -sLO https://raw.githubusercontent.com/SortableJS/Sortable/master/Sortable.js
# Place at: apps/athanor_web/assets/vendor/sortable.js
```

---

## Architecture Patterns

### Recommended File Structure
```
apps/athanor/lib/experiment/
└── config_schema.ex              # Add group/4, extend field/4 opts, add :enum type

apps/athanor_web/lib/athanor_web/
├── live/experiments/
│   ├── instance_live/
│   │   └── new.ex                # Slim down: delegate config rendering to component
│   └── components/
│       └── config_form_component.ex  # New: all config form rendering logic
└── assets/vendor/
    └── sortable.js               # New: SortableJS for drag-and-drop (if chosen)
```

### Pattern 1: ConfigSchema Extension — group/4

**What:** Add a `group/4` function to `ConfigSchema` that bundles fields under a named grouping key. Groups are non-repeating (unlike `list/4`). Fields inside a group get rendered in their own card.

**Example schema field definition after extension:**
```elixir
# Source: Modeled on existing list/4 signature in config_schema.ex

def group(%__MODULE__{} = schema, name, sub_schema, opts \\ []) do
  label = Keyword.get(opts, :label, nil)
  description = Keyword.get(opts, :description, nil)

  %{
    schema
    | properties:
        Map.put(schema.properties, name, %{
          type: :group,
          label: label,
          description: description,
          sub_schema: sub_schema
        })
  }
end

# Extended field/4 with format:, min:, max:, step:, options:, description:, required:
def field(%__MODULE__{} = schema, name, type, opts \\ []) do
  %{
    schema
    | properties:
        Map.put(schema.properties, name, %{
          type: type,
          default: Keyword.get(opts, :default, nil),
          label: Keyword.get(opts, :label, nil),
          description: Keyword.get(opts, :description, nil),
          required: Keyword.get(opts, :required, false),
          format: Keyword.get(opts, :format, nil),       # :text | :textarea | :url | :email
          options: Keyword.get(opts, :options, nil),      # for :enum type
          min: Keyword.get(opts, :min, nil),              # for :integer/:number
          max: Keyword.get(opts, :max, nil),
          step: Keyword.get(opts, :step, nil)
        })
  }
end
```

### Pattern 2: ConfigFormComponent — Functional Component Module

**What:** Extract all `render_config_field` and `render_list_item_field` `defp` functions from `InstanceLive.New` into a dedicated `Phoenix.Component` module.

**When to use:** Always. The current approach (defp helpers inside a LiveView) is valid but makes the logic hard to test and reuse.

**Key design:**
- Top-level entry: `config_form/1` component that iterates schema properties
- Dispatches to: `config_group/1`, `config_list_field/1`, `config_scalar_field/1`
- Scalar field dispatcher pattern-matches on `field_def.type` and `field_def.format`
- Each renders the full label + input + error + help text block
- Errors are stored in a `%{field_path => [error_string]}` map assign on the socket

```elixir
# Source: Phoenix.Component pattern — hexdocs.pm/phoenix_live_view/Phoenix.Component.html

defmodule AthanorWeb.Experiments.Components.ConfigFormComponent do
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  attr :schema, :map, required: true
  attr :path, :list, default: []
  attr :list_items, :map, required: true
  attr :errors, :map, default: %{}

  def config_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= for {name, field_def} <- ordered_properties(@schema) do %>
        <.dispatch_field
          name={name}
          field_def={field_def}
          path={@path ++ [name]}
          list_items={@list_items}
          errors={@errors}
        />
      <% end %>
    </div>
    """
  end
end
```

### Pattern 3: Blur Validation with used_input?

**What:** LiveView 1.0+ replaced `phx-feedback-for` with server-side `used_input?/1`. The form sends `_unused_` prefixed params to mark untouched fields. `used_input?/1` returns true only if the field has been interacted with.

**How it works for config fields:**

Since config fields are NOT backed by an Ecto changeset (they use raw `name=` attributes), validation must be custom. The approach:

1. Track which field paths have been blurred in socket assigns: `%{validated_paths: MapSet.t()}`
2. On `phx-change` (via `phx-debounce="blur"` on each input): receive the `"validate"` event, add the triggering field path to `validated_paths`, run custom validation, store errors map
3. On form submit: validate all fields regardless of blur state
4. Render errors only if path is in `validated_paths` OR form was submitted

**Critical:** The existing `phx-change="validate"` event on the form fires for ALL fields on any change. `phx-debounce="blur"` on individual inputs makes each input only trigger the change event on blur (not on every keystroke).

```heex
<%!-- Source: hexdocs.pm/phoenix_live_view/form-bindings.html --%>
<input
  type="text"
  name={field_name(@path)}
  value={@field_def.default}
  phx-debounce="blur"
  class={["input w-full", has_error?(@errors, @path) && "input-error"]}
/>
<p :if={get_error(@errors, @path)} class="mt-1 flex gap-2 items-center text-sm text-error">
  <.icon name="hero-exclamation-circle" class="size-5" />
  {get_error(@errors, @path)}
</p>
```

### Pattern 4: Collapsible List Items with JS.toggle_class

**What:** Each list item card has a collapse button that toggles between showing the full fields and showing just "Item N" summary. Uses client-side `JS.toggle_class` to survive LiveView DOM patches.

**Established pattern from phase 3 (results_panel):**
```elixir
# Source: apps/athanor_web/lib/athanor_web/live/experiments/components/results_panel.ex
phx-click={
  JS.toggle_class("hidden", to: "#item-detail-#{idx}")
  |> JS.toggle_class("hidden", to: "#item-summary-#{idx}")
}
```

Apply same approach for list item collapse:
- Summary line: `id="config-item-summary-#{path_key}-#{idx}"` — visible by default OR collapsed
- Detail block: `id="config-item-detail-#{path_key}-#{idx}"` — visible by default
- Toggle button uses `JS.toggle_class("hidden", ...)` on both elements

### Pattern 5: SortableJS Hook for Drag-and-Drop Reordering

**What:** A LiveView hook that initializes SortableJS on the list container. When drag ends, the hook pushes the old and new index to the LiveView via `pushEventTo`.

**Implementation:**
```javascript
// Source: fly.io/phoenix-files/liveview-drag-and-drop/
// Add to assets/vendor/sortable.js (download from SortableJS releases)
// In app.js:
import Sortable from "../vendor/sortable"

// In Hooks object:
SortableList: {
  mounted() {
    this.sortable = new Sortable(this.el, {
      animation: 150,
      handle: ".drag-handle",
      onEnd: (e) => {
        this.pushEventTo(this.el, "reorder_list_item", {
          path: this.el.dataset.path,
          old_index: e.oldIndex,
          new_index: e.newIndex
        })
      }
    })
  },
  destroyed() {
    if (this.sortable) this.sortable.destroy()
  }
}
```

Server-side handler in `InstanceLive.New`:
```elixir
def handle_event("reorder_list_item", %{"path" => path, "old_index" => old, "new_index" => new_idx}, socket) do
  old_idx = String.to_integer(old)
  new_idx = String.to_integer(new_idx)

  list_items =
    Map.update(socket.assigns.list_items, path, [], fn items ->
      item = Enum.at(items, old_idx)
      items
      |> List.delete_at(old_idx)
      |> List.insert_at(new_idx, item)
    end)

  {:noreply, assign(socket, :list_items, list_items)}
end
```

**Fallback (if drag-and-drop is too complex):** Up/down buttons:
```elixir
# phx-click="move_list_item_up" phx-value-path={path_key} phx-value-index={idx}
# phx-click="move_list_item_down" phx-value-path={path_key} phx-value-index={idx}
```

### Pattern 6: daisyUI Card and Fieldset for Group Layout

**What:** Each schema group renders as a `card bg-base-200` with `card-body`. The card title is the group label. Individual fields inside the card use `fieldset` semantics but rendered as standard label+input blocks (stacked layout per user decision).

```heex
<%!-- Source: daisyui.com/components/card/ and daisyui.com/components/fieldset/ --%>
<div class="card bg-base-200">
  <div class="card-body gap-4">
    <h3 class="card-title text-base">{group_label}</h3>
    <p :if={group_description} class="text-sm text-base-content/70">{group_description}</p>
    <%!-- field components --%>
  </div>
</div>
```

For the "ungrouped fields" default card, use the same card structure with a generic title or no title.

### Anti-Patterns to Avoid

- **Treating config validation like Ecto changeset validation:** Config fields are raw maps, not Ecto schemas. Do NOT try to use `Phoenix.HTML.FormField` structs for these inputs. Manage error state manually in socket assigns.
- **Using `phx-blur` binding instead of `phx-debounce="blur"`:** `phx-blur` fires immediately and requires a separate event handler name. `phx-debounce="blur"` delays the existing `phx-change` event until blur — simpler and the documented approach.
- **Keeping config form logic inside `InstanceLive.New`:** The current `defp` approach worked for a basic form but cannot support the required complexity. Extract to a component module.
- **Using `form-control` class:** This daisyUI 4 class was deleted in daisyUI 5. The project is on daisyUI 5. Use `fieldset` / `label` / `input` classes instead. The existing `new.ex` still uses `form-control` — this is a bug to fix during this phase.
- **Passing `phx-target` incorrectly for pushEventTo:** When a hook calls `this.pushEventTo(this.el, ...)`, the element needs `phx-target` to be set if it's not the root LiveView. For drag-and-drop inside the LiveView's main form, `pushEvent` (not `pushEventTo`) is sufficient.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Drag-and-drop reordering | Custom mouse event tracking | SortableJS + hook | Touch support, keyboard, accessibility, edge cases |
| Client-side collapse/expand | JS class manipulation by hand | `Phoenix.LiveView.JS.toggle_class` | Survives LiveView DOM patches; used in phase 3 already |
| Blur-based validation UX | Custom JS that tracks blur state | `phx-debounce="blur"` | Built into LiveView; no JS code needed |
| Form field error display | Global flash messages | Inline error pattern from `core_components.ex` | Already defined as `error/1` private component there |

**Key insight:** LiveView's form binding system (`phx-debounce="blur"`, `used_input?`, `_unused_` params) handles the hard parts of progressive validation UX entirely server-side. Resist the urge to add JavaScript for this.

---

## Common Pitfalls

### Pitfall 1: Config Validation Has No Ecto Changeset
**What goes wrong:** Trying to use `Phoenix.HTML.FormField`, `to_form`, or `used_input?` for config fields. These work only when fields are backed by an Ecto schema.
**Why it happens:** The `InstanceLive.New` form wraps an `Instance` changeset, but the config sub-fields are raw `name=` attributes going into `params["configuration"]` — not part of the changeset.
**How to avoid:** Track config validation state manually. Store `%{errors: %{path_key => message}, touched_paths: MapSet.t()}` in socket assigns. Validate in the `"validate"` handler; render errors conditionally based on touched state.
**Warning signs:** Trying to do `@form[:configuration][:some_field]` — this doesn't work for nested raw params.

### Pitfall 2: phx-debounce="blur" + form-level phx-change interaction
**What goes wrong:** The `phx-change="validate"` on the `<.form>` element fires on every change. Adding `phx-debounce="blur"` to an input delays that input's change event, but OTHER inputs without debounce still trigger validate on keystroke. Validation handler must be idempotent and only update errors/touched state correctly.
**Why it happens:** `phx-change` is a form-level binding that fires for any input in the form. `phx-debounce` scopes the delay to the individual element.
**How to avoid:** In the `"validate"` handler, identify which field triggered the event (Phoenix passes `"_target"` in the params map). Only mark that field as touched.
**Warning signs:** Error state appearing prematurely on unrelated fields when user types in one field.

### Pitfall 3: LiveView DOM Patching Destroys SortableJS Instance
**What goes wrong:** After a `handle_event` response re-renders the list, SortableJS loses its binding because LiveView replaced the DOM element.
**Why it happens:** LiveView's morphdom diffing can replace the container element, destroying the SortableJS instance attached to it.
**How to avoid:** Use `phx-update="ignore"` on the sortable container (LiveView won't touch its children) and manage list state manually via pushEvent. OR rely on the hook's `updated()` callback to re-initialize. The Fly.io guide uses a full re-render approach and accepts the re-bind cost.
**Warning signs:** Drag-and-drop stops working after the first reorder.

### Pitfall 4: form-control Class Is Deleted in daisyUI 5
**What goes wrong:** Using `class="form-control"` produces no styling (class is silently ignored).
**Why it happens:** daisyUI 5 removed `form-control`. The existing `new.ex` uses it — this is a pre-existing issue.
**How to avoid:** Replace `form-control` div wrappers with proper `fieldset` element or plain `div` with appropriate Tailwind spacing. The existing `core_components.ex` already uses the updated `fieldset mb-2` pattern.
**Warning signs:** Form fields lack expected vertical spacing or label styling.

### Pitfall 5: Ordered Map Iteration for Schema Properties
**What goes wrong:** Schema `properties` is a `%{}` map. Elixir maps do not preserve insertion order for arbitrary string/atom keys. Form renders in unpredictable order.
**Why it happens:** `%{runs_per_pair: ..., model_pairs: ...}` may not render in definition order.
**How to avoid:** The `ConfigSchema` should store properties as an ordered list of `{name, field_def}` tuples, OR use a `Map` and sort by a `:order` metadata field added during construction. The simplest fix: change `properties` from `%{}` to a list of `{name, def}` pairs in `ConfigSchema.new()`. This is a schema change that affects all rendering.
**Warning signs:** Form fields appear in different order than schema definition on different Elixir versions or after map merges.

### Pitfall 6: String Keys vs Atom Keys in Config Params
**What goes wrong:** Form params come back as `%{"runs_per_pair" => "10", "model_pairs" => %{"0" => ...}}` but schema properties use atom keys like `:runs_per_pair`.
**Why it happens:** HTML form submissions are always string-keyed. The existing `parse_configuration` code handles this but it's fragile.
**How to avoid:** Be explicit about key normalization in the `parse_configuration` helper. Always compare `to_string(name)` against string param keys, not atom keys.
**Warning signs:** Config values not appearing in form after page refresh / validate cycle.

---

## Code Examples

### Stacked Label + Input (Standard Pattern)
```heex
<%!-- Source: core_components.ex — fieldset mb-2 pattern (verified in codebase) --%>
<div class="fieldset mb-2">
  <label>
    <span class="label mb-1">
      {label_text}
      <span :if={field_def.required} class="text-error ml-1">*</span>
    </span>
    <p :if={field_def.description} class="text-xs text-base-content/60 mb-1">
      {field_def.description}
    </p>
    <input
      type="text"
      name={field_name(path)}
      value={field_def.default}
      phx-debounce="blur"
      class={["input w-full", has_error && "input-error"]}
    />
  </label>
  <p :if={error_msg} class="mt-1 flex gap-2 items-center text-sm text-error">
    <.icon name="hero-exclamation-circle" class="size-5" />
    {error_msg}
  </p>
</div>
```

### Enum Field as Select
```heex
<%!-- Source: core_components.ex — select type already defined --%>
<div class="fieldset mb-2">
  <label>
    <span class="label mb-1">{label_text}</span>
    <select
      name={field_name(path)}
      phx-debounce="blur"
      class={["select w-full", has_error && "select-error"]}
    >
      <option :for={opt <- field_def.options} value={opt} selected={field_def.default == opt}>
        {humanize(opt)}
      </option>
    </select>
  </label>
</div>
```

### Group Card Wrapper
```heex
<%!-- Source: daisyui.com/components/card/ — verified card/card-body/card-title classes --%>
<div class="card bg-base-200">
  <div class="card-body gap-4">
    <h3 class="card-title text-base">{group_label || humanize(name)}</h3>
    <p :if={group_description} class="text-sm text-base-content/70">{group_description}</p>
    <.config_form schema={group_def.sub_schema} path={path} list_items={list_items} errors={errors} />
  </div>
</div>
```

### List Item Collapsible Card
```heex
<%!-- Source: Phase 3 pattern — JS.toggle_class survives LiveView DOM patches --%>
<div class="card bg-base-300 mb-3" id={"item-card-#{path_key}-#{idx}"}>
  <div class="card-body p-3 gap-2">
    <%!-- Header row with toggle + remove --%>
    <div class="flex items-center gap-2">
      <span class="drag-handle cursor-grab text-base-content/40">
        <.icon name="hero-bars-2" class="size-4" />
      </span>
      <button
        type="button"
        class="flex-1 text-left text-sm font-medium"
        phx-click={
          JS.toggle_class("hidden", to: "#item-summary-#{path_key}-#{idx}")
          |> JS.toggle_class("hidden", to: "#item-detail-#{path_key}-#{idx}")
        }
      >
        <span id={"item-summary-#{path_key}-#{idx}"} class="hidden text-base-content/60">
          Item {idx + 1}
        </span>
        <span class="text-base-content/40 text-xs">
          <.icon name="hero-chevron-down" class="size-3" />
        </span>
      </button>
      <button type="button" phx-click="remove_list_item" phx-value-path={path_key} phx-value-index={idx}
              class="btn btn-ghost btn-xs">
        <.icon name="hero-x-mark" class="size-4" />
      </button>
    </div>
    <%!-- Expandable detail --%>
    <div id={"item-detail-#{path_key}-#{idx}"} class="space-y-2 pl-6">
      <%!-- nested field rendering --%>
    </div>
  </div>
</div>
```

### Validation Error Tracking in Socket
```elixir
# Source: Custom pattern — no Ecto changeset for config fields
# In mount/3:
socket =
  socket
  |> assign(:config_errors, %{})         # %{path_key => error_message}
  |> assign(:config_touched, MapSet.new()) # paths that have been blurred

# In handle_event("validate", %{"instance" => params, "_target" => target}, socket):
# _target contains the input name that triggered the event, e.g., ["instance", "configuration", "runs_per_pair"]
# Use it to determine which path to add to config_touched
path_key = extract_config_path(target)
touched = MapSet.put(socket.assigns.config_touched, path_key)
errors = validate_config(schema, params["configuration"] || %{}, touched)
{:noreply, socket |> assign(:config_touched, touched) |> assign(:config_errors, errors)}
```

### ConfigSchema — Preserving Field Order
```elixir
# Source: Existing config_schema.ex — proposed fix for map ordering
# Change properties from %{} to list of {name, field_def} pairs

defstruct [:type, :properties]

def new() do
  %__MODULE__{type: :object, properties: []}  # List, not map
end

def field(%__MODULE__{} = schema, name, type, opts \\ []) do
  entry = {name, %{type: type, default: Keyword.get(opts, :default, nil), ...}}
  %{schema | properties: schema.properties ++ [entry]}
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `phx-feedback-for` attribute | `used_input?/1` server-side | LiveView 1.0 | Validation feedback is fully server-side; no HTML attribute tracking needed |
| `form-control` daisyUI class | `fieldset` + `label` components | daisyUI 5 | `form-control` was deleted; use `fieldset` instead |
| Manual JS for blur tracking | `phx-debounce="blur"` | Early LiveView | Standard, documented, built-in |
| `card-compact` | `card-sm` | daisyUI 5 | Renamed for consistency |

**Deprecated/outdated in THIS codebase:**
- `form-control` class in `new.ex`: used in current config field rendering — must be replaced with `fieldset mb-2` or plain div, matching `core_components.ex` pattern
- All `render_config_field` and `render_list_item_field` defp functions in `new.ex` will be superseded by the new component module

---

## Open Questions

1. **Schema property ordering**
   - What we know: Elixir maps do not preserve insertion order (technically they do for small maps in current BEAM, but it's not guaranteed)
   - What's unclear: Does the current code rely on ordering? Existing `model_pair_schema` has only 2 fields, masking the problem
   - Recommendation: Change `properties` from `%{}` to `[]` (list of tuples) in `ConfigSchema.new()`. This is a breaking change to the internal struct but no external code reads `schema.properties` as a map except the rendering code — which iterates it.

2. **Drag-and-drop vs up/down buttons**
   - What we know: SortableJS is the ecosystem standard; not yet in vendor
   - What's unclear: Scope complexity vs payoff — drag-and-drop requires hook + JS library + phx-update consideration; up/down buttons are 2 event handlers
   - Recommendation: Implement up/down buttons first (simpler, no JS library), then upgrade to SortableJS if time permits. Both are valid; the user left this to Claude's discretion. Up/down buttons avoid the `phx-update="ignore"` complexity.

3. **Where to put custom config validation logic**
   - What we know: Config fields are not Ecto-backed; validation must be custom
   - What's unclear: Should validation logic live in `ConfigSchema` (close to the schema definition) or in `InstanceLive.New` (close to the form)?
   - Recommendation: Add a `ConfigSchema.validate/2` function that takes the schema and a raw config map and returns `%{field_path => [error]}`. Keeps validation co-located with schema definition.

---

## Sources

### Primary (HIGH confidence)
- `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/new.ex` — Current implementation analyzed directly
- `apps/athanor/lib/experiment/config_schema.ex` — Current schema module (40 lines)
- `apps/athanor_web/lib/athanor_web/components/core_components.ex` — Existing `input/1`, `error/1` patterns
- `apps/athanor_web/lib/athanor_web/live/experiments/components/results_panel.ex` — `JS.toggle_class` precedent
- `apps/athanor_web/assets/css/app.css` — daisyUI 5 confirmed, theme tokens
- `config/config.exs` — esbuild `NODE_PATH` includes `Mix.Project.build_path()` (colocated hooks path)
- [hexdocs.pm/phoenix_live_view/form-bindings.html](https://hexdocs.pm/phoenix_live_view/form-bindings.html) — `phx-debounce="blur"`, `used_input?` documentation
- [hexdocs.pm/phoenix_live_view/Phoenix.Component.html](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) — Component extraction patterns

### Secondary (MEDIUM confidence)
- [daisyui.com/components/card/](https://daisyui.com/components/card/) — Card class names verified
- [daisyui.com/components/fieldset/](https://daisyui.com/components/fieldset/) — Fieldset class names verified
- [fly.io/phoenix-files/liveview-drag-and-drop/](https://fly.io/phoenix-files/liveview-drag-and-drop/) — SortableJS hook pattern (official Phoenix blog)

### Tertiary (LOW confidence)
- daisyUI 5 `validator` class: Uses native HTML `:invalid` pseudo-class — NOT suitable for server-side changeset errors. Skip this class entirely for this phase. Use `input-error`/`select-error`/`textarea-error` classes instead (already in `core_components.ex`).

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified in codebase; versions confirmed in mix.lock
- Architecture: HIGH — component extraction and validation patterns verified against official docs and existing codebase conventions
- Pitfalls: HIGH (form-control, ordering) / MEDIUM (SortableJS DOM patching) — form-control confirmed deleted in daisyUI 5; DOM patching concern based on SortableJS + LiveView known interaction pattern

**Research date:** 2026-02-17
**Valid until:** 2026-03-17 (stable stack — Phoenix LV 1.1.x and daisyUI 5 are stable)
