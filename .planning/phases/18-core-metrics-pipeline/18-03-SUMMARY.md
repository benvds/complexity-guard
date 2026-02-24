---
phase: 18-core-metrics-pipeline
plan: 03
subsystem: metrics
tags: [scoring, duplication, rabin-karp, analyze-file, rust]

requires:
  - phase: 18-core-metrics-pipeline
    provides: cognitive, halstead, cyclomatic, structural modules

provides:
  - sigmoid scoring with compute_function_score and compute_file_score
  - Rabin-Karp duplication detection with Type 1/2 clones
  - analyze_file() entry point wiring all 6 metric families
  - ScoringWeights, ScoringThresholds, Token, CloneGroup, DuplicationResult, FunctionAnalysisResult, FileAnalysisResult, AnalysisConfig types

affects: [19-cli-output]

tech-stack:
  added: []
  patterns: [sigmoid normalization, Rabin-Karp rolling hash, single-pass metric assembly]

key-files:
  created:
    - rust/src/metrics/scoring.rs
    - rust/src/metrics/duplication.rs
  modified:
    - rust/src/types.rs
    - rust/src/metrics/mod.rs
    - rust/src/metrics/halstead.rs

key-decisions:
  - "ScoringThresholds defaults match Zig binary: function_length 25/50, params_count 3/6, nesting_depth 3/5"
  - "Weight normalization in 4-metric mode (duplication disabled) divides by sum of 4 weights"
  - "Made halstead::is_type_only_node pub for reuse in duplication tokenizer"

patterns-established:
  - "analyze_file() runs all metric analyzers on the same parsed tree root, then tokenizes before tree is dropped"
  - "Function results merged by index (all walkers discover functions in same DFS order)"

requirements-completed: [METR-05, METR-06]

duration: 15min
completed: 2026-02-24
---

# Plan 18-03: Scoring, Duplication & analyze_file() Summary

**Sigmoid scoring, Rabin-Karp duplication detection, and single-pass analyze_file() entry point matching Zig binary output**

## Performance

- **Duration:** 15 min
- **Tasks:** 3 (scoring + duplication + analyze_file)
- **Files modified:** 5

## Accomplishments
- Sigmoid scoring matches Zig for greet health_score=82.71258735483063 (exact match within 1e-6)
- Duplication detection finds Type 1 and Type 2 clones with Rabin-Karp rolling hash
- analyze_file() produces complete FileAnalysisResult with all 6 metric families in a single pass
- Token sequences embedded in results without re-parsing (tokenize before tree is dropped)
- All 70 tests pass (62 lib + 8 parser integration)

## Task Commits

1. **Tasks 1-3: scoring + duplication + analyze_file** - `43e7786` (feat)

## Files Created/Modified
- `rust/src/metrics/scoring.rs` - Sigmoid scoring with compute_function_score, compute_file_score, compute_project_score
- `rust/src/metrics/duplication.rs` - Rabin-Karp with HASH_BASE=37, MAX_BUCKET_SIZE=1000, Type 2 normalization
- `rust/src/types.rs` - Added ScoringWeights, ScoringThresholds, Token, CloneGroup, DuplicationResult, FunctionAnalysisResult, FileAnalysisResult, AnalysisConfig
- `rust/src/metrics/mod.rs` - Added pub mod scoring, pub mod duplication, analyze_file() entry point
- `rust/src/metrics/halstead.rs` - Made is_type_only_node pub for duplication reuse

## Decisions Made
- Used Zig binary defaults for ScoringThresholds (function_length 25/50 not 30/60, params_count 3/6 not 4/8, nesting_depth 3/5 not 3/6) to match actual Zig output

## Deviations from Plan
- ScoringThresholds defaults adjusted to match actual Zig binary config (plan specified different values from Zig source)

## Issues Encountered
- Plan specified incorrect ScoringThreshold defaults; verified against Zig binary and source to get correct values

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Complete metrics pipeline ready for CLI output integration (Phase 19)
- analyze_file() returns FileAnalysisResult with all data needed for JSON/table output

---
*Phase: 18-core-metrics-pipeline*
*Completed: 2026-02-24*
