---
phase: quick-5
plan: 01
subsystem: "release-tooling"
tags: ["safety", "ux", "scripts"]
dependency_graph:
  requires: []
  provides: ["safer-release-process"]
  affects: ["scripts/release.sh", "docs/releasing.md"]
tech_stack:
  added: []
  patterns: ["required-arguments", "clear-error-messages"]
key_files:
  created: []
  modified:
    - path: "scripts/release.sh"
      role: "Release automation script with required argument validation"
    - path: "docs/releasing.md"
      role: "Release process documentation"
decisions: []
metrics:
  duration_minutes: 1
  completed_at: "2026-02-16T09:00:01Z"
---

# Quick Task 5: Update Release Script to Require Explicit Bump Type

**One-liner:** Remove default patch bump from release script, requiring explicit major/minor/patch argument to prevent accidental releases.

## Objective Achieved

The release script now requires an explicit bump type argument (`major`, `minor`, or `patch`) instead of defaulting to `patch` when no argument is provided. This prevents accidental patch releases and makes the release process more explicit and safer.

## Changes Made

### 1. Release Script Updates (`scripts/release.sh`)

**Removed default value:**
- Changed `BUMP_TYPE="${1:-patch}"` to `BUMP_TYPE="${1:-}"` (no default)

**Added argument validation:**
- Added check for empty `BUMP_TYPE` that prints usage and exits with error:
  ```
  Usage: ./scripts/release.sh <major|minor|patch>
  Error: Bump type is required. Must be: major, minor, or patch
  ```

**Updated documentation comment:**
- Changed usage syntax from `[major|minor|patch]` (brackets = optional) to `<major|minor|patch>` (angle brackets = required)
- Removed line: `#   Defaults to 'patch' if no argument provided`

### 2. Documentation Updates (`docs/releasing.md`)

**Updated syntax in Step 2:**
- Changed from `./scripts/release.sh [major|minor|patch]` to `./scripts/release.sh <major|minor|patch>`
- Changed description from "The bump type defaults to `patch` if not specified." to "The bump type is required."

**Removed default behavior example:**
- Removed the "Default behavior (patch if no argument)" example from the Concrete Examples section
- Kept the three explicit examples (patch, minor, major)

## Verification Results

All verification checks passed:

```
✓ bash -n scripts/release.sh          → Syntax check PASSED
✓ grep -c 'Defaults to' scripts/       → 0 (removed)
✓ grep -c 'required' scripts/          → 1 (added)
✓ grep -c 'defaults to' docs/          → 0 (removed)
✓ grep -c 'Default behavior' docs/     → 0 (removed)
```

## Behavior Changes

**Before:**
```sh
./scripts/release.sh           # Would create patch release (0.1.0 -> 0.1.1)
./scripts/release.sh patch     # Would create patch release (0.1.0 -> 0.1.1)
```

**After:**
```sh
./scripts/release.sh           # Prints usage error and exits 1
./scripts/release.sh patch     # Creates patch release (0.1.0 -> 0.1.1) ✓
./scripts/release.sh minor     # Creates minor release (0.1.0 -> 0.2.0) ✓
./scripts/release.sh major     # Creates major release (0.1.0 -> 1.0.0) ✓
```

## Impact

**Safety:** Prevents accidental patch releases when running the script without arguments during testing or by mistake.

**UX:** Makes the release intent explicit - users must consciously choose the bump type every time.

**Documentation:** Aligns docs with actual behavior, removing confusion about defaults.

## Deviations from Plan

None - plan executed exactly as written.

## Files Modified

| File | Lines Changed | Purpose |
|------|---------------|---------|
| `scripts/release.sh` | 6 lines modified | Remove default, add validation, update comments |
| `docs/releasing.md` | 5 lines modified | Update syntax and remove default behavior docs |

## Commits

| Hash | Message |
|------|---------|
| 9fa4762 | chore(quick-5): require explicit bump type argument in release script |

## Self-Check: PASSED

**Files exist:**
- FOUND: scripts/release.sh
- FOUND: docs/releasing.md

**Commit exists:**
- FOUND: 9fa4762

**Validation:**
- Script has no syntax errors
- No mentions of defaults remain
- Required argument validation added
- Documentation updated consistently
