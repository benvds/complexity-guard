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

# Use python3 to extract project data from JSON and clone projects
python3 - <<PYTHON
import json, subprocess, os, sys

projects_json = "$PROJECTS_JSON"
projects_dir = "$PROJECTS_DIR"
suite = "$SUITE"

quick_suite = set("""$QUICK_SUITE""".split())
stress_suite = set("""$STRESS_SUITE""".split())

with open(projects_json) as f:
    data = json.load(f)

libraries = data["libraries"]

# Filter based on suite
if suite == "quick":
    selected = [lib for lib in libraries if lib["name"] in quick_suite]
    # Sort to match the quick_suite ordering
    order = list("""$QUICK_SUITE""".split())
    selected.sort(key=lambda x: order.index(x["name"]) if x["name"] in order else 999)
elif suite == "stress":
    selected = [lib for lib in libraries if lib["name"] in stress_suite]
else:  # full
    selected = libraries

print(f"Cloning {len(selected)} project(s) for '{suite}' suite...")
print("")

cloned = 0
cached = 0
errors = 0
error_names = []

for lib in selected:
    name = lib["name"]
    url = lib["git_url"]
    tag = lib["latest_stable_tag"]
    dest = os.path.join(projects_dir, name)

    if os.path.isdir(dest):
        print(f"  Cached:  {name}")
        cached += 1
        continue

    print(f"  Cloning: {name} @ {tag}", flush=True)
    result = subprocess.run(
        ["git", "clone", "--branch", tag, "--depth", "1",
         "--single-branch", "--no-tags", url, dest],
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        print(f"  Warning: Failed to clone {name} @ {tag}")
        print(f"           {result.stderr.strip().splitlines()[-1] if result.stderr.strip() else 'unknown error'}")
        errors += 1
        error_names.append(name)
        # Clean up partial clone directory if it exists
        if os.path.isdir(dest):
            import shutil
            shutil.rmtree(dest, ignore_errors=True)
    else:
        cloned += 1

print("")
print(f"Done: {cloned} cloned, {cached} cached, {errors} skipped (tag not found)")
if error_names:
    print(f"Skipped: {', '.join(error_names)}")
    print("Note: Some tags in public-projects.json may not match upstream tag names.")
    print("      These projects will be excluded from benchmark runs.")
PYTHON
