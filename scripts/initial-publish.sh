#!/usr/bin/env bash
set -euo pipefail

# ONE-TIME initial npm publish script for complexity-guard
#
# Purpose: Claim all 6 npm package names on the registry before setting up
# automated OIDC trusted publishing in GitHub Actions.
#
# This script uses interactive npm login (supports 2FA/OTP prompts).
# After running this once, set up OIDC trusted publishing and use CI for all future releases.
#
# Usage: ./scripts/initial-publish.sh [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

DRY_RUN=""
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN="--dry-run"
  echo "=== DRY RUN MODE ==="
  echo ""
fi

# Step 1: Verify npm login
echo "Verifying npm login..."
if ! USERNAME=$(npm whoami 2>/dev/null); then
  echo "Error: Not logged in to npm."
  echo ""
  echo "Please run: npm login"
  echo ""
  echo "This will prompt for your npm credentials and 2FA if enabled."
  exit 1
fi
echo "Logged in as: $USERNAME"
echo ""

# Step 2: Check @complexity-guard scope access (warn if missing)
echo "Checking @complexity-guard scope access..."
if ! npm org ls complexity-guard "$USERNAME" 2>/dev/null >/dev/null; then
  echo "WARNING: You may not have access to the @complexity-guard npm org."
  echo "If scoped packages fail to publish, you may need to:"
  echo "  1. Create the org at https://www.npmjs.com/org/create"
  echo "  2. Add yourself as a member"
  echo ""
  echo "Continuing anyway (npm publish --access public will create packages if you have the right to the scope)..."
  echo ""
fi

# Step 3: Confirm before publishing
echo "Packages to publish:"
echo ""

# Read version from main package
MAIN_VERSION=$(node -p "require('$PROJECT_ROOT/publication/npm/package.json').version" 2>/dev/null || echo "UNKNOWN")
echo "  complexity-guard@$MAIN_VERSION"

# Platform packages
PLATFORMS=(
  "darwin-arm64"
  "darwin-x64"
  "linux-arm64"
  "linux-x64"
  "windows-x64"
)

for platform in "${PLATFORMS[@]}"; do
  pkg_json="$PROJECT_ROOT/publication/npm/packages/$platform/package.json"
  if [ -f "$pkg_json" ]; then
    PKG_VERSION=$(node -p "require('$pkg_json').version" 2>/dev/null || echo "UNKNOWN")
    echo "  @complexity-guard/$platform@$PKG_VERSION"
  else
    echo "  @complexity-guard/$platform (MISSING)"
  fi
done

echo ""
read -r -p "Publish all 6 packages? [y/N] " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Publish cancelled."
  exit 0
fi

echo ""

# Step 4: Publish platform packages first, then main
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
echo ""

# Step 5: Post-publish instructions
echo "=========================================="
echo "NEXT STEPS: Set up OIDC Trusted Publishing"
echo "=========================================="
echo ""
echo "For each package, enable OIDC trusted publishing:"
echo ""
echo "  1. complexity-guard:"
echo "     https://www.npmjs.com/package/complexity-guard/access"
echo ""
echo "  2. @complexity-guard/darwin-arm64:"
echo "     https://www.npmjs.com/package/@complexity-guard/darwin-arm64/access"
echo ""
echo "  3. @complexity-guard/darwin-x64:"
echo "     https://www.npmjs.com/package/@complexity-guard/darwin-x64/access"
echo ""
echo "  4. @complexity-guard/linux-arm64:"
echo "     https://www.npmjs.com/package/@complexity-guard/linux-arm64/access"
echo ""
echo "  5. @complexity-guard/linux-x64:"
echo "     https://www.npmjs.com/package/@complexity-guard/linux-x64/access"
echo ""
echo "  6. @complexity-guard/windows-x64:"
echo "     https://www.npmjs.com/package/@complexity-guard/windows-x64/access"
echo ""
echo "Configure the GitHub Actions workflow as the trusted publisher for:"
echo "  - Repository: benvds/complexity-guard"
echo "  - Workflow: release.yml"
echo ""
echo "After that, CI releases via \`scripts/release.sh\` will publish automatically."
echo ""
