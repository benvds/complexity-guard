---
phase: quick-14
plan: 01
subsystem: ci-cd
tags:
  - github-actions
  - release-workflow
  - developer-experience
dependency_graph:
  requires: []
  provides:
    - improved-release-naming
  affects:
    - github-releases
tech_stack:
  added: []
  patterns:
    - package@version naming convention
key_files:
  created: []
  modified:
    - .github/workflows/release.yml
decisions:
  - title: Use package@version naming convention
    rationale: Matches industry standard (TanStack, etc.) and makes releases immediately identifiable in GitHub's UI
    alternatives: Keep generic "Release X.Y.Z" format
    trade_offs: None - pure improvement
metrics:
  duration: 24s
  task_count: 1
  file_count: 1
  completed: 2026-02-16T19:01:10Z
---

# Quick Task 14: Fix GitHub Release Name Summary

**One-liner:** Updated GitHub release naming from generic "Release X.Y.Z" to industry-standard "complexity-guard@X.Y.Z" format

## What Was Done

Updated the GitHub release workflow to use the `package@version` naming convention instead of the generic `Release {version}` format. This change affects how releases appear in GitHub's UI, making them immediately identifiable.

### Task 1: Update release name format in workflow

**Status:** Complete
**Commit:** 415d57f
**Files modified:** .github/workflows/release.yml

Changed the release name in `.github/workflows/release.yml` line 153 from:
```yaml
name: Release ${{ needs.validate.outputs.version }}
```

to:
```yaml
name: complexity-guard@${{ needs.validate.outputs.version }}
```

This single-line change aligns with industry standards used by projects like TanStack, where releases are named `@tanstack/query@5.0.0` rather than generic version numbers.

## Deviations from Plan

None - plan executed exactly as written.

## Verification

**Checks performed:**
- Confirmed new format exists: `grep "name: complexity-guard@" .github/workflows/release.yml` ✓
- Confirmed old format removed from release step: `grep "name: Release " .github/workflows/release.yml` (no matches in release step) ✓
- Note: The top-level workflow `name: Release` on line 14 is intentional and unrelated to this change

**Expected behavior:**
Future releases will appear in GitHub as:
- `complexity-guard@0.1.9`
- `complexity-guard@0.2.0`
- etc.

Instead of:
- `Release 0.1.9`
- `Release 0.2.0`
- etc.

## Success Criteria Met

- [x] GitHub release workflow uses `complexity-guard@{version}` format
- [x] No other lines in the workflow were modified
- [x] Change committed with proper commit message

## Impact

**Developer Experience:**
- Releases are now immediately identifiable in GitHub's sidebar and release list
- Matches naming convention users expect from modern npm packages
- Improves discoverability and professional appearance

**Technical:**
- No breaking changes
- No functional changes to workflow behavior
- Only affects display name in GitHub UI

## Next Release

The next release (0.1.9 or later) will automatically use the new naming format when the release workflow runs.

## Self-Check: PASSED

**Created files:**
```bash
$ [ -f ".planning/quick/14-fix-github-release-name-to-show-package-/14-SUMMARY.md" ] && echo "FOUND" || echo "MISSING"
FOUND
```

**Modified files:**
```bash
$ [ -f ".github/workflows/release.yml" ] && echo "FOUND" || echo "MISSING"
FOUND
```

**Commits:**
```bash
$ git log --oneline --all | grep -q "415d57f" && echo "FOUND: 415d57f" || echo "MISSING: 415d57f"
FOUND: 415d57f
```

All artifacts verified.
