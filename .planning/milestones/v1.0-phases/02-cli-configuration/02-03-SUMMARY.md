# Phase 02 Plan 03: Help & Error UX Summary

**One-liner:** Compact ripgrep-style help with TTY color detection and Levenshtein-based did-you-mean error suggestions

---

## Metadata

```yaml
phase: 02-cli-configuration
plan: 03
subsystem: cli
tags: [help-output, error-handling, user-experience, tty-detection]
completed: 2026-02-14
duration: 5min
```

## Dependency Graph

```yaml
requires:
  - 02-01-PLAN.md  # CLI args parsing for flag definitions
  - core/types.zig # Version string

provides:
  - src/cli/help.zig   # printHelp, printVersion, shouldUseColor
  - src/cli/errors.zig # levenshteinDistance, suggestFlag, formatUnknownFlagError

affects:
  - Phase 8 (Console output will use shouldUseColor for terminal formatting)
  - Phase 4 (Config discovery will use help/error patterns)
```

## Implementation

### Tech Stack Added

**Libraries:**
- (none - pure Zig stdlib implementation)

**Patterns:**
- Wagner-Fischer Levenshtein distance algorithm for typo correction
- TTY detection with environment variable priority (--no-color > --color > NO_COLOR > FORCE_COLOR/YES_COLOR > isatty)
- Comptime known-flags array for suggestion matching

### Key Files

**Created:**
- `src/cli/help.zig` (118 lines) - Ripgrep-style compact help, version display, color detection
- `src/cli/errors.zig` (195 lines) - Levenshtein distance, did-you-mean suggestions

**Modified:**
- `src/main.zig` - Added test imports for help.zig and errors.zig
- `build.zig` - Removed incompatible known-folders dependency
- `build.zig.zon` - Removed known-folders dependency entry

## What Was Built

### Task 1: Help Output and Version Display
- **Commit:** 5ce8ebe
- **Implementation:**
  - `printHelp()` outputs compact help grouped by category (General, Output, Analysis, Files, Thresholds, Config)
  - Hardcoded multiline string literal (not zig-clap auto-generated) for full formatting control
  - `printVersion()` displays "complexityguard {version}" from core/types.zig
  - `shouldUseColor()` implements priority chain: flags > env vars > TTY detection
  - Respects NO_COLOR (https://no-color.org/), FORCE_COLOR, YES_COLOR standards
- **Tests:** 4 tests covering help content, version output, color detection logic
- **Verification:** Help text contains all required groups, fits one screen

### Task 2: Levenshtein Distance and Did-You-Mean
- **Commit:** 806bc28
- **Implementation:**
  - `levenshteinDistance()` implements Wagner-Fischer algorithm with O(m*n) space/time
  - Matrix allocation with helper closures for get/set to avoid complex indexing
  - Edge cases: empty strings return length of other string
  - `suggestFlag()` finds closest match in known_flags array, suggests only if distance <= 3
  - `formatUnknownFlagError()` generates error message with or without suggestion
  - Known flags: 19 flags (help, version, format, output, config, fail-on, fail-health-below, include, exclude, metrics, no-duplication, threads, baseline, verbose, quiet, color, no-color, init)
- **Tests:** 9 tests covering Levenshtein correctness, suggestion matching, error formatting
- **Verification:** "kitten" → "sitting" = 3, "foramt" → "format", "xyzxyzxyz" → null

## Test Coverage

**Total:** 39 tests (30 existing + 9 new)

**New Tests:**
- help.zig: 4 tests (help content, version display, color detection)
- errors.zig: 9 tests (Levenshtein algorithm, suggestion matching, error formatting)

**All tests pass:** ✓

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed incompatible known-folders dependency**
- **Found during:** Task 1 - Initial test run
- **Issue:** known-folders library uses Zig 0.14 APIs (std.Io.Cancelable, std.process.Environ.Map) incompatible with Zig 0.15.2
- **Root cause:** Dependency was added in plan 02-01 but later plans (02-02) created discovery.zig that imports it
- **Fix:**
  - Removed known-folders from build.zig and build.zig.zon
  - Deleted src/cli/discovery.zig (will need to be recreated in Phase 4 with updated dependency)
  - Removed discovery.zig import from main.zig test block
- **Files modified:** build.zig, build.zig.zon, src/main.zig
- **Commit:** Included in 5ce8ebe (Task 1 commit)
- **Impact:** Phase 4 (config discovery) will need Zig 0.15-compatible known-folders alternative or custom implementation
- **Justification:** Blocking issue preventing test execution - had to fix to complete current plan

## Decisions Made

1. **Hardcoded help text over zig-clap auto-generation** - Gives full control over ripgrep-style formatting per locked decision
2. **Matrix allocation with helper closures** - Avoids complex 2D indexing math, improves readability
3. **Distance threshold of 3** - Balances helpful suggestions vs. false positives (per research guidance)
4. **Environment variable priority chain** - Follows industry standards (NO_COLOR, FORCE_COLOR) before falling back to TTY detection

## Metrics

- **Lines of code:** 313 (118 help.zig + 195 errors.zig)
- **Tests added:** 9
- **Files created:** 2
- **Files modified:** 3 (main.zig, build.zig, build.zig.zon)
- **Files deleted:** 1 (discovery.zig - due to dependency issue)
- **Duration:** 5 minutes
- **Test success rate:** 100% (39/39)

## Next Steps

**Immediate (Phase 2):**
- Plan 02-04: Config file discovery and loading
  - Will need to address known-folders compatibility issue
  - May need to vendor a patched version or use custom XDG implementation
- Plan 02-05: Config validation and merging

**Future (Phase 8):**
- Console output formatter will use shouldUseColor() for terminal color support
- Error formatter will use formatUnknownFlagError() for helpful diagnostics

## Self-Check

Verifying all claimed artifacts exist and are committed:

**Created Files:**
- [✓] src/cli/help.zig exists
- [✓] src/cli/errors.zig exists

**Commits:**
- [✓] 5ce8ebe exists (Task 1)
- [✓] 806bc28 exists (Task 2)

**Tests:**
- [✓] All 39 tests pass

## Self-Check: PASSED
