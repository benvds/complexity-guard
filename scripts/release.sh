#!/usr/bin/env bash
set -euo pipefail

# Release script - bumps version, commits, tags, and pushes to trigger release workflow
# Usage: ./scripts/release.sh <major|minor|patch>
#
# Flow:
#   1. Bumps version in src/main.zig, publication/npm/package.json (including optionalDependencies), and npm platform packages
#   2. Auto-generates CHANGELOG.md entries from conventional commits
#   3. Creates git commit and tag
#   4. Pushes to origin (with confirmation) to trigger GitHub Actions release

# Generate changelog entries from conventional commits between two tags.
# Filters to feat/fix only, strips prefixes, inserts into CHANGELOG.md.
# Arguments: $1 = last tag (e.g. v0.1.8), $2 = new version (e.g. 0.1.9)
generate_changelog() {
  local LAST_TAG="$1"
  local NEW_VERSION="$2"
  local PREVIOUS_VERSION="${LAST_TAG#v}"
  local TODAY
  TODAY=$(date +%Y-%m-%d)

  # Collect commits since last tag
  local COMMITS
  COMMITS=$(git log "$LAST_TAG"..HEAD --oneline --no-decorate)

  # Filter and categorize
  local ADDED=""
  local FIXED=""

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    # Strip leading commit hash
    local msg="${line#* }"

    # Match feat or fix commits: type(scope): message
    if [[ "$msg" =~ ^(feat|fix)(\(.*\))?:\ (.+) ]]; then
      local TYPE="${BASH_REMATCH[1]}"
      local entry="${BASH_REMATCH[3]}"
      # Capitalize first letter
      entry="$(echo "${entry:0:1}" | tr '[:lower:]' '[:upper:]')${entry:1}"
      if [[ "$TYPE" == "feat" ]]; then
        ADDED="${ADDED}- ${entry}\n"
      else
        FIXED="${FIXED}- ${entry}\n"
      fi
    fi
  done <<< "$COMMITS"

  # Build the new section
  local SECTION_FILE
  SECTION_FILE=$(mktemp)

  echo "## [$NEW_VERSION] - $TODAY" > "$SECTION_FILE"

  if [[ -n "$ADDED" ]]; then
    echo "" >> "$SECTION_FILE"
    echo "### Added" >> "$SECTION_FILE"
    echo "" >> "$SECTION_FILE"
    printf '%b' "$ADDED" >> "$SECTION_FILE"
  fi

  if [[ -n "$FIXED" ]]; then
    echo "" >> "$SECTION_FILE"
    echo "### Fixed" >> "$SECTION_FILE"
    echo "" >> "$SECTION_FILE"
    printf '%b' "$FIXED" >> "$SECTION_FILE"
  fi

  if [[ -z "$ADDED" && -z "$FIXED" ]]; then
    echo "Warning: No feat or fix commits found since $LAST_TAG. Generating empty changelog section."
  fi

  # Insert new section after ## [Unreleased] line using temp file approach
  local TMPFILE
  TMPFILE=$(mktemp)
  local INSERTED=false
  while IFS= read -r fileline; do
    echo "$fileline" >> "$TMPFILE"
    if [[ "$fileline" == "## [Unreleased]" && "$INSERTED" == false ]]; then
      echo "" >> "$TMPFILE"
      cat "$SECTION_FILE" >> "$TMPFILE"
      INSERTED=true
    fi
  done < CHANGELOG.md
  mv "$TMPFILE" CHANGELOG.md
  rm "$SECTION_FILE"

  # Update [Unreleased] comparison link
  sed -i.bak "s|\[Unreleased\]: https://github.com/benvds/complexity-guard/compare/v.*\.\.\.HEAD|[Unreleased]: https://github.com/benvds/complexity-guard/compare/v${NEW_VERSION}...HEAD|" CHANGELOG.md
  rm CHANGELOG.md.bak

  # Add new version comparison link (insert before the previous version link)
  sed -i.bak "/^\[${PREVIOUS_VERSION}\]:/i\\
[$NEW_VERSION]: https://github.com/benvds/complexity-guard/compare/v${PREVIOUS_VERSION}...v${NEW_VERSION}" CHANGELOG.md
  rm CHANGELOG.md.bak

  # Stage CHANGELOG.md
  git add CHANGELOG.md

  echo "CHANGELOG.md updated with v$NEW_VERSION entries"
}

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

# Detect last tag for changelog generation
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

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

# Generate changelog entries from conventional commits
if [[ -n "$LAST_TAG" ]]; then
  generate_changelog "$LAST_TAG" "$NEW_VERSION"
else
  echo "Warning: No previous tag found, skipping changelog generation"
fi

# Commit and tag
git commit -m "chore: release v$NEW_VERSION"
git tag -a "v$NEW_VERSION" -m "Release $NEW_VERSION"

echo ""
echo "Release v$NEW_VERSION prepared:"
echo "  - Version bumped: $CURRENT_VERSION -> $NEW_VERSION"
echo "  - CHANGELOG.md updated with v$NEW_VERSION entries"
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
