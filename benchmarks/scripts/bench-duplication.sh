#!/usr/bin/env bash
# bench-duplication.sh — Benchmark duplication detection overhead vs baseline
#
# Usage:
#   bash benchmarks/scripts/bench-duplication.sh
#
# Measures wall time with and without --duplication flag on representative
# TypeScript projects. Uses the quick benchmark suite project set (zod, got, dayjs).
#
# Prerequisites:
#   - Run setup.sh --suite quick first to clone benchmark projects
#   - hyperfine must be installed (checked at /home/ben/.cargo/bin/hyperfine or on PATH)
#   - Binary built in ReleaseFast mode (script will build if needed)
#
# Output:
#   /tmp/bench-dup-<project>-without.json  (hyperfine JSON, no duplication)
#   /tmp/bench-dup-<project>-with.json     (hyperfine JSON, with --duplication)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
PROJECTS_DIR="$PROJECT_ROOT/benchmarks/projects"
CG_BIN="$PROJECT_ROOT/zig-out/bin/complexity-guard"

# Verify binary exists (or build it)
if [[ ! -f "$CG_BIN" ]]; then
    echo "Binary not found at $CG_BIN — building in ReleaseFast mode..."
    (cd "$PROJECT_ROOT" && zig build -Doptimize=ReleaseFast)
fi

# Locate hyperfine
HYPERFINE=$(command -v hyperfine 2>/dev/null || echo /home/ben/.cargo/bin/hyperfine)
if [[ ! -x "$HYPERFINE" ]]; then
    echo "Error: hyperfine not found. Install with: cargo install hyperfine" >&2
    exit 1
fi

echo "=== Duplication Detection Overhead Benchmark ==="
echo "Binary: $CG_BIN ($("$CG_BIN" --version 2>&1 || true))"
echo "hyperfine: $HYPERFINE ($("$HYPERFINE" --version))"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Subset of quick suite projects for duplication benchmark
# These three cover small (got), medium (zod), and many-file (dayjs) ranges
PROJECTS=("zod" "got" "dayjs")

# Collect results for summary table
declare -A WITHOUT_MS
declare -A WITH_MS

for project in "${PROJECTS[@]}"; do
    PROJECT_DIR="$PROJECTS_DIR/$project"

    if [[ ! -d "$PROJECT_DIR" ]]; then
        echo "SKIP: $project (not cloned — run: bash benchmarks/scripts/setup.sh --suite quick)"
        echo ""
        continue
    fi

    # Count TS/JS files
    FILE_COUNT=$(find "$PROJECT_DIR" \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) 2>/dev/null | wc -l | tr -d ' ')

    echo "--- $project ($FILE_COUNT files) ---"

    WITHOUT_JSON="/tmp/bench-dup-${project}-without.json"
    WITH_JSON="/tmp/bench-dup-${project}-with.json"

    # Benchmark without duplication (baseline)
    echo "Without --duplication (baseline):"
    "$HYPERFINE" \
        --warmup 2 \
        --min-runs 5 \
        --ignore-failure \
        --export-json "$WITHOUT_JSON" \
        "$CG_BIN --fail-on none $PROJECT_DIR" 2>&1 | grep -E "Time \(mean|Range"

    # Benchmark with duplication enabled
    echo "With --duplication:"
    "$HYPERFINE" \
        --warmup 2 \
        --min-runs 5 \
        --ignore-failure \
        --export-json "$WITH_JSON" \
        "$CG_BIN --fail-on none --duplication $PROJECT_DIR" 2>&1 | grep -E "Time \(mean|Range"

    # Extract mean times using jq (if available)
    if command -v jq &>/dev/null && [[ -f "$WITHOUT_JSON" && -f "$WITH_JSON" ]]; then
        without_ms=$(jq -r '.results[0].mean * 1000 | . * 10 | round / 10' "$WITHOUT_JSON" 2>/dev/null || echo "")
        with_ms=$(jq -r '.results[0].mean * 1000 | . * 10 | round / 10' "$WITH_JSON" 2>/dev/null || echo "")
        if [[ -n "$without_ms" && -n "$with_ms" ]]; then
            WITHOUT_MS[$project]="$without_ms"
            WITH_MS[$project]="$with_ms"
        fi
    fi

    echo ""
done

# Print summary table
echo "=== Summary: Duplication Detection Overhead ==="
printf "%-12s %8s %8s %10s %10s\n" "Project" "Without" "With" "Overhead" "Pct"
printf "%-12s %8s %8s %10s %10s\n" "-------" "-------" "----" "--------" "---"

for project in "${PROJECTS[@]}"; do
    if [[ -n "${WITHOUT_MS[$project]:-}" && -n "${WITH_MS[$project]:-}" ]]; then
        without="${WITHOUT_MS[$project]}"
        with="${WITH_MS[$project]}"
        overhead=$(node -e "
            const a = ${without}, b = ${with};
            const diff = b - a;
            const pct = (diff / a * 100).toFixed(0);
            console.log('+' + diff.toFixed(1) + 'ms ' + pct + '%');
        " 2>/dev/null || echo "N/A")
        printf "%-12s %8s %8s %10s\n" "$project" "${without}ms" "${with}ms" "$overhead"
    fi
done

echo ""
echo "Results saved to /tmp/bench-dup-*.json"
echo "Tip: Run 'bash benchmarks/scripts/bench-quick.sh' for full CG vs FTA comparison."
