# Phase 1: Project Foundation - Research

**Researched:** 2026-02-14
**Domain:** Zig 0.14+ build system, testing infrastructure, and CLI tool development
**Confidence:** MEDIUM-HIGH

## Summary

Zig 0.14+ provides a modern, fast-feedback build system with native testing support, making it well-suited for TDD workflows. The language reached a maturity milestone with version 0.14.0 (released late 2025) introducing incremental compilation, file system watching, and significant performance improvements. Version 0.15.x continues this trajectory with further build optimizations.

The build system uses `build.zig` (executable build script) and `build.zig.zon` (dependency manifest) to create reproducible, cross-platform builds. Zig's testing framework is built-in with `zig test` and `zig build test`, supporting inline test blocks alongside code or separate test files. The standard library provides JSON serialization via `std.json`, arena allocators for simple memory management in CLI tools, and explicit error handling that prevents silent failures.

For this phase, Zig's fast compile times (especially with the native x86/aarch64 backends), single static binary output, and `--watch` mode for continuous rebuilding enable the "tight feedback loop" requirement. The ecosystem conventions favor pragmatic simplicity over framework complexity, aligning well with the foundational phase goals.

**Primary recommendation:** Use Zig 0.14.x or 0.15.x with native backend (default for debug builds), arena allocators for memory management, standard `src/` directory structure, and inline tests during early development transitioning to separate test files as the codebase grows.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Development workflow:**
- TDD red-green-refactor cycle — tests come first, implementation follows
- Fast feedback loops are top priority — build and test must be quick to iterate
- Follow Zig community best practices and conventions throughout

**Test infrastructure:**
- Create tooling for easy generation of test cases (helpers, builders, or scripts to scaffold tests quickly)
- Hand-crafted synthetic examples for unit tests (predictable, focused)
- Real-world TypeScript/JavaScript snippets from open-source projects for integration and validation tests
- Researcher should find good real-world test data sources (complex functions from React, Express, etc.)

### Claude's Discretion

- Project directory layout and module organization
- Core data structure field design and extensibility approach
- Error handling philosophy (fail-fast vs collect-and-continue)
- Build configuration (debug/release profiles)
- CI setup details
- Specific Zig patterns and idioms for the codebase

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope

</user_constraints>

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Zig | 0.14.x or 0.15.x | Language, compiler, build system, test runner | Official toolchain; 0.14+ has incremental compilation, file watching, fast native backends |
| std.json | stdlib | JSON serialization/deserialization | Built-in, zero dependencies, handles structs natively |
| std.testing | stdlib | Test assertions and utilities | Built-in test framework, memory leak detection |
| std.heap.ArenaAllocator | stdlib | Memory management for CLI tools | Bulk allocation/deallocation pattern suits CLI lifecycle |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| std.heap.DebugAllocator | stdlib | Detect memory leaks, double-free, use-after-free | Development/debug builds only |
| std.heap.c_allocator | stdlib | C-style allocator | When SmpAllocator unavailable (requires `-lc`) |
| tree-sitter | External (via build.zig.zon) | Code parsing (future phases) | Not needed in Phase 1, but architect for it |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Zig 0.14/0.15 | Zig 0.13 or earlier | 0.14+ has critical features: incremental compilation, --watch, new package manager. Earlier versions lack fast-feedback tools |
| Native backend | LLVM backend | Native backend faster for debug builds, LLVM better for release optimization. Use native for dev, LLVM for release |
| std.json | External JSON library (getty-zig/json) | std.json sufficient for simple structs; getty provides more control for complex serialization needs |

**Installation:**

```bash
# Install Zig 0.14.x or 0.15.x
# Download from https://ziglang.org/download/
# Or use version manager like zigup

# Initialize new project
zig init

# This creates:
# - build.zig
# - build.zig.zon
# - src/main.zig
# - src/root.zig
```

**Note on versions:** As of February 2026, Zig 0.15.2 is the latest stable release. Zig 0.14.0 was the breakthrough release with incremental compilation. Use 0.14.x minimum, 0.15.x recommended.

## Architecture Patterns

### Recommended Project Structure

```
complexity-guard/
├── build.zig              # Build script (executable Zig code)
├── build.zig.zon          # Dependency manifest (ZON format)
├── .gitignore             # Include zig-cache/, zig-out/, zig-pkg/
├── src/
│   ├── main.zig           # CLI entry point
│   ├── core/              # Core data structures
│   │   ├── file_result.zig
│   │   ├── function_result.zig
│   │   └── project_result.zig
│   ├── json/              # JSON serialization (if needed separately)
│   └── test_helpers/      # Shared test utilities
└── tests/                 # Integration tests (optional; inline tests also valid)
    └── fixtures/          # Real-world test data (TS/JS snippets)
```

**Rationale:**
- `src/` holds all application code (Zig convention from `zig init`)
- Organize by domain (`core/`, `json/`, etc.) rather than technical layer
- `test_helpers/` co-located with code for easy imports
- `tests/fixtures/` for external test data separate from code
- `zig-pkg/` (new in 2026) stores fetched dependencies locally — add to .gitignore

### Pattern 1: Build.zig Structure

**What:** Zig build scripts are executable Zig programs that define a DAG of build steps.

**When to use:** Every Zig project requires `build.zig`.

**Example:**
```zig
// Source: https://ziglang.org/learn/build-system/
const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard options for target and optimization
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Define executable
    const exe = b.addExecutable(.{
        .name = "complexity-guard",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Install artifact
    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    // Test step
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
```

**Key features:**
- `standardTargetOptions` and `standardOptimizeOption` provide CLI flags
- `b.createModule()` replaced older inline config (0.14+ pattern)
- Separate compile and run steps enable concurrent execution
- Test compilation uses same target resolution as main build

### Pattern 2: Inline Tests for TDD

**What:** Test blocks embedded in source files, executed by `zig test`.

**When to use:** Early development, unit testing individual functions, documentation examples.

**Example:**
```zig
// Source: https://zig.guide/getting-started/running-tests/
const std = @import("std");
const expect = std.testing.expect;

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "add function" {
    try expect(add(2, 3) == 5);
    try expect(add(-1, 1) == 0);
}

test "add with allocator for complex setup" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Use allocator for test data setup
    const result = add(10, 20);
    try expect(result == 30);
}
```

**TDD workflow:**
1. Write test describing desired behavior
2. Run `zig test src/module.zig` (fails — red)
3. Implement minimal code to pass
4. Run `zig test src/module.zig` (passes — green)
5. Refactor with confidence

### Pattern 3: Arena Allocator for CLI Tools

**What:** Bulk allocation pattern where all memory is freed at once.

**When to use:** CLI tools with clear lifecycle (start, process, exit). Avoids individual `free()` calls.

**Example:**
```zig
// Source: https://zig.guide/standard-library/allocators/
const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit(); // Free everything at once

    const allocator = arena.allocator();

    // Multiple allocations throughout program
    const data1 = try allocator.alloc(u8, 100);
    const data2 = try allocator.alloc(u8, 200);

    // No individual free() calls needed
    // arena.deinit() cleans up everything
}
```

**Why it works for CLI tools:** Complexity-guard runs, analyzes, outputs JSON, exits. No long-running server lifecycle. Arena suits this pattern perfectly.

### Pattern 4: JSON Serialization with std.json

**What:** Serialize Zig structs to JSON and parse JSON into structs.

**When to use:** Data structure output (FileResult, FunctionResult, ProjectResult).

**Example:**
```zig
// Source: https://zig.guide/standard-library/json/
const std = @import("std");

const FileResult = struct {
    path: []const u8,
    function_count: u32,
    total_lines: u32,
};

pub fn serializeToJson(allocator: std.mem.Allocator, result: FileResult) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try std.json.stringify(result, .{}, buffer.writer());
    return buffer.toOwnedSlice();
}

test "serialize FileResult to JSON" {
    const allocator = std.testing.allocator;

    const result = FileResult{
        .path = "src/main.ts",
        .function_count = 5,
        .total_lines = 120,
    };

    const json_str = try serializeToJson(allocator, result);
    defer allocator.free(json_str);

    try std.testing.expectEqualStrings(
        \\{"path":"src/main.ts","function_count":5,"total_lines":120}
    , json_str);
}
```

**Memory management:** JSON parsing requires allocator; remember to `defer parsed.deinit()`.

### Pattern 5: Error Handling - Fail-Fast (Recommended for Phase 1)

**What:** Propagate errors upward immediately using `try`, handle at top level.

**When to use:** Simple CLI tools, foundational phase. Avoids complexity of error collection.

**Example:**
```zig
// Source: https://zig.guide/language-basics/errors/
const FileError = error{
    NotFound,
    AccessDenied,
    InvalidFormat,
};

pub fn processFile(path: []const u8) FileError!void {
    // Fail fast - propagate error immediately
    try validatePath(path);
    try readFile(path);
    try parseContent();
}

pub fn main() !void {
    processFile("input.ts") catch |err| {
        // Handle all errors at top level
        std.debug.print("Error processing file: {}\n", .{err});
        return err;
    };
}
```

**Alternative - Error Collection Pattern (if needed later):**
```zig
const ErrorList = std.ArrayList(FileError);

pub fn processFiles(allocator: std.mem.Allocator, paths: [][]const u8) !ErrorList {
    var errors = ErrorList.init(allocator);

    for (paths) |path| {
        processFile(path) catch |err| {
            try errors.append(err);
            continue; // Collect error, continue processing
        };
    }

    return errors;
}
```

**Recommendation for Phase 1:** Start with fail-fast. Error collection adds complexity that may not be needed initially.

### Pattern 6: Fast Feedback with --watch

**What:** Continuous rebuild on file changes.

**When to use:** Active development, TDD red-green-refactor cycles.

**Example:**
```bash
# Source: https://ziglang.org/learn/build-system/
# Watch mode - rebuild on file changes
zig build test --watch

# With incremental compilation (faster reanalysis)
zig build test --watch -fincremental

# Custom debounce (wait 500ms after last change)
zig build test --watch --debounce 500
```

**Performance:** Zig 0.14+ with `-fincremental` can reduce reanalysis from 14s to 63ms on large codebases. For small projects, benefits visible immediately.

### Anti-Patterns to Avoid

- **Using `error{Unknown}` everywhere:** Defeats purpose of error unions. Define specific error sets.
- **Manual `free()` calls with ArenaAllocator:** Individual `free()` becomes no-op; use `defer arena.deinit()` instead.
- **Overusing comptime:** Don't treat code generation as a goal. Use comptime only when it simplifies runtime or API.
- **Testing implementation details:** Test behavior, not private functions. Zig test blocks have access to private functions, but that doesn't mean you should test them directly.
- **Git-ignoring zig-out/ but not zig-pkg/:** zig-pkg/ (new in 2026) should be in .gitignore; it's the local dependency cache.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON serialization | Custom JSON writer/parser | `std.json.stringify` / `std.json.parseFromSlice` | Handles edge cases (escaping, Unicode), memory management, type safety |
| Memory leak detection | Manual tracking, custom allocator | `std.testing.allocator` (debug builds) | Built-in leak detection, double-free checks, use-after-free detection |
| Build system / task runner | Makefiles, shell scripts, separate build tool | `build.zig` | Cross-platform, Zig code (type-safe), dependency graph management, caching |
| Test framework | Custom test runner, assertion library | `std.testing` + built-in test runner | Integrated with compiler, automatic test discovery, standard assertions |
| Package management | Git submodules, manual vendoring | `build.zig.zon` + Zig package manager | Content-addressed hashing, reproducible builds, peer-to-peer friendly (future) |
| Command-line argument parsing | String manipulation | Consider external package (future) or simple manual parsing | For Phase 1, CLI is minimal; defer to later phase if complex CLI needed |

**Key insight:** Zig's standard library and build system are designed to eliminate external dependencies for common tasks. If you're tempted to add a dependency or write custom infrastructure, check stdlib first. The ecosystem values "boring" reliability over novelty.

## Common Pitfalls

### Pitfall 1: Version Mismatch (0.13 vs 0.14+ APIs)

**What goes wrong:** Build scripts or code using 0.13 patterns fail on 0.14+. The build API changed significantly.

**Why it happens:** Zig is pre-1.0, breaking changes occur between minor versions. 0.14 introduced module-based build API.

**How to avoid:**
- Use Zig 0.14.0 or later (0.15.x recommended as of Feb 2026)
- Check official release notes when upgrading
- Use `b.createModule()` pattern, not deprecated inline config

**Warning signs:**
- Build errors mentioning `setTheTarget` or `setBuildMode` (old API)
- Documentation or examples referencing Zig 0.11 or 0.12
- Missing `build.zig.zon` file (introduced in 0.11, refined in 0.14+)

### Pitfall 2: Forgetting `defer` for Cleanup

**What goes wrong:** Memory leaks, resource leaks (files not closed).

**Why it happens:** Zig requires explicit cleanup; no garbage collector or RAII (like C++).

**How to avoid:**
- Write `defer arena.deinit()` immediately after `ArenaAllocator.init()`
- Use `std.testing.allocator` in tests to catch leaks
- Use `errdefer` for cleanup on error paths

**Warning signs:**
- `std.testing.allocator` reports memory leaks in test output
- Increasing memory usage during development
- File descriptor exhaustion

**Example:**
```zig
// BAD - no cleanup
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();
// ... use allocator ...
// LEAK: forgot arena.deinit()

// GOOD - cleanup guaranteed
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit(); // Runs at scope exit, even on error
const allocator = arena.allocator();
// ... use allocator ...
```

### Pitfall 3: Numeric Type Confusion

**What goes wrong:** Compile errors about incompatible types (u32 vs usize, i32 vs c_int).

**Why it happens:** Zig requires explicit numeric types; no implicit conversion. Integer widths matter.

**How to avoid:**
- Use `usize` for array indices and sizes (architecture-dependent)
- Use specific widths (u32, i64) when exact size matters (serialization, file formats)
- Explicit cast with `@intCast` when necessary, but understand why it's needed

**Warning signs:**
- Compiler errors: "expected type 'usize', found 'u32'"
- Arithmetic overflow in tests (wrong width for value range)

### Pitfall 4: Misunderstanding Test Execution Context

**What goes wrong:** Tests pass individually but fail in `zig build test`, or vice versa.

**Why it happens:**
- `zig test src/file.zig` runs tests only in that file
- `zig build test` runs all tests defined in build.zig test step
- Test order is not guaranteed; tests must be independent

**How to avoid:**
- Tests should not depend on each other
- Use `std.testing.allocator` to isolate memory
- Avoid global state; pass context explicitly

**Warning signs:**
- Test failures that only occur when running full suite
- Tests work locally but fail in CI
- "Memory leak detected" in some test runs but not others

### Pitfall 5: Build Artifact Location Confusion

**What goes wrong:** Can't find compiled binary, tests fail to find fixtures.

**Why it happens:**
- `zig build` outputs to `zig-out/bin/` by default
- Test runner changes working directory
- Relative paths resolve differently in different contexts

**How to avoid:**
- Use `b.path()` in build.zig for source-relative paths
- Use `b.getInstallPath()` for output-relative paths
- For test fixtures, use `@embedFile()` or pass absolute paths

**Warning signs:**
- "File not found" errors in tests
- Binary runs from command line but not via `zig build run`
- CI failures with "no such file or directory"

### Pitfall 6: Incremental Compilation Instability

**What goes wrong:** Builds fail or produce incorrect results with `-fincremental`.

**Why it happens:** Incremental compilation is beta (as of 0.14/0.15), doesn't support all language features yet.

**How to avoid:**
- Use `-fincremental` for development speed, but test without it before committing
- Report issues to Zig project if reproducible
- Avoid `usingnamespace` (not supported by incremental compilation as of 0.15)

**Warning signs:**
- Build works without `-fincremental`, fails with it
- Changing unrelated file breaks build
- "Incremental compilation not available" warnings

### Pitfall 7: Documentation Staleness

**What goes wrong:** Following outdated tutorial or example leads to compilation errors.

**Why it happens:** Zig is pre-1.0, ecosystem documentation often lags releases. Community content may reference 0.9, 0.10, 0.11.

**How to avoid:**
- Check publication date on tutorials/articles
- Prefer official ziglang.org documentation
- Check Zig version in examples (`zig version` command)
- Verify against release notes: https://ziglang.org/download/0.14.0/release-notes.html

**Warning signs:**
- Code examples don't compile
- API functions mentioned don't exist
- Patterns look very different from official docs

## Code Examples

Verified patterns from official sources:

### Example 1: Minimal build.zig for CLI Tool

```zig
// Source: https://ziglang.org/learn/build-system/
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "complexity-guard",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
        }),
    });

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);
}
```

### Example 2: Test with Memory Leak Detection

```zig
// Source: https://pedropark99.github.io/zig-book/Chapters/03-unittests.html
const std = @import("std");
const testing = std.testing;

test "allocations with leak detection" {
    // std.testing.allocator detects leaks automatically
    const allocator = testing.allocator;

    const data = try allocator.alloc(u8, 100);
    defer allocator.free(data); // If you forget this, test fails

    data[0] = 42;
    try testing.expect(data[0] == 42);
}
```

### Example 3: Error Handling with Try/Catch

```zig
// Source: https://zig.guide/language-basics/errors/
const std = @import("std");

const ParseError = error{
    InvalidSyntax,
    UnexpectedEOF,
};

fn parseInput(input: []const u8) ParseError!u32 {
    if (input.len == 0) return error.UnexpectedEOF;
    if (input[0] == '#') return error.InvalidSyntax;

    return std.fmt.parseInt(u32, input, 10) catch {
        return error.InvalidSyntax;
    };
}

pub fn main() !void {
    const result = parseInput("123") catch |err| {
        std.debug.print("Parse failed: {}\n", .{err});
        return;
    };
    std.debug.print("Parsed: {}\n", .{result});
}
```

### Example 4: Test Helper Pattern

```zig
// Source: Community convention (derived from std.testing patterns)
const std = @import("std");
const testing = std.testing;

// Test helper - build complex test data
fn createTestResult(allocator: std.mem.Allocator, count: u32) !FileResult {
    const path = try std.fmt.allocPrint(allocator, "test_{d}.ts", .{count});
    return FileResult{
        .path = path,
        .function_count = count,
        .total_lines = count * 10,
    };
}

test "helper function for test data" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const result = try createTestResult(allocator, 5);
    try testing.expectEqualStrings("test_5.ts", result.path);
    try testing.expectEqual(@as(u32, 5), result.function_count);
}
```

### Example 5: Build.zig.zon Dependency Example

```zig
// Source: https://github.com/ziglang/zig/blob/master/doc/build.zig.zon.md
.{
    .name = "complexity-guard",
    .version = "0.1.0",
    .fingerprint = 0x1234567890abcdef, // Generated by zig build
    .minimum_zig_version = "0.14.0",

    .dependencies = .{
        // Example dependency (not needed for Phase 1)
        // .tree_sitter = .{
        //     .url = "https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v0.22.0.tar.gz",
        //     .hash = "1220abcd...", // Content hash
        // },
    },

    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
        // LICENSE, README.md if distributing as package
    },
}
```

**Note:** For Phase 1 (foundational), no external dependencies needed. tree-sitter comes in later phases.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Global package cache only | Local `zig-pkg/` + global cache | February 2026 (Zig devlog) | Easier to tinker with dependencies, IDE autocomplete works, self-contained tarballs |
| LLVM backend for all builds | Native x86/aarch64 backend (default debug) | Zig 0.14.0 (late 2025) | Dramatically faster debug builds, faster iteration |
| `exe.setTarget()`, `exe.setBuildMode()` | `b.createModule()` with target/optimize | Zig 0.14.0 | Cleaner API, explicit module boundaries |
| GeneralPurposeAllocator | DebugAllocator (std.heap.debug) | Zig 0.14.0 | 10% faster, 39% fewer cache misses |
| No incremental compilation | `-fincremental` flag | Zig 0.14.0 (beta) | 14s → 63ms reanalysis time on large codebases |
| `@fence` builtin | Stronger atomic orderings | Zig 0.14.0 | Clearer memory synchronization semantics |
| "Managed" container style (ArrayList, HashMap) | Unmanaged style (pass allocator to methods) | Zig 0.14.0 (deprecated old) | Explicit allocator visibility, better control |

**Deprecated/outdated:**
- **Git submodules for dependencies:** Use `build.zig.zon` instead. Submodules mentioned in older articles (pre-0.11).
- **gyro, zigmod package managers:** Obsolete. Official package manager built into Zig 0.11+.
- **`@setAlignStack` builtin:** Replaced by inline `callconv` stack alignment (Zig 0.14.0).
- **Old build API (`setTarget`, `setBuildMode`):** Use `b.createModule()` with target and optimize parameters.

## Real-World Test Data Sources

For integration tests using real TypeScript/JavaScript code:

### Recommended Sources (HIGH confidence)

| Source | Why | How to Use |
|--------|-----|------------|
| [typescript-eslint/typescript-eslint](https://github.com/typescript-eslint/typescript-eslint) | Extensive AST fixture collection, hyper-focused test cases | `/packages/ast-spec/src/*/fixtures/` - organized by AST node type |
| [typescript-eslint/typescript-estree](https://github.com/typescript-eslint/typescript-eslint/tree/main/packages/typescript-estree) | TypeScript → ESTree AST parser with test suite | Real-world TS parsing edge cases, complex type scenarios |
| [facebook/react](https://github.com/facebook/react) | Production TypeScript codebase, complex patterns | `/packages/react/src/` - hooks, reconciler logic, performance-critical code |
| [expressjs/express](https://github.com/expressjs/express) (JavaScript) | Mature Node.js codebase, middleware patterns | Complex callback patterns, error handling, route management |

### Specific Examples to Extract (MEDIUM confidence - requires validation)

**Complex TypeScript patterns to test:**
- React hooks with dependencies: `packages/react/src/ReactHooks.js` (note: some React internals are JS, not TS)
- TypeScript generics and conditional types: typescript-eslint fixtures
- Nested callbacks and promises: Express route handlers
- Class hierarchies and decorators: NestJS source code (if using)

**Fixture organization pattern:**
```
tests/fixtures/
├── typescript/
│   ├── simple/
│   │   ├── function.ts          # Basic function
│   │   └── class.ts             # Simple class
│   ├── complex/
│   │   ├── react-hook.ts        # useState, useEffect
│   │   ├── generics.ts          # Generic constraints
│   │   └── async-patterns.ts    # Promise chains
│   └── edge-cases/
│       ├── deeply-nested.ts     # Callback hell
│       └── template-literal.ts  # Template literal types
└── javascript/
    ├── express-middleware.js
    └── callback-patterns.js
```

### Test Data Collection Script (Recommendation)

Create a helper script to fetch and organize fixtures:

```bash
# tests/fetch-fixtures.sh
#!/usr/bin/env bash

# Fetch typescript-eslint fixtures
git clone --depth=1 --filter=blob:none --sparse \
  https://github.com/typescript-eslint/typescript-eslint.git \
  temp/typescript-eslint

cd temp/typescript-eslint
git sparse-checkout set packages/ast-spec/src/*/fixtures

# Copy relevant fixtures
cp -r packages/ast-spec/src/declaration/FunctionDeclaration/fixtures/*.ts \
  ../../tests/fixtures/typescript/functions/

# Clean up
cd ../..
rm -rf temp/
```

**Run during Phase 1 setup, commit fixtures to repo for reproducible tests.**

## Open Questions

1. **Binary size target (5 MB) with tree-sitter dependency**
   - What we know: ReleaseSmall + --strip achieves 3-5MB for simple Zig programs
   - What's unclear: tree-sitter C library impact on binary size (addressed in future phase)
   - Recommendation: Validate in Phase 2 when integrating tree-sitter. May need custom tree-sitter build or dynamic linking for size target.

2. **CI platform choice (GitHub Actions vs Codeberg/other)**
   - What we know: Zig project moved from GitHub Actions to Codeberg CI in Dec 2025 due to reliability issues
   - What's unclear: Whether GitHub Actions issues affect smaller projects, or only high-volume CI like Zig itself
   - Recommendation: Start with GitHub Actions (most common, easiest integration). If reliability issues occur, evaluate Codeberg Actions or alternatives. The Zig community provides `mlugg/setup-zig` action that works on both platforms.

3. **Error handling strategy evolution**
   - What we know: Fail-fast suits CLI tools and foundational phase. Error collection more complex.
   - What's unclear: At what complexity threshold does error collection become necessary?
   - Recommendation: Start fail-fast. Revisit in Phase 2/3 if processing multiple files. Sign to reconsider: needing to report multiple file errors without stopping.

4. **Test organization: inline vs separate files**
   - What we know: Both patterns valid. Zig stdlib uses inline. Some projects prefer `tests/` directory.
   - What's unclear: Threshold for splitting to separate files.
   - Recommendation: Start inline for TDD velocity. Split when single-file test blocks exceed ~200 lines or when integration tests need external fixtures. Hybrid approach valid (unit tests inline, integration tests in `tests/`).

## Sources

### Primary (HIGH confidence)

- [Zig Build System - Official Documentation](https://ziglang.org/learn/build-system/)
- [Zig 0.14.0 Release Notes](https://ziglang.org/download/0.14.0/release-notes.html)
- [Zig 0.15.1 Release Notes](https://ziglang.org/download/0.15.1/release-notes.html)
- [Zig Language Documentation (0.15.2)](https://ziglang.org/documentation/master/)
- [build.zig.zon Specification](https://github.com/ziglang/zig/blob/master/doc/build.zig.zon.md)
- [JSON - zig.guide](https://zig.guide/standard-library/json/)
- [Errors - zig.guide](https://zig.guide/language-basics/errors/)
- [Allocators - zig.guide](https://zig.guide/standard-library/allocators/)
- [Running Tests - zig.guide](https://zig.guide/getting-started/running-tests/)
- [Zig Devlog February 2026](https://ziglang.org/devlog/2026/) - zig-pkg directory changes

### Secondary (MEDIUM confidence)

- [Introduction to Zig - Unit Tests (Pedro Park)](https://pedropark99.github.io/zig-book/Chapters/03-unittests.html)
- [Zig Package Manager - WTF is Zon](https://zig.news/edyu/zig-package-manager-wtf-is-zon-558e)
- [Zig Bits 0x3: Mastering Project Management](https://blog.orhun.dev/zig-bits-03/)
- [Mitchell Hashimoto - Zig Builds Getting Faster](https://mitchellh.com/writing/zig-builds-getting-faster)
- [10 Zig Build Tricks That Shrink Binaries](https://medium.com/@kaushalsinh73/10-zig-build-tricks-that-shrink-binaries-c9e1476dea54)
- [typescript-eslint AST Spec Fixtures](https://github.com/typescript-eslint/typescript-eslint/tree/main/packages/ast-spec)
- [Zig in Practice: A Senior Engineer's First Pass](https://thelinuxcode.com/zig-in-practice-a-senior-engineers-first-pass/)

### Tertiary (LOW confidence - requires validation)

- [I think Zig is hard...but worth it](https://ratfactor.com/zig/hard) - Subjective learning experience, useful for pitfall awareness
- [GitHub Copilot focus sees Zig move to Codeberg](https://aitoolsbee.com/news/github-copilot-focus-sees-zig-move-to-codeberg-over-actions-issues/) - News article about CI migration
- Medium articles on Zig optimization - Practical tips but not official sources

## Metadata

**Confidence breakdown:**
- **Standard stack:** HIGH - Official toolchain and stdlib, well-documented
- **Architecture patterns:** MEDIUM-HIGH - Official docs + verified community patterns, but 0.14/0.15 API relatively new
- **Pitfalls:** MEDIUM - Derived from community experience, release notes, and common issues on Ziggit forums
- **Test data sources:** MEDIUM - typescript-eslint verified as authoritative source; extraction approach needs validation in practice
- **Build optimization:** HIGH - Official release notes and verified benchmarks

**Research date:** 2026-02-14

**Valid until:** 2026-03-14 (30 days - Zig is pre-1.0 but 0.14/0.15 represent stable milestone)

**Caveats:**
- Zig is pre-1.0; breaking changes possible but less frequent post-0.14
- Incremental compilation is beta; expect refinement in 0.15.x, 0.16.x
- Native backends (x86/aarch64) approaching stability but still evolving
- Tree-sitter integration research deferred to Phase 2 (per phase boundary)
