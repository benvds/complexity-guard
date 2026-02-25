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
#   - jq must be installed for JSON extraction
#
# Output:
#   benchmarks/results/baseline-YYYY-MM-DD/${project}-subsystems.json
#   (one JSON file per project with per-subsystem timing breakdown)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

# Capture system specs into $RESULTS_DIR/system-info.json (skip if already present).
# Called after mkdir -p "$RESULTS_DIR". Works on Linux and macOS.
capture_system_info() {
  local results_dir="$1"
  local system_info_file="$results_dir/system-info.json"

  if [[ -f "$system_info_file" ]]; then
    return 0
  fi

  local hostname_val kernel_val arch os_name
  local cpu_model cpu_cores cpu_threads cpu_max_mhz mem_total_gb

  hostname_val=$(hostname 2>/dev/null || echo "unknown")
  kernel_val=$(uname -r 2>/dev/null || echo "unknown")
  arch=$(uname -m 2>/dev/null || echo "unknown")

  if [[ "$(uname -s)" == "Darwin" ]]; then
    os_name="macOS $(sw_vers -productVersion 2>/dev/null || echo "unknown")"
    cpu_model=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "unknown")
    cpu_threads=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 0)
    cpu_cores=$(sysctl -n hw.physicalcpu 2>/dev/null || echo 0)
    local mem_bytes
    mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    mem_total_gb=$(node -e "console.log(($mem_bytes / 1073741824).toFixed(1))" 2>/dev/null || echo "0")
    cpu_max_mhz=$(sysctl -n hw.cpufrequency_max 2>/dev/null | node -e "const n=parseInt(require('fs').readFileSync('/dev/stdin','utf8'));console.log(Math.round(n/1000000))" 2>/dev/null || echo 0)
  else
    # Linux
    local os_id os_version
    os_id=$(grep '^NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "Linux")
    os_version=$(grep '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")
    os_name="$os_id${os_version:+ $os_version}"
    cpu_model=$(lscpu 2>/dev/null | grep 'Model name:' | sed 's/Model name:\s*//' | xargs || echo "unknown")
    cpu_threads=$(lscpu 2>/dev/null | grep '^CPU(s):' | awk '{print $2}' || echo 0)
    cpu_cores=$(lscpu 2>/dev/null | grep '^Core(s) per socket:' | awk '{print $4}' || echo 0)
    local max_mhz_raw
    max_mhz_raw=$(lscpu 2>/dev/null | grep 'CPU max MHz:' | awk '{print $4}' || echo "0")
    cpu_max_mhz=$(node -e "console.log(Math.round(parseFloat('$max_mhz_raw')))" 2>/dev/null || echo 0)
    local mem_kb
    mem_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0)
    mem_total_gb=$(node -e "console.log(($mem_kb / 1048576).toFixed(1))" 2>/dev/null || echo "0")
  fi

  jq -n \
    --arg hostname "$hostname_val" \
    --arg os "$os_name" \
    --arg kernel "$kernel_val" \
    --arg arch "$arch" \
    --arg cpu_model "$cpu_model" \
    --argjson cpu_cores "$cpu_cores" \
    --argjson cpu_threads "$cpu_threads" \
    --argjson cpu_max_mhz "$cpu_max_mhz" \
    --argjson mem_total_gb "$mem_total_gb" \
    --arg captured_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{hostname: $hostname, os: $os, kernel: $kernel, arch: $arch,
      cpu: {model: $cpu_model, cores: $cpu_cores, threads: $cpu_threads, max_mhz: $cpu_max_mhz},
      memory: {total_gb: $mem_total_gb}, captured_at: $captured_at}' \
    > "$system_info_file"
  echo "System info: $system_info_file"
}

# Check for jq
if ! command -v jq &>/dev/null; then
  echo "Error: jq not found. Install via: sudo apt install jq (or brew install jq)" >&2
  exit 1
fi

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
capture_system_info "$RESULTS_DIR"

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

  # Extract hotspot from JSON using jq
  if [[ -f "$RESULT_JSON" ]]; then
    hotspot_name=$(jq -r '.hotspot // "unknown"' "$RESULT_JSON" 2>/dev/null || echo "unknown")
    hotspot_pct=$(jq -r '(.hotspot_pct // 0) * 10 | round / 10' "$RESULT_JSON" 2>/dev/null || echo "0")

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
