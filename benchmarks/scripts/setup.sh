#!/usr/bin/env bash
# setup.sh — Clone benchmark projects from tests/public-projects.json
#
# Usage:
#   bash benchmarks/scripts/setup.sh [--suite quick|full|stress]
#
# Suites:
#   quick  (default) — 10 representative projects spanning all quality tiers
#   full             — all 76 projects from public-projects.json
#   stress           — only massive repos: vscode, typescript, effect

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
PROJECTS_JSON="$PROJECT_ROOT/tests/public-projects.json"
PROJECTS_DIR="$PROJECT_ROOT/benchmarks/projects"

# Check for jq
if ! command -v jq &>/dev/null; then
  echo "Error: jq not found. Install via: sudo apt install jq (or brew install jq)" >&2
  exit 1
fi

# Quick suite: 10 representative projects spanning size/quality/language tiers
# Rationale: 2 small (zod, dayjs), 3 medium (got, vite, rxjs),
#            3 large (nestjs, webpack, typeorm), 2 massive (effect, vscode)
QUICK_SUITE="zod got dayjs vite nestjs webpack typeorm rxjs effect vscode"

# Stress suite: only the 3 largest repos
STRESS_SUITE="vscode typescript effect"

# Parse --suite flag
SUITE="quick"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --suite)
      SUITE="$2"
      shift 2
      ;;
    --suite=*)
      SUITE="${1#--suite=}"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--suite quick|full|stress]" >&2
      exit 1
      ;;
  esac
done

if [[ "$SUITE" != "quick" && "$SUITE" != "full" && "$SUITE" != "stress" ]]; then
  echo "Error: --suite must be 'quick', 'full', or 'stress'" >&2
  exit 1
fi

echo "=== ComplexityGuard Benchmark Setup ==="
echo "Suite: $SUITE"
echo "Projects dir: $PROJECTS_DIR"
echo ""

mkdir -p "$PROJECTS_DIR"

# Build list of projects to clone based on suite
# Each line: "name git_url tag"
case "$SUITE" in
  quick)
    # Filter and sort to match QUICK_SUITE ordering
    CLONE_LIST=$(
      for name in $QUICK_SUITE; do
        jq -r --arg name "$name" \
          '.libraries[] | select(.name == $name) | "\(.name) \(.git_url) \(.latest_stable_tag)"' \
          "$PROJECTS_JSON"
      done
    )
    ;;
  stress)
    CLONE_LIST=$(
      for name in $STRESS_SUITE; do
        jq -r --arg name "$name" \
          '.libraries[] | select(.name == $name) | "\(.name) \(.git_url) \(.latest_stable_tag)"' \
          "$PROJECTS_JSON"
      done
    )
    ;;
  full)
    CLONE_LIST=$(
      jq -r '.libraries[] | "\(.name) \(.git_url) \(.latest_stable_tag)"' "$PROJECTS_JSON"
    )
    ;;
esac

TOTAL=$(echo "$CLONE_LIST" | wc -l | tr -d ' ')
echo "Cloning $TOTAL project(s) for '$SUITE' suite..."
echo ""

cloned=0
cached=0
errors=0
error_names=()

while IFS=' ' read -r name url tag; do
  [[ -z "$name" ]] && continue
  dest="$PROJECTS_DIR/$name"

  if [[ -d "$dest" ]]; then
    echo "  Cached:  $name"
    ((cached++)) || true
    continue
  fi

  echo "  Cloning: $name @ $tag"
  if git clone --branch "$tag" --depth 1 --single-branch --no-tags "$url" "$dest" 2>/tmp/git-clone-err; then
    ((cloned++)) || true
  else
    last_line=$(tail -1 /tmp/git-clone-err 2>/dev/null || echo "unknown error")
    echo "  Warning: Failed to clone $name @ $tag"
    echo "           $last_line"
    ((errors++)) || true
    error_names+=("$name")
    # Clean up partial clone directory if it exists
    if [[ -d "$dest" ]]; then
      rm -rf "$dest"
    fi
  fi
done <<< "$CLONE_LIST"

echo ""
echo "Done: $cloned cloned, $cached cached, $errors skipped (tag not found)"
if [[ ${#error_names[@]} -gt 0 ]]; then
  echo "Skipped: ${error_names[*]}"
  echo "Note: Some tags in public-projects.json may not match upstream tag names."
  echo "      These projects will be excluded from benchmark runs."
fi
