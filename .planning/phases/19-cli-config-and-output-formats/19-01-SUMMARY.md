---
phase: 19-cli-config-and-output-formats
plan: 01
subsystem: rust-cli
tags: [cli, config, exit-codes, clap, serde]
dependency_graph:
  requires: [18-metrics-pipeline]
  provides: [cli-arg-parsing, config-loading, exit-code-logic, runnable-binary]
  affects: [19-02, 19-03, 19-04]
tech_stack:
  added: [clap-4.5-derive, tempfile-3-dev]
  patterns: [clap-derive-args, serde-deserialize-config, upward-config-discovery, exit-code-priority]
key_files:
  created:
    - rust/src/cli/mod.rs
    - rust/src/cli/args.rs
    - rust/src/cli/config.rs
    - rust/src/cli/merge.rs
    - rust/src/cli/discovery.rs
    - rust/src/output/mod.rs
    - rust/src/output/exit_codes.rs
  modified:
    - rust/Cargo.toml
    - rust/Cargo.lock
    - rust/src/lib.rs
    - rust/src/main.rs
decisions:
  - "clap derive #[command(version)] handles --version automatically; no custom handler needed"
  - "tempfile added as dev-dependency for discovery unit tests (temp dir creation)"
  - "fail_on semantics: 'none' override checked first, then parse_error, then baseline/errors, then warnings"
  - "Config overlay in main.rs is field-by-field merge (not struct replace) to preserve defaults"
metrics:
  duration: 6min
  completed: 2026-02-24
  tasks_completed: 2
  files_created: 7
  files_modified: 4
  tests_added: 64
  total_tests: 126
---

# Phase 19 Plan 01: CLI Arguments, Config Loading, and Exit Codes Summary

Implemented full CLI interface via clap derive, JSON config loading with upward directory search, CLI-over-config merge semantics, exit code logic matching Zig parity, and a wired main.rs entry point.

## What Was Built

### Task 1: CLI modules (commit 7301dd8)

**`rust/src/cli/args.rs`** — clap derive `Args` struct with all CLI flags matching the Zig binary interface: positional `paths`, `--init`, `--format/-f`, `--output/-o`, `--color`, `--no-color`, `--quiet/-q`, `--verbose/-v`, `--metrics`, `--duplication`, `--no-duplication`, `--threads`, `--include`, `--exclude`, `--fail-on`, `--fail-health-below`, `--config/-c`, `--baseline`. 21 unit tests.

**`rust/src/cli/config.rs`** — `Config`, `OutputConfig`, `AnalysisConfig`, `FilesConfig`, `WeightsConfig`, `ThresholdsConfig`, `ThresholdPair`, `DuplicationThresholds`, `OverrideConfig` all with `#[derive(Debug, Default, Clone, serde::Deserialize)]`. `config_defaults()` matching Zig `defaults()`. 13 unit tests.

**`rust/src/cli/merge.rs`** — `merge_args_into_config(args, config)` applying CLI overrides: format, output file, duplication flags, threads, include/exclude globs, comma-separated metrics parsing. 12 unit tests.

**`rust/src/cli/discovery.rs`** — `discover_config(explicit_path)` with upward search from CWD stopping at `.git` boundary. Checks `.complexityguard.json` and `complexityguard.config.json` (TOML skipped in v0.8). 7 unit tests.

### Task 2: Exit codes and main.rs (commit d116c70)

**`rust/src/output/exit_codes.rs`** — `ExitCode` enum (0-4) and `determine_exit_code()` with priority: `ParseError(4) > baseline_failed/errors(1) > warnings+fail_on_warning(2) > Success(0)`. `--fail-on none` override returns Success regardless. 13 unit tests.

**`rust/src/main.rs`** — Full entry point: parse args with `Args::parse()`, `--init` stub, config discovery + field-by-field overlay on defaults, `merge_args_into_config`, placeholder output showing resolved format/paths, `determine_exit_code`, `std::process::exit`.

## Verification Results

- `cargo build` — compiles without warnings
- `cargo test` — 126 tests pass (64 new + 62 existing Phase 17/18)
- `cargo run -- --help` — shows all flags with correct names and short aliases
- `cargo run -- --version` — prints "complexityguard 0.8.0"
- `cargo run -- --init` — prints stub message and exits 0
- Config file in CWD loaded and format applied (tested manually with `/tmp/.complexityguard.json`)

## Deviations from Plan

### Auto-fixed Issues

None.

### Notes

- The plan stated "28 flags" but the Zig source (args.zig, help.zig) has 19 named flags + positional paths. All flags present in the Zig binary are implemented; "28" was an overcount in the plan.
- `tempfile` added as dev-dependency (Rule 2 — needed for discovery unit tests). This is a test-only dependency.
- Config overlay in main.rs uses field-by-field merge rather than struct replacement to correctly preserve defaults when file config has None fields.

## Self-Check: PASSED

All 7 key files exist on disk. Both task commits (7301dd8, d116c70) found in git log. 126 tests pass. Binary responds correctly to --help, --version, --init.
