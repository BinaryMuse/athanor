# Testing Patterns

**Analysis Date:** 2026-02-16

## Test Framework

**Runner:**
- ExUnit (Elixir standard testing framework)
- Config files: `test/test_helper.exs` per app
- Database sandbox mode: `Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)`

**Assertion Library:**
- ExUnit assertions: `assert`, `refute`, `assert_raise`
- Pattern matching for complex assertions

**Run Commands:**
```bash
mix test                    # Run all tests in umbrella
mix test apps/athanor       # Run specific app tests
mix test --watch            # Watch mode (requires mix_test_watch)
mix test --include pending  # Include tagged tests
```

## Test File Organization

**Location:**
- Co-located: `lib/` and `test/` mirror each other by app
- Directory structure matches source: `test/athanor/experiments/instance_test.exs` mirrors `lib/athanor/experiments/instance.ex`
- Support modules in `test/support/` directory

**File Structure by Type:**

**Apps Directory:**
```
apps/athanor/
├── lib/
│   ├── athanor.ex
│   ├── athanor/
│   │   ├── experiments.ex        # Context
│   │   ├── experiments/
│   │   │   ├── instance.ex
│   │   │   ├── run.ex
│   │   │   └── log.ex
│   │   ├── runtime.ex
│   │   └── runtime/
│   │       ├── run_server.ex
│   │       └── run_context.ex
│   └── experiment/
│       └── definition.ex
└── test/
    ├── test_helper.exs
    ├── support/
    │   └── data_case.ex
    └── athanor/
        ├── experiments_test.exs    # Tests for context
        └── runtime_test.exs
```

**Naming:**
- Schema tests: `instance_test.exs` or `run_test.exs`
- Context tests: `experiments_test.exs`
- Support modules use naming: `*_case.ex`
- Test helper: `test_helper.exs`

## Test Case Modules

**Base Case Templates:**
Located at `test/support/`:
- `Athanor.DataCase` - For tests accessing database
- `AthanorWeb.ConnCase` - For web/controller tests

**DataCase (`test/support/data_case.ex`):**
```elixir
defmodule Athanor.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Athanor.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Athanor.DataCase
    end
  end

  setup tags do
    Athanor.DataCase.setup_sandbox(tags)
    :ok
  end
end
```

**Usage:**
```elixir
defmodule Athanor.ExperimentsTest do
  use Athanor.DataCase

  # Has access to Repo, Ecto imports, and sandbox setup
  test "creates instance" do
    {:ok, instance} = Athanor.Experiments.create_instance(%{...})
    assert instance.name == "Test"
  end
end
```

**ConnCase (`test/support/conn_case.ex`):**
```elixir
defmodule AthanorWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint AthanorWeb.Endpoint
      use AthanorWeb, :verified_routes
      import Plug.Conn
      import Phoenix.ConnTest
      import AthanorWeb.ConnCase
    end
  end

  setup tags do
    Athanor.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
```

## Test Structure

**Basic Test Suite:**
```elixir
defmodule Athanor.ExperimentsTest do
  use Athanor.DataCase

  describe "list_instances/0" do
    test "returns all instances" do
      instance1 = create_instance(%{name: "First"})
      instance2 = create_instance(%{name: "Second"})

      assert Athanor.Experiments.list_instances() == [instance1, instance2]
    end
  end

  describe "create_instance/1" do
    test "with valid attrs creates instance" do
      valid_attrs = %{experiment_module: "My.Module", name: "Test"}
      {:ok, instance} = Athanor.Experiments.create_instance(valid_attrs)

      assert instance.name == "Test"
      assert instance.experiment_module == "My.Module"
    end

    test "with invalid attrs returns error changeset" do
      {:error, changeset} = Athanor.Experiments.create_instance(%{})

      assert changeset.errors != %{}
      refute changeset.valid?
    end
  end
end
```

**Patterns:**
- Organize with `describe/2` blocks for grouping related tests
- One assertion per test (or closely related assertions)
- Setup helpers for creating test data: `create_instance(attrs)`
- Test both happy path and error cases

**Error Testing Helper:**
```elixir
defmodule Athanor.DataCase do
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

# Usage in tests
assert "password is too short" in errors_on(changeset).password
```

## Database Sandbox

**Setup Pattern:**
```elixir
setup tags do
  Athanor.DataCase.setup_sandbox(tags)
  :ok
end
```

**How it works:**
- ExUnit starts owner process: `Ecto.Adapters.SQL.Sandbox.start_owner!(Repo, shared: not tags[:async])`
- Automatic rollback after test completes
- Allows async tests with `use Athanor.DataCase, async: true`
- For PostgreSQL: multiple tests can run concurrently

**Disabling Async (when needed):**
```elixir
defmodule MyTest do
  use Athanor.DataCase, async: false

  # Tests run sequentially due to database constraints
end
```

## Test Helpers

**Setup Functions:**
- Define helper functions in test module or case module
- Use meaningful names: `create_instance/1`, `create_run/2`
- Accept attrs parameter to customize: `create_instance(attrs \\ %{})`

**Factory Pattern (Not Used):**
- No dedicated factory library detected
- Helper functions used directly: `create_instance(%{name: "Test"})`
- Minimal setup philosophy

## Coverage

**Requirements:** Not explicitly enforced

**View Coverage:**
```bash
mix test --cover          # If configured
```

**CI/Precommit:**
```bash
mix precommit   # Runs: compile --warnings-as-errors, format, test
```

## Test Types

**Unit Tests:**
- Scope: Individual schema changesets and context functions
- Approach: DataCase with database access
- Example: `Athanor.Experiments` tests for CRUD operations
- File: `test/athanor/experiments_test.exs`

**Schema/Changeset Tests:**
- Validate changeset logic in schema modules
- Test validation rules, constraints
- Example from Instance schema:
```elixir
test "validates experiment module exists" do
  {:error, changeset} = Athanor.Experiments.create_instance(%{
    experiment_module: "NonExistent.Module",
    name: "Test"
  })

  assert "module not found" in errors_on(changeset).experiment_module
end
```

**Controller/Web Tests:**
- Use `AthanorWeb.ConnCase`
- Test request/response, routing, status codes
- Example from `page_controller_test.exs`:
```elixir
defmodule AthanorWeb.PageControllerTest do
  use AthanorWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Peace of mind from prototype to production"
  end
end
```

**Integration Tests:**
- Not separate; use DataCase + business logic
- Combine multiple modules: context + persistence + broadcasting
- Example: Creating a run tests Instance -> Run creation -> PubSub broadcasts

**E2E Tests:**
- Not implemented
- Could use Phoenix test helpers for full flow

## Async Testing

**Configuration:**
```elixir
use Athanor.DataCase, async: true   # Safe for PostgreSQL
use Athanor.DataCase, async: false  # Default, sequential
use AthanorWeb.ConnCase, async: true # Safe for web tests
```

**Considerations:**
- Async requires database support (PostgreSQL recommended)
- Each test gets its own sandbox
- Share keyword in sandbox config: `shared: not tags[:async]`

## Common Patterns

**Testing Changesets:**
```elixir
defmodule Athanor.Experiments.InstanceTest do
  use Athanor.DataCase

  alias Athanor.Experiments.Instance

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Instance.changeset(%Instance{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).experiment_module
    end

    test "validates experiment module" do
      changeset = Instance.changeset(%Instance{}, %{
        experiment_module: "InvalidModule",
        name: "Test"
      })

      refute changeset.valid?
      assert "module not found" in errors_on(changeset).experiment_module
    end
  end
end
```

**Testing Context Functions:**
```elixir
describe "create_instance/1" do
  test "creates and persists instance" do
    attrs = %{experiment_module: "My.Experiment", name: "Test Exp"}

    {:ok, instance} = Athanor.Experiments.create_instance(attrs)

    assert instance.name == "Test Exp"
    assert Athanor.Experiments.get_instance(instance.id) == instance
  end
end
```

**Testing Error Handling:**
```elixir
test "returns error on invalid attrs" do
  {:error, changeset} = Athanor.Experiments.create_instance(%{})

  assert changeset.errors != %{}
  refute changeset.valid?
end
```

**Testing Queries:**
```elixir
test "list_runs returns runs for instance" do
  instance = create_instance()
  run1 = create_run(instance)
  run2 = create_run(instance)

  other_instance = create_instance()
  other_run = create_run(other_instance)

  runs = Athanor.Experiments.list_runs(instance)

  assert length(runs) == 2
  assert run1 in runs
  assert run2 in runs
  refute other_run in runs
end
```

**Testing Supervisor Behavior:**
```elixir
test "starts and monitors run server" do
  {:ok, pid} = Athanor.Runtime.start_run(instance)

  assert is_pid(pid)
  assert Process.alive?(pid)
end
```

## Test Helpers to Create

**Location:** In test modules or `test/support/`:

```elixir
# Helper for creating test instances
defp create_instance(attrs \\ %{}) do
  valid_attrs = %{
    experiment_module: "Test.Experiment",
    name: "Test Instance"
  }

  attrs = Map.merge(valid_attrs, attrs)
  {:ok, instance} = Athanor.Experiments.create_instance(attrs)
  instance
end

# Helper for creating test runs
defp create_run(instance, attrs \\ %{}) do
  {:ok, run} = Athanor.Experiments.create_run(instance, attrs)
  run
end
```

## Doctest

**Usage:**
- Enabled in some modules with `doctest ModuleName`
- Example: `SubstrateShiftTest` includes `doctest SubstrateShift`
- Tests code examples in module documentation
- Rarely used in this codebase; focus is on integration tests

## Test Execution Order

**Default:** Sequential within same test file

**Async:** When tagged with `async: true`, tests run in parallel within sandbox

**Pre-commit Hook:**
```bash
mix precommit  # Runs: compile --warnings-as-errors, format, test
```

---

*Testing analysis: 2026-02-16*
