#!/usr/bin/env bash
# bench-rust-vs-zig.sh — Hyperfine benchmark: Rust binary vs Zig binary, quick suite (10 projects)
#
# Usage:
#   bash benchmarks/scripts/bench-rust-vs-zig.sh
#
# Prerequisites:
#   - Run setup.sh --suite quick first to clone projects
#   - hyperfine must be installed (checked at /home/ben/.cargo/bin/hyperfine or on PATH)
#   - jq must be installed for JSON extraction
#   - Zig 0.14.0+ must be available (for building the Zig binary)
#   - Rust / Cargo must be available (for building the Rust binary)
#
# Output:
#   benchmarks/results/rust-vs-zig-YYYY-MM-DD/${project}-rust-vs-zig.json (hyperfine JSON per project)

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
    mem_total_gb=$(python3 -c "print(round($mem_bytes / 1073741824, 1))" 2>/dev/null || echo "0")
    cpu_max_mhz=$(sysctl -n hw.cpufrequency_max 2>/dev/null | python3 -c "import sys; n=int(sys.stdin.read().strip()); print(round(n/1000000))" 2>/dev/null || echo 0)
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
    cpu_max_mhz=$(python3 -c "print(round(float('$max_mhz_raw')))" 2>/dev/null || echo 0)
    local mem_kb
    mem_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0)
    mem_total_gb=$(python3 -c "print(round($mem_kb / 1048576, 1))" 2>/dev/null || echo "0")
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

# Build Zig binary in ReleaseFast mode
echo "Building Zig ComplexityGuard in ReleaseFast mode..."
(cd "$PROJECT_ROOT/zig" && zig build -Doptimize=ReleaseFast)
ZIG_BIN="$PROJECT_ROOT/zig/zig-out/bin/complexity-guard"
echo "Zig binary: $ZIG_BIN ($("$ZIG_BIN" --version 2>&1 || true))"

# Build Rust binary in release mode
echo "Building Rust ComplexityGuard in release mode..."
(cd "$PROJECT_ROOT/rust" && cargo build --release)
RUST_BIN="$PROJECT_ROOT/rust/target/release/complexity-guard"
echo "Rust binary: $RUST_BIN ($("$RUST_BIN" --version 2>&1 || true))"

# Create timestamped results directory
RESULTS_DATE=$(date +%Y-%m-%d)
RESULTS_DIR="$PROJECT_ROOT/zig/benchmarks/results/rust-vs-zig-${RESULTS_DATE}"
mkdir -p "$RESULTS_DIR"
capture_system_info "$RESULTS_DIR"
echo "Results dir: $RESULTS_DIR"

# Quick suite project list (must match setup.sh QUICK_SUITE)
QUICK_SUITE=(zod got dayjs vite nestjs webpack typeorm rxjs effect vscode)
PROJECTS_DIR="$PROJECT_ROOT/zig/benchmarks/projects"

# Verify at least some projects are cloned
CLONED_COUNT=0
for project in "${QUICK_SUITE[@]}"; do
  if [[ -d "$PROJECTS_DIR/$project" ]]; then
    ((CLONED_COUNT++)) || true
  fi
done

if [[ "$CLONED_COUNT" -eq 0 ]]; then
  echo "Error: No quick suite projects found in $PROJECTS_DIR" >&2
  echo "Run: bash benchmarks/scripts/setup.sh --suite quick" >&2
  exit 1
fi

echo ""
echo "=== Rust vs Zig ComplexityGuard Quick Suite Benchmark ==="
echo "Projects available: $CLONED_COUNT / ${#QUICK_SUITE[@]}"
echo "Warmup runs: 3 | Benchmark runs: 15"
echo ""

# Collect results for summary table
declare -A RUST_MEAN
declare -A ZIG_MEAN

# Run hyperfine for each project
for project in "${QUICK_SUITE[@]}"; do
  PROJECT_DIR="$PROJECTS_DIR/$project"

  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Skipping $project (not cloned — run setup.sh to clone)"
    continue
  fi

  RESULT_JSON="$RESULTS_DIR/${project}-rust-vs-zig.json"
  echo "Benchmarking: $project"

  "$HYPERFINE" \
    --warmup 3 \
    --runs 15 \
    --ignore-failure \
    --command-name "Rust" \
    --command-name "Zig" \
    --export-json "$RESULT_JSON" \
    "${RUST_BIN} --format json --fail-on none ${PROJECT_DIR}" \
    "${ZIG_BIN} --format json --fail-on none ${PROJECT_DIR}"

  # Extract mean times from JSON using jq
  if [[ -f "$RESULT_JSON" ]]; then
    rust_ms=$(jq -r '.results[0].mean * 1000 | . * 10 | round / 10' "$RESULT_JSON" 2>/dev/null || echo "")
    zig_ms=$(jq -r '.results[1].mean * 1000 | . * 10 | round / 10' "$RESULT_JSON" 2>/dev/null || echo "")
    if [[ -n "$rust_ms" && -n "$zig_ms" ]]; then
      RUST_MEAN[$project]="$rust_ms"
      ZIG_MEAN[$project]="$zig_ms"
    fi
  fi

  echo ""
done

# Print summary table
echo "=== Summary: Mean Wall-Clock Time (ms) ==="
echo "Ratio = Rust / Zig  (< 1.0 means Rust is faster, > 1.0 means Zig is faster)"
echo ""
printf "%-15s %10s %10s %10s\n" "Project" "Rust (ms)" "Zig (ms)" "Ratio"
printf "%-15s %10s %10s %10s\n" "-------" "---------" "--------" "-----"

TOTAL_RATIO=0
RATIO_COUNT=0

for project in "${QUICK_SUITE[@]}"; do
  if [[ -n "${RUST_MEAN[$project]:-}" && -n "${ZIG_MEAN[$project]:-}" ]]; then
    rust_ms="${RUST_MEAN[$project]}"
    zig_ms="${ZIG_MEAN[$project]}"
    ratio=$(python3 -c "print(f'{${rust_ms} / max(${zig_ms}, 0.001):.3f}')" 2>/dev/null || echo "N/A")
    printf "%-15s %10s %10s %10s\n" "$project" "${rust_ms}ms" "${zig_ms}ms" "$ratio"
    if [[ "$ratio" != "N/A" ]]; then
      TOTAL_RATIO=$(python3 -c "print($TOTAL_RATIO + $ratio)" 2>/dev/null || echo "$TOTAL_RATIO")
      ((RATIO_COUNT++)) || true
    fi
  fi
done

if [[ "$RATIO_COUNT" -gt 0 ]]; then
  AVG_RATIO=$(python3 -c "print(f'{$TOTAL_RATIO / $RATIO_COUNT:.3f}')" 2>/dev/null || echo "N/A")
  printf "%-15s %10s %10s %10s\n" "-------" "---------" "--------" "-----"
  printf "%-15s %31s\n" "Average ratio" "$AVG_RATIO"
  echo ""
  if python3 -c "exit(0 if $AVG_RATIO < 1.0 else 1)" 2>/dev/null; then
    echo "Overall: Rust is faster on average (ratio $AVG_RATIO)"
  elif python3 -c "exit(0 if $AVG_RATIO > 1.0 else 1)" 2>/dev/null; then
    echo "Overall: Zig is faster on average (ratio $AVG_RATIO)"
  else
    echo "Overall: Equal performance on average (ratio $AVG_RATIO)"
  fi
fi

echo ""
echo "Results saved to: $RESULTS_DIR"
echo "Run 'ls $RESULTS_DIR/' to see per-project JSON files."
