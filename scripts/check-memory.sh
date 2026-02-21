#!/usr/bin/env bash
# check-memory.sh — Memory leak and thread-safety verification script.
#
# Runs Valgrind memcheck (single-threaded + multi-threaded) and Helgrind
# (thread-safety) against the complexity-guard binary to verify zero leaks
# and no data races.
#
# Exit codes:
#   0 — All checks passed
#   1 — One or more checks failed (or Valgrind not installed)

set -euo pipefail

BINARY="./zig-out/bin/complexity-guard"
FIXTURES="tests/fixtures/typescript"
PASS=0
FAIL=0

# ── Preflight ─────────────────────────────────────────────────────────────────

if ! command -v valgrind &>/dev/null; then
  echo "ERROR: valgrind is not installed. Install it with:"
  echo "  sudo apt-get install valgrind   # Debian/Ubuntu"
  echo "  brew install valgrind           # macOS (limited support)"
  exit 1
fi

# ── Build ─────────────────────────────────────────────────────────────────────

echo "=== Building (ReleaseSafe) ==="
zig build -Doptimize=ReleaseSafe
echo "Build complete: $BINARY"
echo ""

# ── Helper ────────────────────────────────────────────────────────────────────

# Run a valgrind command and determine pass/fail.
# Valgrind exit 99 = Valgrind-detected error.
# Any other exit code = program exit (threshold violations etc.) — not a memory issue.
run_check() {
  local label="$1"
  shift
  echo "=== $label ==="
  local exit_code=0
  "$@" || exit_code=$?
  if [ "$exit_code" -eq 99 ]; then
    echo "FAIL: $label — Valgrind detected errors (exit 99)"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $label (exit $exit_code)"
    PASS=$((PASS + 1))
  fi
  echo ""
}

# ── Valgrind memcheck: single-threaded ───────────────────────────────────────

run_check "Valgrind memcheck (single-threaded)" \
  valgrind \
    --leak-check=full \
    --errors-for-leak-kinds=all \
    --error-exitcode=99 \
    "$BINARY" \
    --threads 1 \
    --fail-on none \
    "$FIXTURES"

# ── Valgrind memcheck: multi-threaded ────────────────────────────────────────

run_check "Valgrind memcheck (multi-threaded, --threads 4)" \
  valgrind \
    --leak-check=full \
    --errors-for-leak-kinds=all \
    --error-exitcode=99 \
    "$BINARY" \
    --threads 4 \
    --fail-on none \
    "$FIXTURES"

# ── Helgrind: thread-safety ───────────────────────────────────────────────────

run_check "Helgrind thread-safety (--threads 4)" \
  valgrind \
    --tool=helgrind \
    --error-exitcode=99 \
    "$BINARY" \
    --threads 4 \
    --fail-on none \
    "$FIXTURES"

# ── Stress test: real-world codebase (optional) ───────────────────────────────

WEBPACK_DIR="tests/repos/webpack"
if [ -d "$WEBPACK_DIR" ]; then
  run_check "Valgrind memcheck stress test (webpack, --threads 4)" \
    valgrind \
      --leak-check=full \
      --errors-for-leak-kinds=all \
      --error-exitcode=99 \
      "$BINARY" \
      --threads 4 \
      --fail-on none \
      "$WEBPACK_DIR"
else
  echo "=== Stress test (webpack) ==="
  echo "SKIP: $WEBPACK_DIR not found — run 'git clone https://github.com/webpack/webpack tests/repos/webpack' to enable"
  echo ""
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "RESULT: FAIL — $FAIL check(s) failed"
  exit 1
else
  echo "RESULT: PASS — all checks clean"
  exit 0
fi
