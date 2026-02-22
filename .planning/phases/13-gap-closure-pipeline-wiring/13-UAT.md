---
status: diagnosed
phase: 13-gap-closure-pipeline-wiring
source: 13-01-SUMMARY.md
started: 2026-02-22T12:00:00Z
updated: 2026-02-22T21:35:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Cyclomatic thresholds from config file
expected: Create a config file with custom cyclomatic thresholds (e.g., warning: 15, error: 30). Run complexity-guard against a TypeScript file using that config. The output should use those custom thresholds instead of defaults (10/20). Functions exceeding the custom thresholds should be flagged accordingly.
result: pass

### 2. --metrics flag gates exit codes
expected: Run `complexity-guard --metrics cyclomatic` against files that have both cyclomatic AND halstead violations. The exit code should only reflect cyclomatic violations — halstead violations should be ignored for exit code purposes. Without --metrics, all violations count.
result: pass

### 3. --no-duplication skips duplication detection
expected: Run `complexity-guard --no-duplication` against files with duplicated code. Duplication analysis should be completely skipped — no duplication results in the output, regardless of config file settings or --metrics flags.
result: pass

### 4. --save-baseline includes duplication weight
expected: Run `complexity-guard --save-baseline`. The generated config file should include a `"duplication": 0.20` entry in the weights section alongside the other metric weights.
result: issue
reported: "remove any baseline saving functionality, only keep --init. --init is now missing options in it's generated config. please make this generated config include all options"
severity: major

## Summary

total: 4
passed: 3
issues: 1
pending: 0
skipped: 0

## Gaps

- truth: "--save-baseline generates config with duplication weight"
  status: failed
  reason: "User reported: remove any baseline saving functionality, only keep --init. --init is now missing options in it's generated config. please make this generated config include all options"
  severity: major
  test: 4
  root_cause: "Two issues: (1) --save-baseline is fully wired across 3 source files and 5+ doc files but user wants it removed entirely. (2) --init generateJsonConfig only emits 2 of 12 threshold categories (cyclomatic/cognitive), missing halstead, structural, duplication, file_length, export_count, nesting_depth, params_count, logical_lines, and baseline/threads/include config."
  artifacts:
    - path: "src/cli/args.zig:21,78-79,251-260"
      issue: "save_baseline field, parsing, and test to remove"
    - path: "src/main.zig:28-48,619-675"
      issue: "writeDefaultConfigWithBaseline function and save_baseline handler to remove"
    - path: "src/cli/help.zig:28"
      issue: "--save-baseline help line to remove"
    - path: "src/cli/init.zig:69-113"
      issue: "generateJsonConfig only emits cyclomatic + cognitive thresholds"
    - path: "src/cli/config.zig:34-47"
      issue: "ThresholdsConfig has 12 threshold fields; init generates only 2"
  missing:
    - "Remove --save-baseline from args, main.zig handler, help text, all docs"
    - "Expand generateJsonConfig to emit all 12 threshold categories with defaults"
    - "Expand generateTomlConfig similarly"
    - "Add include patterns, baseline, threads to --init output"
  debug_session: ".planning/debug/save-baseline-init-config.md"
