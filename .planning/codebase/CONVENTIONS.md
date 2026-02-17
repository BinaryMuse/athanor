# Coding Conventions

**Analysis Date:** 2026-02-16

## Language

**Primary:** Elixir - Phoenix web framework with LiveView and OTP patterns

## Naming Patterns

**Files:**
- Singular names for modules: `instance.ex`, `run.ex`, `log.ex`
- Directories group related modules: `experiments/`, `runtime/`
- Schema definitions and changesets in the same file as the schema
- Test files: `*.test.exs` or `*_test.exs` suffix

**Modules:**
- Context modules use plural nouns: `Athanor.Experiments`, `Athanor.Runtime`
- Schema modules use singular: `Athanor.Experiments.Instance`, `Athanor.Experiments.Run`
- Public interfaces in context modules follow the domain (e.g., `list_instances`, `get_instance`, `create_instance`)
- Changesets grouped by purpose: `changeset/2`, `start_changeset/1`, `fail_changeset/2`

**Functions:**
- Query functions: `get_*` (single record), `list_*` (multiple records)
- Bang variants: `get_*!` (raises on error) alongside safe variants
- Mutation functions: `create_*`, `update_*`, `delete_*`
- Predicate functions: `cancelled?`, `implements_schema?`
- Changesets: specific variants named by operation, e.g., `start_changeset`, `complete_changeset`

**Variables:**
- Lowercase with underscores: `run_id`, `instance_id`, `experiment_module`
- Pattern matching with meaningful names in function heads
- Single letter bindings only for ignored values: `_`
- Type annotations in module attributes: `@statuses`, `@required_fields`, `@optional_fields`

**Types:**
- Type definitions in @type annotations: `@type t :: %__MODULE__{}`
- Type specs on public function signatures
- Structs use defstruct with atom keys

**Module Attributes:**
- Configuration constants as module attributes: `@pubsub Athanor.PubSub`, `@statuses ~w(pending running completed failed cancelled)`
- Field specifications for schemas: `@required_fields ~w(experiment_module name)a`, `@optional_fields ~w(description configuration)a`

## Code Style

**Formatting:**
- Tool: Phoenix's Elixir formatter (built-in)
- Config file: `.formatter.exs` at project root and per-app
- Format includes: `mix format` command
- Key settings: Respects standard Elixir conventions with plugin support for HTMLFormatter

**Linting:**
- Compiler warnings enforced: `mix compile --warnings-as-errors`
- Pre-commit task includes formatting check
- No dedicated linter tool; relies on Elixir compiler

**Code Organization:**
- Pipe operator heavily used for data transformation
- Private functions marked with `defp` and typically placed after public functions
- Multi-line function definitions indented with 2 spaces
- Pattern matching in function heads preferred over conditionals

## Import Organization

**Pattern in files:**
```elixir
defmodule Athanor.Experiments do
  @moduledoc """..."""

  import Ecto.Query
  alias Athanor.Repo
  alias Athanor.Experiments.{Instance, Run, Result, Log}

  # Public API
  def list_instances do...
end
```

**Order:**
1. Imports (e.g., `import Ecto.Query`)
2. Aliases in order: common external first, then local
3. Module attributes and module docstring before function definitions

**Path Aliases:**
- Full paths used for external libraries: `alias Ecto.Query`
- Local modules with full module path: `alias Athanor.Experiments.{Instance, Run, Result, Log}`
- Short aliases for frequently used modules: `alias Athanor.Repo`

## Error Handling

**Patterns:**
- Return tuples: `{:ok, value}` or `{:error, reason}`
- Database operations return Ecto.Changeset on validation errors
- Validate with `validate_required`, `validate_inclusion`, `validate_change`
- Custom validation functions check conditions and return error list
- Rescue clauses for known exceptions (e.g., `ArgumentError` in string-to-atom conversions)
- Try/catch/rescue in GenServer for catching crashes: see `Athanor.Runtime.RunServer`
- Error messages as atoms when codes (`{:error, :not_running}`) or strings for details

**Example from `Athanor.Experiments.Instance`:**
```elixir
defp check_experiment_module(module_string) do
  module = String.to_existing_atom(module_string)

  case Code.ensure_loaded(module) do
    {:module, ^module} ->
      if function_exported?(module, :experiment, 0) do
        []
      else
        [experiment_module: "module does not implement experiment/0"]
      end

    {:error, _} ->
      [experiment_module: "module not found"]
  end
rescue
  ArgumentError ->
    [experiment_module: "invalid module name"]
end
```

## Logging

**Framework:** Elixir Logger (standard library)

**Patterns:**
- Explicit logging through `Athanor.Runtime` API: `Runtime.log(ctx, :info, "message")`
- Log levels: `:debug`, `:info`, `:warn`, `:error`
- Metadata optional: `Runtime.log(ctx, :warn, "Retrying", %{attempt: 3})`
- Batch logging for efficiency: `Runtime.log_batch(ctx, entries)`
- Level stored as string in database: `level_str = to_string(level)`

## Documentation

**Module Documentation:**
- Every module has `@moduledoc """..."""` describing purpose
- Examples in docstrings for public APIs: see `Athanor.Runtime`
- Sections in docstrings: `## Usage in Experiments`, `## Examples`

**Function Documentation:**
- Public functions documented with `@doc` including examples
- Parameter descriptions using markdown
- Return value documentation
- Example with `##Examples` sections showing typical usage

**Example from `Athanor.Runtime`:**
```elixir
@doc """
Log a message for the current run.

## Examples

    Runtime.log(ctx, :info, "Processing item")
    Runtime.log(ctx, :warn, "Retrying request", %{attempt: 3})
    Runtime.log(ctx, :error, "Failed to connect")
"""
def log(%RunContext{} = ctx, level, message, metadata \\ nil)
```

## Structs and Schemas

**Ecto Schemas:**
- Binary UUID as primary key: `@primary_key {:id, :binary_id, autogenerate: true}`
- Binary IDs for foreign keys: `@foreign_key_type :binary_id`
- Timestamps with microsecond precision: `timestamps(type: :utc_datetime_usec)`
- Associations for relationships: `has_many :runs, Run`, `belongs_to :instance, Instance`

**Plain Structs:**
- Use when not persisted to database: `defstruct [:field1, :field2]`
- Type definitions: `@type t :: %__MODULE__{field1: Type}`
- Constructor function `new()` returns empty struct

**Example from `Athanor.Runtime.RunContext`:**
```elixir
defstruct [:run, :instance, :configuration, :experiment_module]

@type t :: %__MODULE__{
  run: Run.t(),
  instance: Instance.t(),
  configuration: map(),
  experiment_module: atom()
}
```

## Comments

**When to Comment:**
- Explain *why*, not *what* - code should be readable
- Non-obvious algorithm choices or trade-offs
- Section headers for logical groupings: `# --- Instances ---`, `# --- Client API ---`
- Rarely needed given module and function documentation

**Inline Comments:**
- Minimal; prefer clear code
- Use `# comment` format
- Section dividers: `# --- Description ---` to organize related functions

## Module Design

**Exports:**
- Context modules export public functions only (no private details)
- Changesets defined in schema modules for encapsulation
- Helpers and internal functions marked with `defp`
- No barrel files; direct imports of specific modules

**Context Pattern:**
- One context module per domain: `Athanor.Experiments`, `Athanor.Runtime`
- Functions follow CRUD pattern: list, get, get!, create, update, delete
- Specialized changesets: `start_changeset`, `complete_changeset`, `fail_changeset`
- Related schemas grouped in context (Instance, Run, Result, Log all in Experiments)

**Example from `Athanor.Experiments`:**
```elixir
defmodule Athanor.Experiments do
  @moduledoc """
  Context for managing experiments, runs, results, and logs.
  """

  import Ecto.Query
  alias Athanor.Repo
  alias Athanor.Experiments.{Instance, Run, Result, Log}

  # --- Instances ---
  def list_instances do
  def get_instance(id) do
  def get_instance!(id) do
  def create_instance(attrs) do
  # ... etc
end
```

## GenServer Pattern

**Supervision:**
- `use GenServer, restart: :temporary` for processes that shouldn't auto-restart
- Struct for state management: `defstruct [:run, :ctx, :task_ref, :cancelled]`
- `@impl true` annotations on callback implementations
- Via registry for named processes: `{:via, Registry, {Registry.Name, key}}`

**Example from `Athanor.Runtime.RunServer`:**
```elixir
defmodule Athanor.Runtime.RunServer do
  use GenServer, restart: :temporary

  defstruct [:run, :ctx, :task_ref, :cancelled]

  def start_link(args) do
    run = Keyword.fetch!(args, :run)
    GenServer.start_link(__MODULE__, args,
      name: {:via, Registry, {Athanor.Runtime.RunRegistry, run.id}}
    )
  end

  @impl true
  def init(args) do
    # state initialization
  end
end
```

## PubSub Pattern

**Broadcasting:**
- Central module for all broadcasts: `Athanor.Experiments.Broadcasts`
- Specific topics per entity: `"experiments:instances"`, `"experiments:run:#{run_id}"`
- Functions return `:ok` after broadcast
- Multiple topics for different subscribers: specific and aggregate

**Example from `Athanor.Experiments.Broadcasts`:**
```elixir
def instance_updated(instance) do
  PubSub.broadcast(@pubsub, "experiments:instances", {:instance_updated, instance})
  PubSub.broadcast(@pubsub, "experiments:instance:#{instance.id}", {:instance_updated, instance})
end
```

---

*Convention analysis: 2026-02-16*
