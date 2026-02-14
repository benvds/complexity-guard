# Phase 2: CLI & Configuration - Research

**Researched:** 2026-02-14
**Domain:** Zig CLI development, argument parsing, config file loading
**Confidence:** HIGH

## Summary

Phase 2 implements CLI argument parsing and configuration file loading for ComplexityGuard. Zig has a mature ecosystem for this domain with multiple well-tested libraries and clear standard library support for file I/O, JSON parsing, and TTY detection. The user has made comprehensive decisions about the CLI personality (ripgrep/fd-style), config structure (JSON/TOML with ESLint-style overrides), and discovery patterns (upward search to .git boundary, XDG user config).

**Key findings:**
- **zig-clap** is the most mature argument parsing library, supports help generation, and handles all required flag patterns
- **std.json** in Zig 0.14+ provides robust JSON parsing with `parseFromSlice` and automatic memory management via `Parsed(T)`
- **zig-toml** (sam701) is the recommended TOML parser, parses directly into structs matching JSON pattern
- Config discovery requires manual upward directory walking using `std.fs.path.dirname()` in a loop
- TTY detection and color output are built into `std.io.tty` with NO_COLOR/YES_COLOR environment variable support

**Primary recommendation:** Use zig-clap for argument parsing, std.json for JSON config, zig-toml for TOML config, and known-folders library for XDG directory resolution. Arena allocators handle all short-lived parsing memory.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Config file structure
- Top-level keys grouped by concern: `output` (format, file), `analysis` (metrics, thresholds), `files` (include, exclude), `weights`, `overrides`
- Thresholds nested by metric: `{ "cyclomatic": { "warning": 10, "error": 20 }, "cognitive": { ... } }`
- Per-path overrides array with glob patterns, like ESLint: `"overrides": [{ "files": ["tests/**"], "analysis": { ... } }]`

#### Config file naming & formats
- Four config file names supported: `.complexityguard.json`, `complexityguard.config.json`, `.complexityguard.toml`, `complexityguard.config.toml`
- JSON and TOML both supported as formats
- First found wins (search order: dotfile JSON, config JSON, dotfile TOML, config TOML)

#### Config discovery
- Search upward from CWD, stop at nearest `.git` directory
- Also check user-level config: `~/.config/complexityguard/config.json` or `~/.config/complexityguard/config.toml`
- Project config wins entirely over user config (no merge — if project config exists, user config is ignored)
- `--config` flag overrides all discovery

#### Default behavior
- Bare `complexityguard` (no args, no config) analyzes current directory recursively for TS/JS files
- Equivalent to `complexityguard .`

#### Init command
- `complexityguard --init` runs interactive setup, asks a few questions, generates config file
- Produces config with chosen settings plus comments explaining options

#### Help output
- Compact style like ripgrep — short descriptions per flag, grouped by category, fits in one screen
- Groups: General, Output, Analysis, Files, Thresholds

#### Error reporting
- Invalid flags: error + did-you-mean suggestion (Levenshtein distance matching)
- Invalid config: hard fail with exit code 3, clear error message pointing to the problem
- No lenient mode — broken config is always a hard stop

#### Color output
- Auto-detect TTY: color when stdout is a terminal, plain when piped
- `--color` / `--no-color` flags to override
- Results to stdout, diagnostics/errors/progress to stderr (pipeable)

#### Flag conventions
- Short aliases for key flags only: `-f` (format), `-o` (output), `-v` (verbose), `-q` (quiet), `-c` (config)
- `--metrics` accepts comma-separated values: `--metrics cyclomatic,cognitive,halstead`
- Flag values override config file values (CFG-07)

#### CLI personality
- Inspired by ripgrep/fd: fast, focused, great defaults, compact help
- Respects `.gitignore` patterns when discovering files (in addition to include/exclude config)

### Claude's Discretion

- Exact flag grouping in help text
- `--init` question flow and default choices
- TOML parsing library choice (or hand-rolled) → **DECIDED: Use zig-toml (sam701)**
- Config validation error message formatting
- Short flag assignments beyond the five listed above

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

## Standard Stack

### Core Libraries

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| zig-clap | 0.9.1+ | CLI argument parsing | Most mature Zig CLI library, supports help generation, comptime param validation |
| std.json | stdlib 0.14+ | JSON config parsing | Built-in, robust, uses `parseFromSlice` with `Parsed(T)` wrapper for memory management |
| zig-toml | git-master | TOML config parsing | Top-down LL parser, parses directly to structs, TOML 1.0.0 compliant |
| known-folders | git | XDG directory resolution | Cross-platform config path discovery, supports `XDG_CONFIG_HOME` |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| glob.zig | git | Glob pattern matching | For include/exclude patterns and override file matching |
| zlob | git | .gitignore parsing | For respecting .gitignore during file discovery (Phase 3 integration) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| zig-clap | yazap | yazap has nicer API but less mature, fewer stars (198 vs 540+) |
| zig-clap | Hand-rolled stdlib parsing | Would need to implement help generation, validation, did-you-mean from scratch |
| zig-toml (sam701) | tomlz (mattyhall) | tomlz supports Table intermediate type, but sam701 has direct-to-struct like JSON |
| known-folders | Manual XDG detection | Would need platform-specific env var handling, fallback logic, Windows/macOS paths |

**Installation:**
```bash
# Add to build.zig.zon
zig fetch --save git+https://github.com/Hejsil/zig-clap
zig fetch --save git+https://github.com/sam701/zig-toml
zig fetch --save git+https://github.com/ziglibs/known-folders
zig fetch --save git+https://github.com/xcaeser/glob.zig
```

## Architecture Patterns

### Recommended Project Structure

```
src/
├── cli/
│   ├── args.zig         # Argument parsing (zig-clap integration)
│   ├── config.zig       # Config loading & validation
│   ├── help.zig         # Help text generation
│   └── init.zig         # --init interactive setup
├── core/
│   ├── types.zig        # (existing) Core data structures
│   └── json.zig         # (existing) JSON serialization
└── main.zig             # Entry point, orchestration
```

### Pattern 1: CLI Argument Parsing with zig-clap

**What:** Define parameters at comptime using zig-clap's string DSL, parse args into struct
**When to use:** All CLI flag/argument handling

**Example:**
```zig
// Source: https://github.com/Hejsil/zig-clap
const clap = @import("clap");

const params = comptime clap.parseParamsComptime(
    \\-h, --help                Display this help and exit
    \\-v, --version             Display version information
    \\-f, --format <STR>        Output format (console, json, sarif, html)
    \\-o, --output <FILE>       Write report to file
    \\-c, --config <FILE>       Path to config file
    \\--fail-on <LEVEL>         Failure level (warning, error, none)
    \\--metrics <LIST>          Comma-separated metrics to compute
    \\--no-duplication          Skip duplication analysis
    \\--threads <NUM>           Number of threads to use
    \\--color                   Force color output
    \\--no-color                Disable color output
    \\--init                    Run interactive setup
    \\<PATH>...                 Files or directories to analyze
);

pub fn parseArgs(allocator: std.mem.Allocator) !clap.Result(clap.Help, &params, clap.parsers.default) {
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };

    if (res.args.help != 0) {
        return clap.help(std.io.getStdOut().writer(), clap.Help, &params, .{});
    }

    return res;
}
```

### Pattern 2: JSON Config Loading

**What:** Use std.json.parseFromSlice with struct type, handle with Parsed(T) wrapper
**When to use:** Loading .complexityguard.json files

**Example:**
```zig
// Source: https://www.openmymind.net/Reading-A-Json-Config-In-Zig/
const Config = struct {
    output: ?OutputConfig = null,
    analysis: ?AnalysisConfig = null,
    files: ?FilesConfig = null,
    weights: ?WeightsConfig = null,
    overrides: ?[]OverrideConfig = null,
};

pub fn loadJsonConfig(allocator: std.mem.Allocator, path: []const u8) !std.json.Parsed(Config) {
    const data = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024); // 1MB max
    defer allocator.free(data);

    return std.json.parseFromSlice(Config, allocator, data, .{
        .allocate = .alloc_always,  // Copy strings for ownership
    });
}

// Usage:
const parsed = try loadJsonConfig(allocator, ".complexityguard.json");
defer parsed.deinit();
const config = parsed.value;
```

### Pattern 3: TOML Config Loading

**What:** Use zig-toml Parser(T) with same struct types as JSON
**When to use:** Loading .complexityguard.toml files

**Example:**
```zig
// Source: https://github.com/sam701/zig-toml
const toml = @import("toml");

pub fn loadTomlConfig(allocator: std.mem.Allocator, path: []const u8) !toml.Result(Config) {
    var parser = toml.Parser(Config).init(allocator);
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    return try parser.parseFile(file, path);
}

// Usage:
const result = try loadTomlConfig(allocator, ".complexityguard.toml");
defer result.deinit();
const config = result.value;
```

### Pattern 4: Upward Directory Search for Config

**What:** Walk parent directories until .git boundary to find config files
**When to use:** Config discovery without --config flag

**Example:**
```zig
// Source: https://ziggit.dev/t/alternative-to-realpath-for-finding-parent-directories/12115
pub fn findConfigUpward(allocator: std.mem.Allocator, filenames: []const []const u8) !?[]const u8 {
    var cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(cwd);

    var current: []const u8 = cwd;
    const max_iterations = 100;
    var i: usize = 0;

    while (i < max_iterations) : (i += 1) {
        // Check for .git in current directory (boundary)
        const git_path = try std.fs.path.join(allocator, &.{current, ".git"});
        defer allocator.free(git_path);

        const is_boundary = blk: {
            std.fs.cwd().access(git_path, .{}) catch break :blk false;
            break :blk true;
        };

        // Check for config files
        for (filenames) |filename| {
            const config_path = try std.fs.path.join(allocator, &.{current, filename});
            defer allocator.free(config_path);

            std.fs.cwd().access(config_path, .{}) catch continue;
            return try allocator.dupe(u8, config_path);
        }

        // Stop at .git boundary
        if (is_boundary) break;

        // Move to parent directory
        const parent = std.fs.path.dirname(current) orelse break;
        current = parent;
    }

    return null;
}
```

### Pattern 5: XDG User Config Path

**What:** Use known-folders library to get ~/.config/complexityguard path
**When to use:** Fallback when no project config found

**Example:**
```zig
// Source: https://github.com/ziglibs/known-folders/blob/master/known-folders.zig
const known_folders = @import("known-folders");

pub fn getUserConfigPath(allocator: std.mem.Allocator) !?[]const u8 {
    const config_home = try known_folders.getPath(allocator, .roaming_configuration) orelse return null;
    defer allocator.free(config_home);

    const user_config_dir = try std.fs.path.join(allocator, &.{config_home, "complexityguard"});
    defer allocator.free(user_config_dir);

    // Try both JSON and TOML
    const json_path = try std.fs.path.join(allocator, &.{user_config_dir, "config.json"});
    defer allocator.free(json_path);
    std.fs.cwd().access(json_path, .{}) catch {
        const toml_path = try std.fs.path.join(allocator, &.{user_config_dir, "config.toml"});
        std.fs.cwd().access(toml_path, .{}) catch return null;
        return try allocator.dupe(u8, toml_path);
    };
    return try allocator.dupe(u8, json_path);
}
```

### Pattern 6: TTY Detection for Color Output

**What:** Use std.io.tty to detect terminal and respect NO_COLOR/YES_COLOR env vars
**When to use:** Auto-detecting color support before output

**Example:**
```zig
// Source: http://ratfactor.com/zig/stdlib-browseable2/io/tty.zig.html
pub fn shouldUseColor(force_color: ?bool, no_color: ?bool) bool {
    if (no_color) |nc| if (nc) return false;
    if (force_color) |fc| if (fc) return true;

    // Check environment variables
    const env_no_color = std.process.getEnvVarOwned(allocator, "NO_COLOR") catch null;
    if (env_no_color) |_| return false;

    const env_yes_color = std.process.getEnvVarOwned(allocator, "YES_COLOR") catch null;
    if (env_yes_color) |_| return true;

    // Default: detect TTY
    const stdout = std.io.getStdOut();
    return std.io.tty.detectConfig(stdout).isColorSupported();
}
```

### Pattern 7: Arena Allocator for CLI Parsing

**What:** Use arena allocator for all short-lived CLI/config parsing, single deinit at end
**When to use:** Main function lifecycle for argument and config parsing

**Example:**
```zig
// Source: https://zig.guide/standard-library/allocators/
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Arena for all CLI/config parsing
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const args = try parseArgs(arena_allocator);
    const config = try loadConfig(arena_allocator, args);

    // All parsing memory freed with single arena.deinit()
}
```

### Anti-Patterns to Avoid

- **Manual flag parsing with std.process.argsWithAllocator()**: Reinventing zig-clap's help generation, validation, and error reporting
- **Merging project and user configs**: User specified no-merge strategy, project config wins entirely
- **Continuing with invalid config**: User requires hard fail with exit code 3
- **Using FixedBufferAllocator for config**: JSON/TOML parsing needs dynamic allocation, use arena
- **Calling std.process.exit() in library code**: Return errors, let main() handle exit codes

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CLI argument parsing | Manual argv iteration, flag parsing | zig-clap | Help generation, validation, did-you-mean, subcommands all implemented |
| Levenshtein distance | String edit distance algorithm | Hand-roll simple version | No mature Zig library found; algorithm is ~20 lines for basic version |
| TOML parsing | TOML spec implementation | zig-toml (sam701) | TOML 1.0.0 compliance is complex (date/time, dotted keys, inline tables) |
| XDG directory discovery | Platform-specific env var checks | known-folders | Cross-platform (Linux, macOS, Windows), handles defaults and fallbacks |
| Glob pattern matching | Wildcard expansion | glob.zig | Supports **, [], negation; edge cases in path separators |
| .gitignore parsing | Git pattern spec | zlob | gitignore spec is surprisingly complex (negation, directory-only, trailing slash semantics) |

**Key insight:** CLI libraries save hundreds of lines of boilerplate and edge case handling. JSON is stdlib so free, but TOML parsing is non-trivial. Glob/gitignore patterns have surprising edge cases (trailing slashes, directory-only matches, negation order).

## Common Pitfalls

### Pitfall 1: Arena Allocator Struct Initialization Order

**What goes wrong:** Memory leaks even with proper defer arena.deinit() when arena is stored in a struct field

**Why it happens:** Zig initializes struct fields in declaration order, not assignment order. If you create an arena, then create a struct that copies the arena, the copy might outlive the original's deinit().

**How to avoid:**
- Don't store arena allocators in struct fields
- Use arena in main() scope only
- Pass arena.allocator() to functions, not the arena itself

**Warning signs:** Unexpected memory leak reports with std.testing.allocator when arena is involved

**Source:** [Be Careful When Assigning ArenaAllocators](https://www.openmymind.net/Be-Careful-When-Assigning-ArenaAllocators/)

### Pitfall 2: Invalid Flag Did-You-Mean Without Levenshtein

**What goes wrong:** User expects "did you mean?" suggestions but zig-clap's diagnostics don't provide them

**Why it happens:** zig-clap focuses on parsing, not suggestion generation

**How to avoid:** Implement simple Levenshtein distance (Wagner-Fischer algorithm, ~20 lines) and scan all valid flag names when parse fails

**Warning signs:** User types `--foramt` and gets "unknown option" without helpful suggestion

**Source:** [Levenshtein Distance Basics](https://prabeshthapa.medium.com/from-frustrating-typos-to-smart-suggestions-implementing-levenshtein-distance-in-go-clis-3708c0a3b4e1)

### Pitfall 3: TOML/JSON Schema Mismatch

**What goes wrong:** Same struct works for JSON but fails for TOML or vice versa

**Why it happens:** TOML's dotted keys and table syntax don't map 1:1 to JSON's nested objects. `[analysis.cyclomatic]` in TOML vs `{"analysis": {"cyclomatic": {}}}` in JSON.

**How to avoid:**
- Test config loading with both JSON and TOML fixtures
- Use flat struct fields where possible
- Ensure nested structs have same field names in both formats

**Warning signs:** JSON config loads fine but equivalent TOML config fails to parse

**Source:** [zig-toml README](https://github.com/sam701/zig-toml)

### Pitfall 4: Config Validation Happens Too Late

**What goes wrong:** Load config successfully, use invalid threshold value deep in analysis phase, confusing error

**Why it happens:** std.json.parseFromSlice validates JSON syntax and type matching, but not domain constraints (e.g., threshold >= 0)

**How to avoid:**
- Add explicit `validate()` method on Config struct
- Check thresholds > 0, file patterns are valid globs, metric names are known
- Fail immediately after parse with exit code 3 and clear message

**Warning signs:** Error message appears during analysis, not during config load

**Source:** [Config File Validation Best Practices](https://github.com/aws/amazon-cloudwatch-agent/issues/404)

### Pitfall 5: Upward Search Doesn't Stop at Filesystem Root

**What goes wrong:** Infinite loop or panic when searching for config files in directories without .git

**Why it happens:** `std.fs.path.dirname()` returns null at root, but loop doesn't check for this

**How to avoid:**
- Implement max iteration limit (e.g., 100)
- Check `dirname(current) orelse break`
- Consider stopping at filesystem root explicitly (compare with "/" or "C:\\" on Windows)

**Warning signs:** Hangs when run from `/tmp` or other non-git directory

**Source:** [Alternative to realpath for finding parent directories](https://ziggit.dev/t/alternative-to-realpath-for-finding-parent-directories/12115)

### Pitfall 6: Forgetting to Flush Buffered Writers

**What goes wrong:** Output missing or incomplete when piped

**Why it happens:** Zig 0.15+ introduced buffered writers that require explicit flush()

**How to avoid:**
- Always call `.flush()` before program exit
- Use defer writer.flush() immediately after obtaining buffered writer
- Errors to stderr should flush immediately

**Warning signs:** Output works in terminal but truncates when redirected to file

**Source:** [Zig 0.15.1 Release Notes - Writergate](https://ziglang.org/download/0.15.1/release-notes.html)

### Pitfall 7: Flag Values Not Overriding Config

**What goes wrong:** User specifies `--format json` but config file's `format = "console"` wins

**Why it happens:** Loading config after parsing args, or not checking "was flag explicitly set" vs. "using default"

**How to avoid:**
- Parse args first, then load config
- For each flag, check if it was explicitly provided (zig-clap tracks this)
- Apply config values only for flags not explicitly set
- Document precedence: CLI flags > config file > defaults

**Warning signs:** Users report flags "don't work" when config file exists

**Source:** User requirement CFG-07

## Code Examples

Verified patterns from official sources:

### Interactive Prompt for --init

```zig
// Source: https://medium.com/@eddo2626/lets-learn-zig-1-using-stdout-and-stdin-842ee641cd
const std = @import("std");

pub fn promptString(allocator: std.mem.Allocator, prompt_text: []const u8) ![]const u8 {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.print("{s}: ", .{prompt_text});

    var buf: [256]u8 = undefined;
    const line = try stdin.readUntilDelimiter(&buf, '\n');
    return try allocator.dupe(u8, std.mem.trim(u8, line, "\r\n "));
}

pub fn promptChoice(comptime T: type, prompt_text: []const u8, default: T, choices: []const T) !T {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.print("{s} (", .{prompt_text});
    for (choices, 0..) |choice, i| {
        if (i > 0) try stdout.writeAll("/");
        try stdout.print("{s}", .{@tagName(choice)});
    }
    try stdout.print(") [{s}]: ", .{@tagName(default)});

    var buf: [64]u8 = undefined;
    const line = try stdin.readUntilDelimiter(&buf, '\n');
    const trimmed = std.mem.trim(u8, line, "\r\n ");

    if (trimmed.len == 0) return default;

    for (choices) |choice| {
        if (std.mem.eql(u8, trimmed, @tagName(choice))) return choice;
    }

    return error.InvalidChoice;
}
```

### Exit Code Handling

```zig
// Source: https://github.com/ziglang/zig/issues/16135
const std = @import("std");

pub const ExitCode = enum(u8) {
    success = 0,
    general_error = 1,
    usage_error = 2,
    config_error = 3,
    threshold_exceeded = 4,
};

pub fn main() !void {
    // ... do work ...

    if (config_invalid) {
        std.log.err("Invalid config: {s}", .{error_msg});
        std.process.exit(@intFromEnum(ExitCode.config_error));
    }

    if (analysis_failed) {
        std.process.exit(@intFromEnum(ExitCode.threshold_exceeded));
    }
}
```

### Compact Help Output (ripgrep-style)

```zig
// Pattern based on: https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md
pub fn printCompactHelp(writer: anytype) !void {
    try writer.writeAll(
        \\complexityguard [OPTIONS] [PATH]...
        \\
        \\Analyze code complexity for TypeScript/JavaScript files
        \\
        \\GENERAL:
        \\  -h, --help               Show this help message
        \\  -v, --version            Show version information
        \\      --init               Run interactive setup
        \\
        \\OUTPUT:
        \\  -f, --format <FORMAT>    Output format [console, json, sarif, html]
        \\  -o, --output <FILE>      Write report to file instead of stdout
        \\      --color              Force color output
        \\      --no-color           Disable color output
        \\  -q, --quiet              Suppress progress messages
        \\  -v, --verbose            Show detailed progress
        \\
        \\ANALYSIS:
        \\      --metrics <LIST>     Comma-separated metrics [cyclomatic,cognitive,halstead]
        \\      --no-duplication     Skip duplication analysis
        \\      --threads <N>        Number of threads (default: CPU count)
        \\      --baseline <FILE>    Compare against baseline report
        \\
        \\FILES:
        \\      --include <GLOB>     Include files matching pattern (can be repeated)
        \\      --exclude <GLOB>     Exclude files matching pattern (can be repeated)
        \\
        \\THRESHOLDS:
        \\      --fail-on <LEVEL>    Exit non-zero on [warning, error, none]
        \\      --fail-health-below <N> Exit non-zero if health score below N
        \\
        \\CONFIG:
        \\  -c, --config <FILE>      Use specific config file
        \\
        \\Run 'complexityguard --init' to create a config file interactively.
        \\
    );
}
```

### Simple Levenshtein Distance for Did-You-Mean

```zig
// Source: Wagner-Fischer algorithm - https://en.wikipedia.org/wiki/Levenshtein_distance
pub fn levenshteinDistance(a: []const u8, b: []const u8, allocator: std.mem.Allocator) !usize {
    const m = a.len;
    const n = b.len;

    if (m == 0) return n;
    if (n == 0) return m;

    var matrix = try allocator.alloc(usize, (m + 1) * (n + 1));
    defer allocator.free(matrix);

    for (0..m + 1) |i| matrix[i * (n + 1)] = i;
    for (0..n + 1) |j| matrix[j] = j;

    for (1..m + 1) |i| {
        for (1..n + 1) |j| {
            const cost: usize = if (a[i - 1] == b[j - 1]) 0 else 1;
            const deletion = matrix[(i - 1) * (n + 1) + j] + 1;
            const insertion = matrix[i * (n + 1) + (j - 1)] + 1;
            const substitution = matrix[(i - 1) * (n + 1) + (j - 1)] + cost;
            matrix[i * (n + 1) + j] = @min(@min(deletion, insertion), substitution);
        }
    }

    return matrix[m * (n + 1) + n];
}

pub fn findClosestFlag(unknown: []const u8, known_flags: []const []const u8, allocator: std.mem.Allocator) !?[]const u8 {
    var min_distance: usize = std.math.maxInt(usize);
    var closest: ?[]const u8 = null;

    for (known_flags) |flag| {
        const dist = try levenshteinDistance(unknown, flag, allocator);
        if (dist < min_distance and dist <= 3) {  // Max distance of 3
            min_distance = dist;
            closest = flag;
        }
    }

    return closest;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| std.io.GenericWriter/Reader | std.Io.Writer/Reader with buffers | Zig 0.15 | Must provide buffers, call flush() explicitly |
| std.process.Child direct pipe setup | Buffered I/O on child stdout/stderr | Zig 0.15 | Simpler subprocess output collection |
| process.Child.collectOutput with managed ArrayList | Unmanaged containers + explicit allocator | Zig 0.14 | Safer (no ptr comparison), more explicit |
| u8/!u8 return from main | std.process.ExitStatus union | Zig 0.14+ | Cross-platform exit codes, more flexible |

**Deprecated/outdated:**
- **std.io.GenericWriter/GenericReader**: Removed in 0.15, use std.Io.Writer/Reader
- **Returning u8 from main()**: Use ExitStatus union for platform-agnostic exit codes
- **Managed ArrayList for child output**: Use unmanaged variants with explicit allocator

## Open Questions

1. **Levenshtein Distance Library**
   - What we know: No mature Zig library found, algorithm is simple (20-30 lines)
   - What's unclear: Should we vendor a library or hand-roll?
   - Recommendation: Hand-roll Wagner-Fischer algorithm (see code example above), it's well-understood and small

2. **--init Question Flow**
   - What we know: User wants interactive prompts, output format selection, threshold defaults
   - What's unclear: Exact questions and order
   - Recommendation: Start simple (output format, threshold style, file patterns), expand based on feedback

3. **glob.zig vs zlob for Pattern Matching**
   - What we know: glob.zig for simple wildcards, zlob for gitignore
   - What's unclear: Can we use glob.zig for both include/exclude and gitignore, or do we need zlob?
   - Recommendation: Start with glob.zig for config patterns, integrate zlob in Phase 3 for gitignore specifically

4. **TOML Date/Time Handling**
   - What we know: Zig has no stdlib datetime types, TOML parsers return strings
   - What's unclear: Does our config even need datetime fields?
   - Recommendation: No datetime fields in config, this is a non-issue

## Sources

### Primary (HIGH confidence)

- [zig-clap GitHub](https://github.com/Hejsil/zig-clap) - CLI argument parsing API and examples
- [Zig std.json Guide](https://zig.guide/standard-library/json/) - Official zig.guide JSON parsing tutorial
- [Reading a JSON config in Zig](https://www.openmymind.net/Reading-A-Json-Config-In-Zig/) - Complete config loading pattern
- [zig-toml GitHub](https://github.com/sam701/zig-toml) - TOML parser API and usage
- [known-folders GitHub](https://github.com/ziglibs/known-folders/blob/master/known-folders.zig) - XDG directory resolution API
- [Zig Allocators Guide](https://zig.guide/standard-library/allocators/) - Arena allocator best practices
- [Zig 0.14.0 Release Notes](https://ziglang.org/download/0.14.0/release-notes.html) - Breaking changes and new APIs
- [Zig 0.15.1 Release Notes](https://ziglang.org/download/0.15.1/release-notes.html) - I/O API overhaul (Writergate)

### Secondary (MEDIUM confidence)

- [fd GitHub](https://github.com/sharkdp/fd) - CLI design inspiration, help format patterns
- [ripgrep GUIDE.md](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md) - CLI philosophy and flag organization
- [Alternative to realpath for finding parent directories](https://ziggit.dev/t/alternative-to-realpath-for-finding-parent-directories/12115) - Upward search pattern
- [glob.zig GitHub](https://github.com/xcaeser/glob.zig) - Glob pattern matching
- [zlob GitHub](https://github.com/dmtrKovalenko/zlob) - .gitignore parsing
- [Command Line Interface Guidelines](https://clig.dev/) - CLI best practices
- [Be Careful When Assigning ArenaAllocators](https://www.openmymind.net/Be-Careful-When-Assigning-ArenaAllocators/) - Arena allocator pitfall

### Tertiary (LOW confidence, marked for validation)

- [Levenshtein Distance in Go CLIs](https://prabeshthapa.medium.com/from-frustrating-typos-to-smart-suggestions-implementing-levenshtein-distance-in-go-clis-3708c0a3b4e1) - Did-you-mean pattern (language-agnostic algorithm)
- [Config File Validation Best Practices](https://github.com/aws/amazon-cloudwatch-agent/issues/404) - Error handling patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries verified via official repos, std.json is stdlib, zig-clap has 540+ stars
- Architecture: HIGH - Patterns verified with official docs and working examples, arena allocator is idiomatic Zig
- Pitfalls: MEDIUM-HIGH - Most verified with official sources or community discussions, arena allocator pitfall is well-documented

**Research date:** 2026-02-14
**Valid until:** 2026-03-14 (30 days - Zig ecosystem is stable, 0.15.1 released Jan 2025)
