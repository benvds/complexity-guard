---
phase: 11-duplication-detection
verified: 2026-02-22T20:00:00Z
status: passed
score: 17/17 must-haves verified
re_verification: false
---

# Phase 11: Duplication Detection Verification Report

**Phase Goal:** Tool detects code clones across files using Rabin-Karp rolling hash
**Verified:** 2026-02-22T20:00:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Duplication module tokenizes TypeScript AST into normalized token sequences stripping comments and whitespace | VERIFIED | `tokenizeNode()` in `src/metrics/duplication.zig:152-186` — `isSkippedKind()` filters comments/punctuation, leaf-only collection confirmed |
| 2 | Identifiers are normalized to sentinel "V" for Type 2 clone detection | VERIFIED | `normalizeKind()` at `duplication.zig:139-148` maps `identifier`, `property_identifier`, `shorthand_property_identifier`, `shorthand_property_identifier_pattern` → `"V"` |
| 3 | Rolling hash correctly computes and slides over token windows of configurable size | VERIFIED | `RollingHasher` struct at `duplication.zig:215-237` with `init()`, `roll()`, HASH_BASE=37, u64 wrapping arithmetic; configurable `min_window` from `DuplicationConfig` |
| 4 | Cross-file hash index maps hash values to token window locations across multiple files | VERIFIED | `buildHashIndex()` at `duplication.zig:239-269` — `AutoHashMap(u64, ArrayList(TokenWindow))` populated for all files |
| 5 | Hash collision verification confirms token-by-token match before forming clone groups | VERIFIED | `tokensMatch()` at `duplication.zig:274-288`; MAX_BUCKET_SIZE=1000 guard prevents O(N^2); called from `formCloneGroups()` |
| 6 | Overlapping clone intervals are merged into maximal spans per file | VERIFIED | `countMergedClonedTokens()` at `duplication.zig:384-418` — sort-and-merge algorithm; `duplication_pct` never exceeds 100% |
| 7 | User can enable duplication detection via `--duplication` CLI flag | VERIFIED | `args.zig:19,74-75` — `duplication: bool = false` field, parsed to `cli_args.duplication = true`; `merge.zig:35-36` sets `duplication_enabled = true` |
| 8 | User can enable duplication detection via `--metrics duplication` | VERIFIED | `main.zig:283-285` — `std.mem.eql(u8, m, "duplication")` check in `duplication_enabled` block |
| 9 | User can enable duplication detection via config file `duplication_enabled` field | VERIFIED | `config.zig:29` — `duplication_enabled: ?bool = null` in `AnalysisConfig`; `main.zig:277-281` checks it |
| 10 | When duplication is not enabled, zero overhead — no duplication code path runs | VERIFIED | `main.zig:526-554` — entire re-parse/tokenize/detect block guarded by `if (duplication_enabled)`; confirmed by SUMMARY: 13 problems without flag, 19 with |
| 11 | Duplication results include per-file duplication percentages with warning/error status | VERIFIED | `FileDuplicationResult` struct has `duplication_pct`, `warning`, `@"error"` fields; set in `detectDuplication()` at `main.zig:507-530`; displayed in all output formats |
| 12 | Duplication results include project-level duplication percentage with threshold status | VERIFIED | `DuplicationResult` has `project_duplication_pct`, `project_warning`, `project_error`; displayed in console, JSON, SARIF, HTML |
| 13 | Configurable thresholds for file-level (default 15%/25%) and project-level (default 5%/10%) | VERIFIED | `DuplicationConfig.default()` at `duplication.zig:97-105`; `DuplicationThresholds` in `config.zig:58-75`; `buildDuplicationConfig()` in `main.zig:66-80` |
| 14 | Health score integrates duplication when enabled (5-metric normalization, 0.20 weight) | VERIFIED | `scoring.zig:103-160` — `resolveEffectiveWeights(weights, duplication_enabled)` normalizes 5 weights when enabled; `normalizeDuplication()` and `computeFileScoreWithDuplication()` present |
| 15 | Console output shows Duplication section with clone groups and per-file/project percentages | VERIFIED | `formatDuplicationSection()` in `console.zig:546-620`; called from `main.zig:829-834` when `dup_result` non-null |
| 16 | JSON output includes duplication object with clone_groups array and file duplication data | VERIFIED | `JsonDuplication`/`JsonCloneGroup`/`JsonCloneLocation`/`JsonFileDuplication` structs in `json_output.zig`; populated in `buildJsonOutput()` via optional `?DuplicationResult` |
| 17 | SARIF output includes duplication rule with relatedLocations for clone group instances | VERIFIED | `RULE_DUPLICATION=10` at `sarif_output.zig:18`; `SarifRelatedLocation` struct; one result per clone group with `relatedLocations` array for GitHub Code Scanning |

**Score:** 17/17 truths verified

---

## Required Artifacts

### Plan 11-01 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/metrics/duplication.zig` | Core duplication detection algorithm (min 200 lines) | VERIFIED | 827 lines; exports all required types and functions |
| `tests/fixtures/typescript/duplication_cases.ts` | Test fixture with known duplicate code blocks (min 30 lines) | VERIFIED | 48 lines; Type 1 clones (processUserData/processItemData), Type 2 clones (validateEmail/validatePhone), unique control function |

### Plan 11-02 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/cli/args.zig` | `duplication: bool` field in `CliArgs` | VERIFIED | `duplication: bool = false` at line 19; `--duplication` parsed at lines 74-75 |
| `src/cli/config.zig` | `DuplicationThresholds` struct and `duplication_enabled` field | VERIFIED | `DuplicationThresholds` at line 58; `duplication_enabled: ?bool = null` in `AnalysisConfig` at line 29 |
| `src/main.zig` | Duplication pass wired after parallel/sequential analysis | VERIFIED | `detectDuplication` called at line 549; re-parse loop at lines 527-553 |
| `src/metrics/scoring.zig` | 5-metric weight normalization when duplication enabled | VERIFIED | `duplication: f64` in `EffectiveWeights`; `resolveEffectiveWeights(weights, duplication_enabled: bool)` |

### Plan 11-03 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/output/console.zig` | Duplication section containing `formatDuplication` | VERIFIED | `formatDuplicationSection` at line 548; imports `duplication` module |
| `src/output/json_output.zig` | Duplication object in JSON output containing `duplication` | VERIFIED | `JsonDuplication` struct at line 31; `duplication` field in `JsonOutput` at line 48 |
| `src/output/sarif_output.zig` | Duplication SARIF rule and results containing `duplication` | VERIFIED | `RULE_DUPLICATION` const at line 18; duplication rule in `buildRules()`; `relatedLocations` emission |
| `src/output/html_output.zig` | Clone groups table and heatmap in HTML report containing `duplication` | VERIFIED | `writeDuplicationSection()` at line 1225; clone table, file list, adjacency heatmap with CSS |

### Plan 11-04 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `docs/duplication-detection.md` | Comprehensive documentation (min 80 lines) | VERIFIED | 366 lines; covers algorithm, clone types, enabling, thresholds, output formats, health score, config reference |
| `benchmarks/scripts/bench-duplication.sh` | Reproducible benchmark script (min 20 lines) | VERIFIED | 122 lines; executable (`-rwxr-xr-x`); hyperfine + export-json; covers zod/got/dayjs |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `src/metrics/duplication.zig` | `src/parser/tree_sitter.zig` | `tree_sitter.Node` API for AST leaf traversal | WIRED | `const tree_sitter = @import("../parser/tree_sitter.zig")` at line 2; `tree_sitter.Node` used in `tokenizeNode()` and `tokenizeTree()` |
| `src/main.zig` | `src/metrics/duplication.zig` | test import for discovery AND runtime import | WIRED | `const duplication_mod = @import("metrics/duplication.zig")` at line 18 (runtime); `_ = @import("metrics/duplication.zig")` at line 984 (test discovery) |
| `src/main.zig` | `src/metrics/duplication.zig` | `duplication.detectDuplication` call after file analysis | WIRED | `duplication_mod.detectDuplication(arena_allocator, ...)` at line 549 |
| `src/cli/merge.zig` | `src/cli/config.zig` | merge `--duplication` flag into config | WIRED | `cfg.analysis.?.duplication_enabled = true` at line 36 when `cli_args.duplication` is true |
| `src/metrics/scoring.zig` | duplication weight | 5-metric effective weights when duplication enabled | WIRED | `duplication: f64` field in `EffectiveWeights`; `w_dup` in `resolveEffectiveWeights()` used in both 4-metric and 5-metric normalization |
| `src/main.zig` | `src/output/console.zig` | passes `dup_result` to `formatDuplicationSection` | WIRED | `console.formatDuplicationSection(...)` at line 830 inside `if (dup_result) |dup|` block |
| `src/main.zig` | `src/output/json_output.zig` | passes `dup_result` to `buildJsonOutput` | WIRED | `json_output.buildJsonOutput(..., dup_result, ...)` at line 710 |
| `src/main.zig` | `src/output/sarif_output.zig` | passes `dup_result` to `buildSarifOutput` | WIRED | `sarif_output.buildSarifOutput(..., dup_result, ...)` at line 758 |
| `src/main.zig` | `src/output/html_output.zig` | passes `dup_result` to `buildHtmlReport` | WIRED | `html_output.buildHtmlReport(..., dup_result, ...)` at line 781 |
| `README.md` | `docs/duplication-detection.md` | documentation link | WIRED | Line 68: `see [duplication docs](docs/duplication-detection.md)`; line 97: `**[Duplication Detection](docs/duplication-detection.md)**` |
| `docs/getting-started.md` | `docs/duplication-detection.md` | cross-reference link | WIRED | Line 81 links to `duplication-detection.md`; "Duplication Detection" in Next Steps |

---

## Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| DUP-01 | 11-01, 11-04 | Tool tokenizes source files stripping comments and whitespace | SATISFIED | `tokenizeNode()` skips `isSkippedKind()` (comment/line_comment/block_comment/;/,); 7 tests in `duplication.zig` pass including `"tokenizeTree: skips comments"` |
| DUP-02 | 11-01, 11-04 | Tool normalizes identifiers for Type 2 clone detection | SATISFIED | `normalizeKind()` maps identifier variants to `"V"`; test `"tokenizeTree: normalizes identifiers to V"` verified |
| DUP-03 | 11-01, 11-04 | Tool uses Rabin-Karp rolling hash with configurable minimum window (default 25 tokens) | SATISFIED | `RollingHasher` with base 37; `DuplicationConfig.min_window = 25` default; `buildHashIndex()` uses sliding window |
| DUP-04 | 11-01, 11-04 | Tool builds cross-file hash index and verifies matches token-by-token | SATISFIED | `buildHashIndex()` builds `AutoHashMap(u64, ArrayList(TokenWindow))`; `tokensMatch()` verifies before clone group formation |
| DUP-05 | 11-01, 11-04 | Tool merges overlapping matches into maximal clone groups | SATISFIED | `countMergedClonedTokens()` sort-and-merge interval algorithm; test `"detectDuplication: merges overlapping intervals correctly"` |
| DUP-06 | 11-02, 11-03, 11-04 | Tool reports clone groups with locations, token counts, and duplication percentages | SATISFIED | `CloneGroup.token_count` + `CloneLocation.file_path/start_line/end_line`; `FileDuplicationResult.duplication_pct`; displayed in console, JSON, SARIF, HTML |
| DUP-07 | 11-02, 11-03, 11-04 | Tool applies configurable thresholds for file duplication % and project duplication % | SATISFIED | `DuplicationThresholds` struct with file_warning/error/project_warning/error; applied in `detectDuplication()`; violations counted in `total_warnings`/`total_errors` in `main.zig` |

All 7 DUP requirements are SATISFIED. No orphaned requirements found.

---

## Anti-Patterns Found

No anti-patterns detected across the key implementation files:

- No TODO/FIXME/PLACEHOLDER comments in `src/metrics/duplication.zig` (827 lines)
- No stub implementations (`return null`, `return {}`, `return []`) — `detectDuplication()` returns fully populated `DuplicationResult`
- No empty handlers in output modules
- All 7 tests in `duplication.zig` are substantive (parse real TypeScript ASTs, assert specific outcomes)
- `zig build test` exits 0 with no failures
- `zig build` exits 0 (binary compiles)

---

## Human Verification Required

### 1. Console Duplication Output Visual Inspection

**Test:** Run `zig-out/bin/complexity-guard --duplication tests/fixtures/`
**Expected:** Console shows "Duplication" header, clone group lines formatted as `Clone group (N tokens): path:line`, file duplication percentages with [OK]/[WARNING]/[ERROR] indicators, and project summary
**Why human:** Visual format correctness and readability cannot be verified programmatically

### 2. HTML Heatmap Rendering

**Test:** Run `zig-out/bin/complexity-guard --duplication --format html --output /tmp/report.html tests/fixtures/` and open the HTML in a browser
**Expected:** HTML report shows a "Duplication" section with a clone groups table, file duplication list with percentage bars, and an adjacency heatmap with orange-to-red intensity coloring
**Why human:** Visual rendering and heatmap legibility require browser inspection

### 3. GitHub Code Scanning Integration (SARIF relatedLocations)

**Test:** Upload SARIF output from `--duplication --format sarif` to a GitHub repository with Code Scanning enabled
**Expected:** Duplication findings appear as alerts; each clone group shows linked related locations pointing to all clone instances
**Why human:** GitHub Code Scanning integration behavior cannot be verified locally

---

## Gaps Summary

No gaps. All must-haves from all four plans are verified against the actual codebase:

- Plan 11-01 (core algorithm): `src/metrics/duplication.zig` (827 lines) with full Rabin-Karp implementation, 7 passing tests, typed structs, and proper tree-sitter wiring
- Plan 11-02 (CLI/pipeline/scoring): `--duplication` flag parsed and merged into config; `detectDuplication` called in `main.zig` pipeline; 5-metric weight normalization in `scoring.zig`
- Plan 11-03 (output): All four formats (console/JSON/SARIF/HTML) show duplication results when enabled; exit codes integrate duplication violations via `total_warnings`/`total_errors`
- Plan 11-04 (docs/benchmarks): `docs/duplication-detection.md` (366 lines) covers algorithm, configuration, all output formats; benchmark script is executable (122 lines); all publication READMEs synced (5/5 platform packages)

The phase goal — "Tool detects code clones across files using Rabin-Karp rolling hash" — is fully achieved.

---

_Verified: 2026-02-22T20:00:00Z_
_Verifier: Claude (gsd-verifier)_
