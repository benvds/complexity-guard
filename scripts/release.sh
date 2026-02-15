#!/usr/bin/env bash
set -euo pipefail

# Release script - bumps version, commits, and tags
# Usage: ./scripts/release.sh [major|minor|patch]
#   Defaults to 'patch' if no argument provided

BUMP_TYPE="${1:-patch}"

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
if [[ -f package.json ]]; then
  sed -i.bak "s/\"version\": \".*\"/\"version\": \"$NEW_VERSION\"/" package.json
  rm package.json.bak
  git add package.json
fi

# Update version in npm platform packages if they exist
if [[ -d npm ]]; then
  for pkg_json in npm/*/package.json; do
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
echo "Release v$NEW_VERSION created successfully!"
echo "To publish, run: git push origin main --follow-tags"
