---
phase: quick-31
plan: 01
subsystem: documentation
tags: [docs, config-schema, cli-reference, accuracy]
dependency_graph:
  requires: []
  provides: [accurate-documentation, correct-config-schema-examples]
  affects: [README.md, docs/cli-reference.md, docs/getting-started.md, docs/examples.md, publication/npm/README.md]
tech_stack:
  added: []
  patterns: [nested-config-schema, analysis.thresholds]
key_files:
  created: []
  modified:
    - README.md
    - docs/cli-reference.md
    - docs/getting-started.md
    - docs/examples.md
    - publication/npm/README.md
    - publication/npm/packages/darwin-arm64/README.md
    - publication/npm/packages/darwin-x64/README.md
    - publication/npm/packages/linux-arm64/README.md
    - publication/npm/packages/linux-x64/README.md
    - publication/npm/packages/windows-x64/README.md
decisions:
  - "Removed counting_rules documentation section (rules are hardcoded in Rust, not configurable)"
  - "Replaced flat thresholds schema with nested analysis.thresholds throughout all docs"
  - "Updated field names: line_count (not function_length), params_count (not params), nesting_depth (not nesting), export_count (not exports)"
  - "Documented --init as reserved for future use / stub, not a working config generator"
  - "Removed XDG config directory from discovery docs; added .git boundary traversal and complexityguard.config.json alternative"
  - "Added --no-duplication flag documentation to cli-reference.md"
  - "Added Automatic Safety Limits bullet to all 5 package READMEs to match main README"
metrics:
  duration: 5 min
  completed: 2026-02-28
  tasks_completed: 2
  tasks_total: 2
  files_modified: 10
---

# Quick Task 31: Update README and Docs to Reflect Actual Rust Code Summary

All 10 documentation files updated to accurately reflect the actual Rust codebase. Config schema examples now use the correct nested `analysis.thresholds` structure, field names match the Rust `ThresholdsConfig` struct, CLI flag behavior matches `args.rs`, and default values match `ResolvedConfig::default()`.

## Tasks Completed

| Task | Name | Commit | Key Changes |
|------|------|--------|-------------|
| 1 | Fix docs/cli-reference.md and docs/getting-started.md | 432d314 | Nested schema, field renames, --init stub, --fail-on none, halstead_bugs 1.0, remove XDG, add --no-duplication |
| 2 | Fix README.md, docs/examples.md, and sync publication READMEs | 769168a | Nested schema, remove counting_rules, fix --error 25, sync all publication READMEs |

## What Was Fixed

### Major Schema Correction (All Files)
The documentation previously showed a flat top-level `thresholds` key that does not exist in the Rust code. The actual schema nests thresholds under `analysis.thresholds`. All config JSON examples across all 10 files have been updated.

### Field Name Corrections
Old (wrong) names → New (correct) names:
- `function_length` → `line_count`
- `params` → `params_count`
- `nesting` → `nesting_depth`
- `exports` → `export_count`

### counting_rules Removed
The `counting_rules` config section was fully documented but does not exist in the Rust code. Cyclomatic counting rules are hardcoded (ESLint-aligned: logical operators, nullish coalescing, optional chaining all count; switch per case). Documentation replaced with a note explaining this.

### --init Flag
Updated from "generates a comprehensive config file" to accurately state it is reserved for future use and currently prints a message and exits.

### --fail-on Values
Changed `never` to `none` everywhere (matches the actual accepted values in args.rs).

### halstead_bugs Error Default
Corrected from `2.0` to `1.0` (matches `ResolvedConfig::default()` in config.rs).

### Config Discovery
Removed reference to XDG config directory (not implemented in Rust). Added: searches upward from CWD to `.git` boundary, recognizes `complexityguard.config.json` as alternative filename.

### --output Flag Behavior
Corrected claim that JSON is "written to file AND printed to stdout" — it writes to file OR stdout, not both.

### --no-duplication Flag
Added documentation for this flag in cli-reference.md (existed in args.rs but was undocumented).

### --error 25 Flag
Removed invalid `--error 25` flag usage from examples.md HTML report example (no such flag exists).

### Rust Note Banners
Removed outdated "Note: ComplexityGuard is built with Rust..." banners from docs/cli-reference.md and docs/examples.md.

### Publication READMEs
- `publication/npm/README.md`: Synced config example with main README, removed --init Quick Start
- All 5 package READMEs: Added "Automatic Safety Limits" bullet point to match main README features list

## Deviations from Plan

None — plan executed exactly as written. All 13 fix items from the task descriptions were addressed.

## Self-Check

All files modified exist and were committed.
