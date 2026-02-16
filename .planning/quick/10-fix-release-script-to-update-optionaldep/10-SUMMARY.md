---
phase: quick
plan: 10
subsystem: release-automation
tags: [npm, release-script, bugfix]
dependency_graph:
  requires: []
  provides: [correct-optional-deps]
  affects: [release-workflow, npm-publish]
tech_stack:
  added: []
  patterns: [sed-version-bumping]
key_files:
  created: []
  modified:
    - path: publication/npm/package.json
      provides: Correct optionalDependencies versions
    - path: scripts/release.sh
      provides: Automated optionalDependencies version bumping
decisions: []
metrics:
  duration_seconds: 42
  completed_date: 2026-02-16
---

# Quick Task 10: Fix Release Script to Update optionalDependencies

**One-liner:** Fix stale optionalDependencies versions (0.1.0 → 0.1.5) and automate future bumps in release script using sed pattern matching

## Context

The npm package publication/npm/package.json includes five optionalDependencies for platform-specific binaries (@complexity-guard/darwin-arm64, darwin-x64, linux-arm64, linux-x64, windows-x64). These dependencies must reference the exact same version as the main package to ensure npm can resolve the correct platform binaries during installation.

The release script (scripts/release.sh) was bumping the main package version and platform package versions, but forgot to update the optionalDependencies version references in the main package.json, causing them to become stale.

## Tasks Completed

### Task 1: Fix stale optionalDependencies and update release script

**Commit:** dd2d90f

**Changes:**

1. **Fixed stale versions in publication/npm/package.json:**
   - Updated all five optionalDependencies from `"0.1.0"` to `"0.1.5"` to match current package version
   - Entries fixed: darwin-arm64, darwin-x64, linux-arm64, linux-x64, windows-x64

2. **Updated scripts/release.sh to automate future bumps:**
   - Added sed command after main version bump to update @complexity-guard/* dependency versions
   - Pattern: `sed -i.bak "s/\(\"@complexity-guard\/[^\"]*\": \"\)[^\"]*/\1$NEW_VERSION/" publication/npm/package.json`
   - Targets only lines containing @complexity-guard/ package names
   - Updated script header comment to mention optionalDependencies

**Verification:**
- ✅ No stale 0.1.0 versions remain in publication/npm/package.json
- ✅ All five @complexity-guard entries show version 0.1.5
- ✅ Release script contains sed command targeting @complexity-guard packages
- ✅ Bash syntax validation passed

## Deviations from Plan

None - plan executed exactly as written.

## Impact

**Immediate fix:** Corrects npm package metadata so current version (0.1.5) has matching optionalDependencies versions.

**Future-proof:** Release script now automatically updates optionalDependencies on every version bump, preventing this issue from recurring.

**Risk reduction:** Eliminates potential npm install failures caused by version mismatches between main package and platform binaries.

## Self-Check: PASSED

**Files exist:**
```
FOUND: publication/npm/package.json
FOUND: scripts/release.sh
```

**Commits exist:**
```
FOUND: dd2d90f
```

**Content verification:**
- All optionalDependencies show version 0.1.5 ✅
- Release script contains @complexity-guard sed pattern ✅
