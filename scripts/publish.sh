#!/usr/bin/env bash
set -euo pipefail

# Local npm publish script for complexity-guard
# Publishes main package + all 5 platform packages to npm
#
# Prerequisites:
#   1. Copy .env.example to .env and fill in NPM_TOKEN
#   2. Platform binaries must exist in publication/npm/packages/<platform>/ directories
#      (either from local Zig cross-compilation or downloaded from a release)
#
# Usage: ./scripts/publish.sh [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load .env if present
ENV_FILE="$PROJECT_ROOT/.env"
if [ -f "$ENV_FILE" ]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
else
  echo "Error: .env file not found at $ENV_FILE"
  echo "Copy .env.example to .env and set NPM_TOKEN"
  exit 1
fi

# Verify NPM_TOKEN is set
if [ -z "${NPM_TOKEN:-}" ]; then
  echo "Error: NPM_TOKEN is not set in .env"
  exit 1
fi

export NODE_AUTH_TOKEN="$NPM_TOKEN"

DRY_RUN=""
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN="--dry-run"
  echo "=== DRY RUN MODE ==="
  echo ""
fi

# Platform packages to publish (order doesn't matter, but publish before main)
PLATFORMS=(
  "darwin-arm64"
  "darwin-x64"
  "linux-arm64"
  "linux-x64"
  "windows-x64"
)

echo "Publishing platform packages..."
echo ""

for platform in "${PLATFORMS[@]}"; do
  pkg_dir="$PROJECT_ROOT/publication/npm/packages/$platform"
  if [ ! -f "$pkg_dir/package.json" ]; then
    echo "Warning: $pkg_dir/package.json not found, skipping"
    continue
  fi
  echo "  Publishing @complexity-guard/$platform..."
  (cd "$pkg_dir" && npm publish --access public $DRY_RUN)
done

echo ""
echo "Publishing main package (complexity-guard)..."
(cd "$PROJECT_ROOT/publication/npm" && npm publish --access public $DRY_RUN)

echo ""
echo "Done! All packages published."
