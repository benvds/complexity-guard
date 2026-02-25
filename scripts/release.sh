#!/usr/bin/env bash
set -euo pipefail

# Release script - sets version, commits, tags, and pushes to trigger release workflow
# Usage: ./scripts/release.sh <version|major|minor|patch>
#   e.g.: ./scripts/release.sh v0.8.0
#         ./scripts/release.sh 0.8.0
#         ./scripts/release.sh patch
#
# Flow:
#   1. Sets version in Cargo.toml, Cargo.lock, publication/npm/package.json (including optionalDependencies), and npm platform packages
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

VERSION_ARG="${1:-}"

# Check if version was provided
if [[ -z "$VERSION_ARG" ]]; then
  echo "Usage: ./scripts/release.sh <version|major|minor|patch>"
  echo "  e.g.: ./scripts/release.sh v0.8.0"
  echo "        ./scripts/release.sh 0.8.0"
  echo "        ./scripts/release.sh patch"
  exit 1
fi

# Read current version from Cargo.toml
CURRENT_VERSION=$(grep '^version' Cargo.toml | head -1 | sed -E 's/version = "(.*)"/\1/')

if [[ -z "$CURRENT_VERSION" ]]; then
  echo "Error: Could not find version in Cargo.toml"
  exit 1
fi

# Support both explicit version (v0.8.0 / 0.8.0) and bump type (major/minor/patch)
if [[ "$VERSION_ARG" =~ ^(major|minor|patch)$ ]]; then
  IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
  case "$VERSION_ARG" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
  esac
  NEW_VERSION="$MAJOR.$MINOR.$PATCH"

  echo "Current version: $CURRENT_VERSION"
  echo "Computed version: $NEW_VERSION"
  read -r -p "Release v$NEW_VERSION? [y/N] " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Release cancelled."
    exit 0
  fi
else
  # Strip leading 'v' if present
  NEW_VERSION="${VERSION_ARG#v}"

  # Validate semver format
  if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid version '$VERSION_ARG'. Must be semver (e.g. v0.8.0) or bump type (major/minor/patch)"
    exit 1
  fi

  if [[ "$CURRENT_VERSION" == "$NEW_VERSION" ]]; then
    echo "Error: Version $NEW_VERSION is already the current version"
    exit 1
  fi

  echo "Current version: $CURRENT_VERSION"
  echo "New version: $NEW_VERSION"
fi

# Detect last tag for changelog generation
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

# Update version in Cargo.toml
sed -i.bak "s/^version = \".*\"/version = \"$NEW_VERSION\"/" Cargo.toml
rm Cargo.toml.bak

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

# Regenerate Cargo.lock to match new version
cargo update --workspace

# Stage Cargo.toml and Cargo.lock
git add Cargo.toml Cargo.lock

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
echo "  - Version updated: $CURRENT_VERSION -> $NEW_VERSION"
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
