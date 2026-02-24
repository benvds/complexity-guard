# Phase 19: CLI, Config, and Output Formats - Research

**Researched:** 2026-02-24
**Domain:** Rust CLI argument parsing, config loading, and output format rendering
**Confidence:** HIGH

## Summary

Phase 19 wires the existing Phase 18 metric pipeline into a runnable binary with a complete CLI, config file loading, and all four output formats. The Zig implementation is thoroughly understood: 28 CLI flags across three short/long aliases, a JSON config schema with six top-level sections, and four output renderers (console/ESLint-style, JSON envelope, SARIF 2.1.0, self-contained HTML with embedded CSS and JS). The Rust stack for this phase is well-established — clap 4.5 derive for CLI, serde_json for config and JSON output, hand-rolled SARIF structs (not serde-sarif), and a single-string `include_str!` approach for the HTML template.

The key discovery from inspecting the Zig source is that the config file format supports both JSON and TOML (`.complexityguard.json` / `.complexityguard.toml` / `complexityguard.config.json` / `complexityguard.config.toml`) with upward directory search stopping at a `.git` boundary. The Rust port needs only JSON config support for v0.8 parity (the TOML path in the Zig version used a vendored TOML parser; there is no TOML requirement in REQUIREMENTS.md). The exit code logic is deterministic: parse_error(4) > baseline_failed(1) > error_count>0(1) > warning_count>0+fail_on_warnings(2) > success(0).

The HTML output is fully self-contained — CSS and JS are embedded as string constants in the Zig source and injected into the HTML template at runtime. The Rust port should extract these into separate files under `rust/src/output/` and embed them with `include_str!`. The SARIF output uses 11 rule definitions with camelCase field names (matching SARIF 2.1.0 schema requirements) that cannot be serde-renamed without care — hand-rolled structs with `#[serde(rename = "...")]` is the correct approach, since serde-sarif 0.8.x is pre-1.0 and was noted as an open concern in STATE.md.

**Primary recommendation:** Implement this phase in three sequential tasks: (1) CLI + config module, (2) console + JSON + exit codes, (3) SARIF + HTML. This ordering ensures the binary is runnable and produces text output quickly, leaving the two complex serialization formats for last.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CLI-01 | Same CLI flags as Zig binary (all options preserved) | clap 4.5 derive struct with exact flag names from args.zig; 28 flags documented below |
| CLI-02 | `.complexityguard.json` config loading with same schema | serde_json + Config struct with all six top-level sections from config.zig |
| CLI-03 | CLI flags override config file values | mergeArgsIntoConfig pattern — initialize defaults, load config, apply CLI overrides |
| OUT-01 | Console output matches Zig ESLint-style format | owo-colors for ANSI; exact format documented from console.zig inspection |
| OUT-02 | JSON output matches Zig schema (field names, structure) | serde Serialize derives with snake_case field names matching JsonOutput struct |
| OUT-03 | SARIF 2.1.0 output accepted by GitHub Code Scanning | Hand-rolled serde structs with `#[serde(rename)]` for camelCase SARIF fields |
| OUT-04 | HTML report is self-contained with same embedded JS/CSS | include_str! for CSS/JS files; minijinja template render |
| OUT-05 | Exit codes 0-4 match Zig semantics | determineExitCode logic: parse_error(4) > baseline(1) > errors(1) > warnings+fail_on(2) > 0 |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| clap | 4.5.x | CLI argument parsing | De facto standard; derive API maps directly from Zig CliArgs struct |
| serde + serde_json | 1.x / 1.x | Config loading + JSON output | Already in Cargo.toml; serde Deserialize for config, Serialize for output |
| owo-colors | 4.x | ANSI terminal colors | Zero-allocation; respects NO_COLOR env; maps to Zig AnsiCode constants |
| minijinja | 2.x | HTML report rendering | Single complex template embedded with include_str!; runtime Jinja2-compatible |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| anyhow | 1.x | Error propagation in main | Wrap all errors at CLI boundary with context chains |
| thiserror | 2.x | Typed errors in library code | ConfigError, CliError — already in Cargo.toml |

### Dependencies to Add
The current `rust/Cargo.toml` is missing these libraries needed for Phase 19:

```toml
clap = { version = "4.5", features = ["derive"] }
owo-colors = "4"
minijinja = "2"
```

serde, serde_json, thiserror, and anyhow are already present.

**Note on serde-sarif:** STATE.md explicitly flags serde-sarif 0.8.x as pre-1.0 with a fallback plan. The Zig sarif_output.zig uses hand-rolled structs — do the same in Rust. Avoid serde-sarif entirely. Use `#[serde(rename = "fieldName")]` on struct fields where SARIF requires camelCase.

## Architecture Patterns

### Recommended Project Structure
```
rust/src/
├── cli/
│   ├── mod.rs           # re-exports
│   ├── args.rs          # clap derive Args struct
│   ├── config.rs        # Config struct + serde Deserialize + defaults()
│   ├── merge.rs         # merge_args_into_config() logic
│   └── discovery.rs     # config file path discovery (upward search)
├── output/
│   ├── mod.rs           # OutputFormat enum + dispatch
│   ├── console.rs       # ESLint-style colored output
│   ├── json_output.rs   # JsonOutput serde structs + serialization
│   ├── sarif_output.rs  # SARIF 2.1.0 hand-rolled structs
│   ├── html_output.rs   # HTML template rendering via minijinja
│   ├── exit_codes.rs    # determine_exit_code() function
│   └── assets/
│       ├── report.css   # embedded via include_str!
│       ├── report.js    # embedded via include_str!
│       └── report.html  # minijinja template
├── metrics/             # (Phase 18, existing)
├── parser/              # (Phase 17, existing)
├── types.rs             # (Phase 17-18, existing)
├── lib.rs               # add cli and output modules
└── main.rs              # full CLI entry point
```

### Pattern 1: clap Derive for CLI Args
**What:** Annotated struct maps directly to the CliArgs fields in args.zig. All 28 flags are reproduced with exact long-form names.
**When to use:** Single Args struct passed into main, then merged into Config.

```rust
// Source: clap 4.5 derive documentation
use clap::Parser;

#[derive(Parser, Debug)]
#[command(name = "complexityguard")]
#[command(about = "Analyze code complexity for TypeScript/JavaScript files")]
pub struct Args {
    // Positional paths
    pub paths: Vec<std::path::PathBuf>,

    // General
    #[arg(long)]
    pub version: bool,
    #[arg(long)]
    pub init: bool,

    // Output
    #[arg(short = 'f', long)]
    pub format: Option<String>,
    #[arg(short = 'o', long = "output")]
    pub output_file: Option<String>,
    #[arg(long)]
    pub color: bool,
    #[arg(long)]
    pub no_color: bool,
    #[arg(short = 'q', long)]
    pub quiet: bool,
    #[arg(short = 'v', long)]
    pub verbose: bool,

    // Analysis
    #[arg(long)]
    pub metrics: Option<String>,
    #[arg(long)]
    pub duplication: bool,
    #[arg(long)]
    pub no_duplication: bool,
    #[arg(long)]
    pub threads: Option<u32>,

    // Files
    #[arg(long)]
    pub include: Vec<String>,
    #[arg(long)]
    pub exclude: Vec<String>,

    // Thresholds
    #[arg(long)]
    pub fail_on: Option<String>,
    #[arg(long)]
    pub fail_health_below: Option<f64>,

    // Config
    #[arg(short = 'c', long)]
    pub config: Option<String>,

    // Baseline
    #[arg(long)]
    pub baseline: Option<String>,
}
```

**Important flag name mapping** (Zig kebab-case → clap long name):
- `--fail-on` → `#[arg(long = "fail-on")]`
- `--fail-health-below` → `#[arg(long = "fail-health-below")]`
- `--no-duplication` → `#[arg(long = "no-duplication")]`
- `--no-color` → `#[arg(long = "no-color")]`

clap automatically converts Rust field `fail_on` to `--fail-on`, so explicit `long = "..."` is only needed for disambiguation.

### Pattern 2: Config Struct with serde Deserialize
**What:** Mirror the Zig Config struct exactly. All fields optional to support partial configs.

```rust
#[derive(Debug, Default, Clone, serde::Deserialize)]
pub struct Config {
    pub output: Option<OutputConfig>,
    pub analysis: Option<AnalysisConfig>,
    pub files: Option<FilesConfig>,
    pub weights: Option<WeightsConfig>,
    pub overrides: Option<Vec<OverrideConfig>>,
    pub baseline: Option<f64>,
}

#[derive(Debug, Default, Clone, serde::Deserialize)]
pub struct OutputConfig {
    pub format: Option<String>,  // "console", "json", "sarif", "html"
    pub file: Option<String>,
}

#[derive(Debug, Default, Clone, serde::Deserialize)]
pub struct AnalysisConfig {
    pub metrics: Option<Vec<String>>,
    pub thresholds: Option<ThresholdsConfig>,
    pub no_duplication: Option<bool>,
    pub duplication_enabled: Option<bool>,
    pub threads: Option<u32>,
}

// ThresholdsConfig mirrors Zig exactly:
// cyclomatic, cognitive, halstead_volume, halstead_difficulty,
// halstead_effort, halstead_bugs, nesting_depth, line_count,
// params_count, file_length, export_count, duplication (float pair)
```

Note: Zig uses `@"error"` as a field name (reserved keyword); in Rust this maps cleanly to `error` since it is not reserved in struct field position.

### Pattern 3: CLI Override Merge
**What:** Start with defaults, overlay config file, then overlay CLI args. Mirrors mergeArgsIntoConfig in merge.zig.

```rust
pub fn merge_args_into_config(args: &Args, config: &mut Config) {
    let output = config.output.get_or_insert_with(Default::default);
    if let Some(fmt) = &args.format {
        output.format = Some(fmt.clone());
    }
    if let Some(file) = &args.output_file {
        output.file = Some(file.clone());
    }

    let analysis = config.analysis.get_or_insert_with(Default::default);
    if args.duplication {
        analysis.duplication_enabled = Some(true);
    }
    if args.no_duplication {
        analysis.no_duplication = Some(true);
    }
    if let Some(t) = args.threads {
        analysis.threads = Some(t);
    }

    let files = config.files.get_or_insert_with(Default::default);
    if !args.include.is_empty() {
        files.include = Some(args.include.clone());
    }
    if !args.exclude.is_empty() {
        files.exclude = Some(args.exclude.clone());
    }
}
```

### Pattern 4: SARIF Hand-Rolled Structs
**What:** Mirror the Zig SarifLog/SarifRun/SarifResult hierarchy. Use `#[serde(rename)]` for camelCase SARIF fields.

```rust
#[derive(serde::Serialize)]
pub struct SarifLog<'a> {
    #[serde(rename = "$schema")]
    pub schema: &'a str,
    pub version: &'a str,
    pub runs: Vec<SarifRun>,
}

#[derive(serde::Serialize)]
pub struct SarifDriver {
    pub name: &'static str,
    pub version: &'static str,
    #[serde(rename = "informationUri")]
    pub information_uri: &'static str,
    pub rules: Vec<SarifRule>,
}

#[derive(serde::Serialize)]
pub struct SarifRegion {
    #[serde(rename = "startLine")]
    pub start_line: u32,
    #[serde(rename = "startColumn")]
    pub start_column: u32,
    #[serde(rename = "endLine")]
    pub end_line: u32,
}
```

The 11 SARIF rules from the Zig source (rule IDs and descriptions must match exactly):
- `complexity-guard/cyclomatic` (index 0)
- `complexity-guard/cognitive` (index 1)
- `complexity-guard/halstead-volume` (index 2)
- `complexity-guard/halstead-difficulty` (index 3)
- `complexity-guard/halstead-effort` (index 4)
- `complexity-guard/halstead-bugs` (index 5)
- `complexity-guard/line-count` (index 6)
- `complexity-guard/param-count` (index 7)
- `complexity-guard/nesting-depth` (index 8)
- `complexity-guard/health-score` (index 9)
- `complexity-guard/duplication` (index 10)

### Pattern 5: HTML via minijinja + include_str!
**What:** Extract the Zig CSS/JS string constants into separate asset files. Embed them with `include_str!`. Pass data as a minijinja context.

```rust
const CSS: &str = include_str!("assets/report.css");
const JS: &str = include_str!("assets/report.js");
const TEMPLATE: &str = include_str!("assets/report.html");

pub fn render_html(data: &HtmlContext) -> anyhow::Result<String> {
    let mut env = minijinja::Environment::new();
    env.add_template("report", TEMPLATE)?;
    let tmpl = env.get_template("report")?;
    Ok(tmpl.render(minijinja::context! {
        css => CSS,
        js => JS,
        data => data,
    })?)
}
```

The CSS and JS from the Zig source are long (CSS ~235 lines, JS includes sortTable, SVG treemap rendering, and bar chart functions). Extracting them verbatim to asset files is the cleanest approach.

### Pattern 6: Exit Code Logic
**What:** Direct translation of determineExitCode from exit_codes.zig.

```rust
pub enum ExitCode {
    Success = 0,
    ErrorsFound = 1,
    WarningsFound = 2,
    ConfigError = 3,
    ParseError = 4,
}

pub fn determine_exit_code(
    has_parse_errors: bool,
    error_count: u32,
    warning_count: u32,
    fail_on_warnings: bool,
    baseline_failed: bool,
) -> ExitCode {
    if has_parse_errors { return ExitCode::ParseError; }
    if baseline_failed  { return ExitCode::ErrorsFound; }
    if error_count > 0  { return ExitCode::ErrorsFound; }
    if warning_count > 0 && fail_on_warnings { return ExitCode::WarningsFound; }
    ExitCode::Success
}
```

### Pattern 7: Color Detection
The Zig shouldUseColor logic must be replicated:
1. `--no-color` flag → always no color
2. `--color` flag → always color
3. `NO_COLOR` env var present → no color
4. `FORCE_COLOR` or `YES_COLOR` env var present → color
5. TTY detection → color if stdout is a TTY

owo-colors handles `NO_COLOR` env automatically when using `OwoColorize` methods. For TTY detection, use `std::io::IsTerminal` (stable since Rust 1.70).

### Anti-Patterns to Avoid
- **Using serde-sarif:** It is pre-1.0 and STATE.md explicitly calls it out as a concern. Use hand-rolled structs.
- **Storing format as an enum in Args:** clap can parse into enums but the Zig source uses string comparison throughout. Parse the format string at dispatch time.
- **Sharing mutable Config between threads:** Config is resolved once in main before the parallel analysis pass. It should be resolved to a final `ResolvedConfig` (non-optional fields with defaults applied) before being passed to workers.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CLI flag parsing | Custom arg parser | clap 4.5 derive | clap handles --help, --version, error messages, short aliases automatically |
| Config file loading | Manual JSON string parsing | serde_json::from_str::<Config> | Handles partial configs, unknown fields, and type coercion free |
| ANSI color codes | Raw `\x1b[31m` string constants | owo-colors | Automatic NO_COLOR, respects TTY, zero-allocation |
| HTML template string building | fmt::write chains | minijinja | The HTML report has complex conditional logic (duplication section, empty state); template is cleaner |

**Key insight:** The Zig codebase hand-rolled all of CLI parsing (400 lines in args.zig), config JSON parsing, and ANSI codes. In Rust, clap + serde eliminate all of that. The only output format that warrants care is SARIF (camelCase field names, required schema URL).

## Common Pitfalls

### Pitfall 1: SARIF camelCase Field Names
**What goes wrong:** serde serializes Rust snake_case fields as snake_case by default. SARIF 2.1.0 requires camelCase for all composite property names (`startLine`, `ruleIndex`, `physicalLocation`, `artifactLocation`, `informationUri`, `relatedLocations`, `defaultConfiguration`, `shortDescription`, `fullDescription`, `helpUri`).
**Why it happens:** Forgetting `#[serde(rename = "...")]` on any field that has a camelCase SARIF name.
**How to avoid:** Add a `#[serde(rename_all = "camelCase")]` container attribute on each SARIF struct. Only exceptions are simple lowercase names (`uri`, `text`, `level`, `version`, `name`, `tool`, `rules`, `results`, `runs`).
**Warning signs:** GitHub Code Scanning rejects SARIF with "expected property 'physicalLocation'" or similar.

### Pitfall 2: JSON Field Name Drift
**What goes wrong:** Rust field names or serde renames drift from the Zig JsonOutput struct field names. This breaks any consumer parsing the JSON output.
**Why it happens:** Rust convention is snake_case which matches the Zig JSON output, but easy to accidentally diverge.
**How to avoid:** The Zig JsonOutput struct uses these exact field names: `version`, `timestamp`, `summary`, `files`, `metadata`, `duplication`. FunctionOutput uses: `name`, `start_line`, `end_line`, `start_col`, `cyclomatic`, `cognitive`, `halstead_volume`, `halstead_difficulty`, `halstead_effort`, `halstead_bugs`, `nesting_depth`, `line_count`, `params_count`, `health_score`, `status`. serde's default snake_case serialization matches — no renames needed for JSON.
**Warning signs:** Integration test comparing JSON output to Zig binary output fails on field names.

### Pitfall 3: Float Serialization Precision in JSON
**What goes wrong:** `serde_json` and Zig's `std.json.Stringify` may format `f64` values differently in the last digit (e.g., `150.0` vs `150`). Halstead metrics (`halstead_volume`, `halstead_difficulty`, `halstead_effort`, `halstead_bugs`, `health_score`) are affected.
**Why it happens:** Different float-to-string algorithms (Ryu vs Grisu).
**How to avoid:** Integration tests for JSON output should compare float fields with a tolerance (e.g., within 1e-6), not byte-exact string comparison. Document this in the test strategy.
**Warning signs:** Tests fail on last digit of Halstead float values when comparing to Zig output.

### Pitfall 4: Config File Discovery Scope
**What goes wrong:** Config discovery searches only the current directory, missing the upward-search-to-.git behavior.
**Why it happens:** Simple `std::fs::read_to_string(".complexityguard.json")` only checks CWD.
**How to avoid:** Implement upward search: start from CWD, check all four filenames (`.complexityguard.json`, `complexityguard.config.json`, `.complexityguard.toml`, `complexityguard.config.toml`), walk parent directories, stop at `.git` boundary or filesystem root. For v0.8, TOML config support is optional since REQUIREMENTS.md only mentions `.complexityguard.json`.
**Warning signs:** Config not loaded when binary is run from a subdirectory of the project root.

### Pitfall 5: HTML Template Missing Duplication Section
**What goes wrong:** The HTML report omits the duplication section when duplication results are present.
**Why it happens:** Incomplete template — the Zig HTML source includes a `duplication-section` div with clone-table and dup-file-list components that are conditionally rendered.
**How to avoid:** Extract the full Zig CSS + JS constants verbatim. The minijinja template must include a conditional block for the duplication section.
**Warning signs:** HTML report missing the duplication table when `--duplication` is used.

### Pitfall 6: `--fail-on` Flag Semantics
**What goes wrong:** `fail_on_warnings` logic applied incorrectly — warnings cause exit 2 even when `--fail-on` is not set.
**Why it happens:** Default behavior is to only exit non-zero on errors. `--fail-on warning` enables warning failures. `--fail-on none` disables all failures.
**How to avoid:** Parse `--fail-on` string at runtime: "warning" → `fail_on_warnings = true`; "none" → override error/warning counting to success; "error" or absent → default behavior.
**Warning signs:** Binary returns exit code 2 when no `--fail-on` flag is passed but warnings exist.

### Pitfall 7: Missing `--init` Subcommand Behavior
**What goes wrong:** `--init` flag is listed in the help but not implemented, causing a panic or silent no-op.
**Why it happens:** init.zig has interactive config setup logic not yet ported.
**How to avoid:** For v0.8, implement `--init` as a stub that prints "Interactive config setup not yet implemented in v0.8." and exits 0. Full implementation is out of scope per REQUIREMENTS.md (no INIT-xx requirement listed).

## Code Examples

### Complete Config Default Values
From config.zig `defaults()`:
```rust
pub fn config_defaults() -> Config {
    Config {
        output: Some(OutputConfig {
            format: Some("console".to_string()),
            file: None,
        }),
        analysis: Some(AnalysisConfig {
            metrics: Some(vec![
                "cyclomatic".to_string(),
                "cognitive".to_string(),
                "halstead".to_string(),
                "nesting".to_string(),
                "line_count".to_string(),
                "params_count".to_string(),
            ]),
            thresholds: None,
            no_duplication: Some(false),
            duplication_enabled: Some(false),
            threads: None,  // None = use CPU count
        }),
        files: None,
        weights: Some(WeightsConfig {
            cognitive: Some(0.30),
            cyclomatic: Some(0.20),
            duplication: Some(0.20),
            halstead: Some(0.15),
            structural: Some(0.15),
        }),
        overrides: None,
        baseline: None,
    }
}
```

### JSON Output Schema (exact field names from json_output.zig)
```json
{
  "version": "1.0.0",
  "timestamp": 1234567890,
  "summary": {
    "files_analyzed": 1,
    "total_functions": 5,
    "warnings": 0,
    "errors": 0,
    "status": "pass",
    "health_score": 95.2
  },
  "files": [{
    "path": "src/foo.ts",
    "functions": [{
      "name": "myFunc",
      "start_line": 10,
      "end_line": 25,
      "start_col": 0,
      "cyclomatic": 3,
      "cognitive": 2,
      "halstead_volume": 45.0,
      "halstead_difficulty": 3.5,
      "halstead_effort": 157.5,
      "halstead_bugs": 0.015,
      "nesting_depth": 1,
      "line_count": 15,
      "params_count": 2,
      "health_score": 88.0,
      "status": "ok"
    }],
    "file_length": 100,
    "export_count": 3
  }],
  "metadata": {
    "elapsed_ms": 45,
    "thread_count": 8
  },
  "duplication": null
}
```

### Config File Auto-Discovery Order
From discovery.zig, the search checks these filenames in order:
1. `.complexityguard.json`
2. `complexityguard.config.json`
3. `.complexityguard.toml`
4. `complexityguard.config.toml`

For v0.8, only JSON needs to be supported (no TOML requirement in REQUIREMENTS.md). The upward search stops at a `.git` directory boundary. Fallback to XDG config dir (`$XDG_CONFIG_HOME/complexityguard/config.json`).

### SARIF Schema URL and Version Constants
```rust
const SARIF_SCHEMA: &str =
    "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json";
const SARIF_VERSION: &str = "2.1.0";
const TOOL_NAME: &str = "ComplexityGuard";
const TOOL_VERSION: &str = env!("CARGO_PKG_VERSION");
const TOOL_INFO_URI: &str = "https://github.com/benvds/complexity-guard";
```

### Console Output Format (ESLint-style)
From console.zig, the output format is:
```
src/example.ts
  10:0  warning  Cyclomatic complexity 12 exceeds warning threshold 10  complexity-guard/cyclomatic
  25:4  error    Cognitive complexity 31 exceeds error threshold 30     complexity-guard/cognitive

1 file, 2 functions, 1 warning, 1 error
Health score: 72.4
```

Key formatting rules:
- File path line: no color, just the path
- Violation line: `  {line}:{col}  {level}  {message}  {rule-id}`
  - Line/col in dim/muted color
  - "warning" in yellow, "error" in red
  - Rule ID in dim/muted color
- Summary line: bold counts
- Health score: color by value (green >= 80, yellow >= 60, red < 60)
- Verbose mode: shows all functions including ok ones
- Quiet mode: errors only

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Zig hand-rolled arg parser (400 lines) | clap 4.5 derive (struct + annotations) | Phase 19 | ~380 lines eliminated |
| Zig hand-rolled JSON serialization | serde Serialize derive + serde_json | Phase 19 | All manual serialization eliminated |
| Zig hand-rolled ANSI codes | owo-colors | Phase 19 | NO_COLOR support, zero-allocation |
| serde-sarif (considered) | Hand-rolled SARIF structs | Phase 19 planning | More stable, pre-1.0 concern avoided |

## Open Questions

1. **TOML config support in v0.8**
   - What we know: Zig supports both JSON and TOML config files. REQUIREMENTS.md only mentions `.complexityguard.json`. CLI-02 says "same schema" but doesn't specify format support.
   - What's unclear: Does v0.8 need to load `.complexityguard.toml` files as well?
   - Recommendation: Implement JSON only for v0.8 — if a TOML file is found during discovery, skip it and continue searching. Log a debug note if verbose. TOML support can be added in a subsequent phase via the `toml` crate.

2. **`--metrics` flag value parsing**
   - What we know: In Zig, `--metrics` takes a comma-separated string (e.g., `"cyclomatic,cognitive"`). The merge step passes the raw string to analysis config.
   - What's unclear: Whether the Rust implementation should parse the comma-separated string into `Vec<String>` at clap parse time or at config merge time.
   - Recommendation: Parse comma-separated at merge time, consistent with how the Zig code passes the raw string through config.

3. **`--baseline` flag behavior**
   - What we know: The `--baseline` flag takes a file path to a baseline JSON file for ratchet enforcement. The config also has a `baseline: ?f64` field for a score.
   - What's unclear: Phase 19 should implement exit code logic for baseline failure but may not need full baseline file loading — that depends on whether Phase 18 output includes the project health score accessible at this stage.
   - Recommendation: Implement `--fail-health-below N` (numeric threshold) which maps to `baseline_failed` in exit code logic. The `--baseline` file-based ratchet can be stubbed to always pass in v0.8 if it is too complex.

## Sources

### Primary (HIGH confidence)
- `/Users/benvds/code/complexity-guard/src/cli/args.zig` — All 28 CLI flags with exact names, short aliases, and types inspected directly
- `/Users/benvds/code/complexity-guard/src/cli/config.zig` — Complete Config schema with all six top-level sections, defaults(), validation logic
- `/Users/benvds/code/complexity-guard/src/cli/merge.zig` — mergeArgsIntoConfig() exact override logic
- `/Users/benvds/code/complexity-guard/src/cli/discovery.zig` — Config file search order and upward-search-to-.git logic
- `/Users/benvds/code/complexity-guard/src/cli/help.zig` — Exact help text, shouldUseColor() logic with env var priority
- `/Users/benvds/code/complexity-guard/src/output/exit_codes.zig` — determineExitCode() with full priority order and all helper functions
- `/Users/benvds/code/complexity-guard/src/output/json_output.zig` — Complete JsonOutput schema with exact field names
- `/Users/benvds/code/complexity-guard/src/output/sarif_output.zig` — 11 SARIF rule definitions, all camelCase field names, SarifLog structure
- `/Users/benvds/code/complexity-guard/src/output/html_output.zig` — CSS (~235 lines) and JS embedded constants, HTML template structure
- `/Users/benvds/code/complexity-guard/src/output/console.zig` — ESLint-style output format, Verbosity enum, color logic
- `/Users/benvds/code/complexity-guard/rust/src/types.rs` — Existing Rust type definitions (FunctionAnalysisResult, FileAnalysisResult)
- `/Users/benvds/code/complexity-guard/rust/Cargo.toml` — Current dependencies (serde, serde_json, thiserror, anyhow present; clap, owo-colors, minijinja absent)
- `/Users/benvds/code/complexity-guard/.planning/STATE.md` — serde-sarif 0.8.x flagged as pre-1.0 concern; fallback is hand-rolled structs

### Secondary (MEDIUM confidence)
- `.planning/research/STACK.md` — Stack research confirming clap 4.5, owo-colors 4.x, minijinja 2.x as standard choices
- `.planning/research/SUMMARY.md` — Architecture patterns for CLI/output module structure

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all crates already identified in STACK.md research; verified against existing Cargo.toml
- Architecture: HIGH — directly derived from reading Zig source code; no speculation required
- Pitfalls: HIGH — SARIF camelCase, JSON field names, and float precision issues all identified from direct source inspection; STATE.md confirms serde-sarif concern

**Research date:** 2026-02-24
**Valid until:** 2026-03-24 (stable Rust crates; SARIF schema is frozen at 2.1.0)
