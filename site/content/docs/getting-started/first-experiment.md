+++
title = "Your First Experiment"
description = "Create and run your first experiment instance."
weight = 2
template = "docs.html"
+++

Once Athanor is running, let's create an experiment instance and execute a run.

## Using the Web Interface

### 1. Create an Instance

1. Navigate to [http://localhost:4000](http://localhost:4000)
2. Click **New Instance**
3. Select an experiment module from the dropdown (try `SubstrateShift` if available)
4. Give your instance a name and optional description
5. Configure the experiment parameters using the form
6. Click **Create Instance**

### 2. Start a Run

From the instance detail page:

1. Click **Start Run**
2. Watch the run execute in real-time
3. View logs as they stream in
4. See results populate as the experiment progresses

### 3. Analyze Results

Once the run completes:

- Review the full log history
- Examine structured results with their keys and values
- Compare with other runs of the same instance

## Using the MCP Server

If you prefer programmatic access, Athanor exposes an MCP server at `/mcp`.

### List Available Experiment Modules

```json
{
  "method": "tools/call",
  "params": {
    "name": "list_available_modules"
  }
}
```

### Create an Instance

```json
{
  "method": "tools/call",
  "params": {
    "name": "create_experiment",
    "arguments": {
      "module": "Elixir.SubstrateShift",
      "name": "My First Instance",
      "configuration": {
        "runs_per_pair": 5,
        "parallelism": 2
      }
    }
  }
}
```

### Start a Run

```json
{
  "method": "tools/call",
  "params": {
    "name": "start_run",
    "arguments": {
      "instance_id": "your-instance-uuid"
    }
  }
}
```

## What's Happening?

When you start a run, Athanor:

1. **Creates a Run record** with status `pending`
2. **Spawns a RunServer** GenServer under the RunSupervisor
3. **Executes the experiment's `run/1` callback** in a monitored Task
4. **Buffers logs and results** in ETS for performance
5. **Flushes to the database** periodically and on completion
6. **Broadcasts updates** via PubSub for real-time UI updates

## Next Steps

- [Understand the core concepts](/docs/concepts/) behind Athanor's architecture
- [Create your own experiment](/docs/creating-experiments/)
