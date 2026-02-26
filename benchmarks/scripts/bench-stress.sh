#!/usr/bin/env bash
# bench-stress.sh — Hyperfine stress-test benchmark: massive repos (vscode, TypeScript, effect)
#
# Usage:
#   bash benchmarks/scripts/bench-stress.sh
#
# Prerequisites:
#   - Run setup.sh --suite stress first to clone massive repos
#   - hyperfine must be installed (checked at /home/ben/.cargo/bin/hyperfine or on PATH)
#   - jq must be installed for JSON extraction
#
# Output:
#   benchmarks/results/baseline-YYYY-MM-DD/${project}-stress.json (hyperfine JSON per project)
#
# Note: Stress suite uses reduced runs (5) and warmup (1) due to massive repo size.
#       Each hyperfine invocation has a 5-minute timeout to prevent runaway processes.

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

# Locate hyperfine
HYPERFINE=$(command -v hyperfine 2>/dev/null || echo /home/ben/.cargo/bin/hyperfine)
if [[ ! -x "$HYPERFINE" ]]; then
  echo "Error: hyperfine not found. Install via: cargo install hyperfine" >&2
  exit 1
fi
echo "hyperfine: $HYPERFINE ($("$HYPERFINE" --version))"

# Build CG in release mode
echo "Building ComplexityGuard in release mode..."
(cd "$PROJECT_ROOT" && cargo build --release)
CG_BIN="$PROJECT_ROOT/target/release/complexity-guard"
echo "CG binary: $CG_BIN ($("$CG_BIN" --version 2>&1 || true))"

# Create timestamped results directory
RESULTS_DATE=$(date +%Y-%m-%d)
RESULTS_DIR="$PROJECT_ROOT/benchmarks/results/baseline-${RESULTS_DATE}"
mkdir -p "$RESULTS_DIR"
capture_system_info "$RESULTS_DIR"
echo "Results dir: $RESULTS_DIR"

# Stress suite: only the 3 massive repos
# Note: Uses fewer runs and warmup than quick/full due to repo size.
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
echo "=== ComplexityGuard Stress-Test Suite Benchmark ==="
echo "Projects available: $CLONED_COUNT / ${#STRESS_SUITE[@]}"
echo "Warmup runs: 1 | Benchmark runs: 5 | Timeout: 5 minutes per invocation"
echo ""

declare -A CG_MEAN

for project in "${STRESS_SUITE[@]}"; do
  PROJECT_DIR="$PROJECTS_DIR/$project"

  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Skipping $project (not cloned — run setup.sh --suite stress to clone)"
    continue
  fi

  RESULT_JSON="$RESULTS_DIR/${project}-stress.json"
  ANALYSIS_JSON="$RESULTS_DIR/${project}-analysis.json"
  echo "Benchmarking (stress): $project"
  echo "  Warning: This may take several minutes for massive repos."

  # 5-minute timeout per hyperfine invocation for massive repos
  timeout 300 "$HYPERFINE" \
    --warmup 1 \
    --runs 5 \
    --ignore-failure \
    --export-json "$RESULT_JSON" \
    "${CG_BIN} --format json --fail-on none ${PROJECT_DIR}" || {
    echo "  Warning: $project benchmark timed out or failed (exit: $?)"
    echo "  Partial results may exist at $RESULT_JSON"
    continue
  }

  # Capture analysis output (files, functions, metrics, health score)
  if [[ ! -f "$ANALYSIS_JSON" ]]; then
    "$CG_BIN" --format json --fail-on none "$PROJECT_DIR" > "$ANALYSIS_JSON" 2>/dev/null || true
  fi

  # Extract mean time from JSON using jq
  if [[ -f "$RESULT_JSON" ]]; then
    cg_ms=$(jq -r '.results[0].mean * 1000 | . * 10 | round / 10' "$RESULT_JSON" 2>/dev/null || echo "")
    if [[ -n "$cg_ms" ]]; then
      CG_MEAN[$project]="$cg_ms"
    fi
  fi

  echo ""
done

# Print summary table
echo "=== Summary: Mean Wall-Clock Time (ms) ==="
printf "%-15s %12s\n" "Project" "CG (ms)"
printf "%-15s %12s\n" "-------" "-------"
for project in "${STRESS_SUITE[@]}"; do
  if [[ -n "${CG_MEAN[$project]:-}" ]]; then
    cg_ms="${CG_MEAN[$project]}"
    printf "%-15s %12s\n" "$project" "${cg_ms}ms"
  fi
done

echo ""
echo "Results saved to: $RESULTS_DIR"
