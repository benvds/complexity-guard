---
phase: quick-30
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
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
  - README.md
  - publication/npm/README.md
autonomous: true
must_haves:
  truths:
    - "Files exceeding 10,000 lines are skipped from analysis and listed in output"
    - "Functions exceeding 5,000 lines are skipped from analysis and listed in output"
    - "All output formats (console, JSON, SARIF, HTML) include the skipped list when non-empty"
    - "Skipped files/functions do not cause crashes or panics"
    - "Analysis continues normally for non-skipped files/functions"
  artifacts:
    - path: "src/types.rs"
      provides: "SkippedItem struct and SkipReason enum"
    - path: "src/pipeline/parallel.rs"
      provides: "File-level size guard returning skipped list"
    - path: "src/metrics/mod.rs"
      provides: "Function-level size guard returning skipped functions"
    - path: "src/output/console.rs"
      provides: "Skipped section in console output"
    - path: "src/output/json_output.rs"
      provides: "Skipped array in JSON output"
  key_links:
    - from: "src/pipeline/parallel.rs"
      to: "src/main.rs"
      via: "skipped list returned alongside file results"
    - from: "src/main.rs"
      to: "src/output/*.rs"
      via: "skipped list passed to all renderers"
---

<objective>
Add fail-safe size guards to skip files larger than 10,000 lines and functions larger than 5,000 lines. Track skipped items in a list and surface them in all output formats (console, JSON, SARIF, HTML). This prevents stack overflows, excessive memory use, and runaway analysis times on pathologically large files (e.g., auto-generated code, minified bundles, the TypeScript compiler checker.ts).

Purpose: Protect against analysis crashes and timeouts on oversized files while maintaining full transparency about what was skipped and why.
Output: Updated binary with size guards, skipped list in all output formats, updated documentation.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@src/types.rs
@src/pipeline/parallel.rs
@src/metrics/mod.rs
@src/main.rs
@src/output/console.rs
@src/output/json_output.rs
@src/output/sarif_output.rs
@src/output/html_output.rs
@src/output/assets/report.html
@src/cli/config.rs

<interfaces>
<!-- Key types and contracts the executor needs -->

From src/types.rs:
```rust
pub struct FileAnalysisResult {
    pub path: PathBuf,
    pub functions: Vec<FunctionAnalysisResult>,
    pub tokens: Vec<Token>,
    pub file_score: f64,
    pub file_length: u32,
    pub export_count: u32,
    pub error: bool,
}

pub struct FunctionAnalysisResult {
    pub name: String,
    pub start_line: usize,
    pub end_line: usize,
    // ... (many metric fields)
    pub function_length: u32,
    // ...
}
```

From src/pipeline/parallel.rs:
```rust
pub fn analyze_files_parallel(
    paths: &[PathBuf],
    config: &AnalysisConfig,
    threads: u32,
) -> (Vec<FileAnalysisResult>, bool);
```

From src/metrics/mod.rs:
```rust
pub fn analyze_file(
    path: &Path,
    config: &AnalysisConfig,
) -> Result<FileAnalysisResult, ParseError>;
```

From src/output/ renderers (all take &[FileAnalysisResult]):
```rust
pub fn render_console(files: &[FileAnalysisResult], duplication: Option<&DuplicationResult>, config: &ResolvedConfig, writer: &mut dyn Write) -> anyhow::Result<()>;
pub fn render_json(files: &[FileAnalysisResult], duplication: Option<&DuplicationResult>, config: &ResolvedConfig, elapsed_ms: u64) -> anyhow::Result<String>;
pub fn render_sarif(files: &[FileAnalysisResult], duplication: Option<&DuplicationResult>, config: &ResolvedConfig) -> anyhow::Result<String>;
pub fn render_html(files: &[FileAnalysisResult], duplication: Option<&DuplicationResult>, config: &ResolvedConfig, elapsed_ms: u64) -> anyhow::Result<String>;
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add SkippedItem type and implement size guards in pipeline and metrics</name>
  <files>
    src/types.rs
    src/pipeline/parallel.rs
    src/metrics/mod.rs
    src/main.rs
  </files>
  <action>
1. **src/types.rs** -- Add new types at the end of the file (before tests):

```rust
/// Reason a file or function was skipped during analysis.
#[derive(Debug, Clone, serde::Serialize)]
pub enum SkipReason {
    /// File exceeded the maximum line count threshold.
    FileTooLarge { lines: usize, max_lines: usize },
    /// Function exceeded the maximum line count threshold.
    FunctionTooLarge { lines: u32, max_lines: u32 },
}

/// A file or function that was skipped during analysis.
#[derive(Debug, Clone, serde::Serialize)]
pub struct SkippedItem {
    /// File path (always present).
    pub path: PathBuf,
    /// Function name (None for file-level skips).
    pub function_name: Option<String>,
    /// Line number where the skipped item starts (1-indexed; 0 for file-level).
    pub start_line: usize,
    /// Why the item was skipped.
    pub reason: SkipReason,
}
```

Also add constants for the thresholds:
```rust
/// Maximum file line count before the file is skipped entirely.
pub const MAX_FILE_LINES: usize = 10_000;
/// Maximum function line count before the function is skipped.
pub const MAX_FUNCTION_LINES: u32 = 5_000;
```

2. **src/pipeline/parallel.rs** -- Modify `analyze_files_parallel` to:
   - Change return type to `(Vec<FileAnalysisResult>, bool, Vec<SkippedItem>)` (add third element).
   - Before sending a file path to `analyze_file`, read the file and count newlines. If line count > `MAX_FILE_LINES`, add a `SkippedItem` with `SkipReason::FileTooLarge` and do NOT analyze the file.
   - Implementation: Use `par_iter().map()` to return an enum `Either<FileAnalysisResult, SkippedItem>` (or a custom enum), then partition results. Actually, simpler approach: before the rayon parallel map, do a quick sequential pre-filter to split paths into (analyzable, skipped). The pre-filter reads each file and counts `\n` bytes (use `std::fs::read` + `bytecount::count` or `source.iter().filter(|&&b| b == b'\n').count() + 1`). This is fast because it's just I/O + byte counting, no parsing. Then only analyzable paths go into the parallel analysis.
   - Actually, even simpler: keep the parallel map, but inside each worker check the file size first. Change the map closure to: read the file bytes, count lines, if > MAX_FILE_LINES return a skip marker, else call `analyze_file`. Use a custom enum for the result:
   ```rust
   enum FileOutcome {
       Analyzed(Result<FileAnalysisResult, ParseError>),
       Skipped(SkippedItem),
   }
   ```
   Then partition outcomes into (analyzed_results, skipped_items, has_errors).
   - Import `MAX_FILE_LINES`, `SkippedItem`, `SkipReason` from crate::types.

3. **src/metrics/mod.rs** -- Modify `analyze_file` to:
   - Change return type to `Result<(FileAnalysisResult, Vec<SkippedItem>), ParseError>`.
   - After computing `structural_results` (which contains `function_length` for each function), check each function: if `function_length > MAX_FUNCTION_LINES`, add a `SkippedItem` with `SkipReason::FunctionTooLarge` and exclude that function from the `functions` Vec in the result. The function's tokens should still be included for duplication detection, but the function metrics are not reported.
   - Filter the parallel metric result vectors (cyclomatic_results, cognitive_results, halstead_results, structural_results) by the same indices to keep them in sync. Build a `keep` boolean vec based on `structural_results[i].function_length <= MAX_FUNCTION_LINES`.
   - Import `MAX_FUNCTION_LINES`, `SkippedItem`, `SkipReason` from crate::types.

4. **src/main.rs** -- Update the main function to:
   - Destructure the new third return value from `analyze_files_parallel`: `let (files, has_parse_errors, skipped) = ...;`
   - Pass `&skipped` (as `Option<&[SkippedItem]>` or `&[SkippedItem]`) to all four render functions. Use `if skipped.is_empty() { None } else { Some(&skipped) }` or just pass `&skipped` directly and let renderers check emptiness.
   - After rendering, if `!skipped.is_empty()` and verbose mode, consider printing a count to stderr (optional, console renderer will handle it).

Note: The file-level line count should count newlines in the raw bytes (before tree-sitter parsing). Count `\n` bytes and add 1 (or just count `\n` bytes -- files typically end with a newline so `count(\n)` is close enough). Use `memchr::memchr_iter(b'\n', &source).count()` if memchr is available, otherwise `source.iter().filter(|&&b| b == b'\n').count()`. Check if memchr is already a dependency (it likely is via tree-sitter or walkdir). If not, just use the iterator filter approach -- it's fast enough for a size check.
  </action>
  <verify>
    `cargo test` passes (all existing tests continue to work, new return types are handled).
    `cargo build --release` succeeds.
    Run `cargo run -- tests/fixtures/typescript/` and verify output is normal (no files are skipped since fixtures are small).
  </verify>
  <done>
    Size guard logic implemented: files > 10,000 lines and functions > 5,000 lines are skipped.
    SkippedItem type exists with path, function_name, start_line, and reason.
    Pipeline returns skipped list alongside analysis results.
    Main passes skipped list to renderers.
  </done>
</task>

<task type="auto">
  <name>Task 2: Surface skipped list in all output formats and update documentation</name>
  <files>
    src/output/console.rs
    src/output/json_output.rs
    src/output/sarif_output.rs
    src/output/html_output.rs
    src/output/mod.rs
    src/output/assets/report.html
    docs/cli-reference.md
    docs/getting-started.md
    docs/examples.md
    README.md
    publication/npm/README.md
  </files>
  <action>
1. **src/output/console.rs** -- Update `render_console` signature to accept skipped items:
   - Add parameter: `skipped: &[SkippedItem]`
   - After the verdict line (at the end of the function), if `!skipped.is_empty()`, render a "Skipped" section:
   ```
   Skipped (2 items):
     src/generated/huge-bundle.ts — file too large (15,234 lines, max 10,000)
     src/utils/parser.ts:142 — function 'processAll' too large (6,200 lines, max 5,000)
   ```
   - Use yellow color for the "Skipped" header if color is enabled.
   - In quiet mode, still show skipped items (they are important safety warnings).
   - Update the "Analyzed N files" summary line to also mention skipped count if > 0: `"Analyzed {file_count} files, {total_functions} functions ({skipped_count} skipped)"`

2. **src/output/json_output.rs** -- Update JSON output:
   - Add a `skipped` field to `JsonOutput` struct: `pub skipped: Option<Vec<JsonSkippedItem>>`
   - Define `JsonSkippedItem`:
   ```rust
   #[derive(serde::Serialize)]
   pub struct JsonSkippedItem {
       pub path: String,
       #[serde(skip_serializing_if = "Option::is_none")]
       pub function_name: Option<String>,
       pub start_line: usize,
       pub reason: String,  // Human-readable: "file_too_large" or "function_too_large"
       pub lines: usize,    // Actual line count
       pub max_lines: usize, // Threshold
   }
   ```
   - Update `render_json` signature to accept `skipped: &[SkippedItem]`.
   - Populate `skipped` field: `if skipped.is_empty() { None } else { Some(mapped_items) }`.
   - Also update `JsonSummary` to add `skipped_count: usize`.

3. **src/output/sarif_output.rs** -- Update SARIF output:
   - Update `render_sarif` signature to accept `skipped: &[SkippedItem]`.
   - For each skipped item, add a SARIF result with a new rule "complexity-guard/skipped" (add as rule index 11 -- but actually, simpler approach: add skipped items as "note" level results using the existing infrastructure, or add them as `invocation.toolExecutionNotifications` which is the SARIF-standard way to report skipped files).
   - Simplest correct approach: For each skipped file, add a SARIF result with `level: "note"`, `ruleId: "complexity-guard/skipped"`, and a message like "File skipped: 15,234 lines exceeds maximum of 10,000". Add a new rule definition for "complexity-guard/skipped" to `build_rules()`.
   - For skipped functions, use the same rule with a message about the function.

4. **src/output/html_output.rs** -- Update HTML output:
   - Update `render_html` signature to accept `skipped: &[SkippedItem]`.
   - Add skipped items to the template context.
   - In the HTML template (`src/output/assets/report.html`), add a "Skipped Items" section (similar to the duplication section -- conditional, only shown when skipped is non-empty). Show a table with columns: Path, Item, Reason, Lines, Max. Use yellow/warning styling.

5. **src/output/mod.rs** -- Update the re-exports if needed. The main.rs calls go through the functions directly, so just ensure the updated signatures are consistent.

6. **src/main.rs** -- Update all four render calls to pass `&skipped`:
   - `render_json(&files, duplication_result.as_ref(), &resolved, elapsed_ms, &skipped)`
   - `render_sarif(&files, duplication_result.as_ref(), &resolved, &skipped)`
   - `render_html(&files, duplication_result.as_ref(), &resolved, elapsed_ms, &skipped)`
   - `render_console(&files, duplication_result.as_ref(), &resolved, &mut std::io::stdout(), &skipped)`

7. **Documentation updates** -- Per CLAUDE.md rules:
   - **docs/cli-reference.md**: Add a "Size Limits" section documenting the 10,000 line file limit and 5,000 line function limit. Mention that skipped items appear in all output formats. Note these are hardcoded safety limits (not configurable).
   - **docs/getting-started.md**: Add a brief note in the "Running Analysis" section mentioning that very large files are automatically skipped with a reference to the CLI reference for details.
   - **docs/examples.md**: Add an example showing what skipped output looks like in console format.
   - **README.md**: Add a one-line mention in the features or output section: "Automatic safety limits skip files > 10,000 lines and functions > 5,000 lines (reported in output)."
   - **publication/npm/README.md**: Mirror the README.md change.
  </action>
  <verify>
    `cargo test` passes.
    `cargo build --release` succeeds.
    Run `cargo run -- tests/fixtures/typescript/ --format json 2>/dev/null | jq '.skipped'` -- should return null (no skipped items in small fixtures).
    Run `cargo run -- tests/fixtures/typescript/` -- console output should NOT show "Skipped" section (nothing to skip).
  </verify>
  <done>
    All four output formats (console, JSON, SARIF, HTML) include skipped items when the list is non-empty.
    JSON output has a "skipped" array with path, function_name, reason, lines, max_lines.
    Console output shows a clear "Skipped (N items):" section after the verdict.
    SARIF adds "note" level results for skipped items.
    HTML report has a conditional "Skipped Items" section.
    Documentation updated in docs/cli-reference.md, docs/getting-started.md, docs/examples.md, README.md, and publication/npm/README.md.
  </done>
</task>

</tasks>

<verification>
1. `cargo test` -- all existing tests pass (backward compatibility)
2. `cargo build --release` -- binary compiles
3. `cargo run -- tests/fixtures/typescript/` -- normal output, no skipped section
4. `cargo run -- tests/fixtures/typescript/ --format json | jq '.summary.skipped_count'` -- returns 0
5. To test actual skipping (if a large file is available): `cargo run -- benchmarks/projects/vscode/` should show skipped items for any files > 10,000 lines
</verification>

<success_criteria>
- Files > 10,000 lines are skipped entirely (no parsing, no analysis)
- Functions > 5,000 lines are excluded from metric results
- Skipped items tracked in a SkippedItem list with path, function name, reason
- All four output formats surface skipped items when list is non-empty
- No output change when nothing is skipped (backward compatible)
- Documentation clearly explains the safety limits and their rationale
</success_criteria>

<output>
After completion, create `.planning/quick/30-add-a-fail-safe-to-skip-files-bigger-tha/30-SUMMARY.md`
</output>
