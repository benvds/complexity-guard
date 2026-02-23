---
phase: 06-cognitive-complexity
plan: 03
subsystem: documentation
tags: [docs, cognitive-complexity, cyclomatic-complexity, user-facing]
dependency_graph:
  requires: ["06-01"]
  provides: ["cognitive-complexity-docs", "cyclomatic-complexity-docs", "updated-user-docs"]
  affects: ["README.md", "docs/cognitive-complexity.md", "docs/cyclomatic-complexity.md", "docs/getting-started.md", "docs/cli-reference.md", "docs/examples.md"]
tech_stack:
  added: []
  patterns: ["TanStack/Astro friendly-thorough doc style", "side-by-side cyclomatic/cognitive output format"]
key_files:
  created:
    - docs/cognitive-complexity.md
    - docs/cyclomatic-complexity.md
  modified:
    - README.md
    - docs/getting-started.md
    - docs/cli-reference.md
    - docs/examples.md
decisions:
  - "Cognitive complexity docs credit G. Ann Campbell/SonarSource per locked requirement"
  - "ComplexityGuard deviations from SonarSource clearly documented (individual operator counting, top-level arrow functions)"
  - "Example output format updated to show side-by-side cyclomatic/cognitive scores"
  - "Separate hotspot lists for cyclomatic and cognitive in README example"
metrics:
  duration: 3 min
  completed: "2026-02-17"
  tasks_completed: 2
  files_changed: 6
---

# Phase 6 Plan 03: Documentation - Cognitive and Cyclomatic Complexity Summary

Two new metric explanation docs and updated user-facing documentation for dual cyclomatic/cognitive complexity output with SonarSource/McCabe attribution.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create cognitive and cyclomatic complexity docs pages | 2003845 | docs/cognitive-complexity.md, docs/cyclomatic-complexity.md |
| 2 | Update README, getting-started, CLI reference, and examples | b1d4402 | README.md, docs/getting-started.md, docs/cli-reference.md, docs/examples.md |

## What Was Built

**New docs pages:**
- `docs/cognitive-complexity.md` (~520 words): Explains structural/flat/non-counting increments, nesting-aware scoring, ComplexityGuard deviations from SonarSource spec, default thresholds (warn 15 / error 25), annotated example, and proper attribution to G. Ann Campbell/SonarSource with whitepaper link.
- `docs/cyclomatic-complexity.md` (~514 words): Explains branch counting rules (ESLint-aligned), switch case modes, logical/nullish/optional chaining operators, default thresholds (warn 10 / error 20), comparison table vs cognitive complexity, and attribution to Thomas J. McCabe, Sr.

**Updated user-facing docs:**
- README: New example output shows `cyclomatic N cognitive N` format with separate Top cyclomatic/Top cognitive hotspot lists. Features section adds Cognitive Complexity bullet. New Metrics section links both docs pages. Config example includes cognitive threshold.
- getting-started: Explains both metrics up front, updated output example, updated default thresholds section, config examples include cognitive thresholds in strict/lenient modes.
- cli-reference: `--metrics` flag updated to mention `cognitive`. Full schema includes cognitive threshold block. New `thresholds.cognitive.warning` and `thresholds.cognitive.error` option docs. JSON output example shows populated cognitive values.
- examples: Strict/lenient configuration recipes include cognitive thresholds. New jq recipes for filtering by cognitive complexity and comparing cyclomatic vs cognitive metrics.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

### Files Exist

- FOUND: docs/cognitive-complexity.md
- FOUND: docs/cyclomatic-complexity.md
- FOUND: README.md
- FOUND: docs/getting-started.md
- FOUND: docs/cli-reference.md
- FOUND: docs/examples.md

### Commits Exist

- FOUND: 2003845 — docs(06-03): add cognitive and cyclomatic complexity docs pages
- FOUND: b1d4402 — docs(06-03): update user-facing docs to reflect cognitive complexity
