---
phase: 11-duplication-detection
plan: 01
subsystem: metrics
tags: [duplication, clone-detection, rabin-karp, rolling-hash, tokenization, tree-sitter, zig]

# Dependency graph
requires:
  - phase: 03-file-discovery-parsing
    provides: tree-sitter Node API (childCount, child, nodeType, startPoint, startByte)
  - phase: 07-halstead
    provides: isTypeOnlyNode() for TypeScript type annotation skipping
provides:
  - Rabin-Karp rolling hash clone detection module (src/metrics/duplication.zig)
  - Normalized token extraction from tree-sitter ASTs
  - Cross-file hash index with token-by-token verification
  - Interval merging to prevent double-counting cloned tokens
  - DuplicationResult/CloneGroup/CloneLocation/FileDuplicationResult types
  - TypeScript fixture with annotated Type 1 and Type 2 clone blocks
affects: [11-02, 11-03, 11-04, output-modules, json-output, sarif-output, html-output]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Rabin-Karp rolling hash with base 37 and u64 wrapping arithmetic for O(1) window sliding"
    - "Cross-file AutoHashMap(u64, ArrayList(TokenWindow)) index for candidate clone grouping"
    - "Token-by-token verification after hash match to eliminate false positives"
    - "Sort-and-merge interval algorithm to prevent double-counting overlapping clone windows"
    - "MAX_BUCKET_SIZE=1000 guard to discard common-pattern buckets and prevent O(N^2) verification"
    - "Identifier normalization to sentinel 'V' for Type 2 clone detection (same structure, different names)"

key-files:
  created:
    - src/metrics/duplication.zig
    - tests/fixtures/typescript/duplication_cases.ts
  modified:
    - src/main.zig
    - src/lib.zig
    - src/discovery/walker.zig

key-decisions:
  - "Identifier sentinel 'V': normalize identifier/property_identifier/shorthand_property_identifier to 'V' for Type 2 clone detection — conservative approach, no string/number literal normalization"
  - "Skip punctuation ';' and ',' but not '{' and '}': preserves block structure information at the cost of slightly lower recall for reformatted code (RESEARCH.md Open Question 2)"
  - "MAX_BUCKET_SIZE=1000: discard hash buckets with >1000 entries (common patterns, not meaningful clones) to prevent O(N^2) verification complexity"
  - "Re-parse approach deferred: tokenizeTree takes a root Node (not source file path), caller re-parses if needed — simplest integration path for this foundational module"
  - "DuplicationConfig uses explicit struct initialization (no default field values) per Zig conventions"
  - "Interval merging uses separate countMergedClonedTokens function with allocator.dupe for sort stability"

patterns-established:
  - "tokenizeNode: recursive leaf traversal with isTypeOnlyNode() subtree skip + isSkippedKind() leaf skip + normalizeKind() identifier mapping"
  - "formCloneGroups: per-bucket pairwise verification with added[] tracking to deduplicate CloneLocation entries"
  - "detectDuplication cleanup: build hash index, form groups, collect intervals, compute per-file results — all from single index traversal"

requirements-completed: [DUP-01, DUP-02, DUP-03, DUP-04, DUP-05]

# Metrics
duration: 5min
completed: 2026-02-22
---

# Phase 11 Plan 01: Core Duplication Detection Summary

**Rabin-Karp rolling hash clone detector with AST-based identifier normalization, cross-file hash index, token-by-token verification, and interval merging to prevent double-counting**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-22T00:09:23Z
- **Completed:** 2026-02-22T00:13:46Z
- **Tasks:** 2 (TDD: RED + GREEN)
- **Files modified:** 5

## Accomplishments
- Implemented `tokenizeTree` that walks tree-sitter ASTs collecting normalized leaf tokens, skipping comments and TypeScript type annotation subtrees, normalizing all identifier variants to sentinel "V"
- Implemented full Rabin-Karp rolling hash pipeline: RollingHasher with `init()`/`roll()`, `buildHashIndex` cross-file AutoHashMap, `formCloneGroups` with token-by-token verification and MAX_BUCKET_SIZE=1000 guard
- Implemented `countMergedClonedTokens` with sort-and-merge algorithm ensuring duplication_pct never exceeds 100%
- All 6 duplication tests pass: tokenization, comment skipping, identifier normalization, type annotation stripping, Type 1 clone detection, Type 2 clone detection, overlapping interval merging
- TDD RED/GREEN commits maintain clean history showing test-first design

## Task Commits

Each task was committed atomically:

1. **Task 1 (RED): Create fixture and write failing tests** - `44fcde4` (test)
2. **Task 2 (GREEN): Implement full algorithm** - `a82f128` (feat)

_Note: TDD plan — two commits (RED failing tests → GREEN passing implementation)_

## Files Created/Modified
- `src/metrics/duplication.zig` - Core duplication detection module: Token/TokenWindow/CloneGroup/CloneLocation/FileDuplicationResult/DuplicationResult/DuplicationConfig/FileTokens types, tokenizeTree, detectDuplication, full Rabin-Karp algorithm
- `tests/fixtures/typescript/duplication_cases.ts` - TypeScript fixture with Type 1 clones (processUserData/processItemData), Type 2 clones (validateEmail/validatePhone), and unique control function
- `src/main.zig` - Added `_ = @import("metrics/duplication.zig")` in test discovery block
- `src/lib.zig` - Added `pub const duplication = @import("metrics/duplication.zig")` for external consumers
- `src/discovery/walker.zig` - Updated fixture file count assertions: TypeScript dir 10→11, all fixtures 13→14, exclude test 9→10

## Decisions Made
- Used identifier sentinel "V" for Type 2 clone detection (conservative — no string/number literal normalization per RESEARCH.md Open Question 1)
- Included `{`/`}` in token stream but skip `;`/`,` — preserves block structure for better Type 1 precision
- MAX_BUCKET_SIZE=1000 guard prevents O(N^2) verification on common-pattern buckets
- `formCloneGroups` uses pairwise verification with per-bucket `added[]` tracking to produce deduplicated CloneLocation entries

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed walker.zig fixture file count assertions**
- **Found during:** Task 1 (RED phase — run zig build test)
- **Issue:** Adding `duplication_cases.ts` to the TypeScript fixtures directory caused 3 pre-existing walker tests to fail (counts 10→11, 13→14, 9→10)
- **Fix:** Updated the three expectEqual counts in `src/discovery/walker.zig` to reflect the new fixture count
- **Files modified:** `src/discovery/walker.zig`
- **Verification:** `zig build test` passed with only duplication tests failing (RED phase confirmed)
- **Committed in:** `44fcde4` (part of Task 1 RED commit)

**2. [Rule 1 - Bug] Fixed Zig var-to-const warning**
- **Found during:** Task 2 (GREEN phase — first compile attempt)
- **Issue:** `var sorted` in `countMergedClonedTokens` was flagged as "local variable is never mutated" (Zig treats this as compilation error)
- **Fix:** Changed `var sorted` to `const sorted`
- **Files modified:** `src/metrics/duplication.zig`
- **Verification:** `zig build test` compiled and all tests passed
- **Committed in:** `a82f128` (part of Task 2 GREEN commit)

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs)
**Impact on plan:** Both fixes were trivial correctness issues directly caused by the new fixture file and implementation. No scope creep.

## Issues Encountered
- None beyond the auto-fixed deviations above.

## Next Phase Readiness
- `tokenizeTree` and `detectDuplication` are ready for integration into the analysis pipeline (Plan 02: CLI flag + main.zig integration)
- DuplicationResult/CloneGroup/CloneLocation types are defined and ready for output module extensions (Plans 03-04: console/JSON/SARIF/HTML output)
- DUP-01 through DUP-05 complete. DUP-06 and DUP-07 (reporting and thresholds) ready for Plan 02.

## Self-Check: PASSED

- FOUND: src/metrics/duplication.zig
- FOUND: tests/fixtures/typescript/duplication_cases.ts
- FOUND: .planning/phases/11-duplication-detection/11-01-SUMMARY.md
- FOUND commit: 44fcde4 (RED phase)
- FOUND commit: a82f128 (GREEN phase)
- `zig build test` exit code: 0 (all tests pass)
- `zig build` exit code: 0 (binary compiles)

---
*Phase: 11-duplication-detection*
*Completed: 2026-02-22*
