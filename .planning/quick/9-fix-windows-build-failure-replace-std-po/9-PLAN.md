---
phase: quick-9
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - src/cli/discovery.zig
  - src/cli/help.zig
autonomous: true
must_haves:
  truths:
    - "Windows cross-compilation succeeds: zig build -Dtarget=x86_64-windows"
    - "Native build and tests still pass: zig build test"
    - "No std.posix.getenv calls remain in production code"
  artifacts:
    - path: "src/cli/discovery.zig"
      provides: "Cross-platform env var access in getConfigHome"
      contains: "std.process.getEnvVarOwned"
    - path: "src/cli/help.zig"
      provides: "Cross-platform env var checks in shouldUseColor"
      contains: "std.process.hasEnvVarConstant"
  key_links:
    - from: "src/cli/discovery.zig"
      to: "std.process"
      via: "getEnvVarOwned replaces std.posix.getenv"
      pattern: "std\\.process\\.getEnvVarOwned"
    - from: "src/cli/help.zig"
      to: "std.process"
      via: "hasEnvVarConstant replaces std.posix.getenv"
      pattern: "std\\.process\\.hasEnvVarConstant"
---

<objective>
Fix Windows cross-compilation build failure caused by std.posix.getenv calls in production code.

Purpose: Enable `zig build -Dtarget=x86_64-windows` to succeed. std.posix.getenv is unavailable on Windows because environment strings use WTF-16 encoding. The Zig compiler suggests std.process.getEnvVarOwned as the cross-platform replacement.
Output: All production code uses cross-platform env var APIs; Windows build compiles cleanly.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@src/cli/discovery.zig
@src/cli/help.zig
</context>

<tasks>

<task type="auto">
  <name>Task 1: Replace std.posix.getenv with cross-platform APIs in discovery.zig and help.zig</name>
  <files>src/cli/discovery.zig, src/cli/help.zig</files>
  <action>
**discovery.zig - getConfigHome function (lines 132-149):**

Replace the three `std.posix.getenv` calls with `std.process.getEnvVarOwned`. This function returns an owned slice (must be freed) and returns `error.EnvironmentVariableNotFound` when the var is not set.

The current function signature already takes an allocator and returns `!?[]const u8`. Rewrite `getConfigHome` to:

1. Try `std.process.getEnvVarOwned(allocator, "XDG_CONFIG_HOME")`. On success, return the owned string directly (caller already frees via the existing contract). On `EnvironmentVariableNotFound`, continue. Let `OutOfMemory` propagate.

2. Try `std.process.getEnvVarOwned(allocator, "HOME")`. On success, join with ".config" (free the intermediate HOME value with defer), return the joined path. On `EnvironmentVariableNotFound`, continue.

3. Try `std.process.getEnvVarOwned(allocator, "APPDATA")`. On success, return owned string. On `EnvironmentVariableNotFound`, continue.

4. Return null.

The key change: `std.posix.getenv` returns a borrowed `?[*:0]const u8` (no free needed), but `std.process.getEnvVarOwned` returns an owned `[]u8` that must be freed. In case 2 (HOME), we get an owned string, use it to build the joined path, then free the intermediate. In cases 1 and 3, we return the owned string directly (caller frees).

Handle the error union with a switch or catch pattern:
```zig
const xdg_config = std.process.getEnvVarOwned(allocator, "XDG_CONFIG_HOME") catch |err| switch (err) {
    error.EnvironmentVariableNotFound => null,
    else => return err,
};
if (xdg_config) |val| return val;
```

Also add `error.InvalidWtf8` to the else branch (it's in the error set on Windows). The simplest approach: use `else => |e| return e` to propagate any non-NotFound error.

**help.zig - shouldUseColor function (lines 62-72):**

Replace the three `std.posix.getenv("NO_COLOR")`, `std.posix.getenv("FORCE_COLOR")`, and `std.posix.getenv("YES_COLOR")` calls with `std.process.hasEnvVarConstant`. This function takes a comptime string and returns bool, works cross-platform, and needs no allocator. It is the perfect fit since shouldUseColor only checks existence, not values.

Replace:
- `if (std.posix.getenv("NO_COLOR")) |_| { return false; }` with `if (std.process.hasEnvVarConstant("NO_COLOR")) return false;`
- `if (std.posix.getenv("FORCE_COLOR")) |_| { return true; }` with `if (std.process.hasEnvVarConstant("FORCE_COLOR")) return true;`
- `if (std.posix.getenv("YES_COLOR")) |_| { return true; }` with `if (std.process.hasEnvVarConstant("YES_COLOR")) return true;`

Note: Do NOT touch `std.posix.chdir` calls in test code (discovery.zig lines 216-217, 252-253 and init.zig lines 198-199, 227-228). These are only compiled for native test builds, not cross-compilation targets, so they do not cause build failures. Fixing them is out of scope for this quick task.
  </action>
  <verify>
1. `zig build -Dtarget=x86_64-windows` succeeds (no compilation errors)
2. `zig build test` passes (native tests still work)
3. Grep confirms no `std.posix.getenv` in production code: `grep -r "std.posix.getenv" src/cli/discovery.zig src/cli/help.zig` returns nothing
  </verify>
  <done>
Windows cross-compilation builds successfully. Native tests pass. All std.posix.getenv calls in production code (discovery.zig getConfigHome, help.zig shouldUseColor) replaced with cross-platform std.process equivalents.
  </done>
</task>

</tasks>

<verification>
- `zig build -Dtarget=x86_64-windows` completes without errors
- `zig build test` passes all existing tests
- No `std.posix.getenv` calls remain in src/cli/discovery.zig or src/cli/help.zig production code
</verification>

<success_criteria>
Windows cross-compilation succeeds and all native tests pass.
</success_criteria>

<output>
After completion, create `.planning/quick/9-fix-windows-build-failure-replace-std-po/9-SUMMARY.md`
</output>
