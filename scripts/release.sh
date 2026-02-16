#!/usr/bin/env bash
set -euo pipefail

# Release script - bumps version, commits, tags, and pushes to trigger release workflow
# Usage: ./scripts/release.sh <major|minor|patch>
#
# Flow:
#   1. Bumps version in src/main.zig, publication/npm/package.json (including optionalDependencies), and npm platform packages
#   2. Creates git commit and tag
#   3. Pushes to origin (with confirmation) to trigger GitHub Actions release

BUMP_TYPE="${1:-}"

# Check if bump type was provided
if [[ -z "$BUMP_TYPE" ]]; then
  echo "Usage: ./scripts/release.sh <major|minor|patch>"
  echo "Error: Bump type is required. Must be: major, minor, or patch"
  exit 1
fi

# Validate bump type
if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
  echo "Error: Invalid bump type '$BUMP_TYPE'. Must be: major, minor, or patch"
  exit 1
fi

# Read current version from src/main.zig
CURRENT_VERSION=$(grep -E '^const version = "' src/main.zig | sed -E 's/const version = "(.*)";/\1/')

if [[ -z "$CURRENT_VERSION" ]]; then
  echo "Error: Could not find version in src/main.zig"
  exit 1
fi

echo "Current version: $CURRENT_VERSION"

# Parse semver components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Compute new version based on bump type
case "$BUMP_TYPE" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
echo "New version: $NEW_VERSION"

# Update version in src/main.zig (portable sed)
sed -i.bak "s/^const version = \".*\";/const version = \"$NEW_VERSION\";/" src/main.zig
rm src/main.zig.bak

# Update version in package.json if it exists
if [[ -f publication/npm/package.json ]]; then
  sed -i.bak "s/\"version\": \".*\"/\"version\": \"$NEW_VERSION\"/" publication/npm/package.json
  rm publication/npm/package.json.bak
  sed -i.bak "s/\(\"@complexity-guard\/[^\"]*\": \"\)[^\"]*/\1$NEW_VERSION/" publication/npm/package.json
  rm publication/npm/package.json.bak
  git add publication/npm/package.json
fi

# Update version in npm platform packages if they exist
if [[ -d publication/npm/packages ]]; then
  for pkg_json in publication/npm/packages/*/package.json; do
    if [[ -f "$pkg_json" ]]; then
      sed -i.bak "s/\"version\": \".*\"/\"version\": \"$NEW_VERSION\"/" "$pkg_json"
      rm "${pkg_json}.bak"
      git add "$pkg_json"
    fi
  done
fi

# Stage main.zig
git add src/main.zig

# Commit and tag
git commit -m "chore: release v$NEW_VERSION"
git tag -a "v$NEW_VERSION" -m "Release $NEW_VERSION"

echo ""
echo "Release v$NEW_VERSION prepared:"
echo "  - Version bumped: $CURRENT_VERSION -> $NEW_VERSION"
echo "  - Commit created: chore: release v$NEW_VERSION"
echo "  - Tag created: v$NEW_VERSION"
echo ""
echo "This will push to origin and trigger the release workflow."
read -r -p "Push to origin? [y/N] " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Push cancelled. Commit and tag remain local."
  echo "To push manually: git push origin main --follow-tags"
  exit 0
fi

# Push commit and tag to trigger release workflow
git push origin main --follow-tags

echo ""
echo "Release v$NEW_VERSION pushed! The release workflow will run automatically."
echo "Monitor: https://github.com/benvds/complexity-guard/actions"
