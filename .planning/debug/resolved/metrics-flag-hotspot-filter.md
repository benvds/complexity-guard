---
status: resolved
trigger: "Investigate why the --metrics flag doesn't filter out summary hotspot sections for non-selected metrics"
created: 2026-02-17T00:00:00Z
updated: 2026-02-17T12:30:00Z
---

## Current Focus

hypothesis: CONFIRMED - Two independent root causes: (1) formatSummary has no awareness of selected metrics, (2) formatFileResults has no awareness of selected metrics
test: Traced full data flow from --metrics parsing in main.zig through to console.zig output
expecting: N/A - root cause confirmed
next_action: Return diagnosis

## Symptoms

expected: When running `--metrics cyclomatic`, only cyclomatic-related hotspots should appear in summary
actual: Summary output still shows Halstead volume hotspots and potentially other metric hotspots
errors: N/A (functional bug, not crash)
reproduction: `zig-out/bin/complexity-guard --metrics cyclomatic` and observe summary output
started: Unknown

## Eliminated

## Evidence

- timestamp: 2026-02-17T00:01:00Z
  checked: main.zig lines 133-158 - how --metrics flag is parsed
  found: parsed_metrics is correctly built from CLI --metrics flag. isMetricEnabled() gates halstead (line 261) and structural (line 305) analysis. Cyclomatic and cognitive are always computed (not gated).
  implication: The analysis phase correctly respects --metrics for halstead/structural computation. However, cyclomatic/cognitive are always computed.

- timestamp: 2026-02-17T00:02:00Z
  checked: main.zig lines 395-422 - how console output functions are called
  found: formatSummary() and formatFileResults() are called with OutputConfig (use_color, verbosity) but parsed_metrics is NEVER passed to any output function. OutputConfig struct has no field for selected metrics.
  implication: The output layer has zero knowledge of which metrics were selected. It unconditionally renders all hotspot sections.

- timestamp: 2026-02-17T00:03:00Z
  checked: console.zig lines 243-419 - formatSummary hotspot rendering
  found: Three hardcoded hotspot sections always rendered: cyclomatic (lines 286-357), cognitive (lines 359-388), Halstead volume (lines 390-419). No conditional check on any metrics filter. Each section renders if its ArrayList has items.
  implication: Even when --metrics cyclomatic is specified, ALL three hotspot sections will appear because the rendering code has no filter.

- timestamp: 2026-02-17T00:04:00Z
  checked: console.zig lines 60-239 - formatFileResults per-file rendering
  found: Per-file output always shows cyclomatic + cognitive on every line (line 196). Halstead info shown if verbose OR if halstead status is non-ok (lines 210-217). Structural info shown if verbose OR if structural status is non-ok (lines 219-234). No metrics filter check.
  implication: Even when halstead/structural analysis is skipped (values stay at defaults/zero), the per-file output code still considers whether to show them based on status, not on whether the metric was selected.

- timestamp: 2026-02-17T00:05:00Z
  checked: console.zig lines 25-28 - OutputConfig struct definition
  found: OutputConfig only has use_color and verbosity fields. No field for selected/enabled metrics.
  implication: The entire output module has no mechanism to know which metrics are active.

## Resolution

root_cause: |
  The `--metrics` flag is parsed in main.zig (lines 146-158) and correctly gates metric
  COMPUTATION (halstead at line 261, structural at line 305), but the parsed_metrics value
  is never passed to the output layer. The console.zig OutputConfig struct (line 25) only
  contains use_color and verbosity -- it has no field for selected metrics.

  As a result, formatSummary() (lines 243-419) unconditionally renders all three hotspot
  sections (cyclomatic, cognitive, Halstead volume), and formatFileResults() (lines 60-239)
  unconditionally renders all metric details on each function line.

  When --metrics cyclomatic is used:
  - Halstead analysis is skipped, so values are 0.0 (defaults)
  - But formatSummary still collects functions with halstead_volume > 0 into hal_hotspots
  - If ANY function has non-zero halstead volume (e.g., from a previous run or default),
    those hotspots appear
  - The cognitive hotspot section ALWAYS appears regardless of --metrics, because cognitive
    analysis is never gated by isMetricEnabled

  There are actually two sub-issues:
  1. Cognitive analysis is never gated by --metrics (always runs, always shows hotspots)
  2. The output layer (console.zig) has no mechanism to filter displayed metric sections

fix:
verification:
files_changed: []
