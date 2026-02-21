#!/usr/bin/env bash
# bench-full.sh — Hyperfine end-to-end benchmark: full suite (all 76 projects, CG vs FTA)
#
# Usage:
#   bash benchmarks/scripts/bench-full.sh
#
# Prerequisites:
#   - Run setup.sh --suite full first to clone all 76 projects
#   - hyperfine must be installed (checked at /home/ben/.cargo/bin/hyperfine or on PATH)
#   - node/npm must be available for FTA auto-install
#   - jq must be installed for JSON extraction
#
# Output:
#   benchmarks/results/baseline-YYYY-MM-DD/${project}-full.json (hyperfine JSON per project)
#
# Note: Full suite takes significantly longer than quick suite. Allow 30-60+ minutes
#       depending on hardware. Some large projects (vscode, TypeScript) may take
#       several minutes each.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
PROJECTS_JSON="$PROJECT_ROOT/tests/public-projects.json"

# Check for jq
if ! command -v jq &>/dev/null; then
  echo "Error: jq not found. Install via: sudo apt install jq (or brew install jq)" >&2
  exit 1
fi

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

PROJECTS_DIR="$PROJECT_ROOT/benchmarks/projects"

# Extract all project names from JSON using jq
PROJECTS=$(jq -r '.libraries[].name' "$PROJECTS_JSON")

# Count available projects
TOTAL_PROJECTS=$(echo "$PROJECTS" | wc -l | tr -d ' ')
CLONED_COUNT=0
while IFS= read -r project; do
  if [[ -d "$PROJECTS_DIR/$project" ]]; then
    ((CLONED_COUNT++)) || true
  fi
done <<< "$PROJECTS"

if [[ "$CLONED_COUNT" -eq 0 ]]; then
  echo "Error: No full suite projects found in $PROJECTS_DIR" >&2
  echo "Run: bash benchmarks/scripts/setup.sh --suite full" >&2
  exit 1
fi

echo ""
echo "=== ComplexityGuard vs FTA Full Suite Benchmark ==="
echo "Projects available: $CLONED_COUNT / $TOTAL_PROJECTS"
echo "Warmup runs: 3 | Benchmark runs: 15"
echo ""

# Collect results for summary
declare -A CG_MEAN
declare -A FTA_MEAN

# Run hyperfine for each available project
BENCHMARKED=0
while IFS= read -r project; do
  PROJECT_DIR="$PROJECTS_DIR/$project"

  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Skipping $project (not cloned)"
    continue
  fi

  RESULT_JSON="$RESULTS_DIR/${project}-full.json"
  echo "[$((BENCHMARKED+1))/$CLONED_COUNT] Benchmarking: $project"

  "$HYPERFINE" \
    --warmup 3 \
    --runs 15 \
    --ignore-failure \
    --export-json "$RESULT_JSON" \
    "${CG_BIN} --format json --fail-on none ${PROJECT_DIR}" \
    "${FTA_BIN} --json --exclude-under 0 ${PROJECT_DIR}"

  # Extract mean times from JSON using jq
  if [[ -f "$RESULT_JSON" ]]; then
    cg_ms=$(jq -r '.results[0].mean * 1000 | . * 10 | round / 10' "$RESULT_JSON" 2>/dev/null || echo "")
    fta_ms=$(jq -r '.results[1].mean * 1000 | . * 10 | round / 10' "$RESULT_JSON" 2>/dev/null || echo "")
    if [[ -n "$cg_ms" && -n "$fta_ms" ]]; then
      CG_MEAN[$project]="$cg_ms"
      FTA_MEAN[$project]="$fta_ms"
    fi
  fi

  ((BENCHMARKED++)) || true
  echo ""
done <<< "$PROJECTS"

# Print summary table
echo "=== Summary: Mean Wall-Clock Time (ms) ==="
printf "%-25s %10s %10s %10s\n" "Project" "CG (ms)" "FTA (ms)" "Ratio"
printf "%-25s %10s %10s %10s\n" "-------" "-------" "--------" "-----"
while IFS= read -r project; do
  if [[ -n "${CG_MEAN[$project]:-}" && -n "${FTA_MEAN[$project]:-}" ]]; then
    cg_ms="${CG_MEAN[$project]}"
    fta_ms="${FTA_MEAN[$project]}"
    ratio=$(node -e "console.log((${fta_ms} / Math.max(${cg_ms}, 0.001)).toFixed(2) + 'x')" 2>/dev/null || echo "N/A")
    printf "%-25s %10s %10s %10s\n" "$project" "${cg_ms}ms" "${fta_ms}ms" "$ratio"
  fi
done <<< "$PROJECTS"

echo ""
echo "Benchmarked: $BENCHMARKED projects"
echo "Results saved to: $RESULTS_DIR"
