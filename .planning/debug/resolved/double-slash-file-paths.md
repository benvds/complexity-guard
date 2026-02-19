---
status: resolved
trigger: "double-slash-file-paths - File paths in output contain double forward slashes"
created: 2026-02-19T00:00:00Z
updated: 2026-02-19T00:03:00Z
---

## Current Focus

hypothesis: CONFIRMED - When user provides a path with trailing slash (e.g. `tests/fixtures/`), `base_path` ends with `/` and the path construction `"{s}/{s}", .{ base_path, entry.path }` adds another `/`, creating double slashes.
test: Ran `./zig-out/bin/complexity-guard tests/fixtures/` - confirmed `tests/fixtures//typescript/...` output
expecting: Fix by stripping trailing slash from base_path before path construction in walkDirectory
next_action: Fix src/discovery/walker.zig line 143 to strip trailing slashes from base_path

## Symptoms

expected: File paths should have single forward slashes between directories (e.g., `tests/fixtures/javascript/jsx_component.jsx`)
actual: File paths sometimes contain double forward slashes (e.g., `tests/fixtures//javascript/jsx_component.jsx`)
errors: No errors — the paths display incorrectly but the tool runs fine
reproduction: Run complexity-guard on a directory and check the output (any format: console, JSON, HTML). All file paths show this behavior.
started: Likely since the path construction code was written. Affects all output formats (console, JSON, HTML), so the issue is in core path building, not format-specific rendering.

## Eliminated

(none)

## Evidence

- timestamp: 2026-02-19T00:00:30Z
  checked: src/discovery/walker.zig lines 140-143
  found: Path construction is `try std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_path, entry.path })` where `entry.path` is relative to the walked dir (e.g. `javascript/jsx_component.jsx`)
  implication: If base_path ends in `/`, the constructed path will have a double slash

- timestamp: 2026-02-19T00:01:00Z
  checked: Running `./zig-out/bin/complexity-guard tests/fixtures/` (trailing slash)
  found: Output contains `tests/fixtures//typescript/...` - double slash confirmed
  implication: Root cause is the trailing slash in user-provided input is not stripped before path concatenation

## Resolution

root_cause: In src/discovery/walker.zig, the full_path is constructed as `"{s}/{s}", .{ base_path, entry.path }` (line 143). When the user provides a directory path with a trailing slash (e.g. `tests/fixtures/`), `base_path` retains that slash, and concatenating `"/" + entry.path` creates a double slash (`tests/fixtures//javascript/jsx_component.jsx`).
fix: Added `const trimmed_base = std.mem.trimRight(u8, base_path, "/")` before path construction and used `trimmed_base` in the format string and the "." check. `std.mem.trimRight` handles single and multiple trailing slashes.
verification: Verified with `tests/fixtures/` (single trailing slash), `tests/fixtures///` (multiple), and `tests/fixtures` (no slash). All produce clean single-slash paths. All existing tests pass (`zig build test`).
files_changed: [src/discovery/walker.zig]
