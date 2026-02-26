---
phase: quick-30
plan: 01
subsystem: pipeline, metrics, output
tags: [safety, size-guard, skipped-items, output-formats]
dependency_graph:
  requires: []
  provides: [size guards, SkippedItem type, skipped list in all output formats]
  affects: [pipeline/parallel.rs, metrics/mod.rs, all output renderers, main.rs]
tech_stack:
  added: []
  patterns: [parallel map with FileOutcome enum, continue-based filtering in merge loop]
key_files:
  created: []
  modified:
    - src/types.rs
    - src/pipeline/parallel.rs
    - src/metrics/mod.rs
    - src/main.rs
    - src/output/console.rs
    - src/output/json_output.rs
    - src/output/sarif_output.rs
    - src/output/html_output.rs
    - src/output/assets/report.html
    - docs/cli-reference.md
    - docs/getting-started.md
    - docs/examples.md
    - README.md
    - publication/npm/README.md
decisions:
  - FileOutcome enum used in parallel pipeline to cleanly separate skipped vs analyzed vs error outcomes
  - Function-level size guard uses `continue` in the merge loop rather than index-based filtering, keeping the code simple
  - JSON skipped array omitted entirely (not null) when empty, using skip_serializing_if
  - SARIF uses "note" level for skipped items, added as rule index 11 (complexity-guard/skipped)
  - File line count uses raw byte counting (iter().filter(b'\n').count() + 1) before parsing
metrics:
  duration: 10 min
  completed: 2026-02-26
  tasks: 2
  files: 14
---

# Quick Task 30: Add Size Guards to Skip Files > 10,000 Lines and Functions > 5,000 Lines

**One-liner:** File and function size guards with SkippedItem tracking surfaced in all four output formats (console, JSON, SARIF, HTML) using a FileOutcome enum pattern in the parallel pipeline.

## What Was Built

Added fail-safe size limits to protect against stack overflows, excessive memory use, and runaway analysis times on pathologically large files (e.g., auto-generated code, minified bundles, TypeScript compiler checker.ts).

### New Types (src/types.rs)

- `MAX_FILE_LINES = 10_000` — file line limit constant
- `MAX_FUNCTION_LINES = 5_000` — function line limit constant
- `SkipReason` enum with `FileTooLarge { lines, max_lines }` and `FunctionTooLarge { lines, max_lines }` variants
- `SkippedItem` struct with `path`, `function_name`, `start_line`, and `reason`

### Pipeline Size Guard (src/pipeline/parallel.rs)

Changed `analyze_files_parallel` return type from `(Vec<FileAnalysisResult>, bool)` to `(Vec<FileAnalysisResult>, bool, Vec<SkippedItem>)`.

Added `FileOutcome` enum (`Analyzed(Result<...>)` or `Skipped(SkippedItem)`) inside the parallel map closure. Each worker reads the file bytes, counts `\n` characters, and short-circuits with a `SkippedItem` if `line_count > MAX_FILE_LINES`. The final partition loop collects all three categories.

### Metrics Size Guard (src/metrics/mod.rs)

Changed `analyze_file` return type from `Result<FileAnalysisResult, ParseError>` to `Result<(FileAnalysisResult, Vec<SkippedItem>), ParseError>`.

After computing all metric results, the merge loop checks `struc.function_length > MAX_FUNCTION_LINES` and emits a `SkippedItem` with `continue` instead of merging the function. This keeps all other functions in sync without index manipulation.

### Output Renderers

All four renderers updated to accept `skipped: &[SkippedItem]`:

- **console**: Renders a yellow "Skipped (N items):" section after the verdict. Summary line shows `(N skipped)` when non-zero.
- **json**: Added `JsonSkippedItem` struct, `skipped: Option<Vec<JsonSkippedItem>>` field to `JsonOutput` (omitted when empty), and `skipped_count: usize` to `JsonSummary`.
- **sarif**: Added `complexity-guard/skipped` as rule index 11 with `"note"` default level. Skipped items emit note-level SARIF results. Rule count is now 12.
- **html**: Added `skipped_ctx` built from the slice, passed to minijinja template. Template renders a conditional "Skipped Items" table section.

### Documentation

- `docs/cli-reference.md`: New "Size Limits" section with table, per-format behavior, and --exclude usage example
- `docs/getting-started.md`: Brief note in "Your First Analysis" section with link to CLI reference
- `docs/examples.md`: "Large File Safety Limits" section with console and JSON output examples
- `README.md`: Added safety limits bullet to features list
- `publication/npm/README.md`: Mirrored README.md change

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Size guards in types, pipeline, metrics, and main | a075e3c |
| 2 | Output renderers + documentation | b8da1c8 |

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

All key files verified present. Both commits verified in git log.

| Check | Result |
|-------|--------|
| src/types.rs | FOUND |
| src/pipeline/parallel.rs | FOUND |
| src/metrics/mod.rs | FOUND |
| src/output/console.rs | FOUND |
| docs/cli-reference.md | FOUND |
| 30-SUMMARY.md | FOUND |
| commit a075e3c | FOUND |
| commit b8da1c8 | FOUND |
