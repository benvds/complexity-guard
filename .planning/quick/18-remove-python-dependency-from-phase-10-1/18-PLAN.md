---
phase: quick-18
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - benchmarks/scripts/summarize_results.py
  - benchmarks/scripts/compare_metrics.py
  - benchmarks/scripts/summarize-results.mjs
  - benchmarks/scripts/compare-metrics.mjs
  - benchmarks/scripts/setup.sh
  - benchmarks/scripts/bench-quick.sh
  - benchmarks/scripts/bench-full.sh
  - benchmarks/scripts/bench-stress.sh
  - benchmarks/scripts/bench-subsystems.sh
  - benchmarks/scripts/compare-metrics.sh
  - benchmarks/README.md
  - docs/benchmarks.md
autonomous: true
requirements: []

must_haves:
  truths:
    - "No Python dependency exists anywhere in the benchmark scripts"
    - "All benchmark scripts use only Zig, Node.js/npm, or jq for JSON processing"
    - "Running any benchmark script does not require python3 on PATH"
    - "summarize-results and compare-metrics produce identical output format to their Python predecessors"
  artifacts:
    - path: "benchmarks/scripts/summarize-results.mjs"
      provides: "Node.js replacement for summarize_results.py"
      contains: "parse_hyperfine_file"
    - path: "benchmarks/scripts/compare-metrics.mjs"
      provides: "Node.js replacement for compare_metrics.py"
      contains: "compute_ranking_correlation"
  key_links:
    - from: "benchmarks/scripts/compare-metrics.sh"
      to: "benchmarks/scripts/compare-metrics.mjs"
      via: "node invocation replacing python3 subprocess"
      pattern: "node.*compare-metrics\\.mjs"
    - from: "benchmarks/scripts/bench-quick.sh"
      to: "jq"
      via: "jq replacing inline python3 for JSON extraction"
      pattern: "jq"
---

<objective>
Replace all Python dependencies in the Phase 10.1 benchmark scripts with Node.js and jq equivalents.

Purpose: Eliminate the python3 prerequisite from the benchmark tooling. The project should only depend on Zig and Node.js/npm (already required for FTA installation). jq is used for simple inline JSON extraction in shell scripts.

Output: Two new Node.js scripts replacing the Python scripts, six updated shell scripts with jq instead of inline Python, and updated documentation removing python3 from prerequisites.
</objective>

<execution_context>
@/home/ben/.claude/get-shit-done/workflows/execute-plan.md
@/home/ben/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@benchmarks/scripts/summarize_results.py
@benchmarks/scripts/compare_metrics.py
@benchmarks/scripts/setup.sh
@benchmarks/scripts/bench-quick.sh
@benchmarks/scripts/bench-full.sh
@benchmarks/scripts/bench-stress.sh
@benchmarks/scripts/bench-subsystems.sh
@benchmarks/scripts/compare-metrics.sh
@benchmarks/README.md
@docs/benchmarks.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Port Python scripts to Node.js and replace inline Python in shell scripts with jq</name>
  <files>
    benchmarks/scripts/summarize-results.mjs
    benchmarks/scripts/compare-metrics.mjs
    benchmarks/scripts/setup.sh
    benchmarks/scripts/bench-quick.sh
    benchmarks/scripts/bench-full.sh
    benchmarks/scripts/bench-stress.sh
    benchmarks/scripts/bench-subsystems.sh
    benchmarks/scripts/compare-metrics.sh
  </files>
  <action>
    **Create `benchmarks/scripts/summarize-results.mjs`** — Port `summarize_results.py` to Node.js ESM:
    - Same CLI interface: `node summarize-results.mjs <results-dir> [--json <output-path>]`
    - Same output format: markdown tables to stdout, JSON to file if --json specified
    - Port all functions: `meanMemory`, `parseHyperfineFile`, `parseSubsystemsFile`, `parseMetricAccuracy`, `formatSpeedRow`, `printSpeedTable`, `printMetricAccuracyTable`, `main`
    - Use `node:fs`, `node:path`, `node:process` only (no npm dependencies)
    - Same speedup formula: `cg_mean / fta_mean` (>1.0 = FTA faster)
    - Same rounding precision as Python version

    **Create `benchmarks/scripts/compare-metrics.mjs`** — Port `compare_metrics.py` to Node.js ESM:
    - Same CLI interface: `node compare-metrics.mjs <cg-json> <fta-json> <project-name>`
    - Same output: JSON to stdout, human summary to stderr
    - Port all functions: `normalizeCgPath`, `loadCgOutput`, `loadFtaOutput`, `diffPct`, `computeRankingCorrelation`, `analyzeMetric`
    - Same tolerance constants: CYCLOMATIC_TOLERANCE=25, HALSTEAD_TOLERANCE=30, LINE_COUNT_TOLERANCE=20
    - Same Spearman rank correlation implementation
    - Use `node:fs`, `node:path`, `node:process` only

    **Update `benchmarks/scripts/setup.sh`** — Replace the inline Python block (lines 60-130) that reads `public-projects.json` and clones repos:
    - Use `node -e` to extract project data from JSON and output in a shell-consumable format
    - OR rewrite the logic in pure bash using `jq` for JSON parsing:
      - `jq -r '.libraries[] | .name' "$PROJECTS_JSON"` to get names
      - `jq -r '.libraries[] | "\(.name) \(.git_url) \(.latest_stable_tag)"' "$PROJECTS_JSON"` to get clone data
    - Preserve the exact same cloning behavior: `git clone --branch TAG --depth 1 --single-branch --no-tags URL DEST`
    - Preserve warn-and-continue on clone failures, partial cleanup, cached/cloned/error counts

    **Update `benchmarks/scripts/bench-quick.sh`** — Replace 3 Python usages:
    1. Lines 98-111: Extract mean times from hyperfine JSON. Replace with:
       `cg_ms=$(jq -r '.results[0].mean * 1000 | . * 10 | round / 10' "$RESULT_JSON")`
       `fta_ms=$(jq -r '.results[1].mean * 1000 | . * 10 | round / 10' "$RESULT_JSON")`
    2. Line 124: Compute ratio. Replace with:
       `ratio=$(jq -rn "$fta_ms / (if $cg_ms == 0 then 0.001 else $cg_ms end) | . * 100 | round / 100 | tostring + \"x\"")`
       OR use `node -e "console.log((${fta_ms} / Math.max(${cg_ms}, 0.001)).toFixed(2) + 'x')"`

    **Update `benchmarks/scripts/bench-full.sh`** — Replace 3 Python usages:
    1. Lines 57-64: Extract project names from JSON. Replace with:
       `PROJECTS=$(jq -r '.libraries[].name' "$PROJECTS_JSON")`
    2. Lines 112-125: Extract mean times. Same jq pattern as bench-quick.sh.
    3. Line 139: Compute ratio. Same jq/node pattern as bench-quick.sh.

    **Update `benchmarks/scripts/bench-stress.sh`** — Replace 2 Python usages:
    1. Lines 109-122: Extract mean times. Same jq pattern as bench-quick.sh.
    2. Line 136: Compute ratio. Same jq/node pattern as bench-quick.sh.

    **Update `benchmarks/scripts/bench-subsystems.sh`** — Replace 1 Python usage:
    1. Lines 175-184: Extract hotspot name and percentage from JSON. Replace with:
       `hotspot_name=$(jq -r '.hotspot // "unknown"' "$RESULT_JSON")`
       `hotspot_pct=$(jq -r '.hotspot_pct // 0 | . * 10 | round / 10' "$RESULT_JSON")`

    **Update `benchmarks/scripts/compare-metrics.sh`** — Replace 2 Python usages:
    1. Lines 80-96 (full suite project list): Replace `python3 -c` with:
       `mapfile -t SUITE_PROJECTS < <(jq -r '.libraries[].name' "$PROJECTS_JSON")`
       Note: The `command -v python3` check on line 81 should be replaced with `command -v jq`.
    2. Lines 156-199 (aggregation block): Replace the inline Python heredoc with a `node` invocation that:
       - Iterates over projects, calls `node compare-metrics.mjs` for each
       - Collects JSON results into an array
       - Writes to `$ACCURACY_FILE`
       This can be done with a bash loop + `node compare-metrics.mjs` directly, collecting into a temp file, then combining with jq:
       ```
       echo "[" > "$ACCURACY_FILE"
       FIRST=true
       for project in "${SUITE_PROJECTS[@]}"; do
         # ... check files exist ...
         RESULT=$(node "$COMPARE_SCRIPT" "$cg_path" "$fta_path" "$project" 2>/dev/null)
         if [[ $? -eq 0 && -n "$RESULT" ]]; then
           $FIRST || echo "," >> "$ACCURACY_FILE"
           echo "$RESULT" >> "$ACCURACY_FILE"
           FIRST=false
         fi
       done
       echo "]" >> "$ACCURACY_FILE"
       ```
       Update the COMPARE_SCRIPT variable to point to `compare-metrics.mjs` and invoke with `node`.
       Update the final echo to reference `node` instead of `python3`.

    **For all shell script updates:** Also add a `jq` prerequisite check near the top:
    ```bash
    if ! command -v jq &>/dev/null; then
      echo "Error: jq not found. Install via: sudo apt install jq (or brew install jq)" >&2
      exit 1
    fi
    ```
    Only add this check in scripts that actually use jq (not in compare-metrics.sh if it only uses node).
  </action>
  <verify>
    1. `grep -r 'python' benchmarks/scripts/*.sh benchmarks/scripts/*.py 2>/dev/null` should return nothing (the .py files should be deleted in Task 2)
    2. `grep -r 'python' benchmarks/scripts/*.sh` should return no matches
    3. `node benchmarks/scripts/summarize-results.mjs --help 2>&1 || true` runs without error
    4. `node benchmarks/scripts/compare-metrics.mjs 2>&1 || true` shows usage without error
    5. `bash -n benchmarks/scripts/bench-quick.sh` (syntax check) passes
    6. `bash -n benchmarks/scripts/bench-full.sh` passes
    7. `bash -n benchmarks/scripts/bench-stress.sh` passes
    8. `bash -n benchmarks/scripts/bench-subsystems.sh` passes
    9. `bash -n benchmarks/scripts/setup.sh` passes
    10. `bash -n benchmarks/scripts/compare-metrics.sh` passes
  </verify>
  <done>All benchmark scripts use only node/jq for JSON processing. No python3 references remain in any .sh file. New .mjs scripts produce same output format as Python predecessors.</done>
</task>

<task type="auto">
  <name>Task 2: Delete Python scripts and update documentation</name>
  <files>
    benchmarks/scripts/summarize_results.py
    benchmarks/scripts/compare_metrics.py
    benchmarks/README.md
    docs/benchmarks.md
  </files>
  <action>
    **Delete Python scripts:**
    - `rm benchmarks/scripts/summarize_results.py`
    - `rm benchmarks/scripts/compare_metrics.py`

    **Update `benchmarks/README.md`:**
    - Prerequisites: Remove "python3 — for JSON parsing and result aggregation". Add "jq — for JSON extraction in shell scripts" with install command: `sudo apt install jq` / `brew install jq`
    - Quick Start: Change `python3 benchmarks/scripts/summarize_results.py` to `node benchmarks/scripts/summarize-results.mjs`
    - Script Reference table: Update `compare_metrics.py` row to `compare-metrics.mjs` and `summarize_results.py` row to `summarize-results.mjs`, change invocation from `python3` to `node`
    - "Adding New Benchmark Runs" section: Update all `python3` invocations to `node`
    - Ensure NO remaining references to `python3` or `.py` scripts (except in vendor/ which is not our concern)

    **Update `docs/benchmarks.md`:**
    - Reproducibility section: Change `python3 benchmarks/scripts/summarize_results.py` to `node benchmarks/scripts/summarize-results.mjs`
    - Detailed Results section: Same update for summarize command
    - "Running a New Baseline" section: Same update
    - Ensure NO remaining references to `python3` or `.py` scripts
  </action>
  <verify>
    1. `ls benchmarks/scripts/*.py 2>/dev/null` should return nothing
    2. `grep -r 'python3\|\.py' benchmarks/README.md docs/benchmarks.md` should return no matches (except possibly in the methodology note about "compare_metrics.py" in metric-accuracy.json schema docs — update that reference too if present)
    3. `grep 'summarize_results\|compare_metrics' benchmarks/README.md docs/benchmarks.md` should return no matches (replaced with kebab-case .mjs versions)
  </verify>
  <done>Python scripts deleted. All documentation references updated to node/jq. No python3 prerequisite listed anywhere in benchmark docs.</done>
</task>

</tasks>

<verification>
1. Full text search: `grep -r 'python' benchmarks/` should only match vendor files (if any), not any scripts or docs we own
2. All shell scripts pass bash syntax check: `for f in benchmarks/scripts/*.sh; do bash -n "$f"; done`
3. Node scripts are valid: `node -c benchmarks/scripts/summarize-results.mjs && node -c benchmarks/scripts/compare-metrics.mjs`
4. Prerequisites in README list only: Zig, Node.js/npm, hyperfine, jq
</verification>

<success_criteria>
- Zero references to python3 in any benchmark shell script
- Zero .py files in benchmarks/scripts/
- New .mjs scripts have same CLI interface and output format as Python predecessors
- All shell scripts pass bash syntax validation
- Documentation accurately reflects node/jq dependencies instead of python3
</success_criteria>

<output>
After completion, create `.planning/quick/18-remove-python-dependency-from-phase-10-1/18-SUMMARY.md`
</output>
