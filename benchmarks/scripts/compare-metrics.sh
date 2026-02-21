#!/usr/bin/env bash
# compare-metrics.sh — Run both CG and FTA on benchmark projects and compare metrics.
#
# Usage:
#   bash benchmarks/scripts/compare-metrics.sh [--suite quick|full|stress]
#
# Prerequisites:
#   - Run setup.sh --suite <suite> first to clone projects
#   - node/npm must be available for FTA auto-install
#   - python3 must be available
#   - Zig must be available for CG ReleaseFast build
#
# Output:
#   benchmarks/results/baseline-YYYY-MM-DD/metric-accuracy.json
#
# What this measures:
#   Per-file metric agreement between CG and FTA:
#     - Cyclomatic complexity (CG: sum of per-function; FTA: file-level)
#     - Halstead volume (CG: sum of per-function; FTA: file-level halstead.volume)
#     - Line count (CG: file_length; FTA: line_count)
#   CG's function-level values are aggregated to file-level for comparison.
#   Parser differences (tree-sitter vs SWC) cause expected divergence —
#   see compare_metrics.py for tolerance bands.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

# Parse --suite flag
SUITE="quick"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --suite)
      SUITE="${2:-quick}"
      shift 2
      ;;
    *)
      echo "Usage: compare-metrics.sh [--suite quick|full|stress]" >&2
      exit 1
      ;;
  esac
done

echo "Suite: $SUITE"
echo ""

# Build CG in ReleaseFast mode
echo "Building ComplexityGuard in ReleaseFast mode..."
(cd "$PROJECT_ROOT" && zig build -Doptimize=ReleaseFast)
CG_BIN="$PROJECT_ROOT/zig-out/bin/complexity-guard"
echo "CG binary: $CG_BIN ($("$CG_BIN" --version 2>&1 || true))"

# Auto-install FTA into temp dir
FTA_VERSION="3.0.0"
FTA_TEMP=$(mktemp -d /tmp/fta-bench-XXXX)
trap "rm -rf $FTA_TEMP" EXIT
echo "Installing fta-cli@${FTA_VERSION} into $FTA_TEMP..."
npm install "fta-cli@${FTA_VERSION}" --prefix "$FTA_TEMP" --quiet 2>/dev/null
FTA_BIN="$FTA_TEMP/node_modules/.bin/fta"
echo "FTA binary: $FTA_BIN ($("$FTA_BIN" --version 2>&1 || true))"

# Create timestamped results directory
RESULTS_DATE=$(date +%Y-%m-%d)
RESULTS_DIR="$PROJECT_ROOT/benchmarks/results/baseline-${RESULTS_DATE}"
mkdir -p "$RESULTS_DIR"
echo "Results dir: $RESULTS_DIR"

# Temp directory for CG/FTA output JSON files
METRICS_TEMP=$(mktemp -d /tmp/cg-fta-metrics-XXXX)
trap "rm -rf $FTA_TEMP $METRICS_TEMP" EXIT

# Project lists
PROJECTS_DIR="$PROJECT_ROOT/benchmarks/projects"

case "$SUITE" in
  quick)
    SUITE_PROJECTS=(zod got dayjs vite nestjs webpack typeorm rxjs effect vscode)
    ;;
  full)
    if ! command -v python3 &>/dev/null; then
      echo "Error: python3 required for full suite project list" >&2
      exit 1
    fi
    PROJECTS_JSON="$PROJECT_ROOT/benchmarks/public-projects.json"
    if [[ ! -f "$PROJECTS_JSON" ]]; then
      echo "Error: $PROJECTS_JSON not found" >&2
      exit 1
    fi
    mapfile -t SUITE_PROJECTS < <(python3 -c "
import json
with open('$PROJECTS_JSON') as f:
    data = json.load(f)
for p in data:
    print(p['name'])
")
    ;;
  stress)
    SUITE_PROJECTS=(vscode typescript)
    ;;
  *)
    echo "Error: unknown suite '$SUITE'. Use: quick, full, stress" >&2
    exit 1
    ;;
esac

echo ""
echo "=== Metric Accuracy Comparison: CG vs FTA ==="
echo "Suite: $SUITE (${#SUITE_PROJECTS[@]} projects)"
echo ""

COMPARED_COUNT=0
SKIPPED_COUNT=0

for project in "${SUITE_PROJECTS[@]}"; do
  PROJECT_DIR="$PROJECTS_DIR/$project"

  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Skipping $project (not cloned — run setup.sh --suite $SUITE)"
    ((SKIPPED_COUNT++)) || true
    continue
  fi

  echo "Comparing: $project"

  CG_OUTPUT="$METRICS_TEMP/cg-output-${project}.json"
  FTA_OUTPUT="$METRICS_TEMP/fta-output-${project}.json"

  # Run CG (capture stdout JSON); exit 1 is expected when threshold violations found
  "$CG_BIN" --format json --fail-on none "$PROJECT_DIR" > "$CG_OUTPUT" 2>/dev/null || true

  if [[ ! -s "$CG_OUTPUT" ]]; then
    echo "  Warning: CG produced no output for $project, skipping"
    ((SKIPPED_COUNT++)) || true
    continue
  fi

  # Run FTA (capture stdout JSON, suppress progress stderr)
  "$FTA_BIN" --json --exclude-under 0 "$PROJECT_DIR" > "$FTA_OUTPUT" 2>/dev/null || true

  if [[ ! -s "$FTA_OUTPUT" ]]; then
    echo "  Warning: FTA produced no output for $project, skipping"
    ((SKIPPED_COUNT++)) || true
    continue
  fi

  ((COMPARED_COUNT++)) || true
  echo ""
done

# Aggregate all comparison results into metric-accuracy.json via Python
ACCURACY_FILE="$RESULTS_DIR/metric-accuracy.json"
COMPARE_SCRIPT="$PROJECT_ROOT/benchmarks/scripts/compare_metrics.py"

echo "Aggregating comparison results..."
python3 - <<PYTHON
import json
import os
import subprocess
import sys

metrics_temp = "$METRICS_TEMP"
project_root = "$PROJECT_ROOT"
suite_projects = "$( IFS=' '; echo "${SUITE_PROJECTS[*]}" )".split()
compare_script = "$COMPARE_SCRIPT"
accuracy_file = "$ACCURACY_FILE"

all_results = []
for project in suite_projects:
    cg_path = os.path.join(metrics_temp, f"cg-output-{project}.json")
    fta_path = os.path.join(metrics_temp, f"fta-output-{project}.json")
    if not os.path.exists(cg_path) or not os.path.exists(fta_path):
        continue
    if os.path.getsize(cg_path) == 0 or os.path.getsize(fta_path) == 0:
        continue

    result = subprocess.run(
        [sys.executable, compare_script, cg_path, fta_path, project],
        capture_output=True, text=True
    )
    if result.returncode == 0 and result.stdout.strip():
        try:
            obj = json.loads(result.stdout)
            all_results.append(obj)
            # Print the human summary that went to stderr
            if result.stderr.strip():
                print(result.stderr.strip(), file=sys.stderr)
        except json.JSONDecodeError as e:
            print(f"Warning: invalid JSON from {project}: {e}", file=sys.stderr)
    else:
        print(f"Warning: comparison failed for {project}", file=sys.stderr)
        if result.stderr:
            print(result.stderr, file=sys.stderr)

with open(accuracy_file, "w") as f:
    json.dump(all_results, f, indent=2)

print(f"Metric accuracy results: {len(all_results)} projects written to {accuracy_file}")
PYTHON

echo ""
echo "=== Summary ==="
echo "Projects compared: $COMPARED_COUNT"
echo "Projects skipped:  $SKIPPED_COUNT"
echo "Results written to: $ACCURACY_FILE"
echo ""
echo "To view results:"
echo "  python3 benchmarks/scripts/summarize_results.py $RESULTS_DIR"
