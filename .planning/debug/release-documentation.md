---
status: resolved
trigger: "The whole release cycle is unclear or too complex. User wants better documentation explaining the end-to-end release process."
created: 2026-02-15T00:00:00Z
updated: 2026-02-15T00:00:00Z
---

## ROOT CAUSE ANALYSIS

The release cycle is unclear because it has **five distributed integration points** with no single source of truth documentation:

1. **Local version bump** (scripts/release.sh)
2. **CI binary building** (.github/workflows/release.yml - build job)
3. **GitHub release creation** (.github/workflows/release.yml - release job)
4. **NPM publishing** (.github/workflows/release.yml - npm-publish job)
5. **Homebrew formula update** (.github/workflows/release.yml - homebrew-update job)

Each step has different:
- Triggering mechanisms (tag push vs workflow_dispatch)
- File updates (src/main.zig, package.json, npm/*/package.json, homebrew/complexity-guard.rb)
- Manual vs automated steps
- Consequences and failure modes

**No diagram, no step-by-step guide, no end-to-end narrative** explains how these fit together.

---

## ARTIFACTS INVENTORY

### Version Sources (Four places to update)
- **src/main.zig** line 17: `const version = "0.1.1"`
- **package.json** line 3: `"version": "0.1.1"`
- **npm/*/package.json** (5 files): Each platform package version
- **homebrew/complexity-guard.rb** line 6: `version "0.1.0"`

### Build Artifacts
- 5 platform binaries (Linux x64/arm64, macOS x64/arm64, Windows x64)
- tar.gz archives (Unix platforms)
- ZIP archive (Windows)
- Uploaded to GitHub artifacts (retention: 1 day)

### Distribution Channels
- **GitHub Releases**: Binary archives + release notes (automatic)
- **NPM Registry**: Main package + 5 platform packages (published sequentially)
- **Homebrew Tap**: benvds/tap/complexity-guard (manual step)

### Trigger Mechanisms
- **Local trigger**: `./scripts/release.sh [major|minor|patch]`
- **CI triggers**:
  - Tag push: `git push origin main --follow-tags`
  - Workflow dispatch: Manual via GitHub Actions UI

### Version Consistency Issues
- src/main.zig and package.json updated by scripts/release.sh
- npm/*/package.json updated by release.sh AND workflow file (lines 204-220)
- homebrew/complexity-guard.rb updated ONLY by workflow (line 278)
- optionalDependencies versions updated ONLY by workflow (line 219)

---

## WHAT'S MISSING

### 1. **End-to-End Process Document** (docs/releasing.md)
A narrative that explains:
- When to release (decision criteria)
- Who can release (permissions needed)
- What happens when you push a tag
- What happens in CI (the five jobs, what each does, what could fail)
- How to verify everything worked
- Rollback procedures

### 2. **Visual Flow Diagram**
```
Developer Action (local)
  ↓
scripts/release.sh [version-type]
  ├→ Reads current version from src/main.zig
  ├→ Calculates new version (semver)
  ├→ Updates: src/main.zig, package.json, npm/*/package.json
  ├→ Creates git commit and tag
  └→ Prints: "git push origin main --follow-tags"

Developer Action (git)
  ↓
git push origin main --follow-tags
  ├→ Pushes commit
  └→ Pushes tag vX.Y.Z

GitHub Actions Triggered by Tag Push
  ↓
Job 1: validate
  └→ Extract version from tag name
  └→ Validate semver format
  └→ Output: version number

Job 2: build (parallel matrix)
  ├→ Setup Zig
  ├→ Build for 5 platforms
  ├→ Create archives
  └→ Upload artifacts (1-day retention)

Job 3: release (needs: build)
  ├→ Download artifacts
  ├→ Create GitHub release with archives
  └→ Generate release notes

Job 4: npm-publish (needs: release)
  ├→ Download artifacts
  ├→ Extract binaries to platform packages
  ├→ Update all package.json versions
  ├→ Publish 5 platform packages
  └→ Publish main package

Job 5: homebrew-update (needs: release)
  ├→ Download artifacts
  ├→ Compute SHA256 checksums
  ├→ Update homebrew/complexity-guard.rb with version + checksums
  └→ Manual step: Copy formula to Homebrew tap repo
```

### 3. **Troubleshooting Guide**
Document common failure modes:
- "Tag already exists" - Duplicate release attempted
- "Binary not found" - Build failed for a platform
- "NPM publish failed" - npm token missing or expired
- "Homebrew formula outdated" - Formula wasn't manually updated in tap
- Version mismatch across channels (npm vs GitHub vs Homebrew)

### 4. **Maintenance Checklist**
What to verify after each release:
- [ ] GitHub release has all 5 binary archives
- [ ] NPM main package updated (npm view complexity-guard version)
- [ ] NPM platform packages updated (npm view @complexity-guard/darwin-arm64 version)
- [ ] Homebrew formula synced (brew tap update benvds/tap && brew show complexity-guard)
- [ ] version string matches across src/main.zig, package.json, and README examples
- [ ] optionalDependencies in package.json match platform package versions

### 5. **Prerequisites & Secrets**
- NPM_TOKEN secret configured in GitHub Actions
- NPM access to publish @complexity-guard/* scope
- Homebrew tap repository (benvds/tap/complexity-guard) manually managed
- Zig 0.15.2 available in GitHub Actions runner

### 6. **Manual Steps Currently Undocumented**
```
After job 5 (homebrew-update) completes:
1. Download updated homebrew/complexity-guard.rb from workflow artifacts
2. Clone https://github.com/benvds/homebrew-tap
3. Replace homebrew/complexity-guard.rb with updated version
4. Commit: "complexity-guard: update to vX.Y.Z"
5. Push to homebrew-tap
6. Verify: brew tap update benvds/tap && brew install complexity-guard
```

This is the biggest source of confusion - the workflow says "Manual step" (line 294) but doesn't explain what the manual step is.

---

## VERSION INCONSISTENCY RISK

There's a **version inconsistency vulnerability**:

1. scripts/release.sh updates src/main.zig → bin/main.zig (correct)
2. scripts/release.sh updates package.json (correct)
3. scripts/release.sh updates npm/*/package.json (correct)
4. scripts/release.sh creates tag vX.Y.Z (correct)
5. **Workflow re-updates package.json and npm/*/package.json again** (lines 204-220) - Why?
   - Because workflow_dispatch path creates the tag, so versions weren't in commit yet
   - But this means if versions drift between local commit and workflow run, there's a conflict

Current workaround: Assume scripts/release.sh always runs before tag push. But this should be documented.

---

## RECOMMENDATIONS

### Priority 1: Create docs/releasing.md
- Complete end-to-end narrative
- Include the flow diagram
- Document all version sources
- Explain the manual Homebrew step clearly

### Priority 2: Create docs/release-troubleshooting.md
- Common failure modes and fixes
- Rollback procedures
- How to manually trigger workflow_dispatch
- How to verify each channel after release

### Priority 3: Fix the Homebrew Manual Step
- Either automate the tap update with a GitHub token
- Or clarify exactly what the manual step is (include file diff, exact git commands)

### Priority 4: Add Release Checklist
- Add to README or create docs/release-checklist.md
- What to verify after each release
- What tests to run pre-release

---

## KEY INSIGHTS

**Why it's complex:**
1. Multiple trigger paths (local script vs workflow_dispatch)
2. Multiple distribution channels (GitHub, NPM x6 packages, Homebrew)
3. Multiple version sources requiring synchronization
4. One step is manual (Homebrew) with no clear documentation
5. Workflow has conditional logic for different trigger types

**What makes it unclear:**
1. No single doc explaining the full flow
2. No visual diagram of dependencies
3. Manual step not explained in workflow file
4. Version updates happen in two places (local script + workflow)
5. Each channel has different artifact handling

**How to fix it:**
1. One comprehensive release guide (docs/releasing.md)
2. Visual flow showing all 5 jobs and their dependencies
3. Clear explanation of each version source and update point
4. Step-by-step manual Homebrew update procedure
5. Pre-release and post-release checklists
