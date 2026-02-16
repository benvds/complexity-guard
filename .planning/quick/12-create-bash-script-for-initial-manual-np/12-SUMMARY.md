---
phase: quick-12
plan: 01
subsystem: release-automation
tags: [npm, publishing, ci-cd, oidc, interactive-script]
dependency-graph:
  requires: [npm-packages, package-json-structure]
  provides: [initial-npm-publish-capability]
  affects: [release-pipeline]
tech-stack:
  added: []
  patterns: [interactive-bash-script, npm-login-verification, 2fa-support]
key-files:
  created:
    - scripts/initial-publish.sh
  modified: []
decisions:
  - Interactive npm login over NPM_TOKEN for initial publish
  - Warn-but-continue on org access check
  - Publish platform packages before main package
  - Print OIDC setup instructions post-publish
metrics:
  duration: 82
  completed: 2026-02-16T18:21:19Z
---

# Quick Task 12: Create bash script for initial manual npm publish

**One-liner:** Interactive bash script for one-time npm package name claiming with 2FA/OTP support before OIDC setup

## What Was Built

Created `scripts/initial-publish.sh` -- a one-time interactive script to claim all 6 npm package names on the registry before setting up automated OIDC trusted publishing in GitHub Actions.

The script uses interactive npm login (with 2FA/OTP support) to publish placeholder versions of:
- Main package: `complexity-guard`
- Platform packages: `@complexity-guard/{darwin-arm64,darwin-x64,linux-arm64,linux-x64,windows-x64}`

After running this once, users set up OIDC trusted publishing and use CI for all future releases.

## Tasks Completed

### Task 1: Create initial-publish.sh script

**Status:** Complete
**Commit:** a89cabf
**Files:** scripts/initial-publish.sh

Created comprehensive initial publish script with:

1. **Header and setup:**
   - `#!/usr/bin/env bash` with `set -euo pipefail`
   - Clear documentation: one-time script for claiming npm names
   - `--dry-run` flag support (same pattern as publish.sh)
   - Project root detection from script location

2. **Step 1 - Verify npm login:**
   - `npm whoami` check with error handling
   - Instructions to run `npm login` if not authenticated
   - Display logged-in username on success

3. **Step 2 - Check @complexity-guard scope access:**
   - `npm org ls complexity-guard "$USERNAME"` check
   - Warning (not error) if access check fails -- user might own the scope
   - Clear instructions for creating org if needed

4. **Step 3 - Confirm before publishing:**
   - Display all 6 packages with versions (using `node -p "require('./package.json').version"`)
   - Interactive confirmation prompt: `read -r -p "Publish all 6 packages? [y/N]"`
   - Exit gracefully if not confirmed

5. **Step 4 - Publish platform packages first, then main:**
   - Same PLATFORMS array as publish.sh: darwin-arm64, darwin-x64, linux-arm64, linux-x64, windows-x64
   - For each platform: check package.json exists, publish with `--access public`
   - npm automatically handles OTP prompts for 2FA (no `--otp` flag needed)
   - Use `(cd "$dir" && npm publish --access public $DRY_RUN)` pattern
   - Then publish main package from `publication/npm/`

6. **Step 5 - Post-publish instructions:**
   - Clear "NEXT STEPS" section with banner
   - List all 6 package URLs for OIDC setup: `https://www.npmjs.com/package/PACKAGE_NAME/access`
   - Instructions to configure GitHub Actions workflow as trusted publisher
   - Reminder that CI releases via `scripts/release.sh` will publish automatically after OIDC setup

**Verification:**
- Bash syntax check passes: `bash -n scripts/initial-publish.sh`
- Script is executable: `test -x scripts/initial-publish.sh`
- Shebang line correct: `#!/usr/bin/env bash`
- Contains 2 npm publish commands (loop + main)
- npm login verification: `npm whoami` check exists
- Dry-run support: `--dry-run` flag handling exists
- Post-publish instructions: "NEXT STEPS" section exists
- Org access check: `npm org ls` command exists
- Confirmation prompt: `read -r -p "Publish all 6 packages?"` exists
- PLATFORMS array matches publish.sh: 5 platforms

## Deviations from Plan

None - plan executed exactly as written.

## Key Decisions

### Interactive npm login over NPM_TOKEN for initial publish
**Context:** Initial publish needs to claim package names, but GitHub Actions OIDC cannot run until packages exist.
**Decision:** Use interactive npm login with 2FA/OTP support for one-time bootstrap.
**Rationale:** npm handles OTP prompts automatically when user is logged in interactively. No need for `--otp` flag or token management.

### Warn-but-continue on org access check
**Context:** `npm org ls` might fail if org doesn't exist yet or user lacks access.
**Decision:** Print warning but don't exit -- let `npm publish --access public` handle it.
**Rationale:** User might be the org owner and the org might not exist yet. npm publish can create scoped packages if user has the right to the scope.

### Publish platform packages before main package
**Context:** Main package depends on platform packages via optionalDependencies.
**Decision:** Follow same pattern as publish.sh -- publish platform packages first.
**Rationale:** Ensures dependencies exist before main package is published (though npm doesn't enforce this for optionalDependencies).

### Print OIDC setup instructions post-publish
**Context:** After initial publish, users need to set up OIDC for automated releases.
**Decision:** Print comprehensive "NEXT STEPS" section with all 6 package URLs and configuration details.
**Rationale:** Clear instructions prevent users from getting stuck. Makes it obvious what to do next.

## Self-Check

Verifying all claims in this summary:

- File exists: scripts/initial-publish.sh
- Commit exists: a89cabf

All checks passed.

## Self-Check: PASSED
