# Phase 21: Integration Testing and Behavioral Parity - Research

**Researched:** 2026-02-24
**Domain:** Rust binary integration testing, Zig-vs-Rust behavioral parity, snapshot comparison patterns, float tolerance validation
**Confidence:** HIGH

## Summary

Phase 21 is a validation phase: write integration tests that run the Rust binary (`rust/target/release/complexity-guard`) against every fixture file and compare output to the Zig v1.0 baseline (`zig-out/bin/complexity-guard`). Research was conducted by directly running both binaries against the full fixture set and diffing outputs field by field.

The critical finding from this research is that **several real deviations exist today** that the integration tests will catch and that must be fixed as part of this phase. These are not hypothetical — they are confirmed by running both binaries. The deviations fall into two categories: (1) bugs that must be fixed for true parity, and (2) legitimate v0.8 differences that must be documented and tested with explicit tolerances.

**Primary recommendation:** Record Zig v1.0 JSON output as committed baseline files (`rust/tests/fixtures/baselines/*.json`), write Rust integration tests that parse these baselines and compare per-field with appropriate tolerances, fix the identified bugs (cognitive complexity off by 3 in async_patterns.ts, health score threshold mismatch, function naming gaps, duplication JSON schema), then confirm exit codes.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PARSE-01 | Binary parses TypeScript files using tree-sitter-typescript | Already complete (Phase 17). Integration tests validate end-to-end behavior including metrics from parsed TypeScript |
| PARSE-02 | Binary parses TSX files using tree-sitter-typescript | Already complete. Integration tests cover react_component.tsx fixture |
| PARSE-03 | Binary parses JavaScript files using tree-sitter-javascript | Already complete. Integration tests cover express_middleware.js fixture |
| PARSE-04 | Binary parses JSX files using tree-sitter-javascript | Already complete. Integration tests cover jsx_component.jsx fixture |
| PARSE-05 | Parser extracts function declarations with name, line, column | Integration tests verify function names, start_line, start_col match Zig baseline |
| METR-01 | Cyclomatic complexity matches Zig output for all fixture files | Manual diff confirmed: cyclomatic matches across all fixtures tested |
| METR-02 | Cognitive complexity matches Zig output including per-operator deviation | **Bug confirmed**: async_patterns.ts: Zig=15, Rust=18 (+3 deviation); all other fixtures match |
| METR-03 | Halstead metrics match Zig output within float tolerance | Values match numerically; JSON serialization differs (Zig: `2`, Rust: `2.0`); tests must use float comparison not string equality |
| METR-04 | Structural metrics (length, params, nesting, exports) match Zig output | All structural metrics confirmed matching; JSON comparison must use numeric equality |
| METR-05 | Duplication detection matches Zig clone groups | duplication_percentage matches (81.99...); but JSON schema differs — Zig has richer nested schema |
| METR-06 | Composite health score matches Zig output within float tolerance | **Bug confirmed**: health_score differs (simple_function.ts: Zig=82.71, Rust=79.38) — root cause: cognitive_error default=30 in Rust ResolvedConfig vs 25 in Zig |
| CLI-01 | Same CLI flags as Zig binary | Integration tests exercise all key flags: --format, --fail-on, --duplication, --threads, --config |
| CLI-02 | .complexityguard.json config loading | Integration tests include a temp-directory config-file test |
| CLI-03 | CLI flags override config values | Integration test verifies override semantics |
| OUT-01 | Console output matches Zig ESLint-style format | **Significant format difference confirmed** — see Console Format Deviation section below |
| OUT-02 | JSON output matches Zig schema (field names, structure) | Field names match; Halstead floats and health_score values differ; duplication sub-schema differs |
| OUT-03 | SARIF 2.1.0 output accepted by GitHub Code Scanning | Schema URL and relatedLocations presence differ; SARIF validation must cover both |
| OUT-04 | HTML report is self-contained | Integration test runs HTML renderer and checks for no external URLs |
| OUT-05 | Exit codes 0-4 match Zig semantics | Codes 0, 1, 2, 3 confirmed matching; code 4 needs a forced parse-fail test |
| PIPE-01 | Recursive directory scanning with glob exclusion | Covered by existing pipeline tests; integration test should verify directory run |
| PIPE-02 | Parallel file analysis with configurable thread count | Integration test with --threads 1 vs --threads 4 (determinism) |
| PIPE-03 | Deterministic output ordering (sorted by path) | Integration test runs same input twice and diffs output order |
</phase_requirements>

## Known Deviations (Confirmed by Research)

These are confirmed differences between Zig v1.0 output and Rust v0.8 output as of Phase 20. Phase 21 must triage each as either "fix" or "accept and document."

### Deviation 1: Cognitive Complexity — async_patterns.ts (BUG — MUST FIX)

**Confirmed:** `fetchUserData` function: Zig=15, Rust=18 (difference of 3).

**Fixture:** `tests/fixtures/typescript/async_patterns.ts`

The function contains `.then(r => {...})` and `.catch(() => [...])` arrow callbacks chained on promise calls. The Rust visitor counts three extra increments that the Zig visitor does not. Likely cause: the Rust `visit_arrow_callback()` increments for arrow functions used as `.then()` / `.catch()` method call arguments, but the Zig implementation applies different rules for short expression-body arrows in method chains.

**Resolution for Phase 21:** Fix the Rust cognitive complexity visitor to match Zig output (15), then add a dedicated test for this fixture pinning the value.

### Deviation 2: Health Score Values (BUG — ROOT CAUSE IN THRESHOLD DEFAULTS)

**Confirmed:** All functions show lower health scores in Rust than Zig.

- simple_function.ts `greet`: Zig=82.71, Rust=79.38
- cognitive_cases.ts overall: Zig=77.81, Rust=74.62

**Root cause identified:** `rust/src/cli/config.rs` `ResolvedConfig::default()` has `cognitive_error: 30`, but `ScoringThresholds::default()` has `cognitive_error: 25.0`. The `build_analysis_config()` in `main.rs` uses `resolved.cognitive_error as f64` to populate `scoring_thresholds.cognitive_error`, so the scoring sigmoid uses `k = ln(4)/(30-15) = 0.0924` instead of the correct `k = ln(4)/(25-15) = 0.1386`. This makes scores appear higher in Zig (steeper sigmoid = higher score at low values).

**Resolution for Phase 21:** Change `cognitive_error` in `ResolvedConfig::default()` from 30 to 25 to match Zig. Then verify all health scores converge.

### Deviation 3: JSON Float Serialization (ACCEPT — DOCUMENT)

**Confirmed:** Zig serializes whole-number floats as integers (`2`, `8`, `0`), Rust serializes them as floats (`2.0`, `8.0`, `0.0`).

```
Zig:  "halstead_volume": 8
Rust: "halstead_volume": 8.0
```

Both are valid JSON. JSON parsers treat them identically. This is a serde serialization behavior difference, not a metric difference.

**Resolution for Phase 21:** Integration tests must compare float fields using numeric equality (parse JSON then compare `f64` values) rather than string equality. Document this tolerance explicitly in test code comments.

**Float tolerance definition:** `1e-9` (nine decimal places) for all Halstead metrics (volume, difficulty, effort, bugs) and health_score.

### Deviation 4: Console Output Format (SIGNIFICANT DIFFERENCE — INVESTIGATE SCOPE)

**Confirmed:** Zig and Rust console formats are substantially different.

Zig format (consolidated per-function):
```
/path/to/file.ts
  5:7  ✗  error  Function 'processData' cyclomatic 11 cognitive 35 [halstead vol 299] [depth 7]

Analyzed 1 files, 1 functions
Health: 34
Found 0 warnings, 1 errors

Top cyclomatic hotspots:
  1. processData (...) complexity 11
...
✗ 1 problems (1 error, 0 warnings)
```

Rust format (individual per-metric violations):
```
/path/to/file.ts
  5:7  warning  Cyclomatic complexity 11 exceeds warning threshold 10  complexity-guard/cyclomatic
  5:7  error  Cognitive complexity 35 exceeds error threshold 30  complexity-guard/cognitive
  5:7  warning  Halstead difficulty 11.3 exceeds warning threshold 10.0  complexity-guard/halstead-difficulty
  5:7  error  Nesting depth 7 exceeds error threshold 5  complexity-guard/nesting-depth

1 file, 1 function, 2 warnings, 2 errors
Health score: 36.9
```

The Rust format also shows different violation counts (2 warnings + 2 errors vs 0 warnings + 1 error) because Rust reports each metric as an individual violation while Zig consolidates per function.

**This is a significant format parity gap.** Requirement OUT-01 requires console output to match the Zig ESLint-style format. The Rust format is completely different and would cause failures in any tooling that scrapes the console output.

**Resolution for Phase 21:** Either (a) fix the Rust console renderer to match Zig format exactly (requires rewriting `src/output/console.rs`), or (b) defer this to Phase 22 and document explicitly. Given that OUT-01 is a stated requirement for this milestone, this MUST be fixed. The console renderer must be rewritten in this phase.

### Deviation 5: Duplication JSON Schema (BUG — MUST FIX)

**Confirmed:** Zig and Rust use different JSON structures for the `duplication` field.

Zig schema:
```json
{
  "duplication": {
    "enabled": true,
    "project_duplication_pct": 81.99,
    "project_status": "error",
    "clone_groups": [{"token_count": 25, "locations": [...]}],
    "files": [{"path": "...", "total_tokens": 211, "cloned_tokens": 173, "duplication_pct": 81.99, "status": "error"}]
  }
}
```

Rust schema:
```json
{
  "duplication": {
    "total_tokens": 211,
    "cloned_tokens": 173,
    "duplication_percentage": 81.99,
    "clone_groups": [{"instances": [...], "token_count": 25}]
  }
}
```

The schemas are entirely different. The `duplication_percentage` value itself matches (81.99...) but everything else differs: field names, nesting, presence of `enabled`/`project_status`/`files` array, `clone_groups.locations` vs `clone_groups.instances`.

**Resolution for Phase 21:** Rewrite the Rust duplication JSON output to match the Zig schema exactly.

### Deviation 6: Function Naming — naming-edge-cases.ts (BUG — INVESTIGATE)

**Confirmed:** Zig extracts richer names for some patterns, Rust returns `<anonymous>`:

```
Zig:   "map callback", "forEach callback", "click handler", "default export"
Rust:  "<anonymous>", "<anonymous>", "<anonymous>", "<anonymous>"
```

Object literal method `process` is also missing in Rust output; `obj` is reported instead.

**Resolution for Phase 21:** Investigate and fix the Rust function name extraction for these patterns in the naming-edge-cases fixture. This affects PARSE-05.

### Deviation 7: SARIF Schema URL and relatedLocations (ACCEPT — DOCUMENT)

Zig uses `https://json.schemastore.org/sarif-2.1.0.json` (community schema store), Rust uses the raw OASIS TC URL. Both are valid SARIF 2.1.0 schemas. Both should be accepted by GitHub Code Scanning.

Zig includes `relatedLocations` in each result; Rust does not. This is a minor feature difference.

**Resolution for Phase 21:** Document both schema URLs as acceptable. SARIF test validates the structural schema (tool.driver, results[].ruleId, results[].level, results[].locations) — not schema URL equality.

### Deviation 8: JSON version Field (ACCEPT)

Zig outputs `"version": "1.0.0"`, Rust outputs `"version": "0.8.0"`. These reflect their respective binary versions and are correct. Integration tests must ignore or explicitly allow this field difference.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `assert_cmd` | 2.1.2 | Run a CLI binary process in tests, capture stdout/stderr/exit code | The standard Rust crate for CLI integration testing; supports `Command::cargo_bin()` for test binary resolution |
| `predicates` | 3.1.4 | Composable assertion predicates for assert_cmd | Used with assert_cmd for exit code and output assertions |
| `serde_json` | 1.x (already in Cargo.toml) | Parse JSON output from binary for per-field comparison | Already present; `serde_json::Value` enables field-by-field traversal |
| `tempfile` | 3 (already in dev-dependencies) | Create temporary directories for config file tests | Already present for discovery tests |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `insta` | 1.46.3 | Snapshot testing with updateable snapshots | Optional: useful if test author wants automated snapshot updates; adds complexity. **Not recommended** for this phase — manual JSON baseline files are simpler and more transparent |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `assert_cmd` for process invocation | `std::process::Command` directly | `std::process::Command` works but requires manual path resolution to binary; assert_cmd's `cargo_bin()` handles this cleanly |
| Manual JSON baseline files | `insta` snapshots | insta adds a snapshot update workflow that is elegant but requires developers to install `cargo insta`; manual JSON files are simpler for a small fixed fixture set |
| Float field-by-field comparison | String equality of JSON output | String equality breaks on float formatting differences (2 vs 2.0) and timestamp fields; field-by-field is required |

**Installation:**
```bash
# Add to [dev-dependencies] in rust/Cargo.toml:
assert_cmd = "2"
predicates = "3"
```

## Architecture Patterns

### Recommended Project Structure

```
rust/tests/
├── parser_tests.rs              # existing — parser-level tests
├── integration_tests.rs         # NEW — end-to-end binary tests
└── fixtures/
    └── baselines/               # NEW — recorded Zig v1.0 JSON output
        ├── simple_function.json
        ├── cognitive_cases.json
        ├── cyclomatic_cases.json
        ├── halstead_cases.json
        ├── structural_cases.json
        ├── async_patterns.json
        ├── class_with_methods.json
        ├── complex_nested.json
        ├── duplication_cases.json
        ├── react_component.json
        ├── express_middleware.json
        ├── jsx_component.json
        └── callback_patterns.json
```

Baselines are recorded from the Zig binary **after the bugs are fixed** (i.e., after cognitive complexity and health score bugs are resolved). They capture what the Rust binary SHOULD output.

### Pattern 1: assert_cmd Binary Integration Test

```rust
// Source: assert_cmd 2.x standard usage
use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn test_simple_function_exit_zero() {
    Command::cargo_bin("complexity-guard")
        .unwrap()
        .arg("--format").arg("json")
        .arg(fixture_path("typescript/simple_function.ts"))
        .assert()
        .success()
        .code(0);
}

#[test]
fn test_errors_cause_exit_one() {
    Command::cargo_bin("complexity-guard")
        .unwrap()
        .arg(fixture_path("typescript/complex_nested.ts"))
        .assert()
        .failure()
        .code(1);
}
```

### Pattern 2: JSON Field Comparison with Float Tolerance

```rust
fn compare_function_metrics(actual: &serde_json::Value, baseline: &serde_json::Value) {
    // Integer fields: exact equality
    assert_eq!(
        actual["cyclomatic"].as_u64(),
        baseline["cyclomatic"].as_u64(),
        "cyclomatic mismatch for {}",
        actual["name"]
    );

    // Float fields: tolerance comparison
    let tol = 1e-9;
    let actual_vol = actual["halstead_volume"].as_f64().unwrap();
    let baseline_vol = baseline["halstead_volume"].as_f64().unwrap();
    assert!(
        (actual_vol - baseline_vol).abs() <= tol,
        "halstead_volume mismatch: actual={} baseline={} (tolerance={})",
        actual_vol, baseline_vol, tol
    );
}
```

### Pattern 3: Exit Code Parity Scenarios

Each exit code needs at least one explicit test:
- **Code 0:** `simple_function.ts` with default thresholds → success
- **Code 1:** `complex_nested.ts` with default thresholds → errors found
- **Code 2:** `cognitive_cases.ts` with `--fail-on warning` → warnings found
- **Code 3:** `--config /nonexistent/path.json` → config error
- **Code 4:** Requires a file that causes a genuine tree-sitter parse failure. Note: `syntax_error.ts` does NOT trigger exit 4 — tree-sitter is error-tolerant. A test may need to verify that a completely unreadable file (permission error or binary file) triggers exit 4, OR document that exit 4 is currently unreachable in practice and add a dedicated fixture.

### Anti-Patterns to Avoid

- **String-comparing full JSON output:** Will fail on timestamp, float serialization, and version fields. Always parse JSON and compare fields.
- **Hardcoding expected float values as string literals:** Use `1e-9` numeric comparison.
- **Testing against live Zig binary output at test runtime:** The Zig binary may not exist in CI. Baselines must be committed files.
- **Running the Zig binary in Rust tests:** The Zig binary is a separate tool; tests compare against committed baseline files, not against a live Zig process.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Running the binary in tests | `std::process::Command` with manual path | `assert_cmd::Command::cargo_bin()` | cargo_bin resolves to the correct test binary automatically; handles target directory |
| Temporary config files | Manual `std::fs::write` + path | `tempfile::NamedTempFile` | Already in dev-deps; handles cleanup |
| JSON field access | Custom traversal functions | `serde_json::Value` indexing | `value["key"]` and `value.as_f64()` cover all cases |

## Common Pitfalls

### Pitfall 1: Timestamp Fields in JSON Comparison

**What goes wrong:** JSON output includes `"timestamp"` (Unix epoch seconds) and `"metadata.elapsed_ms"` which differ between runs.
**Why it happens:** Both are generated at runtime, not from fixture content.
**How to avoid:** Exclude `timestamp` and `metadata.elapsed_ms` from baseline comparison. Compare only `summary`, `files[*].functions[*]` metrics, and `duplication`.

### Pitfall 2: Float Serialization Breaking String Comparison

**What goes wrong:** Zig outputs `"halstead_volume": 2` (no decimal), Rust outputs `"halstead_volume": 2.0`. String comparison fails.
**Why it happens:** Different JSON serializers handle whole-number floats differently.
**How to avoid:** Parse JSON to `serde_json::Value`, then use `.as_f64()` for numeric comparison.

### Pitfall 3: Health Score Divergence from Threshold Default Bug

**What goes wrong:** Even after fixing the cognitive threshold default, health scores may still differ slightly due to floating point accumulation differences between Zig's @exp and Rust's f64::exp.
**Why it happens:** IEEE 754 allows implementations to produce slightly different results for transcendental functions.
**How to avoid:** Use `1e-6` tolerance for health scores (not `1e-9`). Capture actual Rust outputs as the baseline (not Zig outputs) for health score fields once the threshold bug is fixed.

### Pitfall 4: Exit Code 4 Is Currently Unreachable

**What goes wrong:** Trying to trigger exit code 4 with tree-sitter-recoverable syntax errors (like `syntax_error.ts`) produces exit code 0, not 4.
**Why it happens:** Tree-sitter recovers from most syntax errors and produces a tree with ERROR nodes. The `error` field in file output is not set by syntax errors alone.
**How to avoid:** Test exit code 4 with a file that fails at the OS level (e.g., permission denied, binary file that causes parse failure) or create a dedicated fixture. Document this limitation explicitly.

### Pitfall 5: Duplication Tests Require --duplication Flag

**What goes wrong:** Running without `--duplication` flag produces `"duplication": null`. Tests comparing duplication output must pass `--duplication`.
**Why it happens:** Duplication detection is opt-in (disabled by default).
**How to avoid:** Integration tests for duplication always include `--duplication` flag.

### Pitfall 6: Console Format Comparison is Fragile

**What goes wrong:** Console output includes color codes when stdout is a TTY, paths that are absolute and machine-specific, and floating point health scores that vary.
**Why it happens:** owo-colors checks isatty; absolute paths depend on test runner location.
**How to avoid:** Always pass `--no-color` in integration tests. Use substring matching for console tests, not full-string equality. Prefer JSON output tests for metric verification.

## Code Examples

### Baseline Recording Script Pattern

```bash
#!/usr/bin/env bash
# Record Zig v1.0 baseline outputs after bug fixes are applied
FIXTURES="tests/fixtures"
BASELINES="rust/tests/fixtures/baselines"
ZIG_BIN="zig-out/bin/complexity-guard"

for ts_file in "$FIXTURES/typescript"/*.ts "$FIXTURES/typescript"/*.tsx; do
    base=$(basename "$ts_file" | sed 's/\.[^.]*$//')
    "$ZIG_BIN" --format json "$ts_file" > "$BASELINES/${base}.json"
done
```

### Integration Test File Structure

```rust
// rust/tests/integration_tests.rs
use assert_cmd::Command;
use serde_json::Value;

fn cargo_bin() -> Command {
    Command::cargo_bin("complexity-guard").unwrap()
}

fn fixture_path(relative: &str) -> std::path::PathBuf {
    std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .join("tests")
        .join("fixtures")
        .join(relative)
}

fn baseline_path(name: &str) -> std::path::PathBuf {
    std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests")
        .join("fixtures")
        .join("baselines")
        .join(name)
}

fn load_baseline(name: &str) -> Value {
    let content = std::fs::read_to_string(baseline_path(name)).unwrap();
    serde_json::from_str(&content).unwrap()
}

// Float comparison tolerance for Halstead metrics
const HALSTEAD_TOL: f64 = 1e-9;
// Float comparison tolerance for health scores (sigmoid accumulation)
const SCORE_TOL: f64 = 1e-6;
```

### Exit Code Tests Pattern

```rust
#[test]
fn exit_code_zero_clean_analysis() {
    cargo_bin()
        .args(["--format", "json", "--no-color"])
        .arg(fixture_path("typescript/simple_function.ts"))
        .assert()
        .success();
}

#[test]
fn exit_code_one_errors_found() {
    cargo_bin()
        .arg("--no-color")
        .arg(fixture_path("typescript/complex_nested.ts"))
        .assert()
        .code(1);
}

#[test]
fn exit_code_two_warnings_with_fail_on_warning() {
    cargo_bin()
        .args(["--fail-on", "warning", "--no-color"])
        .arg(fixture_path("typescript/cognitive_cases.ts"))
        .assert()
        .code(2);
}

#[test]
fn exit_code_three_bad_config_path() {
    cargo_bin()
        .args(["--config", "/nonexistent/path.json"])
        .arg(fixture_path("typescript/simple_function.ts"))
        .assert()
        .code(3);
}
```

## Open Questions

1. **How to trigger exit code 4 (ParseError)?**
   - What we know: tree-sitter is error-tolerant and recovers from syntax errors; `syntax_error.ts` exits 0 for both Zig and Rust.
   - What's unclear: Whether there is any input that actually triggers exit code 4. The `ParseError::IoError` and `ParseError::ParseFailed` variants exist in code but may never be reached.
   - Recommendation: Investigate what sets `has_parse_errors=true` in `pipeline/parallel.rs`. If exit 4 requires an IO error (unreadable file), create a test with a permission-denied scenario, or document that exit 4 maps to `ParseError::IoError` and test with a missing file path.

2. **Console format: fix or defer?**
   - What we know: Console format is significantly different (Zig: consolidated per-function, Rust: per-metric individual lines).
   - What's unclear: How much work is required to bring Rust console output to exact Zig parity.
   - Recommendation: Fix the console renderer in this phase — it is a stated requirement (OUT-01) and Phase 22 (release) requires parity. The fix requires rewriting `src/output/console.rs` to match the Zig `render_console()` format.

3. **Cognitive complexity async_patterns bug: exact cause**
   - What we know: Rust gives 18, Zig gives 15 for `fetchUserData`. The +3 is from `.then()` / `.catch()` arrow callbacks.
   - What's unclear: Exact rule difference. Zig may not count short expression-body arrow callbacks in method chains, while Rust's `visit_arrow_callback` always increments.
   - Recommendation: Debug by adding temporary logging to count increments, or compare AST traversal carefully for the `.then(r => r.json())` pattern.

4. **Duplication JSON schema fix scope**
   - What we know: Schemas are entirely different.
   - What's unclear: Whether any tooling currently depends on the Rust duplication schema format.
   - Recommendation: Rewrite to match Zig schema. No external tooling depends on the Rust format since it has never shipped.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `cargo test` with `assert_cmd` + `predicates` |
| Test file location | `rust/tests/integration_tests.rs` |
| Quick run command | `cargo test --manifest-path rust/Cargo.toml --test integration_tests -- --test-threads=4` |
| Full suite command | `cargo test --manifest-path rust/Cargo.toml` |
| Estimated runtime | ~5 seconds (binary invocations per fixture) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PARSE-01 | TS files parse and extract functions | integration | `cargo test --test integration_tests` | ❌ Wave 0 gap |
| PARSE-02 | TSX files parse | integration | `cargo test --test integration_tests` | ❌ Wave 0 gap |
| PARSE-03 | JS files parse | integration | `cargo test --test integration_tests` | ❌ Wave 0 gap |
| PARSE-04 | JSX files parse | integration | `cargo test --test integration_tests` | ❌ Wave 0 gap |
| PARSE-05 | Function names, lines, columns correct | integration | `cargo test --test integration_tests` | ❌ Wave 0 gap |
| METR-01 | Cyclomatic matches Zig baseline | integration | `cargo test --test integration_tests` | ❌ Wave 0 gap |
| METR-02 | Cognitive matches Zig baseline (per-operator deviation) | integration | `cargo test --test integration_tests :: cognitive_parity` | ❌ Wave 0 gap |
| METR-03 | Halstead within float tolerance | integration | `cargo test --test integration_tests` | ❌ Wave 0 gap |
| METR-04 | Structural metrics match | integration | `cargo test --test integration_tests` | ❌ Wave 0 gap |
| METR-05 | Duplication matches | integration | `cargo test --test integration_tests` | ❌ Wave 0 gap |
| METR-06 | Health score within tolerance | integration | `cargo test --test integration_tests` | ❌ Wave 0 gap |
| OUT-01 | Console format matches Zig | integration | `cargo test --test integration_tests :: console_format` | ❌ Wave 0 gap |
| OUT-02 | JSON schema matches Zig | integration | `cargo test --test integration_tests :: json_parity` | ❌ Wave 0 gap |
| OUT-03 | SARIF accepted by validator | integration (structural) | `cargo test --test integration_tests :: sarif_structure` | ❌ Wave 0 gap |
| OUT-04 | HTML self-contained | integration | `cargo test --test integration_tests :: html_selfcontained` | ❌ Wave 0 gap |
| OUT-05 | Exit codes 0-4 | integration | `cargo test --test integration_tests :: exit_codes` | ❌ Wave 0 gap |
| PIPE-01 | Directory scan with exclusion | integration | `cargo test --test integration_tests :: directory_scan` | ❌ Wave 0 gap |
| PIPE-02 | Parallel analysis with --threads | integration | `cargo test --test integration_tests :: threading` | ❌ Wave 0 gap |
| PIPE-03 | Deterministic output ordering | integration | `cargo test --test integration_tests :: ordering` | ❌ Wave 0 gap |

### Nyquist Sampling Rate

- **Minimum sample interval:** After every committed task → run: `cargo test --manifest-path rust/Cargo.toml --test integration_tests -- --test-threads=4`
- **Full suite trigger:** Before merging final task of any plan wave
- **Phase-complete gate:** Full suite green before verification runs
- **Estimated feedback latency per task:** ~5-10 seconds

### Wave 0 Gaps (must be created before implementation)

- [ ] `rust/tests/integration_tests.rs` — main integration test file (covers all REQs above)
- [ ] `rust/tests/fixtures/baselines/` directory — baseline JSON files recorded from Zig v1.0
- [ ] `rust/tests/fixtures/baselines/*.json` — one per fixture file (13 fixture files)
- [ ] Framework install: add `assert_cmd = "2"` and `predicates = "3"` to `[dev-dependencies]` in `rust/Cargo.toml`

## Sources

### Primary (HIGH confidence)
- Direct binary execution: both `zig-out/bin/complexity-guard` and `rust/target/release/complexity-guard` run against all fixture files, outputs diffed field-by-field
- `rust/src/cli/config.rs` — `ResolvedConfig::default()` cognitive_error: 30 confirmed
- `rust/src/types.rs` — `ScoringThresholds::default()` cognitive_error: 25.0 confirmed
- `rust/src/main.rs` — `build_analysis_config()` confirmed uses `resolved.cognitive_error` for scoring thresholds
- `src/metrics/scoring.zig` — `resolveEffectiveWeights()` confirmed normalizes 4-metric weights to sum 1.0
- `rust/tests/fixtures/baselines/` — does not yet exist (Wave 0 gap)

### Secondary (MEDIUM confidence)
- `assert_cmd` 2.1.2 — confirmed current version from crates.io API
- `predicates` 3.1.4 — confirmed current version from crates.io API
- `insta` 1.46.3 — confirmed current version; assessed as optional/not recommended

### Tertiary (LOW confidence)
- Exit code 4 reachability — TreeSitter error tolerance means syntax_error.ts exits 0; mechanism for triggering exit 4 not confirmed; needs investigation

## Metadata

**Confidence breakdown:**
- Known deviations: HIGH — all confirmed by running both binaries
- Standard stack: HIGH — assert_cmd/predicates are the standard for Rust CLI testing; confirmed versions
- Architecture: HIGH — baseline file approach is well-understood; float tolerance values derived from actual differences
- Wave 0 gaps: HIGH — no test infrastructure exists in `rust/tests/` beyond `parser_tests.rs`

**Research date:** 2026-02-24
**Valid until:** 2026-03-25 (30 days; deviations list is current to Phase 20 completion state)
