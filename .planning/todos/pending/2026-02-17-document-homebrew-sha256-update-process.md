---
title: Document Homebrew SHA256 update process
area: docs
created: 2026-02-17T07:15:00.000Z
source: debug/homebrew-sha256-update-process
---

## Problem

The Homebrew SHA256 update process is technically implemented but undocumented. Placeholders in `homebrew/complexity-guard.rb` are replaced by the release workflow via `sed`, but no documentation explains:
- The placeholder naming convention and replacement mechanism
- The manual step required to push the updated formula to the tap repository
- How to manually compute/verify SHA256s
- The connection between `release.sh` -> tag push -> workflow -> formula update -> tap push

## Solution

1. Add inline comments to `homebrew/complexity-guard.rb` explaining the placeholder mechanism
2. Add comments to `.github/workflows/release.yml` homebrew-update job explaining the full flow
3. Create `scripts/update-homebrew-sha256.sh` helper script for manual SHA256 computation/verification
4. Document the manual Homebrew tap push step in `docs/releasing.md`
5. Update README Homebrew section to link to release process docs

## Files

- homebrew/complexity-guard.rb
- .github/workflows/release.yml
- docs/releasing.md
- scripts/release.sh
