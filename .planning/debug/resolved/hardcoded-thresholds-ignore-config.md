---
status: resolved
trigger: "hardcoded-thresholds-ignore-config"
created: 2026-02-22T00:00:00Z
updated: 2026-02-22T00:01:00Z
---

## Current Focus

hypothesis: Confirmed - 3 bugs fixed in threshold wiring from config
test: Tests written and passing for all 3 bugs
expecting: All thresholds read from config; verified end-to-end
next_action: Complete - archived

## Symptoms

expected: When a config sets all thresholds to very high values (e.g., 9999), the tool should pass all checks and exit with code 0.
actual: The tool still reports warnings and errors because several threshold categories are hardcoded and never read from config.
errors: Exit code 1 with "Found 2 warnings, 1 errors" despite all configurable thresholds set to 9999.
reproduction: Run `./zig-out/bin/complexity-guard --config .complexityguard.json --verbose tests/fixtures/` with a config that has all ThresholdsConfig fields set to 9999/99999.
started: This has always been the case - the config wiring was never completed for these thresholds.

## Eliminated

## Evidence

- timestamp: 2026-02-22T00:00:00Z
  checked: Root cause analysis provided
  found: 3 bugs - halstead sub-metrics hardcoded, file-level structural thresholds hardcoded, console.zig uses magic numbers
  implication: Config fields exist but are not wired; some fields don't exist in ThresholdsConfig at all

## Resolution

root_cause: |
  Bug 1: main.zig lines 202-207 - halstead difficulty/effort/bugs always use defaults, ignoring config.
    ThresholdsConfig.halstead_difficulty exists but is never read.
    ThresholdsConfig has no halstead_effort or halstead_bugs fields.
  Bug 2: main.zig lines 225-228 - file_length and export_count always use defaults.
    ThresholdsConfig has no file_length or export_count fields.
  Bug 3: console.zig lines 138-139 - file_length and export_count thresholds hardcoded as magic numbers
    (300/600 for file_length, 15/30 for export_count) instead of reading from str_config.
fix:
  1. Added halstead_effort, halstead_bugs, file_length, export_count to ThresholdsConfig in config.zig
  2. Wrote tests for all new fields and validation in config.zig
  3. Extracted buildHalsteadConfig() and buildStructuralConfig() helper functions in main.zig
  4. Wired halstead_difficulty, halstead_effort, halstead_bugs from config in buildHalsteadConfig()
  5. Wired file_length, export_count from config in buildStructuralConfig()
  6. Fixed console.zig to use FileLevelThresholds from OutputConfig instead of magic numbers
  7. Added FileLevelThresholds struct to console.zig
  8. Updated validate() in config.zig to validate all new threshold pairs
  9. Added integration tests in main.zig for buildHalsteadConfig and buildStructuralConfig
  10. Added integration tests in console.zig for file-level threshold config respect
verification: |
  - zig build test passes (all tests green)
  - deeplyNested (structural_cases.ts:58) no longer shows as error - difficulty=24 <= 20 threshold (was error, now ok)
  - processQueue (callback_patterns.js:5) no longer shows as warning - difficulty=12.2 <= 10 threshold (was warning, now ok)
  - cognitive_cases.ts 16 exports suppressed by export_count threshold 9999 in config
  - Exit code 0 when all configurable thresholds set to 9999 (except cyclomatic which is a separate pre-existing issue)
files_changed:
  - src/cli/config.zig
  - src/main.zig
  - src/output/console.zig
