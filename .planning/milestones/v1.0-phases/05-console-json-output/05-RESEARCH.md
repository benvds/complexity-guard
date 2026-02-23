# Phase 5: Console & JSON Output - Research

**Researched:** 2026-02-14
**Domain:** Terminal output formatting and JSON serialization for complexity analysis results
**Confidence:** HIGH

## Summary

Phase 5 implements the primary output layer for ComplexityGuard: human-readable console output for developers and machine-readable JSON for CI pipelines. This phase bridges the gap between computed metrics (Phases 1-4) and actionable feedback by displaying results in ESLint-inspired format with threshold indicators, verbosity modes, and proper exit codes.

The console output must handle null metrics gracefully (since cognitive, Halstead, and health scores are not yet computed), use ANSI colors with NO_COLOR support, and provide three verbosity levels (default, verbose, quiet). JSON output follows ESLint's structure with added metadata (version, timestamp, summary).

**Primary recommendation:** Implement ESLint-style file-grouped output with color-coded threshold indicators (checkmark/warning/X symbols), default mode showing only problems, --verbose for all functions, --quiet for errors only. Use Zig's std.io.tty for color detection, std.json for serialization, and follow the exit code convention from CONTEXT.md (0=pass, 1=errors, 2=warnings, 3=config errors, 4=parse errors).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Console formatting:**
- Default view shows only functions exceeding warning/error thresholds (clean functions skipped)
- Threshold indicators use symbols with color: checkmark for ok, warning symbol for warnings, X for errors
- Project summary at end includes: files analyzed, functions found, warning/error counts, pass/fail verdict, plus top 3-5 worst functions by complexity as hotspot highlights
- ESLint-style output layout: results grouped by file path, problem functions indented underneath, summary line at bottom

**User decisions locked in:**
- ESLint-style grouping by file
- Symbol indicators (✓, ⚠, ✗) with color
- Default mode = problems only
- Summary with top worst functions
- Exit code mapping per requirements

### Claude's Discretion

The user directed "Claude's Discretion" for these areas:

**Verbosity mode details:**
- What --verbose adds (all functions with metrics? raw AST info? timing?)
- What --quiet removes (show only errors or suppress all output except exit code?)

**Exit code mapping:**
- Which codes for which conditions (already partially specified in requirements)
- Edge cases (no files found, all files parse failed, etc.)

**JSON schema structure:**
- Field naming conventions (camelCase vs snake_case)
- Metadata placement (top-level vs nested)
- How to structure summary vs detailed results
- How to handle null/future metrics in JSON (include as null, omit entirely, use sentinel values)

**Color detection:**
- NO_COLOR/FORCE_COLOR environment variable support
- --no-color fallback implementation
- TTY detection strategy

**Null/future metrics handling:**
- Console: use `--` placeholder vs omission
- JSON: include null fields vs omit
- What happens when health_score/grade not available yet

### Deferred Ideas (OUT OF SCOPE)

None specified in CONTEXT.md. SARIF and HTML outputs are separate phases (9-10).

</user_constraints>

## Standard Stack

### Core Zig Standard Library

| Module | Purpose | Why Standard |
|--------|---------|--------------|
| std.io.tty | Terminal color detection | Built-in, supports NO_COLOR/YES_COLOR, TTY detection |
| std.json | JSON serialization | Built-in, already used in Phase 1 for types.zig |
| std.fs.File.stdout/stderr | Output streams | Standard Unix convention |
| std.process.exit | Exit code handling | Standard Zig process control |
| std.time | Timestamp generation for JSON | Built-in monotonic/wall clock time |

### ANSI Color Support

Zig's std.io.tty.Config provides:
- TTY detection via `std.io.tty.detectConfig(std.fs.File.stdout())`
- NO_COLOR environment variable support (https://no-color.org/)
- Windows console API detection
- Returns `.no_color`, `.escape_codes`, or `.windows_api`

Already implemented in help.zig (shouldUseColor function) - can reuse pattern.

### JSON Serialization

Already established in Phase 1:
- `std.json.Stringify.valueAlloc()` for serialization
- `serializeResultPretty()` in core/json.zig for human-readable output
- Round-trip tested with FunctionResult, FileResult, ProjectResult

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| std.io.tty | Third-party ansi-escapes.zig | std.io.tty is standard library, sufficient for basic color |
| Direct ANSI codes | ziglibs/ansi_term | More features (styles, RGB), but overkill for simple red/yellow/green |
| std.json | Custom serializer | std.json handles nested structs correctly, no benefit to hand-rolling |
| Hand-rolled exit codes | No alternative | Standard Unix convention, must match CI expectations |

**Installation:**
No additional dependencies needed - all standard library.

## Architecture Patterns

### Recommended Module Structure

```
src/output/
├── console.zig          # Console formatter with ANSI color support
├── json.zig             # JSON output generator (extends core/json.zig)
├── summary.zig          # Summary calculation (top N worst, counts)
└── exit_codes.zig       # Exit code determination logic
```

### Pattern 1: Threshold-Filtered Output

**What:** Iterate through results and filter based on threshold status before display.

**When to use:** Default console mode (show only warnings/errors).

**Example:**
```zig
// Based on cyclomatic.zig ThresholdResult pattern
pub fn displayResults(
    writer: anytype,
    results: []const ThresholdResult,
    config: OutputConfig,
) !void {
    for (results) |result| {
        if (config.verbose or result.status != .ok) {
            try displayFunction(writer, result, config);
        }
    }
}
```

### Pattern 2: Color-Aware Formatting

**What:** Use std.io.tty to detect color support, apply ANSI codes conditionally.

**When to use:** All console output (status indicators, error messages).

**Example:**
```zig
// Based on help.zig shouldUseColor pattern
const Color = enum {
    reset,
    red,
    yellow,
    green,

    fn code(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[0m",
            .red => "\x1b[31m",
            .yellow => "\x1b[33m",
            .green => "\x1b[32m",
        };
    }
};

pub fn colorize(text: []const u8, color: Color, use_color: bool) ![]u8 {
    if (!use_color) return text;
    return try std.fmt.allocPrint(
        allocator,
        "{s}{s}{s}",
        .{ color.code(), text, Color.reset.code() }
    );
}
```

### Pattern 3: JSON Metadata Envelope

**What:** Wrap ProjectResult in metadata envelope with version, timestamp, summary.

**When to use:** --format json output.

**Example:**
```zig
pub const JsonOutput = struct {
    version: []const u8,        // Schema version (e.g., "1.0.0")
    timestamp: i64,              // Unix timestamp (milliseconds)
    summary: Summary,
    results: types.ProjectResult,

    pub const Summary = struct {
        files_analyzed: u32,
        functions_found: u32,
        warnings: u32,
        errors: u32,
        status: []const u8,      // "pass", "warning", "error"
    };
};
```

### Pattern 4: Exit Code Decision Tree

**What:** Centralized logic to determine exit code from results + config.

**When to use:** End of main.zig pipeline.

**Example:**
```zig
pub const ExitCode = enum(u8) {
    success = 0,
    errors_found = 1,
    warnings_found = 2,
    config_error = 3,
    parse_error = 4,
};

pub fn determineExitCode(
    parse_summary: parse.ParseSummary,
    results: []const ThresholdResult,
    config: Config,
) ExitCode {
    // Parse errors take priority
    if (parse_summary.failed_parses > 0) return .parse_error;

    // Count warnings/errors
    var error_count: u32 = 0;
    var warning_count: u32 = 0;
    for (results) |r| {
        if (r.status == .@"error") error_count += 1;
        if (r.status == .warning) warning_count += 1;
    }

    // Check thresholds based on config
    if (error_count > 0) return .errors_found;
    if (warning_count > 0 and config.fail_on_warning) return .warnings_found;

    return .success;
}
```

### Pattern 5: Top-N Hotspot Calculation

**What:** Sort functions by complexity, take top N for summary.

**When to use:** Console summary section.

**Example:**
```zig
pub fn getTopComplexFunctions(
    results: []const ThresholdResult,
    n: usize,
) []const ThresholdResult {
    // Create sorted copy (descending complexity)
    var sorted = std.ArrayList(ThresholdResult).fromSlice(allocator, results);
    defer sorted.deinit();

    std.sort.block(ThresholdResult, sorted.items, {}, compareComplexity);

    // Return top N
    const count = @min(n, sorted.items.len);
    return sorted.items[0..count];
}

fn compareComplexity(_: void, a: ThresholdResult, b: ThresholdResult) bool {
    return a.complexity > b.complexity;  // Descending
}
```

### Anti-Patterns to Avoid

- **Mixing concerns:** Don't put exit code logic in console formatter. Keep output formatting separate from exit code determination.
- **Hard-coded ANSI codes everywhere:** Use centralized color abstraction with feature detection.
- **String building for JSON:** Use std.json.Stringify.valueAlloc, not manual concatenation.
- **Forgetting null metrics:** Phase 5 runs before cognitive/Halstead/health are computed - handle null gracefully.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ANSI color detection | Custom TTY detection | std.io.tty.detectConfig | Handles NO_COLOR, Windows console, TTY detection correctly |
| JSON serialization | String concatenation | std.json.Stringify | Handles escaping, nested structs, null fields |
| Time/timestamp | Manual epoch calculation | std.time.timestamp() | Cross-platform, handles leap seconds |
| String formatting | Buffer management | std.fmt.allocPrint | Memory-safe, handles all types |

## Common Pitfalls

### Pitfall 1: Forgetting Null Metrics

**What goes wrong:** Console crashes when trying to display health_score or cognitive complexity (not computed until later phases).

**Why it happens:** FunctionResult has optional fields (`?u32`, `?f64`) that are null in Phase 5.

**How to avoid:**
- Check for null before displaying: `if (func.cognitive) |val| { ... }`
- Use placeholder in console: `complexity.cognitive orelse "--"`
- In JSON, include null fields explicitly (better for forward compatibility)

**Warning signs:** Crashes when trying to display results, missing fields in JSON.

### Pitfall 2: Wrong Exit Code Priority

**What goes wrong:** Returning success (0) when config file is invalid, or returning config error when parse actually failed.

**Why it happens:** Not checking errors in priority order.

**How to avoid:** Decision tree order from CONTEXT.md:
1. Config errors (exit 3) - checked during config load
2. Parse errors (exit 4) - checked after parsing
3. Metric errors (exit 1) - checked after analysis
4. Warnings (exit 2) - only if --fail-on warning
5. Success (exit 0)

**Warning signs:** CI pipeline doesn't fail when it should, wrong error messages.

### Pitfall 3: Color in Pipes/Redirects

**What goes wrong:** ANSI codes appear as garbage when output piped to file or grep.

**Why it happens:** Not detecting non-TTY output.

**How to avoid:**
- Use std.io.tty.detectConfig(stdout) before applying color
- Respect NO_COLOR environment variable
- Provide --no-color override

**Warning signs:** Users complain about escape codes in log files.

### Pitfall 4: ESLint Output Misalignment

**What goes wrong:** Output doesn't match ESLint style (file grouping, indentation, summary format).

**Why it happens:** Not studying ESLint's actual output format.

**How to avoid:**
```
src/file.ts
  12:4  error    Function 'foo' has complexity 25 (max: 20)  cyclomatic
  45:2  warning  Function 'bar' has complexity 12 (max: 10)  cyclomatic

✖ 2 problems (1 error, 1 warning)
```

- File path on separate line (no indentation)
- Functions indented 2 spaces
- Line:column format (1-indexed line, 0-indexed column)
- Threshold indicator and rule name at end
- Summary uses checkmark/X symbols

**Warning signs:** Users expect ESLint format but see something different.

### Pitfall 5: Verbose/Quiet Ambiguity

**What goes wrong:** --quiet still shows warnings, or --verbose floods with useless info.

**Why it happens:** Not defining clear levels.

**How to avoid:** Define concrete behavior:
- **Default:** Show files with problems, problem functions only, summary
- **--verbose:** Show ALL files, ALL functions (even complexity 1), timing info, config used
- **--quiet:** Show ONLY errors (suppress warnings), no summary, just exit code

**Warning signs:** Users confused about what each mode does.

## Code Examples

### Console Output with Color Detection

```zig
// Based on help.zig shouldUseColor and std.io.tty pattern
const std = @import("std");

pub const ConsoleFormatter = struct {
    use_color: bool,
    verbose: bool,
    quiet: bool,

    pub fn init(force_color: bool, no_color: bool, verbose: bool, quiet: bool) ConsoleFormatter {
        return .{
            .use_color = shouldUseColor(force_color, no_color),
            .verbose = verbose,
            .quiet = quiet,
        };
    }

    pub fn displayResults(
        self: ConsoleFormatter,
        writer: anytype,
        file_path: []const u8,
        results: []const cyclomatic.ThresholdResult,
    ) !void {
        var has_problems = false;
        for (results) |r| {
            if (r.status != .ok) has_problems = true;
        }

        // Skip file if no problems and not verbose
        if (!self.verbose and !has_problems) return;

        // File header
        try writer.print("{s}\n", .{file_path});

        // Function results
        for (results) |r| {
            if (self.quiet and r.status != .@"error") continue;
            if (!self.verbose and r.status == .ok) continue;

            try self.displayFunction(writer, r);
        }
    }

    fn displayFunction(
        self: ConsoleFormatter,
        writer: anytype,
        result: cyclomatic.ThresholdResult,
    ) !void {
        const symbol = switch (result.status) {
            .ok => "✓",
            .warning => "⚠",
            .@"error" => "✗",
        };

        const color = switch (result.status) {
            .ok => Color.green,
            .warning => Color.yellow,
            .@"error" => Color.red,
        };

        const symbol_colored = if (self.use_color)
            try std.fmt.allocPrint(
                writer.context.allocator,
                "{s}{s}{s}",
                .{ color.code(), symbol, Color.reset.code() },
            )
        else
            symbol;

        try writer.print("  {d}:{d}  {s}  Function '{s}' has complexity {d}\n", .{
            result.start_line,
            result.start_col,
            symbol_colored,
            result.function_name,
            result.complexity,
        });
    }
};
```

### JSON Output with Metadata

```zig
// Extends core/json.zig pattern
const std = @import("std");
const types = @import("../core/types.zig");

pub const JsonOutputEnvelope = struct {
    version: []const u8,
    timestamp: i64,
    summary: Summary,
    files: []const FileResultJson,

    pub const Summary = struct {
        files_analyzed: u32,
        total_functions: u32,
        total_lines: u32,
        warnings: u32,
        errors: u32,
        status: []const u8,  // "pass", "warning", "error"
    };

    pub const FileResultJson = struct {
        path: []const u8,
        functions: []const FunctionResultJson,
    };

    pub const FunctionResultJson = struct {
        name: []const u8,
        start_line: u32,
        end_line: u32,
        start_col: u32,
        cyclomatic: ?u32,
        cognitive: ?u32,      // null in Phase 5
        nesting_depth: u32,
        line_count: u32,
        params_count: u32,
        status: []const u8,   // "ok", "warning", "error"
    };
};

pub fn buildJsonOutput(
    allocator: std.mem.Allocator,
    project_result: types.ProjectResult,
    threshold_results: []const cyclomatic.ThresholdResult,
) !JsonOutputEnvelope {
    var warnings: u32 = 0;
    var errors: u32 = 0;
    for (threshold_results) |r| {
        if (r.status == .warning) warnings += 1;
        if (r.status == .@"error") errors += 1;
    }

    const status = if (errors > 0)
        "error"
    else if (warnings > 0)
        "warning"
    else
        "pass";

    return JsonOutputEnvelope{
        .version = "1.0.0",  // Schema version
        .timestamp = std.time.timestamp(),
        .summary = .{
            .files_analyzed = project_result.files_analyzed,
            .total_functions = project_result.total_functions,
            .total_lines = project_result.total_lines,
            .warnings = warnings,
            .errors = errors,
            .status = status,
        },
        .files = try convertFiles(allocator, project_result.files, threshold_results),
    };
}
```

### Exit Code Decision Tree

```zig
// exit_codes.zig pattern
const std = @import("std");
const parse = @import("../parser/parse.zig");
const cyclomatic = @import("../metrics/cyclomatic.zig");
const config_mod = @import("../cli/config.zig");

pub const ExitCode = enum(u8) {
    success = 0,
    errors_found = 1,
    warnings_found = 2,
    config_error = 3,
    parse_error = 4,

    pub fn toInt(self: ExitCode) u8 {
        return @intFromEnum(self);
    }
};

pub fn determineExitCode(
    parse_summary: parse.ParseSummary,
    threshold_results: []const cyclomatic.ThresholdResult,
    fail_on: []const u8,  // "warning", "error", "none"
) ExitCode {
    // Parse errors take priority (checked in main.zig during parsing)
    if (parse_summary.failed_parses > 0) {
        return .parse_error;
    }

    // Count threshold violations
    var error_count: u32 = 0;
    var warning_count: u32 = 0;

    for (threshold_results) |r| {
        switch (r.status) {
            .@"error" => error_count += 1,
            .warning => warning_count += 1,
            .ok => {},
        }
    }

    // Check based on fail_on policy
    if (error_count > 0) {
        return .errors_found;
    }

    if (warning_count > 0 and std.mem.eql(u8, fail_on, "warning")) {
        return .warnings_found;
    }

    return .success;
}
```

### Summary with Top N Worst Functions

```zig
// summary.zig pattern
pub fn displaySummary(
    writer: anytype,
    file_count: u32,
    function_count: u32,
    warnings: u32,
    errors: u32,
    threshold_results: []const cyclomatic.ThresholdResult,
    use_color: bool,
) !void {
    try writer.print("\n{d} files analyzed, {d} functions found\n", .{
        file_count,
        function_count,
    });

    if (errors > 0 or warnings > 0) {
        try writer.print("{d} errors, {d} warnings\n", .{ errors, warnings });
    }

    // Top 5 most complex functions
    const top_n = getTopComplexFunctions(threshold_results, 5);
    if (top_n.len > 0) {
        try writer.writeAll("\nTop complexity hotspots:\n");
        for (top_n, 1..) |r, idx| {
            try writer.print("  {d}. {s} (line {d}): complexity {d}\n", .{
                idx,
                r.function_name,
                r.start_line,
                r.complexity,
            });
        }
    }

    // Final verdict
    const verdict = if (errors > 0) "FAILED" else if (warnings > 0) "WARNINGS" else "PASSED";
    const color = if (errors > 0) Color.red else if (warnings > 0) Color.yellow else Color.green;

    if (use_color) {
        try writer.print("\n{s}{s}{s}\n", .{
            color.code(),
            verdict,
            Color.reset.code(),
        });
    } else {
        try writer.print("\n{s}\n", .{verdict});
    }
}

fn getTopComplexFunctions(
    results: []const cyclomatic.ThresholdResult,
    n: usize,
) []const cyclomatic.ThresholdResult {
    // Sort descending by complexity
    var sorted = results[0..];  // Slice for in-place sort
    std.sort.block(cyclomatic.ThresholdResult, sorted, {}, struct {
        fn lessThan(_: void, a: cyclomatic.ThresholdResult, b: cyclomatic.ThresholdResult) bool {
            return a.complexity > b.complexity;  // Descending
        }
    }.lessThan);

    const count = @min(n, sorted.len);
    return sorted[0..count];
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Colored output always on | TTY detection + NO_COLOR | 2020 (NO_COLOR standard) | Respects user preference, works in CI |
| Exit code 1 for all failures | Graduated exit codes (1-4) | ESLint/modern tools | CI can distinguish config vs parse vs metric errors |
| --verbose flag only | Three levels: quiet/default/verbose | Recent CLI tools | Better signal-to-noise ratio |
| Plain text summary | ESLint-style grouped output | ESLint 2015+ | Familiar to JavaScript developers |
| JSON with no metadata | Versioned schema with timestamp | JSON Schema 2020-12 | Forward compatibility, debugging |

**Deprecated/outdated:**
- **No verbosity control:** Modern CLIs have --quiet and --verbose flags (best practice since ~2018)
- **ANSI codes without detection:** Must check TTY and NO_COLOR (https://no-color.org/ standard since 2020)
- **Unversioned JSON:** JSON Schema 2020-12 recommends $schema field for version tracking

## Open Questions

1. **Line/column indexing consistency**
   - What we know: ESLint uses 1-indexed lines, 0-indexed columns
   - What's unclear: tree-sitter uses 0-indexed rows/columns internally
   - Recommendation: Convert to ESLint convention (1-indexed line, 0-indexed column) for display - already implemented in cyclomatic.zig (start_line = row + 1)

2. **Top N hotspots count**
   - What we know: User requested "top 3-5" in CONTEXT.md
   - What's unclear: Fixed number or configurable?
   - Recommendation: Hard-code 5 for Phase 5 (simplest), make configurable in later phase if requested

3. **Quiet mode behavior**
   - What we know: --quiet should reduce output
   - What's unclear: Show only errors or suppress all output?
   - Recommendation: Show only errors (exit code 1 conditions) + final verdict, suppress warnings/summary. Rationale: Users need to know *why* it failed.

4. **Verbose mode content**
   - What we know: --verbose shows more detail
   - What's unclear: What extra info to include?
   - Recommendation: Show ALL functions (even complexity 1), ALL files (even clean ones), config used, timing info. Defer timing to later phase if complex.

## Recommended Decisions

Based on research into ESLint (industry standard), NO_COLOR standard, GitHub Actions exit codes, and JSON Schema best practices:

### Verbosity Modes

**Decision:** Three-level verbosity with clear definitions:

**Default mode:**
- Show only files with problems (warnings/errors)
- Show only problem functions (omit complexity 1 clean functions)
- Show summary with top 5 worst functions
- Show final verdict (PASSED/WARNINGS/FAILED)

**--verbose mode:**
- Show ALL files analyzed (even clean ones)
- Show ALL functions with metrics (even complexity 1)
- Show config used (loaded from which file)
- Show summary + verdict
- (Defer timing info to performance phase if needed)

**--quiet mode:**
- Show ONLY error-level problems (suppress warnings)
- Suppress summary (no top N list)
- Show final verdict only (FAILED or PASSED)
- Exit code still reflects result

**Rationale:** Matches ESLint's verbosity model. Default mode balances signal (problems) vs noise (clean code). Verbose mode aids debugging. Quiet mode for CI logs.

### Exit Code Mapping

**Decision:** Use graduated exit codes per requirements:

```
0 = success (no errors, warnings acceptable if --fail-on none)
1 = errors found (metric threshold violations at error level)
2 = warnings found (only if --fail-on warning set)
3 = config errors (validation failed, file not found)
4 = parse errors (tree-sitter parsing failed)
```

**Priority order:**
1. Config errors checked first (during config load in main.zig)
2. Parse errors checked second (after file discovery/parsing)
3. Metric errors checked third (after analysis)
4. Warnings checked if --fail-on warning
5. Success if no above conditions

**Rationale:** Matches requirements CI-01 through CI-05. Graduated codes let CI distinguish config issues (fix config file) from parse issues (syntax errors) from metric violations (complexity too high).

### JSON Schema Structure

**Decision:** Metadata envelope with camelCase fields:

```json
{
  "version": "1.0.0",
  "timestamp": 1707968400000,
  "summary": {
    "filesAnalyzed": 10,
    "totalFunctions": 45,
    "totalLines": 1234,
    "warnings": 3,
    "errors": 1,
    "status": "error"
  },
  "files": [
    {
      "path": "src/main.ts",
      "functions": [
        {
          "name": "processData",
          "startLine": 12,
          "endLine": 45,
          "startCol": 2,
          "cyclomatic": 15,
          "cognitive": null,
          "nestingDepth": 3,
          "lineCount": 34,
          "paramsCount": 2,
          "status": "warning"
        }
      ]
    }
  ]
}
```

**Field naming:** camelCase (matches JavaScript convention, ESLint JSON output)
**Null handling:** Include null fields explicitly (forward compatibility when metrics added)
**Metadata:** Top-level envelope with version/timestamp separate from data
**Summary:** Aggregated counts for quick CI parsing

**Rationale:**
- camelCase matches ESLint's JSON formatter (familiar to JS developers)
- Explicit nulls better than omission (consumers know field exists but not computed yet)
- Version field enables schema evolution (JSON Schema 2020-12 recommendation)
- Timestamp aids debugging (which run produced this report?)
- Status field ("pass"/"warning"/"error") lets CI scripts parse without exit code

### Color Detection

**Decision:** Use Zig's std.io.tty with NO_COLOR/FORCE_COLOR support:

**Priority order:**
1. `--no-color` flag → force off
2. `--color` flag → force on
3. `NO_COLOR` env var → force off (https://no-color.org/)
4. `FORCE_COLOR` or `YES_COLOR` env var → force on
5. TTY detection via `std.io.tty.detectConfig(stdout)` → auto-detect

**Already implemented:** help.zig has shouldUseColor function following this pattern.

**Rationale:** Matches NO_COLOR standard (adopted by ESLint, ripgrep, etc.). Respects user preference without forcing.

### Null/Future Metrics Handling

**Decision:**

**Console:** Use `--` placeholder for null metrics
```
  12:4  ✓  Function 'foo' | cyclomatic: 5 | cognitive: -- | health: --
```

**JSON:** Include null explicitly
```json
{
  "cyclomatic": 5,
  "cognitive": null,
  "halsteadVolume": null,
  "healthScore": null
}
```

**Rationale:**
- Console: `--` visually indicates "not computed" vs "zero" (clarity)
- JSON: Explicit null preserves schema (consumers know field exists, just null)
- Forward compatibility: When Phase 6 adds cognitive complexity, consumers don't break

## Sources

### Primary (HIGH confidence)

**Zig Standard Library Documentation:**
- [io/tty.zig - Zig standard library](http://ratfactor.com/zig/stdlib-browseable2/io/tty.zig.html) - TTY color detection with NO_COLOR support
- [Documentation - The Zig Programming Language](https://ziglang.org/documentation/master/) - Official Zig standard library reference

**NO_COLOR Standard:**
- [NO_COLOR](https://no-color.org/) - Standard for disabling ANSI color (referenced by help.zig implementation)

**ESLint Output Reference:**
- [Formatters Reference - ESLint](https://eslint.org/docs/latest/use/formatters/) - ESLint JSON and console output formats
- [Custom Formatters - ESLint](https://eslint.org/docs/latest/extend/custom-formatters/) - LintResult structure, severity levels

**GitHub Actions Exit Codes:**
- [Setting exit codes for actions - GitHub Docs](https://docs.github.com/en/actions/creating-actions/setting-exit-codes-for-actions) - Official exit code conventions
- [How to Handle Step and Job Errors in GitHub Actions - Ken Muse](https://www.kenmuse.com/blog/how-to-handle-step-and-job-errors-in-github-actions/) - Best practices for CI error handling

**JSON Schema Standards:**
- [JSON Schema - Specification](https://json-schema.org/specification) - Official JSON Schema 2020-12 specification
- [JSON Schema - Dialect and vocabulary declaration](https://json-schema.org/understanding-json-schema/reference/schema) - Version field recommendations

### Secondary (MEDIUM confidence)

**Zig ANSI Libraries:**
- [GitHub - ziglibs/ansi_term](https://github.com/ziglibs/ansi_term) - Third-party ANSI library (decided not to use)
- [GitHub - renatoathaydes/ansi-escapes.zig](https://github.com/renatoathaydes/ansi-escapes.zig) - Alternative ANSI library

**CLI Best Practices:**
- [Verbosity vs. Quietness in CLI - Educative](https://www.educative.io/answers/verbosity-vs-quietness-in-cli) - Verbosity level definitions
- [CLI verbosity levels - Ubuntu Community Hub](https://discourse.ubuntu.com/t/cli-verbosity-levels/26973) - Multi-level verbosity patterns
- [Make Your CLI a Joy to Use - Cadu Henrique](https://www.caduh.com/blog/make-your-cli-a-joy-to-use) - CLI UX patterns

**JSON Schema Design:**
- [JSON Best Practices - JSON Console](https://jsonconsole.com/blog/json-best-practices-writing-clean-maintainable-data-structures) - camelCase vs snake_case
- [Tutorial - Schema Versioning | Couchbase Developer Portal](https://developer.couchbase.com/tutorial-schema-versioning/?learningPath=learn/json-document-management-guide) - Version field patterns

### Tertiary (LOW confidence - reference only)

**Community Resources:**
- Various blog posts on CLI design - used for pattern ideas, not authoritative
- Zig community forum discussions - useful for library comparisons

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - std.io.tty and std.json already in use, well-documented
- ESLint output format: HIGH - Official ESLint docs, can verify with `eslint --format json`
- Exit codes: HIGH - GitHub Actions official docs, industry standard
- Verbosity modes: MEDIUM - Inferred from common CLI tools (ESLint, ripgrep, etc.)
- JSON schema: HIGH - JSON Schema 2020-12 official spec, ESLint JSON format reference

**Research date:** 2026-02-14
**Valid until:** ~60 days (2026-04-15) - NO_COLOR and exit code conventions are stable, Zig std lib evolves slowly
