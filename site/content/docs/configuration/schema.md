+++
title = "Configuration Schema"
description = "Define and validate experiment parameters."
weight = 1
template = "docs.html"
+++

The `Experiment.ConfigSchema` module lets you define typed configuration parameters that:

- Generate form fields in the web UI
- Validate user input
- Provide defaults and constraints
- Document expected parameters

## Basic Usage

```elixir
alias Athanor.Experiment.ConfigSchema

defp config_schema do
  ConfigSchema.new()
  |> ConfigSchema.field(:iterations, :integer, default: 10)
  |> ConfigSchema.field(:model, :string, default: "gpt-4")
  |> ConfigSchema.field(:temperature, :float, default: 0.7)
  |> ConfigSchema.field(:verbose, :boolean, default: false)
end
```

## Field Types

### `:integer`

Whole numbers with optional min/max/step constraints.

```elixir
ConfigSchema.field(:count, :integer,
  default: 10,
  min: 1,
  max: 1000,
  step: 1,
  label: "Count",
  description: "Number of items to process"
)
```

### `:float`

Decimal numbers with optional min/max/step constraints.

```elixir
ConfigSchema.field(:temperature, :float,
  default: 0.7,
  min: 0.0,
  max: 2.0,
  step: 0.1,
  label: "Temperature",
  description: "Sampling temperature for the model"
)
```

### `:string`

Text input with optional predefined options.

```elixir
# Free-form text
ConfigSchema.field(:prompt, :string,
  default: "",
  label: "System Prompt"
)

# Dropdown selection
ConfigSchema.field(:model, :string,
  default: "gpt-4",
  options: ["gpt-4", "gpt-3.5-turbo", "claude-3-opus"],
  label: "Model"
)
```

### `:boolean`

Checkbox/toggle field.

```elixir
ConfigSchema.field(:debug_mode, :boolean,
  default: false,
  label: "Debug Mode",
  description: "Enable verbose logging"
)
```

## Field Options

| Option | Type | Description |
|--------|------|-------------|
| `default` | any | Default value if not specified |
| `required` | boolean | Whether the field must have a value |
| `label` | string | Human-readable field label |
| `description` | string | Help text shown in the UI |
| `min` | number | Minimum value (integer/float) |
| `max` | number | Maximum value (integer/float) |
| `step` | number | Increment step (integer/float) |
| `options` | list | Allowed values (string) |

## Complex Types

### `:list`

Repeatable groups of fields.

```elixir
defp config_schema do
  ConfigSchema.new()
  |> ConfigSchema.list(:model_pairs, model_pair_schema(),
    label: "Model Pairs",
    description: "Pairs of models to compare"
  )
end

defp model_pair_schema do
  ConfigSchema.new()
  |> ConfigSchema.field(:model_a, :string, required: true, label: "Model A")
  |> ConfigSchema.field(:model_b, :string, required: true, label: "Model B")
  |> ConfigSchema.field(:runs, :integer, default: 5, min: 1, label: "Runs")
end
```

In the UI, this renders as a repeatable group where users can add/remove pairs.

### `:group`

Nested fields under a single key.

```elixir
ConfigSchema.new()
|> ConfigSchema.group(:api_settings, api_schema(),
  label: "API Settings"
)

defp api_schema do
  ConfigSchema.new()
  |> ConfigSchema.field(:base_url, :string, default: "https://api.example.com")
  |> ConfigSchema.field(:timeout, :integer, default: 30000)
  |> ConfigSchema.field(:retries, :integer, default: 3)
end
```

## Validation

Schemas are validated when creating or updating instances:

```elixir
# Validates against the schema
{:ok, instance} = Athanor.Experiments.create_instance(%{
  experiment_module: "Elixir.MyExperiment",
  name: "Test",
  configuration: %{
    "iterations" => 50,       # Valid: within range
    "model" => "gpt-4"        # Valid: in options
  }
})

# Returns error if validation fails
{:error, changeset} = Athanor.Experiments.create_instance(%{
  experiment_module: "Elixir.MyExperiment",
  name: "Test",
  configuration: %{
    "iterations" => 5000      # Invalid: exceeds max
  }
})
```

## Accessing Configuration

In your `run/1` callback, access config values as a map with string keys:

```elixir
def run(ctx) do
  config = Athanor.Runtime.config(ctx)

  iterations = config["iterations"]        # => 50
  model = config["model"]                  # => "gpt-4"
  pairs = config["model_pairs"]            # => [%{"model_a" => ..., ...}, ...]
  api_url = config["api_settings"]["base_url"]  # => "https://..."
end
```
