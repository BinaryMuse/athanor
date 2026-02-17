# Stack Research

**Domain:** Phoenix LiveView UI polish with DaisyUI — log virtualization, JSON tree views, theme switching
**Researched:** 2026-02-16
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Phoenix | 1.8.3 (already installed) | Web framework | Already in place; 1.8 ships theme toggle, DaisyUI, and Tailwind 4 out of the box |
| Phoenix LiveView | 1.1.x (already installed) | Real-time UI | `phx-viewport-top`/`phx-viewport-bottom` + `stream/3` `:limit` provide native DOM virtualization with zero JS libraries |
| DaisyUI | 5.5.18 (via vendor JS) | Component styling | Already in use via vendor file; v5 is a complete rewrite targeting Tailwind 4, 75% smaller CSS than v4, zero dependencies |
| Tailwind CSS | 4.1 (already installed) | Utility CSS | Already in place; v4 uses CSS variables natively, enabling DaisyUI's `color-mix()` opacity handling |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| json-formatter-js | 2.3.4 (npm) | Collapsible JSON tree view | Whenever structured API response data or experiment config needs to be browsable inline; pure JS, no React dep, DOM-based so trivially wired into a LiveView hook |
| Prism.js | 1.29.0 (npm) | Syntax highlighting for code/JSON | When displaying raw JSON text blocks, model prompt content, or code snippets; supports JSON natively; avoid for tree-view use (use json-formatter-js there instead) |
| phoenix_live_view ColocatedHook | built into LV 1.1 | Collocate JS hooks next to HEEx | Already wired in app.js (`phoenix-colocated/athanor_web`); use for all new per-component hooks to avoid the sprawling `app.js` hooks object |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| esbuild | JS bundling | Already configured in mix.exs; `mix assets.build` invokes it; resolves `phoenix-colocated/*` path from `_build/` |
| mix phx.gen.* | Code generators | Phoenix 1.8 generators produce colocated-hook-aware components by default |

## Installation

```bash
# Add json-formatter-js for JSON tree views (in assets/ directory)
npm install json-formatter-js --prefix assets

# Add Prism.js for syntax highlighting (optional — only if displaying code blocks)
npm install prismjs --prefix assets
```

No additional Hex packages are needed. DaisyUI, Tailwind, LiveView, and theme toggling are already fully installed.

## Theme Switching — Already Implemented

The project already has the Phoenix 1.8 canonical theme toggle implementation:

- `root.html.heex` contains an inline `<script>` that reads `localStorage.getItem("phx:theme")` before page render and sets `data-theme` on `<html>` — this prevents flash of unstyled content (FOUC) on load.
- `layouts.ex` has a `theme_toggle/1` component that dispatches `phx:set-theme` events via `JS.dispatch/2`; the window listener in the inline script handles those events and persists to `localStorage`.
- `app.css` defines `dark` and `light` custom DaisyUI themes via `@plugin "../vendor/daisyui-theme"`.
- The `@custom-variant dark` rule in `app.css` correctly scopes dark-mode styles to `[data-theme=dark]` rather than `prefers-color-scheme`, so the toggle overrides system preferences correctly.

**No work needed on theme switching infrastructure.** The existing implementation is the 2026 standard approach for Phoenix 1.8 + DaisyUI 5.

## Log Virtualization — Use Native LiveView Streams

The correct 2026 approach for displaying thousands of log entries is **native LiveView streams with viewport bindings**, not an external JS virtualization library.

### Pattern

```elixir
# In mount/3 — load only the first N entries
def mount(_params, _session, socket) do
  entries = LogEntries.list_recent(50)
  {:ok, stream(socket, :log_entries, entries)}
end

# In handle_event — load more as user scrolls
def handle_event("next-page", %{"_overran" => true}, socket) do
  {:noreply, stream(socket, :log_entries, [], reset: true) |> then(&load_page(&1, 1))}
end

def handle_event("next-page", _params, socket) do
  {:noreply, stream_insert(socket, :log_entries, next_entries(), at: -1, limit: 150)}
end
```

```heex
<div
  id="log-container"
  phx-update="stream"
  phx-viewport-bottom="next-page"
  class="overflow-y-auto h-full"
>
  <div :for={{id, entry} <- @streams.log_entries} id={id}>
    <!-- log line rendering -->
  </div>
</div>
```

### Key Parameters

- Set stream `:limit` to **3x the per-page count** (e.g., 50 items per page → limit of 150 in DOM). This keeps DOM size bounded while giving the user an infinite-feel scroll.
- Use `phx-viewport-top` for bidirectional scroll (e.g., scrolling back in history).
- Handle `_overran: true` param to reset to page 1 when user jumps far up with scrollbar.
- Apply top/bottom CSS padding equal to 2x viewport height on the container when paginating to prevent scroll position jumps during DOM pruning.

### Why NOT a JS Virtualization Library (react-window, tanstack-virtual, etc.)

LiveView owns the DOM. External JS virtualizers work by taking full control of a scroll container's item rendering, which directly conflicts with LiveView's DOM diffing and patching. Using them together requires elaborate hooks and reconciliation that is fragile and difficult to debug. The native `stream + phx-viewport` approach delegates DOM management to LiveView where it belongs.

## JSON Tree View — json-formatter-js via LiveView Hook

For displaying structured experiment data, API responses, or config objects:

```js
// assets/js/hooks/json_tree.js
import JSONFormatter from "json-formatter-js";

export default {
  mounted() {
    this.render();
  },
  updated() {
    this.el.innerHTML = "";
    this.render();
  },
  render() {
    const data = JSON.parse(this.el.dataset.json);
    const depth = parseInt(this.el.dataset.depth || "2", 10);
    const formatter = new JSONFormatter(data, depth, {
      hoverPreviewEnabled: true,
      theme: document.documentElement.dataset.theme === "dark" ? "dark" : ""
    });
    this.el.appendChild(formatter.render());
  }
};
```

```heex
<div
  id={"json-#{@id}"}
  phx-hook="JsonTree"
  data-json={Jason.encode!(@data)}
  data-depth="2"
  class="font-mono text-sm"
/>
```

Register in `app.js`:
```js
import JsonTree from "./hooks/json_tree"
// Add to Hooks object:
const Hooks = { JsonTree, ...colocatedHooks }
```

### Why json-formatter-js over alternatives

- **Pure JS, no framework dep**: Works directly with LiveView's DOM model; no React/Vue overhead.
- **DOM-based (not virtual)**: `formatter.render()` returns a real DOM node that LiveView can leave alone (since the hook controls the element).
- **Dark theme support**: Has a built-in `theme: "dark"` option that matches DaisyUI theming.
- **Collapse depth control**: `depth` param allows opening only the first N levels, essential for large nested objects.
- **Hover previews**: Shows a summary of collapsed subtrees on hover — important UX for scientific/technical data.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Native stream + phx-viewport | tanstack-virtual / react-window | Only if the project abandons LiveView server-rendering and moves to a full SPA architecture |
| Native stream + phx-viewport | Custom JS IntersectionObserver hook | For fine-grained control beyond what viewport bindings provide (e.g., horizontal virtualization); much more code for similar results |
| json-formatter-js | react-json-tree | If the project adds a React island for interactive data exploration; react-json-tree has better theming ecosystem but requires React |
| json-formatter-js | Custom HEEx recursive component | For server-rendered static JSON views where the user never needs to expand/collapse; simpler, no JS, but no interactivity |
| DaisyUI built-in theme_toggle | phoenix_dark_mode hex package | If the app moves away from DaisyUI; the package provides a standalone dark/class toggle but is redundant here |
| Prism.js (text highlighting) | highlight.js | highlight.js has better auto-detection but heavier default bundle; Prism is more modular and integrates cleanly with LiveView's `updated` hook lifecycle |
| Prism.js (text highlighting) | Shiki | Shiki produces VS Code quality highlighting and is excellent for SSR/static sites; overkill for LiveView where you want lightweight client-side operation |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| react-window / tanstack-virtual | Takes full DOM control, conflicts with LiveView DOM patching; requires React; adds 200-400KB to bundle | `stream/3` + `phx-viewport-bottom` with `:limit` |
| daisy_ui_components hex package (phcurado) | Replaces Phoenix's own CoreComponents; the app already uses the Phoenix 1.8 native DaisyUI integration which is more up-to-date; daisy_ui_components lags behind DaisyUI 5 | Use DaisyUI classes directly in HEEx templates |
| Phoenix LiveDashboard for log display | LiveDashboard is an ops tool, not a UI building block; its log view is not designed for custom styling or large data volumes | Custom LiveView with streams |
| highlight.js (full bundle) | 2.7MB unminified; loads all languages by default | Prism.js with only the JSON/Elixir language components imported |
| localStorage for theme with CSS class toggle (old approach) | Produces FOUC on initial load before JS runs if done only in app.js; Phoenix 1.8's inline `<script>` in `root.html.heex` already solves this correctly | Existing Phoenix 1.8 `phx:set-theme` + `data-theme` pattern (already in place) |
| Alpine.js for theme toggling | Adds a separate reactive framework; the built-in `JS.dispatch` + window event approach is already working with zero additional dependencies | Existing Phoenix 1.8 approach |

## Stack Patterns by Variant

**If log entries have structured metadata (level, timestamp, source):**
- Store entries as a stream where each DOM item includes `data-*` attributes for level/source
- Use DaisyUI badge classes for level indicators directly in the HEEx template
- No JS needed; LiveView handles the DOM updates

**If users need to filter/search logs:**
- Keep a `filter` assign in the socket; on filter change, call `stream(socket, :log_entries, new_filtered_results, reset: true)`
- The stream `:reset` option clears the DOM container before repopulating — correct for search result changes
- Do NOT manage filter state in JS; keep it server-side in the socket assigns

**If JSON payloads are very large (> 1MB):**
- Truncate server-side before encoding to `data-json`; pass a `truncated: true` flag and show a warning
- json-formatter-js can hang the browser rendering objects with hundreds of thousands of keys
- Consider using a server-rendered summary (HEEx) with a "View raw" link to a separate endpoint for the full payload

**If the app needs a split raw/tree toggle on the same data:**
- Use a LiveView `JS.toggle()` to show/hide the raw `<pre>` and tree `<div>` without a server round-trip
- Keep `json-formatter-js` initialized in `mounted()` so it's ready on either view

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| DaisyUI 5.5.x (vendor JS) | Tailwind CSS 4.1 | DaisyUI 5 was rebuilt for Tailwind 4; the two are co-released and tightly coupled. DaisyUI 4.x will NOT work with Tailwind 4. |
| Phoenix 1.8.3 | LiveView 1.1.x | Phoenix 1.8 requires LiveView 1.1+ for ColocatedHook support |
| json-formatter-js 2.3.4 | esbuild | Pure ESM-compatible; works with esbuild without any special config |
| Prism.js 1.29.0 | esbuild | Import individual language files to avoid bundling unused grammar definitions |
| Phoenix stream `:limit` | LiveView 1.0.0+ | `:limit` on `stream_insert/4` requires LiveView 1.0+ but works fully in 1.1 |

## Sources

- [Phoenix 1.8.0 release blog](https://www.phoenixframework.org/blog/phoenix-1-8-released) — Confirmed DaisyUI built-in, theme toggle, and Tailwind 4 integration
- [DaisyUI 5 release notes](https://daisyui.com/docs/v5/) — Version number, breaking changes, Tailwind 4 dependency
- [DaisyUI npm page](https://www.npmjs.com/package/daisyui) — Current version 5.5.18, weekly download stats
- [LiveView 1.1 changelog](https://hexdocs.pm/phoenix_live_view/changelog.html) — ColocatedHook, phx-viewport bindings
- [LiveView bindings docs](https://hexdocs.pm/phoenix_live_view/bindings.html) — `phx-viewport-top`, `phx-viewport-bottom`, `_overran` param
- [Phoenix LiveView 0.19 released](https://www.phoenixframework.org/blog/phoenix-liveview-0.19-released) — Original introduction of viewport bindings and stream limits
- [json-formatter-js GitHub](https://github.com/mohsen1/json-formatter-js) — API, dark theme support, DOM approach
- Existing project code at `apps/athanor_web/lib/athanor_web/components/layouts.ex` and `assets/css/app.css` — Confirmed theme_toggle and DaisyUI theme implementation already in place
- [Elixir Forum TreeView thread (Jan 2025)](https://elixirforum.com/t/any-suggestions-on-a-html-css-js-treeview-that-fits-into-the-liveview-environment/68949) — Community consensus on JS hook approach for tree views

---
*Stack research for: Phoenix LiveView UI polish — log virtualization, JSON tree views, theme switching (DaisyUI)*
*Researched: 2026-02-16*
