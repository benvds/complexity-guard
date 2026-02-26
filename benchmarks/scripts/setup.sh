#!/usr/bin/env bash
# setup.sh — Clone benchmark projects from tests/public-projects.json
#
# Usage:
#   bash benchmarks/scripts/setup.sh [--suite quick|normal|full|stress]
#
# Suites:
#   quick  (default) — ~17 representative projects from test_sets (one per category/size/tier combo)
#   normal           — ~39 projects from test_sets (2-3 per populated combo)
#   full             — all 76 projects from public-projects.json
#   stress           — only large repo_size entries

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
      echo "Usage: $0 [--suite quick|normal|full|stress]" >&2
      exit 1
      ;;
  esac
done

if [[ "$SUITE" != "quick" && "$SUITE" != "normal" && "$SUITE" != "full" && "$SUITE" != "stress" ]]; then
  echo "Error: --suite must be 'quick', 'normal', 'full', or 'stress'" >&2
  exit 1
fi

echo "=== ComplexityGuard Benchmark Setup ==="
echo "Suite: $SUITE"
echo "Projects dir: $PROJECTS_DIR"
echo ""

mkdir -p "$PROJECTS_DIR"

# Build list of projects to clone based on suite
# Each line: "name git_url tag"
# Project lists are driven by test_sets and repo_size fields in public-projects.json
case "$SUITE" in
  quick)
    CLONE_LIST=$(
      jq -r '.libraries[] | select(.test_sets | contains(["quick"])) | "\(.name) \(.git_url) \(.latest_stable_tag)"' "$PROJECTS_JSON"
    )
    ;;
  normal)
    CLONE_LIST=$(
      jq -r '.libraries[] | select(.test_sets | contains(["normal"])) | "\(.name) \(.git_url) \(.latest_stable_tag)"' "$PROJECTS_JSON"
    )
    ;;
  stress)
    CLONE_LIST=$(
      jq -r '.libraries[] | select(.repo_size == "large") | "\(.name) \(.git_url) \(.latest_stable_tag)"' "$PROJECTS_JSON"
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
