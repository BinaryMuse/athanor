# Athanor MCP Server

The Athanor MCP (Model Context Protocol) server provides AI agents with tools to interact with the experiment management system.

## Endpoint

The MCP server is available at `/mcp` when the athanor_web application is running.

Example: `http://localhost:4000/mcp`

## Available Tools

### Experiment Management

#### `list_experiments`
List all experiment instances with their statistics.

**Parameters:** None

**Returns:** Array of experiment instances with stats

#### `get_experiment`
Get details for a specific experiment instance.

**Parameters:**
- `id` (required, string): Experiment instance ID

**Returns:** Experiment instance details with statistics

#### `create_experiment`
Create a new experiment instance.

**Parameters:**
- `name` (required, string): Human-readable name for the experiment
- `experiment_module` (required, string): Fully-qualified module name implementing Athanor.Experiment.Schema
- `description` (optional, string): Optional description of the experiment
- `configuration` (optional, map): Configuration parameters as a map (must match the module's schema)

**Returns:** Created experiment instance

#### `update_experiment`
Update an experiment instance's configuration or metadata.

**Parameters:**
- `id` (required, string): Experiment instance ID
- `name` (optional, string): New name for the experiment
- `description` (optional, string): New description
- `configuration` (optional, map): New configuration parameters

**Returns:** Updated experiment instance

### Module Discovery

#### `list_available_modules`
List all available experiment module types that can be instantiated.

**Parameters:** None

**Returns:** Array of available experiment modules with their metadata

#### `get_config_schema`
Get the configuration schema for a specific experiment module.

**Parameters:**
- `experiment_module` (required, string): Fully-qualified module name

**Returns:** Configuration schema for the module

#### `validate_config`
Validate a configuration against an experiment module's schema.

**Parameters:**
- `experiment_module` (required, string): Fully-qualified module name
- `configuration` (required, map): Configuration to validate

**Returns:** Validation result with `valid` boolean and optional `errors` array

### Run Management

#### `list_runs`
List all runs for a specific experiment instance.

**Parameters:**
- `experiment_id` (required, string): Experiment instance ID

**Returns:** Array of runs for the experiment

#### `get_run`
Get details for a specific run.

**Parameters:**
- `id` (required, string): Run ID

**Returns:** Run details

#### `start_run`
Create and start a new run for an experiment instance.

**Parameters:**
- `experiment_id` (required, string): Experiment instance ID

**Returns:** Created and started run

#### `cancel_run`
Cancel a running run.

**Parameters:**
- `id` (required, string): Run ID

**Returns:** Cancelled run details

### Logs and Results

#### `get_run_logs`
Fetch the last N logs from a run, optionally filtered by level.

**Parameters:**
- `run_id` (required, string): Run ID
- `limit` (optional, integer): Maximum number of logs to return (default: 100)
- `level` (optional, string): Filter by log level (debug, info, warn, error)

**Returns:** Array of log entries

#### `list_results`
Query an overview of results for a run.

**Parameters:**
- `run_id` (required, string): Run ID
- `limit` (optional, integer): Maximum number of results to return

**Returns:** Array of result entries

#### `get_result_details`
Get advanced details for a specific result by key.

**Parameters:**
- `run_id` (required, string): Run ID
- `key` (required, string): Result key to lookup

**Returns:** Array of results matching the key (there may be multiple)

## Usage Example

To use the MCP server with an MCP client:

1. Start the athanor_web application: `mix phx.server`
2. Connect your MCP client to `http://localhost:4000/mcp`
3. Use the tools listed above to interact with experiments

## Integration with Phoenix

The MCP server is integrated into the Phoenix application using:

1. **Supervision Tree** (`apps/athanor_web/lib/athanor_web/application.ex`):
   - `Hermes.Server.Registry` - MCP server registry
   - `{AthanorWeb.MCP.Server, transport: :streamable_http}` - MCP server process

2. **Router** (`apps/athanor_web/lib/athanor_web/router.ex`):
   - `forward "/mcp", Hermes.Server.Transport.StreamableHTTP.Plug, server: AthanorWeb.MCP.Server`

## Testing

You can test the MCP server using the Hermes CLI tools:

```bash
# Interactive STDIO session (requires running the server in STDIO mode)
mix hermes.stdio.interactive

# For HTTP, use an MCP client or curl to test the endpoint
curl -X POST http://localhost:4000/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
```

## Error Handling

All tools return appropriate error messages when:
- Required resources (experiments, runs) are not found
- Validation fails
- Operations cannot be completed (e.g., cancelling a non-running run)

Error responses include descriptive messages to help diagnose issues.
