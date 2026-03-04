+++
title = "Interface Overview"
description = "Navigate the Athanor web interface."
weight = 1
template = "docs.html"
+++

The web interface is built with Phoenix LiveView, providing real-time updates without page refreshes.

## Dashboard

The main dashboard at `/experiments` shows all experiment instances:

- **Instance list** — All configured instances with their experiment type
- **Run counts** — How many runs each instance has
- **Quick actions** — Start new runs, view details, edit configuration

## Instance View

Click an instance to see its detail page at `/experiments/:id`:

### Instance Details

- Name and description
- Experiment module
- Current configuration values
- Creation and modification timestamps

### Runs List

All runs for this instance, showing:

- Status badge (pending, running, completed, failed, cancelled)
- Started and completed timestamps
- Duration
- Quick access to logs and results

### Actions

- **Start Run** — Create and start a new run
- **Edit** — Modify instance configuration
- **Delete** — Remove the instance and all its runs

## Run View

View a specific run at `/runs/:id`:

### Status Header

- Current status with visual indicator
- Progress bar (while running)
- Timing information

### Live Logs

Streaming log output with:

- Level filtering (debug, info, warn, error)
- Timestamp display
- Metadata expansion
- Auto-scroll to latest

### Results Panel

Structured results as they're recorded:

- Key-value display
- JSON expansion for complex values
- Sortable by key or timestamp

### Actions

- **Cancel** — Stop a running experiment (respects cancellation checks)

## Creating Instances

The new instance form at `/experiments/new`:

1. **Select Experiment** — Dropdown of discovered experiment modules
2. **Name** — Required identifier for this instance
3. **Description** — Optional notes
4. **Configuration** — Dynamic form generated from the experiment's schema

The form validates against the schema in real-time, showing errors before submission.

## Real-Time Updates

The interface uses Phoenix PubSub for live updates:

- **Run status changes** — Badge updates instantly when runs complete
- **Log streaming** — New logs appear as they're written
- **Progress updates** — Progress bar animates during execution
- **Results** — New results appear without refresh

Multiple browser tabs stay synchronized—start a run in one tab, watch it complete in another.

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `n` | New instance (from dashboard) |
| `r` | Start run (from instance view) |
| `Esc` | Close modals |
