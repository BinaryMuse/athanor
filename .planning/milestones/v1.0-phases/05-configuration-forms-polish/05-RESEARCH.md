# Phase 5: Configuration Forms Polish - Research

**Researched:** 2026-02-17 (updated after Plan 01 completion and CONTEXT.md revision)
**Domain:** Phoenix LiveView schema-driven forms, daisyUI 5 components, ConfigSchema extension, client-side JS form management
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

#### Architecture decision: Client-side form management
**Decision:** Use a JavaScript LiveView hook (custom, no third-party form library) to manage form state client-side, rather than syncing state with LiveView on every change.

**Rationale:** Initial implementation attempted server-side form state management via LiveView, but this proved problematic:
- Nested dynamic lists require syncing state on every keystroke
- LiveView's phx-change events don't include form data for phx-click handlers
- Debounce timing causes race conditions between typing and add/remove operations
- The indexed map format from form params is awkward to reconcile with list state

**Approach:**
- Elixir ConfigSchema (from 05-01) defines the schema with metadata
- Schema serialized to JSON and passed to JS form manager via `data-schema` attribute
- JS hook handles all form interactions (typing, add/remove, reorder) client-side
- On submit, JS serializes complete form state and pushes to LiveView via `pushEvent("submit_config", {...})`
- LiveView validates and saves - no complex state sync needed

### Claude's Discretion
- List reordering implementation approach (drag-and-drop vs button-based)
- Exact visual styling within established design system
- Performance optimizations for large schemas
- Specific indentation/spacing for nested levels
- Choice of JS form library (Felte or alternative based on research) — **RESOLVED: custom hook, no library**

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CFG-01 | Configuration fields render with consistent styling, schema-driven fields display appropriate input types, deeply nested schemas render appropriately, validation errors appear inline, form state persists correctly during editing | Plan 01 (ConfigSchema extended), Plan 02 (ConfigFormComponent + scalar rendering), Plan 03 (list fields + validation + submission) |
</phase_requirements>

---

## Current State (After Plan 01)

**Plan 01 is COMPLETE.** `ConfigSchema` has been fully extended:
- Properties stored as ordered `[{atom, map}]` list (not `%{}` map) — definition order preserved
- `field/4` accepts: `label`, `description`, `required`, `format`, `min`, `max`, `step`, `options`
- `list/4` accepts: `label`, `description`
- `group/4` added: creates non-repeating section with `sub_schema`
- `:enum` type supported via `options:` list
- `get_property/2` helper for name-based lookup
- Nil opts are stripped from field maps (clean output, no nil label/description keys)
- `required` defaults to `false` (boolean, not stripped by nil-rejection)

**Plans 02 and 03 are NOT yet started.** This research update focuses on what's needed for those plans.

---

## Summary

The remaining work in Phase 5 (Plans 02 and 03) requires building the full configuration form UI. The ConfigSchema foundation (Plan 01) is complete. Plans 02 and 03 must now:

1. Extract all config form rendering from `InstanceLive.New` into a dedicated `ConfigFormComponent` (a `use Phoenix.Component` module) that handles card-based groups, stacked label+input layout, all scalar field types (string, integer, boolean, enum), help text, required asterisks
2. Build list field rendering with collapsible items, add/remove, and validation — managed entirely client-side via a LiveView JavaScript hook

**Critical architecture shift:** The original RESEARCH.md assumed server-side form management using `phx-debounce="blur"` and `phx-change`. The CONTEXT.md now mandates client-side form state management. This means:
- The form does NOT use `phx-change` for config fields
- A JavaScript hook holds all form state in memory
- Schema is serialized to JSON and passed to the hook via `data-schema` attribute
- The hook intercepts form submit and calls `pushEvent("submit_config", configState)` instead of relying on standard form param serialization
- Validation feedback (blur + submit) is handled by the JS hook tracking field dirty state

**Recommendation for form library:** Felte (`@felte/element`) is marked explicitly unstable in its own documentation. The project has no npm/package.json — only vendored JS. The correct approach is a **custom `ConfigFormHook`** written directly in `app.js` or as a colocated hook. No third-party form library is needed or appropriate.

**Primary recommendation:** Implement `ConfigFormHook` as a LiveView JS hook that owns form state. Serialize ConfigSchema to JSON on the server and pass as `data-schema`. Hook manages add/remove/reorder of list items, blur tracking for validation, and submit serialization via `pushEvent`.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView | 1.1.24 | Hook system, JS commands, component system | Already in project; colocated hooks support |
| daisyUI | 5.x (vendor bundle) | UI components: card, fieldset, input, select, checkbox, textarea | Already in project; established design system |
| Phoenix.Component | (part of PLV 1.1.24) | Functional component extraction with `attr/3`, `slot/3` | Correct abstraction for stateless rendering |
| Jason | ~1.2 | Serialize ConfigSchema struct to JSON for JS consumption | Already in both apps as dependency |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phoenix.LiveView.JS | (part of PLV 1.1.24) | Client-side collapse/expand of list items without server round-trip | Collapsible mini-cards |
| SortableJS | Latest (vendor copy) | Drag-and-drop list reordering | Only if reordering chosen as drag-and-drop (discretion area) |

### Alternatives Considered and Rejected
| Rejected | Reason |
|----------|--------|
| Felte (`@felte/element`) | Explicitly marked "not yet stable" in own docs; API breaks between minor versions; not worth pinning unstable dep |
| `phx-debounce="blur"` + server-side validate | Doesn't work with client-side form management — phx-change fires on every change and doesn't carry form state for phx-click (add/remove) handlers |
| Ecto `inputs_for` / `:sort_param` / `:drop_param` | Config is not Ecto-backed; configuration field is `field :configuration, :map` — raw map, not embedded schema |
| `Phoenix.HTML.FormField` for config inputs | Only works with Ecto-backed form fields; config fields are raw name= attributes |

**No new JS libraries required.** The `ConfigFormHook` is written as vanilla JS (< 150 lines) directly in the project.

---

## Architecture Patterns

### Recommended File Structure
```
apps/athanor_web/lib/athanor_web/
├── live/experiments/
│   ├── instance_live/
│   │   └── new.ex                   # Slimmed down: delegates config to component + hook
│   └── components/
│       └── config_form_component.ex # New: all config form rendering logic
└── assets/
    └── js/
        └── app.js                   # Add ConfigFormHook to Hooks object
```

### Pattern 1: ConfigSchema Serialization to JSON

**What:** Before passing the schema to the HTML template, serialize it to JSON. The JS hook reads it from a `data-schema` attribute.

**Key challenge:** `ConfigSchema` uses atom keys and list-of-tuples for properties. Standard Jason encoding of a struct produces a map with atom keys but may lose the list structure. Must implement `Jason.Encoder` protocol OR serialize manually.

**Approach — implement Jason.Encoder for ConfigSchema:**
```elixir
# Source: Jason docs - implementing protocol for struct
defimpl Jason.Encoder, for: Athanor.Experiment.ConfigSchema do
  def encode(schema, opts) do
    properties =
      Enum.map(schema.properties, fn {name, field_def} ->
        encoded_def = encode_field_def(field_def)
        %{name: name, definition: encoded_def}
      end)

    Jason.Encoder.encode(%{type: schema.type, properties: properties}, opts)
  end

  defp encode_field_def(%{type: :group, sub_schema: sub_schema} = def) do
    Map.put(def, :sub_schema, sub_schema)  # recursive — sub_schema is also a ConfigSchema
  end

  defp encode_field_def(%{type: :list, item_schema: item_schema} = def) do
    Map.put(def, :item_schema, item_schema)  # recursive
  end

  defp encode_field_def(def), do: def
end
```

**Alternative simpler approach** — serialize in the LiveView before assigning:
```elixir
# In handle_event("select_experiment", ...) or mount/3:
schema_json = Jason.encode!(schema)  # Requires Jason.Encoder impl OR manual conversion
assign(socket, :config_schema_json, schema_json)
```

Then in the HEEx template:
```heex
<div
  id="config-form-container"
  phx-hook="ConfigFormHook"
  data-schema={@config_schema_json}
>
  <%!-- JS hook renders fields dynamically --%>
</div>
```

**CRITICAL:** Passing large JSON blobs via `data-*` attributes works fine for schemas but must be regenerated when the experiment changes. Use `phx-update="ignore"` on the hook container to prevent LiveView from overwriting the hook's DOM modifications.

### Pattern 2: ConfigFormHook Architecture

**What:** A LiveView JS hook that owns the entire config form state client-side.

**Key responsibilities:**
1. Parse schema from `data-schema` on mount
2. Initialize form state from schema defaults (nested structure matching schema hierarchy)
3. Render form HTML dynamically based on schema (OR let server render static structure and just manage values)
4. Track blur state per field for validation timing
5. Handle add/remove list items by updating state and re-rendering the list section
6. On form submit (intercepted), serialize state as JSON and call `pushEvent("submit_config", state)`

**Two sub-approaches for rendering:**

**Option A: Server renders HTML shell, hook manages values and dynamic list items**
- Server renders the card structure, label, input shells
- Hook populates input values from state
- For list fields: hook adds/removes item DOM and manages indexes
- Simpler because most HTML comes from Elixir/HEEx

**Option B: Hook renders all config form HTML from schema JSON**
- Pure client-side rendering of form fields
- More complex but avoids mixed server/client rendering confusion for dynamic lists
- Better for the architecture since add/remove of list items won't fight LiveView patching

**Recommendation: Option A for scalar fields (server-renders), Option B for list items only**

This hybrid keeps the server rendering the static card structure and scalar fields (no LiveView conflict since these don't change). For list fields, the server renders an empty container with `phx-update="ignore"` and the hook fully manages the dynamic list item DOM.

```javascript
// In app.js Hooks object:
ConfigFormHook: {
  mounted() {
    this.schema = JSON.parse(this.el.dataset.schema)
    this.state = this.initState(this.schema)
    this.touched = new Set()

    // Set initial values from defaults
    this.populateScalarInputs()
    // Render initial list items (empty - user adds)
    this.renderAllLists()

    // Listen for add/remove buttons (event delegation)
    this.el.addEventListener("click", (e) => {
      if (e.target.closest("[data-action='add-list-item']")) {
        this.handleAddItem(e.target.closest("[data-action='add-list-item']"))
      }
      if (e.target.closest("[data-action='remove-list-item']")) {
        this.handleRemoveItem(e.target.closest("[data-action='remove-list-item']"))
      }
    })

    // Track blur for validation
    this.el.addEventListener("blur", (e) => {
      if (e.target.name) {
        this.touched.add(e.target.name)
        this.validateField(e.target.name, e.target.value)
      }
    }, true)  // capture phase for blur

    // Intercept form submit
    const form = this.el.closest("form")
    form.addEventListener("submit", (e) => {
      e.preventDefault()
      this.handleSubmit()
    })
  },

  handleSubmit() {
    const errors = this.validateAll(this.state)
    if (Object.keys(errors).length > 0) {
      this.renderErrors(errors)
      return
    }
    this.pushEvent("submit_config", { configuration: this.state })
  },

  initState(schema) {
    // Recursively build state object from schema defaults
    return schema.properties.reduce((acc, {name, definition}) => {
      if (definition.type === "list") {
        acc[name] = []
      } else if (definition.type === "group") {
        acc[name] = this.initState(definition.sub_schema)
      } else {
        acc[name] = definition.default ?? null
      }
      return acc
    }, {})
  }
}
```

### Pattern 3: Submit Handler in InstanceLive.New

**What:** Replace current `"save"` phx-submit handler with a `"submit_config"` pushEvent handler. The standard `phx-submit` still handles the Instance fields (name, description, experiment_module), while config comes via `pushEvent`.

**Two-event approach:**
```elixir
# Option: Single phx-submit with config passed alongside
# phx-submit sends instance fields (name, description, experiment_module)
# A hidden input carries the serialized config JSON OR
# pushEvent("submit_config") sends config separately before submit

# Simpler: use phx-submit normally for Instance fields,
# but intercept submit in hook to merge config state into a hidden input first

# Best: Hook populates a hidden <input type="hidden" name="instance[configuration_json]">
# before letting the form submit proceed normally
# Then handle_event("save", ...) reads configuration_json and decodes it

def handle_event("save", %{"instance" => %{"configuration_json" => json} = params}, socket) do
  config = Jason.decode!(json)
  params = Map.put(params, "configuration", config) |> Map.delete("configuration_json")
  # ... rest of save logic unchanged
end
```

**This approach is simpler than pushEvent because it reuses the existing save handler with minimal change.**

The hook, before allowing form submit, sets a hidden input's value to the JSON-serialized config state, then lets the form submit naturally. The server decodes it.

### Pattern 4: Schema Serialization Helper

**What:** A module-level function in `InstanceLive.New` or a separate `ConfigSchema.to_json/1` function that converts the `ConfigSchema` struct to a JSON-serializable map.

**Why needed:** `ConfigSchema` uses atom keys and list-of-tuples. Jason cannot encode structs without implementing the protocol, and atoms-as-keys need string conversion for JS consumption.

```elixir
# In config_schema.ex or a new ConfigSchema.Serializer module
def to_serializable(%__MODULE__{} = schema) do
  %{
    type: schema.type,
    properties: Enum.map(schema.properties, fn {name, def} ->
      %{name: to_string(name), definition: serialize_field_def(def)}
    end)
  }
end

defp serialize_field_def(%{type: :group, sub_schema: sub_schema} = def) do
  def
  |> Map.put(:sub_schema, to_serializable(sub_schema))
  |> Map.update!(:type, &to_string/1)
end

defp serialize_field_def(%{type: :list, item_schema: item_schema} = def) do
  def
  |> Map.put(:item_schema, to_serializable(item_schema))
  |> Map.update!(:type, &to_string/1)
end

defp serialize_field_def(def) do
  Map.update!(def, :type, &to_string/1)
end
```

Then in LiveView:
```elixir
# In handle_event("select_experiment", ...)
schema_json = schema |> ConfigSchema.to_serializable() |> Jason.encode!()
assign(socket, :config_schema_json, schema_json)
```

### Pattern 5: Collapsible List Items with JS.toggle_class

**What:** Each list item card in the hook-managed DOM has a collapse button. The toggle uses `JS.toggle_class` commands on `phx-click` — but since this is hook-managed DOM, we need client JS for the toggle, not LiveView JS commands.

**Since list item DOM is managed by the hook:** Use plain JavaScript toggle in the hook, not `JS.toggle_class`. The hook owns this DOM.

```javascript
// Inside ConfigFormHook event listener:
if (e.target.closest("[data-action='toggle-item']")) {
  const itemCard = e.target.closest("[data-item-card]")
  const detail = itemCard.querySelector("[data-item-detail]")
  const summary = itemCard.querySelector("[data-item-summary]")
  detail.classList.toggle("hidden")
  summary.classList.toggle("hidden")
}
```

### Pattern 6: daisyUI Card and Fieldset Structure

**What:** Server renders the static card layout (for groups and the overall form wrapper). Hook renders dynamic list items using the same daisyUI classes.

**For groups (server-rendered):**
```heex
<%!-- Source: daisyui.com/components/card/ — verified card/card-body/card-title classes --%>
<div class="card bg-base-200">
  <div class="card-body gap-4">
    <h3 class="card-title text-base">{group_label || humanize(name)}</h3>
    <p :if={group_description} class="text-sm text-base-content/70">{group_description}</p>
    <%!-- Scalar fields rendered by server --%>
  </div>
</div>
```

**For scalar inputs (server-rendered, values set by hook on mount):**
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
      data-field-path={Jason.encode!(path)}
      class="input w-full"
    />
    <%!-- Note: no name= attribute here; hook serializes to JSON on submit --%>
  </label>
  <p class="mt-1 flex gap-2 items-center text-sm text-error hidden" data-error-for={Jason.encode!(path)}>
    <.icon name="hero-exclamation-circle" class="size-5" />
    <span></span>
  </p>
</div>
```

**For list containers (server-rendered, hook manages children):**
```heex
<div
  class="space-y-3"
  data-list-container
  data-list-path={Jason.encode!(path)}
  phx-update="ignore"
>
  <%!-- Hook injects item cards here --%>
</div>
```

**For list item cards (hook-generated JS template):**
```javascript
// Template string in ConfigFormHook
function renderListItemCard(path, index, itemSchema, itemState) {
  return `
    <div class="card bg-base-300 mb-3" data-item-card data-path="${path}" data-index="${index}">
      <div class="card-body p-3 gap-2">
        <div class="flex items-center gap-2">
          <button type="button" class="flex-1 text-left text-sm font-medium"
                  data-action="toggle-item">
            <span data-item-summary class="hidden text-base-content/60">Item ${index + 1}</span>
            <span class="text-base-content/40 text-xs">▾</span>
          </button>
          <button type="button" class="btn btn-ghost btn-xs"
                  data-action="remove-list-item" data-path="${path}" data-index="${index}">
            ✕
          </button>
        </div>
        <div data-item-detail class="space-y-2 pl-6">
          ${renderItemFields(path, index, itemSchema, itemState)}
        </div>
      </div>
    </div>
  `
}
```

### Anti-Patterns to Avoid

- **Using `phx-change` for config fields:** The architecture decision explicitly avoids server state sync. Do NOT add `phx-change` bindings to config inputs.
- **Using `phx-debounce="blur"` + server-side validation:** This is the OLD approach, before the client-side decision. Validation is now client-side (hook tracks touched fields) + server-side on submit only.
- **Using `form-control` class:** Deleted in daisyUI 5. The existing `new.ex` still uses it — replace with `fieldset mb-2` or plain `div`. Use `fieldset` / `label` / `input` classes.
- **Using `@felte/element`:** Marked explicitly unstable, breaking changes between minor versions, no npm setup in project. Do not introduce.
- **Treating config validation like Ecto changeset validation:** Config fields are raw maps. Do NOT use `Phoenix.HTML.FormField`, `to_form`, or `used_input?` for these inputs.
- **Using `phx-update` without "ignore" on hook-managed containers:** LiveView will overwrite the hook's DOM unless the container has `phx-update="ignore"`.
- **Passing schema as nested Elixir assigns:** Pass as JSON string via `data-schema` attribute. The hook needs a flat, string-keyed structure — atom-keyed Elixir maps don't survive the JS boundary.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Config form serialization (scalar fields) | Standard HTML form param encoding | Hidden input with JSON from hook | Standard params can't represent arbitrary nested schema; JSON is cleaner |
| Schema inspection | Custom introspection | `ConfigSchema.to_serializable/1` | One canonical conversion function; reusable |
| Client-side collapse/expand of list items | `Phoenix.LiveView.JS.toggle_class` | Plain JS class toggle inside hook | Hook owns this DOM — LiveView JS commands don't apply to hook-managed elements |
| Blur-based validation UX | Phoenix `phx-debounce="blur"` | Hook's blur capture listener + `touched` Set | Config inputs have no `phx-*` bindings; hook must track blur itself |
| Add/remove list items | `phx-click` LiveView events | Hook event delegation on container | LiveView click events can't carry current form values; hook already has state |

**Key insight:** The schema-driven config form is a mini SPA within the LiveView page. The hook IS the controller. Resist mixing LiveView bindings (`phx-change`, `phx-click`) into the config form section — they conflict with the client-side state management approach.

---

## Common Pitfalls

### Pitfall 1: phx-update="ignore" Scope
**What goes wrong:** `phx-update="ignore"` on the list container prevents LiveView from patching children. But if the experiment changes (user selects different experiment), the ENTIRE form container must be replaced with new schema data.
**Why it happens:** `phx-update="ignore"` is sticky for that element's lifetime.
**How to avoid:** Wrap the config form in a keyed element that gets replaced on experiment change. Use `key={@selected_experiment}` on the outer wrapper, OR the hook listens for a `push_event` from the server with new schema and re-initializes.
**Recommended:** Server uses `push_event(socket, "config_schema_changed", %{schema_json: ...})` which the hook handles in `handleEvent("config_schema_changed", ...)` to reset its state and re-render.

### Pitfall 2: JSON Encoding of ConfigSchema Structs
**What goes wrong:** `Jason.encode!(schema)` fails or produces wrong output because `ConfigSchema` is a struct with atom keys and list-of-tuples for `properties`.
**Why it happens:** Jason encodes structs as maps (dropping keys not in the module), and list-of-tuples are encoded as arrays of arrays `[[name, def], ...]` not objects.
**How to avoid:** Use `ConfigSchema.to_serializable/1` to convert to a plain map with string keys BEFORE passing to Jason. Verify the JS side receives `{properties: [{name: "...", definition: {...}}, ...]}`.
**Warning signs:** JS hook can't find properties, or `schema.properties` is an array of arrays instead of array of objects.

### Pitfall 3: form-control Class in Existing new.ex
**What goes wrong:** Using `class="form-control"` produces no styling (class deleted in daisyUI 5).
**Why it happens:** The existing `new.ex` still uses `form-control` — pre-existing bug. The plan must replace these while extracting to the component.
**How to avoid:** Replace with `fieldset mb-2` or plain `div`, matching `core_components.ex` pattern.

### Pitfall 4: Hidden Input Strategy for Config Submission
**What goes wrong:** Setting a hidden input value to a large JSON string and submitting normally works, but if the JSON string is malformed or the input is missing, `handle_event("save", ...)` crashes on `Jason.decode!/1`.
**Why it happens:** Hook bug or race condition on submit.
**How to avoid:** Use `Jason.decode/1` (not bang) with `{:error, _}` handling in the save handler. Return validation error to the user if JSON is invalid.

### Pitfall 5: Conflict Between Server-Rendered Inputs and Hook State
**What goes wrong:** Server renders `<input value={field_def.default}>` and hook also sets values. After LiveView patches (e.g., on flash update), the server re-renders the input with the default value, losing the user's current input.
**Why it happens:** The config form container is NOT set to `phx-update="ignore"`, so LiveView overwrites it.
**How to avoid:** The ENTIRE config form section (or at minimum, all config inputs) must be inside a container with `phx-update="ignore"`. The hook manages all values there.
**Implication:** The component must render into a `phx-update="ignore"` container. Server only renders the initial state once; hook takes over.

### Pitfall 6: Nested Sub-Schema for List Items
**What goes wrong:** When the schema has `list(:model_pairs, model_pair_schema)`, the hook needs to render inputs for `model_pair_schema`'s fields for each item. If `model_pair_schema` itself contains lists (arbitrary nesting), the hook must recursively render.
**Why it happens:** `ConfigSchema` supports unlimited nesting depth. The hook must handle this recursively.
**How to avoid:** The hook's `renderItemFields` function must recursively call into `renderListItemCard` for nested list fields. Test with SubstrateShift (2 levels) and a hypothetical 3-level schema.

### Pitfall 7: String vs Integer Form Values
**What goes wrong:** All inputs return strings. The hook must coerce values to correct types before serializing to JSON (e.g., `"10"` for an integer field must become `10`).
**Why it happens:** HTML form inputs always produce strings.
**How to avoid:** Hook reads `definition.type` (from schema JSON) and coerces: `parseInt()` for integer, `parseFloat()` for number, `value === "true"` for boolean. Apply at state update time (when input changes), not just at submit.

---

## Code Examples

### ConfigSchema.to_serializable/1 (New Function)
```elixir
# Source: Custom — converting struct to JSON-serializable map
# Add to apps/athanor/lib/experiment/config_schema.ex

def to_serializable(%__MODULE__{} = schema) do
  %{
    "type" => to_string(schema.type),
    "properties" => Enum.map(schema.properties, fn {name, def} ->
      %{"name" => to_string(name), "definition" => serialize_field_def(def)}
    end)
  }
end

defp serialize_field_def(%{type: :group, sub_schema: sub} = def) do
  def
  |> Map.delete(:sub_schema)
  |> Map.put(:type, to_string(def.type))
  |> Map.put(:sub_schema, to_serializable(sub))
  |> stringify_keys()
end

defp serialize_field_def(%{type: :list, item_schema: item} = def) do
  def
  |> Map.delete(:item_schema)
  |> Map.put(:type, to_string(def.type))
  |> Map.put(:item_schema, to_serializable(item))
  |> stringify_keys()
end

defp serialize_field_def(def) do
  def
  |> Map.put(:type, to_string(def.type))
  |> stringify_keys()
end

defp stringify_keys(map) do
  Map.new(map, fn {k, v} ->
    key = if is_atom(k), do: to_string(k), else: k
    val = if is_atom(v) and k != :type, do: to_string(v), else: v
    {key, val}
  end)
end
```

### LiveView: Schema JSON Assignment
```elixir
# Source: Custom — in InstanceLive.New handle_event("select_experiment", ...)
def handle_event("select_experiment", %{"instance" => %{"experiment_module" => module}}, socket) do
  case Discovery.get_config_schema(module) do
    {:ok, schema} ->
      schema_json = schema |> ConfigSchema.to_serializable() |> Jason.encode!()

      {:noreply,
       socket
       |> assign(:selected_experiment, module)
       |> assign(:config_schema, schema)
       |> assign(:config_schema_json, schema_json)}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Could not load experiment configuration")}
  end
end
```

### HEEx: Config Form Container (Hook Target)
```heex
<%!-- Source: Custom — wraps config section with hook and schema data --%>
<div :if={@config_schema} class="space-y-4">
  <div class="divider">Configuration</div>
  <div
    id="config-form-hook"
    phx-hook="ConfigFormHook"
    data-schema={@config_schema_json}
    phx-update="ignore"
  >
    <%!-- All config form rendering is managed by the JS hook --%>
    <%!-- Hidden input for config JSON submission --%>
    <input type="hidden" name="instance[configuration_json]" id="config-json-input" />
  </div>
</div>
```

### ConfigFormHook (Skeleton, in app.js)
```javascript
// Source: Custom — LiveView hook managing config form state
ConfigFormHook: {
  mounted() {
    this.schema = JSON.parse(this.el.dataset.schema)
    this.state = this.initStateFromSchema(this.schema)
    this.touched = new Set()
    this.render()
    this.bindEvents()
  },

  handleEvent(event, payload) {
    if (event === "config_schema_changed") {
      this.schema = JSON.parse(payload.schema_json)
      this.state = this.initStateFromSchema(this.schema)
      this.touched = new Set()
      this.render()
    }
  },

  bindEvents() {
    this.el.addEventListener("click", (e) => {
      const addBtn = e.target.closest("[data-add-list-item]")
      const removeBtn = e.target.closest("[data-remove-list-item]")
      const toggleBtn = e.target.closest("[data-toggle-item]")
      if (addBtn) this.addListItem(addBtn.dataset.addListItem)
      if (removeBtn) this.removeListItem(removeBtn.dataset.removeListItem, parseInt(removeBtn.dataset.index))
      if (toggleBtn) this.toggleItemCollapse(toggleBtn)
    })

    this.el.addEventListener("change", (e) => {
      if (e.target.dataset.fieldPath) {
        const path = JSON.parse(e.target.dataset.fieldPath)
        const type = e.target.dataset.fieldType
        this.updateState(path, this.coerceValue(e.target.value, type))
      }
    })

    this.el.addEventListener("blur", (e) => {
      if (e.target.dataset.fieldPath) {
        this.touched.add(e.target.dataset.fieldPath)
        this.renderErrors()
      }
    }, true)

    // Set hidden input before form submits
    const form = this.el.closest("form")
    if (form) {
      form.addEventListener("submit", (e) => {
        const errors = this.validateAll()
        if (errors.size > 0) {
          e.preventDefault()
          // Mark all as touched and show all errors
          this.touched = new Set(this.getAllFieldPaths())
          this.renderErrors()
          return
        }
        const hiddenInput = document.getElementById("config-json-input")
        if (hiddenInput) hiddenInput.value = JSON.stringify(this.state)
      })
    }
  },

  coerceValue(rawValue, type) {
    if (type === "integer") return parseInt(rawValue, 10) || 0
    if (type === "number") return parseFloat(rawValue) || 0
    if (type === "boolean") return rawValue === "true"
    return rawValue
  },

  initStateFromSchema(schema) {
    return schema.properties.reduce((acc, {name, definition}) => {
      if (definition.type === "list") {
        acc[name] = []
      } else if (definition.type === "group") {
        acc[name] = this.initStateFromSchema(definition.sub_schema)
      } else {
        acc[name] = definition.default ?? null
      }
      return acc
    }, {})
  }
}
```

### InstanceLive.New Save Handler (Updated)
```elixir
# Source: Custom — handle config JSON from hidden input
def handle_event("save", %{"instance" => %{"configuration_json" => json} = params}, socket) do
  config =
    case Jason.decode(json) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{}
    end

  params =
    params
    |> Map.put("configuration", config)
    |> Map.delete("configuration_json")

  case Experiments.create_instance(params) do
    {:ok, instance} ->
      Athanor.Experiments.Broadcasts.instance_created(instance)
      {:noreply,
       socket
       |> put_flash(:info, "Experiment instance created")
       |> push_navigate(to: ~p"/experiments/#{instance.id}")}

    {:error, changeset} ->
      {:noreply, assign(socket, :form, to_form(changeset))}
  end
end
```

### ConfigFormComponent for Scalar Fields (Server-Rendered)
```elixir
# Source: Phoenix.Component pattern — hexdocs.pm/phoenix_live_view/Phoenix.Component.html
defmodule AthanorWeb.Experiments.Components.ConfigFormComponent do
  use Phoenix.Component
  import AthanorWeb.CoreComponents

  attr :schema, :map, required: true   # %ConfigSchema{} struct
  attr :schema_json, :string, required: true  # Jason-encoded for hook

  def config_form(assigns) do
    ~H"""
    <div
      id="config-form-hook"
      phx-hook="ConfigFormHook"
      data-schema={@schema_json}
      phx-update="ignore"
    >
      <input type="hidden" name="instance[configuration_json]" id="config-json-input" />
      <%!-- Hook renders everything dynamically --%>
    </div>
    """
  end
end
```

NOTE: Because of `phx-update="ignore"`, the component renders a skeleton only. The hook does the real rendering. The `@schema` assign (Elixir struct) is not needed for rendering but can be used for server-side validation on submit.

### Validation in InstanceLive.New on Save (Server-Side)
```elixir
# Source: Custom — validate config against schema on save
# Optional but recommended: validate required fields server-side even if hook did client-side

defp validate_config(schema, config) do
  Enum.flat_map(schema.properties, fn {name, field_def} ->
    key = to_string(name)
    value = Map.get(config, key)

    cond do
      Map.get(field_def, :required, false) and (is_nil(value) or value == "") ->
        [{key, "is required"}]
      true ->
        []
    end
  end)
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `phx-debounce="blur"` + server validate | JS hook owns form state, validates client-side | CONTEXT.md architecture decision | Removes server round-trips for every field interaction |
| `form-control` daisyUI class | `fieldset` + `label` components | daisyUI 5 | `form-control` deleted; use `fieldset mb-2` |
| Server manages `list_items` assign | Hook manages list items in JS state | CONTEXT.md architecture decision | Eliminates race conditions between typing and add/remove |
| `phx-click="add_list_item"` handlers | Hook `addListItem()` function | CONTEXT.md architecture decision | No server round-trip for list manipulation |
| `phx-feedback-for` | `used_input?/1` server-side | LiveView 1.0 | Now irrelevant for config fields (hook tracks blur) |

**Deprecated in THIS codebase:**
- `list_items` socket assign in `new.ex`: replaced by hook state
- `add_list_item` / `remove_list_item` event handlers: replaced by hook
- `extract_list_items` / `initialize_list_items` / `parse_configuration` helper functions: replaced by hook serialization
- `form-control` class in `new.ex`: must be replaced with `fieldset mb-2`
- `get_item_schema_for_path/2` helper using `schema.properties[name_atom]` (map access): properties is now a list of tuples, this will crash

**CRITICAL BUG to fix in Plan 02:** `get_item_schema_for_path/2` in `new.ex` uses `schema.properties[name_atom]` — this worked when properties was a `%{}` map but will crash now that properties is a `[]` list. This function will be removed entirely as part of the client-side migration.

---

## Open Questions

1. **Full client-side rendering vs hybrid approach for config form**
   - What we know: `phx-update="ignore"` on hook container prevents LiveView patches; hook can render everything; server can also render static structure initially
   - What's unclear: Which is simpler to implement and maintain?
   - Recommendation: Full client-side rendering by the hook (Option B). Avoids the subtle bugs of mixed server/hook rendering (e.g., server re-renders defaults after patch). The hook receives the schema JSON and renders everything in `mounted()`. Pure and predictable.

2. **Experiment change: push_event vs DOM keying**
   - What we know: When user changes the selected experiment, the schema changes
   - What's unclear: Best way to signal the hook to re-initialize
   - Recommendation: Server calls `push_event(socket, "config_schema_changed", %{schema_json: ...})`. Hook implements `handleEvent("config_schema_changed", ...)` to reset and re-render. This avoids destroying/recreating the hook element (which would require removing `phx-update="ignore"` and adding it back).

3. **Validation depth for Plan 03**
   - What we know: Required field validation must happen client-side (per constraint) AND server-side on save
   - What's unclear: How much validation logic to put in the hook vs server
   - Recommendation: Hook validates required + type constraints (min/max) for UX. Server re-validates required fields on save as a safety check. No need for complex server-side config validation beyond required fields.

---

## Plan Breakdown

### Plan 01 (COMPLETE): ConfigSchema Extension
- Ordered properties, `group/4`, enhanced `field/4`, `:enum` type, `get_property/2`
- Committed: `1afcfe1` (schema), `9ea65f9` (SubstrateShift demo)

### Plan 02 (NOT STARTED): ConfigFormComponent + Scalar Field Rendering
**Scope:**
1. Add `ConfigSchema.to_serializable/1` function
2. Extract rendering into `ConfigFormComponent` module (but now as a hook container, not full server-render)
3. Write `ConfigFormHook` in `app.js` — renders all scalar fields (string, integer, boolean, enum, textarea, url, email) client-side from schema JSON
4. Wire up: LiveView assigns `config_schema_json`, component renders hook container, hook renders fields
5. Fix `form-control` -> `fieldset mb-2` in `new.ex`
6. Update `handle_event("save", ...)` to decode `configuration_json` from hidden input
7. Remove now-dead server-side list management code (`list_items` assign, `add_list_item` / `remove_list_item` / `validate` handlers, `extract_list_items`, `parse_configuration`, `get_item_schema_for_path`)
8. Remove `phx-change="validate"` from form (no longer needed for config)

### Plan 03 (NOT STARTED): List Field Rendering + Collapsible Items + Validation
**Scope:**
1. Extend `ConfigFormHook` to render list containers and list item cards
2. Add/remove list items in hook state, re-render dynamically
3. Collapsible list item cards (plain JS toggle)
4. Blur-tracked validation in hook (required, min/max, enum options check)
5. Error display: red border on input + error text below, cleared on valid blur
6. Up/down reorder buttons for list items (or SortableJS if drag-and-drop chosen)
7. Handle nested schemas in list items (recursive rendering)

---

## Sources

### Primary (HIGH confidence)
- `apps/athanor/lib/experiment/config_schema.ex` — Current (post-Plan-01) ConfigSchema implementation
- `apps/substrate_shift/lib/substrate_shift.ex` — Real schema demonstrating all new features
- `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/new.ex` — Current LiveView (to be slimmed)
- `apps/athanor_web/lib/athanor_web/components/core_components.ex` — `fieldset mb-2`, `input/1`, `error/1` patterns
- `apps/athanor_web/assets/js/app.js` — Current Hooks object (where ConfigFormHook will be added)
- `apps/athanor_web/assets/vendor/` — No vendor JS to add (no SortableJS yet)
- `apps/athanor/lib/athanor/experiments/instance.ex` — `field :configuration, :map` — accepts raw map
- [hexdocs.pm/phoenix_live_view/js-interop.html](https://hexdocs.pm/phoenix_live_view/js-interop.html) — `pushEvent`, hook lifecycle, `phx-update="ignore"`
- [hexdocs.pm/phoenix_live_view/Phoenix.Component.html](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) — Component extraction patterns

### Secondary (MEDIUM confidence)
- [felte.dev/docs/element/getting-started](https://felte.dev/docs/element/getting-started) — Verified `@felte/element` is "not yet stable" (rejected)
- [daisyui.com/components/card/](https://daisyui.com/components/card/) — Card class names
- [daisyui.com/components/fieldset/](https://daisyui.com/components/fieldset/) — Fieldset class names

### Tertiary (LOW confidence)
- WebSearch results for client-side form management patterns — used to confirm no established library is appropriate for this use case

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified in codebase; custom hook approach verified as correct given no npm setup and Felte instability
- Architecture (client-side hook): HIGH — pattern directly follows LiveView js-interop docs; `phx-update="ignore"` well-documented
- Schema serialization: HIGH — Jason already in both apps; `to_serializable/1` pattern is standard Elixir map conversion
- JS hook implementation: MEDIUM — hook structure is standard LiveView hook pattern, but the full rendering logic (recursive schema traversal, validation) requires careful implementation
- daisyUI classes: HIGH — verified in existing `core_components.ex`

**Research date:** 2026-02-17
**Valid until:** 2026-03-17 (stable stack — Phoenix LV 1.1.x and daisyUI 5 are stable; custom hook approach is timeless)
