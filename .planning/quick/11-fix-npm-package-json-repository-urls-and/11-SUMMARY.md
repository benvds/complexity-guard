---
phase: quick-11
plan: 1
subsystem: publication
tags: [npm, trusted-publishing, oidc, provenance, supply-chain-security]
dependency_graph:
  requires: []
  provides:
    - "Canonical git+https repository URLs in npm platform packages"
    - "OIDC-based npm trusted publishing (no NPM_TOKEN secret needed)"
  affects:
    - "npm publication workflow"
    - "npm package metadata"
tech_stack:
  added: []
  patterns:
    - "npm provenance attestations"
    - "OIDC trusted publishing"
key_files:
  created: []
  modified:
    - publication/npm/packages/darwin-arm64/package.json
    - publication/npm/packages/darwin-x64/package.json
    - publication/npm/packages/linux-arm64/package.json
    - publication/npm/packages/linux-x64/package.json
    - publication/npm/packages/windows-x64/package.json
    - .github/workflows/release.yml
decisions:
  - "Use npm trusted publishing (OIDC) instead of secret tokens for improved supply chain security"
  - "Add npm@latest update step to ensure provenance support is available"
  - "Remove NODE_AUTH_TOKEN environment variables (OIDC tokens provided automatically by GitHub)"
metrics:
  duration: 62s
  tasks: 2
  files: 6
  commits:
    - c502bc8
    - c5ba6ae
  completed: "2026-02-16"
---

# Quick Task 11: Fix npm package.json repository URLs and switch to OIDC trusted publishing

**One-liner:** Normalized npm repository URLs to git+https format and migrated release workflow to OIDC trusted publishing with provenance attestations for enhanced supply chain security.

## Objective

Fix npm package.json repository URLs to use the canonical git+https format and upgrade the release workflow to npm trusted publishing using OIDC tokens (eliminating the need for the NPM_TOKEN secret).

## Tasks Completed

### Task 1: Commit repository URL fixes already applied to package.json files

**Status:** Complete
**Commit:** c502bc8
**Duration:** ~10s

Updated all 5 platform package.json files to use the canonical repository URL format:
- Changed from: `https://github.com/benvds/complexity-guard`
- Changed to: `git+https://github.com/benvds/complexity-guard.git`

**Files modified:**
- publication/npm/packages/darwin-arm64/package.json
- publication/npm/packages/darwin-x64/package.json
- publication/npm/packages/linux-arm64/package.json
- publication/npm/packages/linux-x64/package.json
- publication/npm/packages/windows-x64/package.json

**Verification:**
- Confirmed all package.json files have correct repository URL format
- Verified only release.yml remained uncommitted

### Task 2: Update release workflow for npm trusted publishing

**Status:** Complete
**Commit:** c5ba6ae
**Duration:** ~52s

Migrated the npm publication workflow from secret token-based auth to OIDC trusted publishing:

1. **Added npm update step** (line 176-177): `npm install -g npm@latest` ensures provenance support is available
2. **Removed NODE_AUTH_TOKEN env vars** from both publish steps: OIDC provides tokens automatically via GitHub Actions
3. **Updated OIDC comment** (line 164): Changed from "Required for OIDC trusted publishing (future)" to "Required for OIDC trusted publishing"
4. **Retained --provenance flags** on both publish commands (already present)

**Files modified:**
- .github/workflows/release.yml

**Verification:**
- No NODE_AUTH_TOKEN references found in release.yml
- Both publish commands include --provenance flag
- npm update step present at line 177
- No "future" references in OIDC comment
- Working tree clean

## Deviations from Plan

None - plan executed exactly as written.

## Benefits

**Supply chain security:**
- Provenance attestations link published packages to source repository and build workflow
- OIDC tokens eliminate need for long-lived NPM_TOKEN secret
- GitHub Actions provides short-lived tokens automatically via id-token permission

**npm metadata:**
- Canonical git+https URL format ensures proper package repository linking on npmjs.com
- Improves discoverability and user confidence

## Self-Check

**Files created:** None expected - PASSED

**Files modified:**
```bash
$ ls -l publication/npm/packages/*/package.json .github/workflows/release.yml
FOUND: publication/npm/packages/darwin-arm64/package.json
FOUND: publication/npm/packages/darwin-x64/package.json
FOUND: publication/npm/packages/linux-arm64/package.json
FOUND: publication/npm/packages/linux-x64/package.json
FOUND: publication/npm/packages/windows-x64/package.json
FOUND: .github/workflows/release.yml
```

**Commits exist:**
```bash
$ git log --oneline --all | grep -E "(c502bc8|c5ba6ae)"
FOUND: c502bc8
FOUND: c5ba6ae
```

**Repository URL format:**
```bash
$ grep "git+https://github.com/benvds/complexity-guard.git" publication/npm/packages/*/package.json
FOUND: All 5 platform packages have canonical URL
```

**OIDC configuration:**
```bash
$ grep -q "NODE_AUTH_TOKEN" .github/workflows/release.yml && echo "FAILED" || echo "PASSED"
PASSED (no NODE_AUTH_TOKEN references)
```

## Self-Check: PASSED

All files modified as expected. Both commits exist in git history. Repository URLs normalized. OIDC trusted publishing configured correctly.
