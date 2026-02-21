#!/usr/bin/env bash
# bench-stress.sh — Hyperfine stress-test benchmark: massive repos (vscode, TypeScript, effect)
#
# Usage:
#   bash benchmarks/scripts/bench-stress.sh
#
# Prerequisites:
#   - Run setup.sh --suite stress first to clone massive repos
#   - hyperfine must be installed (checked at /home/ben/.cargo/bin/hyperfine or on PATH)
#   - node/npm must be available for FTA auto-install
#
# Output:
#   benchmarks/results/baseline-YYYY-MM-DD/${project}-stress.json (hyperfine JSON per project)
#
# Note: Stress suite uses reduced runs (5) and warmup (1) due to massive repo size.
#       Each hyperfine invocation has a 5-minute timeout to prevent runaway processes.
#       ComplexityGuard is currently single-threaded (Phase 12 will add parallelization).
#       These results document the single-threaded baseline for before/after comparison.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

# Locate hyperfine
HYPERFINE=$(command -v hyperfine 2>/dev/null || echo /home/ben/.cargo/bin/hyperfine)
if [[ ! -x "$HYPERFINE" ]]; then
  echo "Error: hyperfine not found. Install via: cargo install hyperfine" >&2
  exit 1
fi
echo "hyperfine: $HYPERFINE ($("$HYPERFINE" --version))"

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

# Stress suite: only the 3 massive repos
# Note: Uses fewer runs and warmup than quick/full due to repo size.
# Note: ComplexityGuard is single-threaded at this baseline. Phase 12 will add
#       parallelization — rerun this suite after Phase 12 for before/after comparison.
STRESS_SUITE=(vscode typescript effect)
PROJECTS_DIR="$PROJECT_ROOT/benchmarks/projects"

CLONED_COUNT=0
for project in "${STRESS_SUITE[@]}"; do
  if [[ -d "$PROJECTS_DIR/$project" ]]; then
    ((CLONED_COUNT++)) || true
  fi
done

if [[ "$CLONED_COUNT" -eq 0 ]]; then
  echo "Error: No stress suite projects found in $PROJECTS_DIR" >&2
  echo "Run: bash benchmarks/scripts/setup.sh --suite stress" >&2
  exit 1
fi

echo ""
echo "=== ComplexityGuard vs FTA Stress-Test Suite Benchmark ==="
echo "Projects available: $CLONED_COUNT / ${#STRESS_SUITE[@]}"
echo "Warmup runs: 1 | Benchmark runs: 5 | Timeout: 5 minutes per invocation"
echo "Limitation: CG is single-threaded (no parallelization until Phase 12)"
echo ""

declare -A CG_MEAN
declare -A FTA_MEAN

for project in "${STRESS_SUITE[@]}"; do
  PROJECT_DIR="$PROJECTS_DIR/$project"

  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Skipping $project (not cloned — run setup.sh --suite stress to clone)"
    continue
  fi

  RESULT_JSON="$RESULTS_DIR/${project}-stress.json"
  echo "Benchmarking (stress): $project"
  echo "  Warning: This may take several minutes for massive repos."

  # 5-minute timeout per hyperfine invocation for massive repos
  timeout 300 "$HYPERFINE" \
    --warmup 1 \
    --runs 5 \
    --ignore-failure \
    --export-json "$RESULT_JSON" \
    "${CG_BIN} --format json --fail-on none ${PROJECT_DIR}" \
    "${FTA_BIN} --json --exclude-under 0 ${PROJECT_DIR}" || {
    echo "  Warning: $project benchmark timed out or failed (exit: $?)"
    echo "  Partial results may exist at $RESULT_JSON"
    continue
  }

  if command -v python3 &>/dev/null && [[ -f "$RESULT_JSON" ]]; then
    read -r cg_ms fta_ms < <(python3 - <<PYTHON
import json
with open("$RESULT_JSON") as f:
    data = json.load(f)
results = data.get("results", [])
cg_ms = round(results[0]["mean"] * 1000, 1) if len(results) > 0 else 0
fta_ms = round(results[1]["mean"] * 1000, 1) if len(results) > 1 else 0
print(cg_ms, fta_ms)
PYTHON
)
    CG_MEAN[$project]="$cg_ms"
    FTA_MEAN[$project]="$fta_ms"
  fi

  echo ""
done

# Print summary table
echo "=== Summary: Mean Wall-Clock Time (ms) ==="
echo "(Single-threaded CG baseline — Phase 12 parallelization will improve this)"
printf "%-15s %12s %12s %10s\n" "Project" "CG (ms)" "FTA (ms)" "Ratio"
printf "%-15s %12s %12s %10s\n" "-------" "-------" "--------" "-----"
for project in "${STRESS_SUITE[@]}"; do
  if [[ -n "${CG_MEAN[$project]:-}" && -n "${FTA_MEAN[$project]:-}" ]]; then
    cg_ms="${CG_MEAN[$project]}"
    fta_ms="${FTA_MEAN[$project]}"
    ratio=$(python3 -c "print(f'{$fta_ms / max($cg_ms, 0.001):.2f}x')" 2>/dev/null || echo "N/A")
    printf "%-15s %12s %12s %10s\n" "$project" "${cg_ms}ms" "${fta_ms}ms" "$ratio"
  fi
done

echo ""
echo "Results saved to: $RESULTS_DIR"
echo ""
echo "Phase 12 note: After parallelization is implemented, rerun this script to"
echo "  measure speedup. Compare $RESULTS_DIR/*-stress.json files."
