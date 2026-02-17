---
status: resolved
issue_type: "UAT Gap - Homebrew SHA256 Update Documentation"
trigger: "Phase 05.1 UAT test 5 failure: 'gap: unclear how dese SHA256 are updated, create docs and necessary scripts'"
diagnosed: 2026-02-15T16:30:00Z
---

## ROOT CAUSE FOUND

The Homebrew SHA256 update process is **technically implemented but completely undocumented**.

### Why This Is Unclear

1. **No user-facing documentation** exists explaining the SHA256 update process
2. **Implementation is split across two files** with no clear connection:
   - `homebrew/complexity-guard.rb` — The template with placeholders
   - `.github/workflows/release.yml` — The workflow that updates them
3. **The mechanism is non-obvious**:
   - Placeholders have specific names (`PLACEHOLDER_SHA256_AARCH64_MACOS`, etc.)
   - Workflow uses `sed` to replace them with computed checksums
   - But no documentation explains: *Where do placeholders come from? How do they get replaced? When? By what?*
4. **No helper script** for maintainers to manually compute/verify SHA256s
5. **No explanation** of the relationship between release artifacts and Homebrew formula

---

## Artifacts Involved

### 1. `homebrew/complexity-guard.rb` (Lines 1, 12, 15, 22, 25)
**Issue:** Contains SHA256 placeholders but no comment explaining the update mechanism

```ruby
# Line 1: Only hint
class ComplexityGuard < Formula
  # ... lines 12, 15, 22, 25: PLACEHOLDER strings with no context
  sha256 "PLACEHOLDER_SHA256_AARCH64_MACOS"
  sha256 "PLACEHOLDER_SHA256_X86_64_MACOS"
  sha256 "PLACEHOLDER_SHA256_AARCH64_LINUX"
  sha256 "PLACEHOLDER_SHA256_X86_64_LINUX"
```

**Current comment (line 1):**
```
# This formula is a template. SHA256 values are updated by the release workflow.
```

**Problem:** Mentions "release workflow" but provides no details

### 2. `.github/workflows/release.yml` (Lines 240-295)
**Issue:** The `homebrew-update` job performs the substitution but lacks documentation

**Key steps:**
- Lines 257-265: Computes SHA256 checksums from artifacts
- Lines 273-286: Uses `sed` to replace placeholders with actual checksums
- Lines 291-295: Outputs notice that formula was updated locally

**Problems:**
1. No inline comments explaining the placeholder naming convention
2. Lines 291-295 reveal the real issue: **Manual step required**
   ```
   ::notice::Manual step: Copy homebrew/complexity-guard.rb to Homebrew tap repository.
   ::notice::Future enhancement: Automate tap update using PAT and git commit.
   ```
3. No documentation on how maintainers should handle the "manual step"

### 3. `scripts/release.sh` (Exists but not mentioned in docs)
**Issue:** Script triggers the release workflow but doesn't document SHA256 flow

**Current documentation:**
```bash
# Release script - bumps version, commits, and tags
# Usage: ./scripts/release.sh [major|minor|patch]
```

**Missing:** Connection between `release.sh` → tag push → workflow trigger → Homebrew update

### 4. `README.md` (Line 14)
**Issue:** References Homebrew without explaining the update process

```markdown
# Homebrew (macOS/Linux)
brew install benvds/tap/complexity-guard
```

**Missing:** Any mention of how the formula gets updated or where to find the tap repository

### 5. No documentation file
**Missing:** No `docs/RELEASE_PROCESS.md` or similar explaining:
- How the release workflow works
- Where SHA256s come from
- How placeholders are named and replaced
- Manual steps required
- Timeline and checklist

---

## What's Missing

### 1. Documentation
**Create: `docs/RELEASE_PROCESS.md`** with sections:

- **Release Overview**: What happens when you push a tag
- **SHA256 Update Mechanism**:
  - Where placeholders come from (Homebrew formula template)
  - How they're computed (from release artifacts)
  - How they're substituted (sed in workflow)
  - Why this process exists (SHA256 varies by platform)
- **Manual Steps**:
  - After workflow completes, formula is updated locally
  - Need to push to `benvds/homebrew-tap` repository
  - Link to tap repository
- **Verification Checklist**:
  - Verify SHA256 matches downloaded artifact
  - Test formula with `brew install --build-from-source`
  - Verify version in formula matches release tag
- **Troubleshooting**:
  - What if SHA256 is wrong?
  - What if formula update fails?

### 2. Helper Script
**Create: `scripts/update-homebrew-sha256.sh`** for manual SHA256 computation

```bash
#!/usr/bin/env bash
# Compute and verify SHA256s for Homebrew formula
# Usage: ./scripts/update-homebrew-sha256.sh <version>
#   Example: ./scripts/update-homebrew-sha256.sh 0.1.0

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 0.1.0"
  exit 1
fi

# Download artifacts from GitHub release
# Compute SHA256s
# Display formatted sed commands for manual update
```

### 3. Update Release Script Documentation
**Enhance: `scripts/release.sh`** documentation at top of file

```bash
# Release script - bumps version, commits, and tags
#
# WHAT IS A RELEASE?
#   A release is creating a new tagged version that triggers CI/CD:
#   1. Builds binaries for 5 platforms
#   2. Creates GitHub release with artifacts
#   3. Publishes npm packages
#   4. Updates Homebrew formula with SHA256s
#
# WHAT IS A PUBLISH?
#   A publish is pushing already-built binaries to package managers
#   (npm, Homebrew). This happens automatically via GitHub Actions
#   when you push a tag.
#
# WORKFLOW:
#   1. Run: ./scripts/release.sh [major|minor|patch]
#   2. This bumps version and creates git tag
#   3. Push tag: git push origin main --follow-tags
#   4. GitHub Actions automatically builds and publishes everything
#   5. After workflow completes, manually push Homebrew formula to tap
#
# Usage: ./scripts/release.sh [major|minor|patch]
#   Defaults to 'patch' if no argument provided
```

### 4. Update `README.md` Homebrew Section
**Add link and explanation:**

```markdown
# Homebrew (macOS/Linux)
brew install benvds/tap/complexity-guard

See [Release Process](docs/RELEASE_PROCESS.md) for details on how
Homebrew formulas are kept up to date with each release.
```

### 5. Update `.github/workflows/release.yml` Comments
**Add comments to `homebrew-update` job:**

```yaml
# Job 5: Update Homebrew formula with SHA256 checksums
#
# PURPOSE:
#   The Homebrew formula is a template with SHA256 placeholders
#   This job computes the actual SHA256 values for each platform's
#   release artifact and substitutes them into the formula.
#
# PLACEHOLDERS:
#   PLACEHOLDER_SHA256_AARCH64_MACOS  → sha256 for aarch64 macOS build
#   PLACEHOLDER_SHA256_X86_64_MACOS   → sha256 for x86_64 macOS build
#   PLACEHOLDER_SHA256_AARCH64_LINUX  → sha256 for aarch64 Linux build
#   PLACEHOLDER_SHA256_X86_64_LINUX   → sha256 for x86_64 Linux build
#
# NEXT STEPS (MANUAL):
#   The updated formula is left in the workflow artifacts.
#   Maintainer must manually push it to the Homebrew tap repository:
#   https://github.com/benvds/homebrew-tap/blob/main/Formula/complexity-guard.rb
#
# FUTURE:
#   Should be automated with GitHub Personal Access Token (PAT)
#   to push directly to tap repository.
```

### 6. Consider Creating `.planning/` Document
**Document the decision:**

Add notes explaining why the process is manual and the plan to automate it.

---

## Evidence Chain

### Finding 1: Placeholders exist without context
**Checked:** `/Users/benvds/code/complexity-guard/homebrew/complexity-guard.rb`
**Found:** 4 placeholder strings (AARCH64_MACOS, X86_64_MACOS, AARCH64_LINUX, X86_64_LINUX)
**Implication:** User wonders: where do these come from? When are they replaced?

### Finding 2: Workflow replaces them with sed
**Checked:** `/Users/benvds/code/complexity-guard/.github/workflows/release.yml` lines 273-286
**Found:** `sed` commands that replace `PLACEHOLDER_*` with computed checksums
**Implication:** Process is automated in CI, but not explained to users/maintainers

### Finding 3: Manual step revealed in workflow output
**Checked:** Lines 291-295 of release.yml
**Found:** Notices indicate "Manual step: Copy homebrew/complexity-guard.rb to Homebrew tap repository"
**Implication:** Process is incomplete — workflow updates file locally but doesn't push to tap repository

### Finding 4: No documentation exists
**Checked:** `/Users/benvds/code/complexity-guard/docs/` directory
**Found:** getting-started.md, cli-reference.md, examples.md, PRD.md, refinements.md
**Not found:** RELEASE_PROCESS.md, HOMEBREW.md, or any release pipeline documentation
**Implication:** Users have no way to understand or reproduce the process

### Finding 5: Release script exists but docs are sparse
**Checked:** `/Users/benvds/code/complexity-guard/scripts/release.sh` (80 lines)
**Found:** Basic comments explaining version bumping
**Missing:** Any explanation of release vs. publish, workflow trigger, or Homebrew integration
**Implication:** User doesn't understand what happens after running the script

### Finding 6: README mentions Homebrew but no explanation
**Checked:** `/Users/benvds/code/complexity-guard/README.md` line 14
**Found:** `brew install benvds/tap/complexity-guard` installation instruction
**Missing:** Any explanation of how the formula gets updated or stays in sync
**Implication:** User sees Homebrew as magic — no visibility into maintenance process

### Finding 7: UAT test specifically flagged this gap
**Checked:** `/Users/benvds/code/complexity-guard/.planning/phases/05.1-ci-cd-release-pipeline-documentation/05.1-UAT.md` line 38
**Found:** Test 5 status "issue" with report: "gap: unclear how dese SHA256 are updated, create docs and necessary scripts"
**Implication:** This is a known gap from user testing, not a speculation

---

## Suggested Fix Direction

### High Priority (Must Have)
1. **Create `docs/RELEASE_PROCESS.md`** explaining the full release lifecycle with focus on SHA256 mechanism
2. **Create `scripts/update-homebrew-sha256.sh`** for manual verification/computation
3. **Update script documentation** to explain release vs. publish and the trigger flow

### Medium Priority (Should Have)
1. **Add inline comments** to workflow file explaining the placeholder mechanism
2. **Update `README.md`** to link to release process documentation
3. **Document manual steps** for pushing to tap repository

### Low Priority (Nice to Have)
1. **Automate tap repository push** (noted as "Future enhancement" in workflow)
2. **Create centralized release checklist** document
3. **Add troubleshooting guide** for common SHA256 issues

---

## Summary

**Root Cause:** The SHA256 update process is technically sound but completely opaque to users and maintainers because:
- No documentation explains the mechanism (placeholders → computation → substitution)
- No helper scripts for manual verification
- No explanation of manual vs. automated steps
- No connection drawn between release.sh → git tag → workflow → formula update → tap push

**Impact:** Maintainers cannot understand or troubleshoot the process; users don't know how formulas stay current.

**Fix:** Documentation-first approach with supporting helper script, making the process explicit and verifiable.
