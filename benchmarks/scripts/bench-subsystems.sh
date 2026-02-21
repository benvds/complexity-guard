#!/usr/bin/env bash
# bench-subsystems.sh — Run the Zig subsystem benchmark (complexity-bench) against
# each project in the selected suite, producing per-project timing JSON files.
#
# Usage:
#   bash benchmarks/scripts/bench-subsystems.sh [--suite quick|full|stress] [--runs N]
#
# Prerequisites:
#   - Run setup.sh first to clone projects (e.g. setup.sh --suite quick)
#   - zig must be available on PATH
#
# Output:
#   benchmarks/results/baseline-YYYY-MM-DD/${project}-subsystems.json
#   (one JSON file per project with per-subsystem timing breakdown)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

# ── Suite definitions (mirror setup.sh) ───────────────────────────────────────
# quick: 10 representative projects spanning size/quality/language tiers
QUICK_SUITE=(zod got dayjs vite nestjs webpack typeorm rxjs effect vscode)
# full: all 76 projects (subset: use quick for now, full list from public-projects.json)
FULL_SUITE=(zod got dayjs vite nestjs webpack typeorm rxjs effect vscode)
# stress: only the 3 largest repos
STRESS_SUITE=(vscode typescript effect)

# ── Argument parsing ───────────────────────────────────────────────────────────

SUITE="quick"
RUNS=""  # empty = use per-suite default

while [[ $# -gt 0 ]]; do
  case "$1" in
    --suite)
      SUITE="${2:-quick}"
      shift 2
      ;;
    --suite=*)
      SUITE="${1#--suite=}"
      shift
      ;;
    --runs)
      RUNS="${2:-}"
      shift 2
      ;;
    --runs=*)
      RUNS="${1#--runs=}"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--suite quick|full|stress] [--runs N]"
      echo ""
      echo "Options:"
      echo "  --suite SUITE   Project suite to benchmark (default: quick)"
      echo "  --runs N        Iterations per subsystem (default: 10 for quick/full, 3 for stress)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--suite quick|full|stress] [--runs N]" >&2
      exit 1
      ;;
  esac
done

# Select project list and default run count based on suite
case "$SUITE" in
  quick)
    SUITE_PROJECTS=("${QUICK_SUITE[@]}")
    DEFAULT_RUNS=10
    ;;
  full)
    SUITE_PROJECTS=("${FULL_SUITE[@]}")
    DEFAULT_RUNS=10
    ;;
  stress)
    SUITE_PROJECTS=("${STRESS_SUITE[@]}")
    DEFAULT_RUNS=3
    ;;
  *)
    echo "Error: --suite must be quick, full, or stress (got: $SUITE)" >&2
    exit 1
    ;;
esac

# Use explicit --runs if provided, otherwise suite default
if [[ -z "$RUNS" ]]; then
  RUNS="$DEFAULT_RUNS"
fi

# ── Build complexity-bench in ReleaseFast ──────────────────────────────────────

echo "Building complexity-bench in ReleaseFast mode..."
(cd "$PROJECT_ROOT" && zig build bench-build -Doptimize=ReleaseFast)
BENCH_BIN="$PROJECT_ROOT/zig-out/bin/complexity-bench"

if [[ ! -x "$BENCH_BIN" ]]; then
  echo "Error: complexity-bench binary not found at $BENCH_BIN" >&2
  exit 1
fi
echo "complexity-bench: $BENCH_BIN"

# ── Check projects are cloned ──────────────────────────────────────────────────

PROJECTS_DIR="$PROJECT_ROOT/benchmarks/projects"

CLONED_COUNT=0
for project in "${SUITE_PROJECTS[@]}"; do
  if [[ -d "$PROJECTS_DIR/$project" ]]; then
    ((CLONED_COUNT++)) || true
  fi
done

if [[ "$CLONED_COUNT" -eq 0 ]]; then
  echo "" >&2
  echo "Error: No ${SUITE} suite projects found in $PROJECTS_DIR" >&2
  echo "Run: bash benchmarks/scripts/setup.sh --suite ${SUITE}" >&2
  echo "" >&2
  exit 1
fi

# ── Create timestamped results directory ───────────────────────────────────────

RESULTS_DATE=$(date +%Y-%m-%d)
RESULTS_DIR="$PROJECT_ROOT/benchmarks/results/baseline-${RESULTS_DATE}"
mkdir -p "$RESULTS_DIR"

TOTAL="${#SUITE_PROJECTS[@]}"

echo ""
echo "=== ComplexityGuard Subsystem Benchmark ==="
echo "Suite: $SUITE ($CLONED_COUNT / $TOTAL projects cloned)"
echo "Runs per subsystem: $RUNS"
echo "Results dir: $RESULTS_DIR"
echo ""

# ── Run benchmark for each project ────────────────────────────────────────────

IDX=0
SKIPPED=0
SUCCEEDED=0

# Track aggregate hotspot data across all projects
declare -A HOTSPOT_COUNT
declare -A HOTSPOT_PROJECT_LIST

for project in "${SUITE_PROJECTS[@]}"; do
  ((IDX++)) || true
  PROJECT_DIR="$PROJECTS_DIR/$project"

  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "[$IDX/$TOTAL] Skipping $project (not cloned — run setup.sh --suite ${SUITE})"
    ((SKIPPED++)) || true
    continue
  fi

  RESULT_JSON="$RESULTS_DIR/${project}-subsystems.json"
  echo "[$IDX/$TOTAL] Benchmarking subsystems: $project"

  # Run the Zig subsystem benchmark; warn and skip on failure
  if ! "$BENCH_BIN" \
    --runs "$RUNS" \
    --json "$RESULT_JSON" \
    "$PROJECT_DIR"; then
    echo "  Warning: benchmark failed for $project (skipping)" >&2
    ((SKIPPED++)) || true
    continue
  fi

  ((SUCCEEDED++)) || true

  # Extract hotspot from JSON for aggregate summary
  if command -v python3 &>/dev/null && [[ -f "$RESULT_JSON" ]]; then
    hotspot_data=$(python3 - <<PYTHON
import json
with open("$RESULT_JSON") as f:
    data = json.load(f)
hotspot = data.get("hotspot", "unknown")
pct = data.get("hotspot_pct", 0.0)
print(f"{hotspot} {pct:.1f}")
PYTHON
)
    hotspot_name=$(echo "$hotspot_data" | awk '{print $1}')
    hotspot_pct=$(echo "$hotspot_data" | awk '{print $2}')

    # Count hotspot occurrences per subsystem
    if [[ -n "${HOTSPOT_COUNT[$hotspot_name]:-}" ]]; then
      HOTSPOT_COUNT[$hotspot_name]=$((${HOTSPOT_COUNT[$hotspot_name]} + 1))
      HOTSPOT_PROJECT_LIST[$hotspot_name]="${HOTSPOT_PROJECT_LIST[$hotspot_name]}, $project"
    else
      HOTSPOT_COUNT[$hotspot_name]=1
      HOTSPOT_PROJECT_LIST[$hotspot_name]="$project"
    fi
    echo "  Hotspot: $hotspot_name (${hotspot_pct}% of total)"
  fi

  echo ""
done

# ── Print aggregate summary ────────────────────────────────────────────────────

echo "=== Summary: $SUCCEEDED / $TOTAL projects benchmarked ==="
echo ""

if [[ ${#HOTSPOT_COUNT[@]} -gt 0 ]]; then
  echo "Hotspot distribution (which subsystem is slowest per project):"
  printf "  %-20s %8s  %s\n" "Subsystem" "Count" "Projects"
  printf "  %-20s %8s  %s\n" "---------" "-----" "--------"

  # Sort by count descending
  for subsystem in $(for k in "${!HOTSPOT_COUNT[@]}"; do echo "${HOTSPOT_COUNT[$k]} $k"; done | sort -rn | awk '{print $2}'); do
    count="${HOTSPOT_COUNT[$subsystem]}"
    projects="${HOTSPOT_PROJECT_LIST[$subsystem]}"
    printf "  %-20s %8d  %s\n" "$subsystem" "$count" "$projects"
  done

  echo ""
  dominant=$(for k in "${!HOTSPOT_COUNT[@]}"; do echo "${HOTSPOT_COUNT[$k]} $k"; done | sort -rn | head -1 | awk '{print $2}')
  echo "Overall hotspot: $dominant (most frequently the slowest subsystem)"
fi

echo ""
echo "Subsystem JSON files written to:"
echo "  $RESULTS_DIR/*-subsystems.json"
echo ""
echo "Done."
