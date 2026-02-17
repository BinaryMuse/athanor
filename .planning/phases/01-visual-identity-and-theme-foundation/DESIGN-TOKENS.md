# Design Tokens - Athanor Visual System

This document defines the visual design tokens for the Athanor application. All UI components should use these semantic tokens rather than hardcoded values. DaisyUI semantic classes use CSS variables that automatically respond to `data-theme` attribute changes, enabling FOUC-free theme switching.

---

## Typography

### Font Families

- **Base font:** System-ui stack (DaisyUI default) — `font-sans`
  - Used for all body text, labels, headings, navigation
- **Monospace:** For logs, code blocks, experiment results — `font-mono`
  - Stack: `ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, Courier New, monospace`

### Scale

| Token | Class | Use |
|-------|-------|-----|
| Extra small | `text-xs` | Log timestamps, metadata, secondary labels |
| Small | `text-sm` | Body text, list items, form labels |
| Base | `text-base` | Default paragraph text |
| Large | `text-lg` | Card headings, section titles |
| XL | `text-xl` | Page titles |
| 2XL+ | `text-2xl` | Hero/dashboard titles only |

### Line Height

- **`leading-relaxed`** — Use for data-dense displays, log output, results tables
- **`leading-snug`** — Use for compact UI elements like badges, buttons

---

## Spacing

### Section Gaps

| Use | Class |
|-----|-------|
| Between major page sections | `space-y-8` |
| Between related subsections | `space-y-4` |
| Between list items | `space-y-2` |

### Card Padding

| Use | Class |
|-----|-------|
| Standard card padding | `p-4` |
| Main content areas | `p-6` |
| Compact insets (log panels) | `p-3` |

### Inline Gaps (Flexbox/Grid)

| Use | Class |
|-----|-------|
| Tight groups (icon + label) | `gap-2` |
| Related items (buttons, badges) | `gap-4` |
| Between sections in a row | `gap-8` |

---

## Colors

All colors should use DaisyUI semantic classes. These automatically update when the `data-theme` attribute changes on `<html>`.

### Background Layers

| Semantic | Class | Use |
|----------|-------|-----|
| Page background | `bg-base-100` | Root page background |
| Cards, panels | `bg-base-200` | Cards on a `base-100` background |
| Insets, code blocks, log panels | `bg-base-300` | Inset content within cards |

### Text Colors

| Semantic | Class | Use |
|----------|-------|-----|
| Primary text | `text-base-content` | All main readable text |
| Secondary text | `text-base-content/60` | Labels, muted descriptions |
| Tertiary text | `text-base-content/40` | Timestamps, metadata, placeholders |

### Interactive / Status Colors

| Semantic | Class | Use |
|----------|-------|-----|
| Interactive elements | `text-primary` / `bg-primary` | Links, primary action buttons |
| Informational | `text-info` / `bg-info` | Info log level, neutral status |
| Success/OK | `text-success` / `bg-success` | Success state, completed runs |
| Warning | `text-warning` / `bg-warning` | Warning log level, degraded state |
| Error/Failure | `text-error` / `bg-error` | Error log level, failed runs |

### Borders and Dividers

| Semantic | Class | Use |
|----------|-------|-----|
| Border color | `border-neutral` | Dividers, card outlines |
| Neutral background | `bg-neutral` | Subtle separators |

---

## Components

### Cards

```html
<div class="bg-base-200 rounded-box p-4">
  <!-- card content -->
</div>
```

Use `bg-base-200` for cards displayed on a `bg-base-100` page background.

### Inset Panels (Log Output, Code Blocks)

```html
<div class="bg-base-300 rounded-box p-3 font-mono text-xs">
  <!-- log output or code -->
</div>
```

Use `bg-base-300` for content that should appear "inside" a card.

### Status Badges

```html
<span class="badge badge-success">running</span>
<span class="badge badge-error">failed</span>
<span class="badge badge-warning">warning</span>
<span class="badge badge-info">info</span>
```

Use `badge-{status}` for semantic status indicators (run states, log levels).

### Buttons

```html
<!-- Primary action -->
<button class="btn btn-primary">Run Experiment</button>

<!-- Navigation / secondary -->
<button class="btn btn-ghost">Back</button>

<!-- Destructive -->
<button class="btn btn-error">Delete</button>
```

- `btn-primary` — for primary call-to-action (one per screen)
- `btn-ghost` — for navigation, secondary/tertiary actions
- `btn-sm` — for compact contexts (inside table rows, toolbars)

---

## Patterns to AVOID

These patterns break theme switching and must not be used:

| Avoid | Use instead | Why |
|-------|-------------|-----|
| `text-white` | `text-base-content` or `text-primary-content` | Breaks in light theme |
| `text-black` | `text-base-content` | Breaks in dark theme |
| `bg-white` | `bg-base-100` | Hardcoded, not theme-aware |
| `bg-black` | `bg-base-100` | Hardcoded, not theme-aware |
| `text-gray-500` | `text-base-content/60` | Not theme-aware |
| `text-gray-400` | `text-base-content/40` | Not theme-aware |
| `bg-gray-100` | `bg-base-200` | Not theme-aware |
| `bg-gray-800` | `bg-base-200` | Not theme-aware |
| Hardcoded hex/rgb | DaisyUI semantic class | Bypasses theming system |

The rule: if a color class does not contain `base-`, `primary`, `secondary`, `accent`, `neutral`, `info`, `success`, `warning`, or `error`, it is likely hardcoded and will break theme switching.

---

## Theme Architecture

Themes are defined as DaisyUI plugins in `apps/athanor_web/assets/css/app.css`. Two themes are provided:

- **`light`** — Scientific lab dashboard feel: clean off-white background, blue-gray text, teal primary
- **`dark`** — Terminal/IDE inspired: deep blue-gray background, soft white text, bright teal accents

Theme is stored in `localStorage` as `phx:theme` with values `"light"`, `"dark"`, or `"system"`.

The inline `<script>` in `root.html.heex` runs **before** CSS loads to prevent FOUC (Flash of Unstyled Content), reading `localStorage` and setting `data-theme` on `<html>` before the first paint.
