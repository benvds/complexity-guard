# CLAUDE.md

## Project

ComplexityGuard -- a Zig-based code complexity analyzer for TypeScript/JavaScript. Single static binary using tree-sitter for parsing. Currently in early development (Phase 1 complete).

## Build & Test

```sh
zig build          # build binary to zig-out/bin/complexity-guard
zig build test     # run all tests
zig build run      # run the binary
```

Requires Zig 0.14.0+. No external dependencies yet.

## Project Structure

```
src/
  main.zig              # entry point, imports all modules for test discovery
  core/types.zig        # core data structures (FunctionResult, FileResult, ProjectResult)
  core/json.zig         # JSON serialization helpers
  test_helpers.zig      # test builders (createTestFunction, createTestFile, etc.)
tests/fixtures/         # real-world TS/JS fixture files for testing
.planning/              # roadmap, requirements, phase plans (do not edit unless asked)
```

## Zig Conventions

- Use `std.testing.allocator` in tests (detects leaks).
- Always `defer` cleanup immediately after allocation: `defer allocator.free(ptr)`.
- Use arena allocators for short-lived scopes; `defer arena.deinit()` at scope start.
- Prefer slices (`[]const u8`) over pointers. Use `?T` for optional fields.
- Use `@as(T, value)` for type coercion in `expectEqual` calls.
- Tests go in the same file as the code they test, below a `// TESTS` comment.
- All test files must be imported in `main.zig` `test {}` block for discovery.
- Use `///` doc comments on public functions and types. Avoid comments on obvious code.
- Struct fields use `snake_case`. Functions use `camelCase`. Types use `PascalCase`.
- Initialize all struct fields explicitly -- Zig has no default field values in non-test code.
- Use the test helpers in `test_helpers.zig` to build test fixtures instead of verbose struct literals.

## Code Patterns

- Core types use `?T` (optionals) for metrics not yet computed (phased implementation).
- JSON serialization uses `std.json.Stringify.valueAlloc` with allocator pattern.
- Test helpers follow options-struct pattern (`TestFunctionOpts`) for builder-style construction.
- File paths in results are relative. Line numbers are 1-indexed. Columns are 0-indexed.
