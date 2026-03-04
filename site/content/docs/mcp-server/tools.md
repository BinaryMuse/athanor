+++
title = "Available Tools"
description = "Complete reference for Athanor's MCP tools."
weight = 1
template = "docs.html"
+++

The MCP server is available at `/mcp` when the web application is running. It provides 15 tools organized into categories.

## Experiment Management

### `list_experiments`

List all experiment instances with their run statistics.

**Parameters:** None

**Returns:**
```json
{
  "experiments": [
    {
      "id": "uuid",
      "name": "My Instance",
      "experiment_module": "Elixir.MyExperiment",
      "description": "...",
      "run_count": 5,
      "last_run_at": "2024-01-15T10:30:00Z"
    }
  ]
}
```

### `get_experiment`

Get detailed information about a specific instance.

**Parameters:**
- `instance_id` (string, required) — The instance UUID

**Returns:**
```json
{
  "id": "uuid",
  "name": "My Instance",
  "experiment_module": "Elixir.MyExperiment",
  "description": "...",
  "configuration": { ... },
  "inserted_at": "...",
  "updated_at": "..."
}
```

### `create_experiment`

Create a new experiment instance.

**Parameters:**
- `module` (string, required) — Fully-qualified module name
- `name` (string, required) — Instance name
- `description` (string, optional) — Instance description
- `configuration` (object, required) — Configuration values

**Returns:**
```json
{
  "id": "uuid",
  "name": "New Instance",
  ...
}
```

### `update_experiment`

Update an existing instance's configuration or metadata.

**Parameters:**
- `instance_id` (string, required) — The instance UUID
- `name` (string, optional) — New name
- `description` (string, optional) — New description
- `configuration` (object, optional) — New configuration values

---

## Module Discovery

### `list_available_modules`

List all discovered experiment modules.

**Parameters:** None

**Returns:**
```json
{
  "modules": [
    {
      "module": "Elixir.MyExperiment",
      "name": "my_experiment",
      "description": "A sample experiment"
    }
  ]
}
```

### `get_config_schema`

Get the configuration schema for a specific module.

**Parameters:**
- `module` (string, required) — Fully-qualified module name

**Returns:**
```json
{
  "schema": {
    "fields": [
      {
        "name": "iterations",
        "type": "integer",
        "default": 10,
        "min": 1,
        "max": 100,
        "label": "Iterations"
      }
    ]
  }
}
```

### `validate_config`

Validate configuration values against a module's schema.

**Parameters:**
- `module` (string, required) — Fully-qualified module name
- `configuration` (object, required) — Configuration to validate

**Returns:**
```json
{
  "valid": true
}
```

Or with errors:
```json
{
  "valid": false,
  "errors": {
    "iterations": ["must be less than or equal to 100"]
  }
}
```

---

## Run Management

### `list_runs`

List all runs for an instance.

**Parameters:**
- `instance_id` (string, required) — The instance UUID
- `status` (string, optional) — Filter by status
- `limit` (integer, optional) — Maximum results (default: 50)

**Returns:**
```json
{
  "runs": [
    {
      "id": "uuid",
      "status": "completed",
      "started_at": "...",
      "completed_at": "...",
      "error": null
    }
  ]
}
```

### `get_run`

Get detailed information about a specific run.

**Parameters:**
- `run_id` (string, required) — The run UUID

**Returns:**
```json
{
  "id": "uuid",
  "instance_id": "uuid",
  "status": "completed",
  "started_at": "...",
  "completed_at": "...",
  "error": null,
  "metadata": { ... }
}
```

### `start_run`

Start a new run for an instance.

**Parameters:**
- `instance_id` (string, required) — The instance UUID

**Returns:**
```json
{
  "id": "uuid",
  "status": "running",
  "started_at": "..."
}
```

### `cancel_run`

Cancel a running experiment.

**Parameters:**
- `run_id` (string, required) — The run UUID

**Returns:**
```json
{
  "id": "uuid",
  "status": "cancelled"
}
```

---

## Logs & Results

### `get_run_logs`

Fetch logs for a run with optional filtering.

**Parameters:**
- `run_id` (string, required) — The run UUID
- `level` (string, optional) — Filter by level (debug, info, warn, error)
- `limit` (integer, optional) — Maximum logs (default: 100)
- `offset` (integer, optional) — Pagination offset

**Returns:**
```json
{
  "logs": [
    {
      "level": "info",
      "message": "Processing started",
      "metadata": null,
      "timestamp": "..."
    }
  ],
  "total": 250
}
```

### `list_results`

Get an overview of results for a run.

**Parameters:**
- `run_id` (string, required) — The run UUID

**Returns:**
```json
{
  "results": [
    {
      "key": "trial_1",
      "inserted_at": "..."
    }
  ],
  "count": 50
}
```

### `get_result_details`

Get the full value for a specific result.

**Parameters:**
- `run_id` (string, required) — The run UUID
- `key` (string, required) — The result key

**Returns:**
```json
{
  "key": "trial_1",
  "value": {
    "input": "...",
    "output": "...",
    "tokens": 150
  },
  "inserted_at": "..."
}
```

---

## Integration

The MCP server uses HTTP-based streamable transport via the Hermes MCP library. Connect using any MCP-compatible client:

```javascript
const client = new MCPClient("http://localhost:4000/mcp");

const experiments = await client.call("list_experiments");
const run = await client.call("start_run", {
  instance_id: experiments[0].id
});
```
