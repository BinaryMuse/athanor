# Codebase Concerns

**Analysis Date:** 2026-02-16

## Documentation Gaps

**Incomplete Project Documentation:**
- Issue: Core modules lack descriptions in their README files
- Files: `/Users/binarymuse/src/ai-reseaerch/athanor_umbrella/apps/athanor/README.md`, `/Users/binarymuse/src/ai-reseaerch/athanor_umbrella/apps/substrate_shift/README.md`
- Impact: New developers cannot understand project purpose or get started; substrate_shift app has template boilerplate instructions
- Fix approach: Write comprehensive README files explaining each app's purpose, how to use it, and key architecture decisions

## Dynamic Atom Conversion

**Unsafe String-to-Atom Conversions:**
- Issue: Multiple places use `String.to_existing_atom()` without sufficient error handling context
- Files:
  - `apps/athanor/lib/athanor/runtime/run_context.ex:28` (creates RunContext)
  - `apps/athanor/lib/athanor/experiments/instance.ex:38` (validation)
  - `apps/athanor/lib/athanor/experiments/discovery.ex:58,75` (discovery)
  - `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/new.ex:403` (form handling)
- Impact: If atom does not exist in Erlang runtime, will raise ArgumentError. Some locations catch this, but `run_context.ex` does not—crashes on malformed instance data
- Risk: Untested code paths could crash experiment execution mid-run
- Fix approach:
  1. Wrap all atom conversions in safe guards with fallback error handling
  2. Consider pre-validating module names at database level
  3. Add tests for malformed module names

## Complex LiveView Component

**Large Monolithic Form Component:**
- Issue: `InstanceLive.New` is 484 lines with 9 function definitions handling form rendering, configuration schema parsing, list item management, and configuration serialization
- Files: `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/new.ex`
- Impact: Difficult to maintain, test, and extend; high cognitive load; nested list handling is error-prone
- Fragility: `get_item_schema_for_path/2` uses broad rescue clause (`_ -> nil`) that silently swallows errors
- Fix approach:
  1. Extract configuration rendering into separate component modules (ConfigFieldRenderer, ListItemManager)
  2. Extract configuration parsing into dedicated Experiments.ConfigParser module
  3. Add comprehensive tests for list item extraction and configuration serialization logic
  4. Replace broad rescue with specific error handling

## Test Coverage Gaps

**Minimal Test Suite:**
- Issue: Only 4 test files found; no tests for core business logic
- Files: Only `substrate_shift_test.exs`, `page_controller_test.exs`, `error_html_test.exs`, `error_json_test.exs`
- Missing tests:
  - Experiments context (list, create, update, delete)
  - Runtime module (start_run, cancel_run, log, result operations)
  - RunServer GenServer behavior (task execution, cancellation, error handling)
  - Instance validation (experiment module validation)
  - Discovery module (module resolution, schema loading)
  - Configuration parsing edge cases (nested objects, lists, type conversions)
- Risk: High risk of regressions; experiment execution bugs may not be caught
- Priority: **HIGH** - Core logic is untested
- Fix approach:
  1. Add tests for `Athanor.Experiments` module CRUD operations
  2. Add tests for `Athanor.Runtime` task execution, cancellation, and error paths
  3. Add tests for `RunServer` GenServer lifecycle (init, handle_continue, info messages)
  4. Add tests for configuration parsing with nested/list scenarios
  5. Set up code coverage tooling (ExCoveralls)

## No Graceful Shutdown/Cleanup

**Task Execution Without Timeout:**
- Issue: `RunServer` spawns `Task.async()` without explicit timeout or timeout handler
- Files: `apps/athanor/lib/athanor/runtime/run_server.ex:60-74`
- Impact:
  - If experiment hangs indefinitely, the task will never complete
  - GenServer will remain in memory indefinitely
  - No mechanism to force-kill hung experiments
  - Web UI shows "running" status that never resolves
- Current behavior: Only handles normal task completion and crashes; no timeout detection
- Fix approach:
  1. Add configurable timeout to Task execution (e.g., 30 min default)
  2. Implement timeout handler in `handle_info/2` to detect missed task completions
  3. Add operator command to forcefully terminate tasks
  4. Store task start time and periodically check elapsed time

## Unsafe Broad Error Handling

**Catch-All Error Handlers:**
- Issue: Multiple locations use broad rescue/catch patterns that hide specific errors
- Files:
  - `apps/athanor/lib/athanor/experiments/instance.ex:51-54` (broad rescue in validation)
  - `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/new.ex:405-407` (broad rescue in schema lookup)
- Impact: Legitimate errors (database failures, permission issues) are silently converted to validation errors
- Risk: Operators cannot debug why operations fail
- Fix approach:
  1. Replace broad `rescue` with specific exception types
  2. Log specific errors for debugging
  3. Return distinct error tuples for different failure modes

## Unchecked Preloading

**Implicit Database Assumptions:**
- Issue: Code assumes relationships are preloaded but doesn't always verify
- Files:
  - `apps/athanor_web/lib/athanor_web/live/experiments/run_live/show.ex:10` (preloads :instance after fetch)
  - `apps/athanor/lib/athanor/runtime/run_context.ex:21` (preloads :instance)
- Impact: If preload fails silently, accessing `run.instance` will raise KeyError
- Risk: Runtime crashes in views when relationships are missing
- Fix approach:
  1. Use Ecto's `Ecto.assoc_loaded?/2` to verify preloads
  2. Add tests that verify association handling
  3. Consider using required associations in schema validation

## Performance Concerns

**N+1 Query Risk:**
- Issue: `Experiments.list_logs/2` in RunLive.Show retrieves all logs for a run into memory without pagination
- Files: `apps/athanor/lib/athanor/experiments.ex:113-126` (list_logs), `apps/athanor_web/lib/athanor_web/live/experiments/run_live/show.ex:16` (calls list_logs)
- Impact: For long-running experiments with thousands of log entries, memory usage grows unbounded; page will be slow to load
- Risk: OOM crashes on experiments with high logging volume
- Fix approach:
  1. Add `limit` parameter with sensible default (e.g., last 1000 logs)
  2. Implement pagination or streaming for logs
  3. Consider pruning old logs after experiment completion
  4. Monitor memory usage in production

**Unbounded Stream Operations:**
- Issue: `Enum.with_index()` used in form rendering loops without bounds checking
- Files: `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/new.ex:128`
- Impact: If user adds hundreds of list items, rendering becomes O(n) expensive
- Risk: Slow UI responsiveness for large configurations
- Fix approach:
  1. Add UI limit for list items (e.g., 100 max)
  2. Implement pagination for list item display
  3. Add client-side validation to prevent adding beyond limit

## Security: Input Validation

**Insufficient Configuration Schema Validation:**
- Issue: Configuration parsing recursively processes nested maps with limited validation
- Files: `apps/athanor_web/lib/athanor_web/live/experiments/instance_live/new.ex:436-463` (parse_configuration)
- Impact:
  - Deeply nested configurations could consume memory/CPU
  - Type conversions are optimistic (string to int)
  - No depth limit on recursion
- Risk: DoS via malicious configuration submission; unexpected type coercion
- Fix approach:
  1. Add schema depth limit validation
  2. Validate all type conversions explicitly
  3. Use Ecto.Changeset for configuration validation
  4. Add rate limiting to instance creation

## Experiment Module Validation Timing

**Runtime Module Loading Risk:**
- Issue: Experiment modules are validated via `Code.ensure_loaded/1` during Instance creation, but the actual module might be unloaded or recompiled between validation and execution
- Files: `apps/athanor/lib/athanor/experiments/instance.ex:40`, `apps/athanor/lib/athanor/runtime/run_server.ex:54-58`
- Impact: Race condition where validated module no longer exists at execution time
- Risk: Experiment starts but crashes immediately with "module not loaded" error
- Fix approach:
  1. Add module re-validation at task start time
  2. Return specific error to user if module unavailable at execution time
  3. Consider caching module metadata instead of reloading

## No API Validation

**Missing Input Sanitization:**
- Issue: No explicit validation of user-supplied experiment module names or configuration data
- Files: `apps/athanor_web/lib/athanor_web/router.ex` (no input validation middleware)
- Impact: Potential for invalid data being stored; no protection against obviously malformed input
- Risk: Garbage data in database; unclear error messages to users
- Fix approach:
  1. Add data validation layer in LiveView event handlers before database operations
  2. Implement plug-based request validation middleware
  3. Add explicit contract validation for configuration JSON

## Missing Run Lifecycle Logging

**Incomplete Event Tracking:**
- Issue: Run state transitions don't log all important events
- Files: `apps/athanor/lib/athanor/runtime/run_server.ex`, `apps/athanor/lib/athanor/runtime.ex`
- Impact: Difficult to audit experiment lifecycle or debug timing issues
- Risk: Cannot track when/why runs enter certain states
- Fix approach:
  1. Log all state transitions (created, started, completed, failed, cancelled)
  2. Include timestamps and metadata in logs
  3. Expose run timeline in UI

## Supervision Strategy

**One-for-One Restart Strategy:**
- Issue: RunSupervisor uses `:one_for_one` strategy meaning failed runs don't cascade
- Files: `apps/athanor/lib/athanor/runtime/run_supervisor.ex:16`
- Current behavior: Acceptable for this use case, but no protection against supervisor crashes
- Context: This is appropriate for independent experiments, no action needed currently
- Monitoring: Watch for repeated task failures in logs

---

*Concerns audit: 2026-02-16*
