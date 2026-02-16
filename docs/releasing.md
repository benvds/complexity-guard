# Release Process

ComplexityGuard uses a two-step release process: a local **release** step (version bump + tag) followed by automated **publish** (CI builds and distributes).

## Overview

Here's how the complete release flow works from start to finish:

```
Local: release.sh -> bump version -> commit -> tag -> push
                                                     |
CI:                                            tag push triggers
                                                     |
                                                 validate
                                                     |
                                                   build (5 targets)
                                                     |
                                                  release (GitHub)
                                                   /       \
                                         npm-publish    homebrew-update
```

## Concepts: Release vs Publish

It's important to understand the distinction between these two steps:

**Release** = Local action you perform on your machine:
- Bumps the version number in source files
- Creates a git commit and annotated tag
- Pushes the tag to origin to trigger CI
- Uses the `scripts/release.sh` script
- **This is what YOU do**

**Publish** = Automated CI action triggered by the tag push:
- Builds binaries for all 5 target platforms
- Creates a GitHub release with binary archives
- Publishes packages to npm registry
- Updates the Homebrew formula with SHA256 checksums
- **This is what GitHub Actions does automatically**

You trigger the process locally with `release.sh`. Everything else happens automatically in CI.

## Step-by-Step: Creating a Release

Follow these steps to create a new release:

1. **Ensure you're on `main` with a clean working tree**
   ```sh
   git checkout main
   git pull origin main
   git status  # Should show "nothing to commit, working tree clean"
   ```

2. **Run the release script**
   ```sh
   ./scripts/release.sh [major|minor|patch]
   ```
   The bump type defaults to `patch` if not specified.

3. **The script reads the current version** from `src/main.zig` (the source of truth)

4. **The script computes the new version** based on your chosen bump type:
   - `major`: 0.1.0 → 1.0.0 (breaking changes)
   - `minor`: 0.1.0 → 0.2.0 (new features, backward compatible)
   - `patch`: 0.1.0 → 0.1.1 (bug fixes, backward compatible)

5. **The script updates version in all necessary files**:
   - `src/main.zig`
   - `publication/npm/package.json`
   - `publication/npm/packages/*/package.json` (all 5 platform packages)

6. **The script creates a commit** with message: `chore: release vX.Y.Z`

7. **The script creates an annotated tag**: `vX.Y.Z`

8. **The script asks for confirmation before pushing**
   ```
   This will push to origin and trigger the release workflow.
   Push to origin? [y/N]
   ```

9. **After confirmation, the push triggers the release workflow** which handles everything else automatically

### Concrete Examples

```sh
# Patch release (0.1.0 -> 0.1.1)
./scripts/release.sh patch

# Minor release (0.1.1 -> 0.2.0)
./scripts/release.sh minor

# Major release (0.2.0 -> 1.0.0)
./scripts/release.sh major

# Default behavior (patch if no argument)
./scripts/release.sh
```

## What Happens After Push (CI Pipeline)

Once you push the tag, GitHub Actions takes over with a 5-job pipeline. Here's what each job does:

### 1. Validate Job

**Purpose:** Ensure the version is valid and there are no duplicates

**Steps:**
- Extracts version from the tag name (strips the `v` prefix)
- Validates semver format (e.g., `0.1.0`, `1.2.3`)
- On manual dispatch: checks that the tag doesn't already exist
- Sets the version as an output for downstream jobs

**Example:** Tag `v0.1.5` → extracted version `0.1.5` → validated as valid semver

### 2. Build Job

**Purpose:** Cross-compile binaries for all 5 target platforms

**Platforms:**
- `x86_64-linux` (Linux x64)
- `aarch64-linux` (Linux ARM64)
- `x86_64-macos` (macOS Intel)
- `aarch64-macos` (macOS Apple Silicon)
- `x86_64-windows` (Windows x64)

**How it works:**
- Runs on a single Ubuntu runner (uses Zig's cross-compilation)
- Sets up Zig 0.15.2 using `mlugg/setup-zig@v2`
- For each platform: runs `zig build -Dtarget=<target> -Doptimize=ReleaseSafe`
- Creates archives: `.tar.gz` for Unix platforms, `.zip` for Windows
- Uploads archives as GitHub Actions artifacts (retained for 1 day)

**Result:** 5 binary archives ready for distribution

### 3. Release Job

**Purpose:** Create a GitHub release and attach binary archives

**Steps:**
- Downloads all build artifacts from the build job
- For manual dispatch: creates the git tag (already exists for tag push)
- Creates a GitHub release using `softprops/action-gh-release`
- Attaches all 5 binary archives to the release
- Auto-generates release notes from commits since the last tag

**Result:** Public GitHub release at `https://github.com/benvds/complexity-guard/releases/tag/vX.Y.Z`

### 4. npm-publish Job

**Purpose:** Publish the main package and all platform-specific packages to npm

**Steps:**
- Downloads all build artifacts
- Extracts binaries into the correct platform package directories:
  - `complexity-guard-x86_64-linux.tar.gz` → `publication/npm/packages/linux-x64/`
  - `complexity-guard-aarch64-linux.tar.gz` → `publication/npm/packages/linux-arm64/`
  - `complexity-guard-x86_64-macos.tar.gz` → `publication/npm/packages/darwin-x64/`
  - `complexity-guard-aarch64-macos.tar.gz` → `publication/npm/packages/darwin-arm64/`
  - `complexity-guard-x86_64-windows.zip` → `publication/npm/packages/windows-x64/`
- Updates version in all 6 `package.json` files (main + 5 platforms)
- Updates `optionalDependencies` versions in the main package
- Publishes the 5 platform packages first (e.g., `@complexity-guard/darwin-arm64`)
- Publishes the main package last (depends on platform packages being available)

**Authentication:** Uses the `NPM_TOKEN` secret (configured in GitHub repository settings)

**Result:** 6 packages published to npmjs.com registry

### 5. homebrew-update Job

**Purpose:** Compute SHA256 checksums and update the Homebrew formula

**Steps:**
- Downloads all build artifacts
- Computes SHA256 checksums using `shasum -a 256` for each Unix archive:
  - `complexity-guard-aarch64-macos.tar.gz` → SHA256
  - `complexity-guard-x86_64-macos.tar.gz` → SHA256
  - `complexity-guard-aarch64-linux.tar.gz` → SHA256
  - `complexity-guard-x86_64-linux.tar.gz` → SHA256
- Updates `publication/homebrew/complexity-guard.rb`:
  - Replaces `PLACEHOLDER_SHA256_*` values with actual checksums
  - Updates the formula `version` field
- Outputs the updated formula for manual copying to the Homebrew tap

**Manual step (for now):** Copy the updated formula to the Homebrew tap repository

**Future enhancement:** Automate tap update using a Personal Access Token and git commit

**Result:** Formula ready for Homebrew tap distribution

## How Homebrew SHA256 Works

The Homebrew formula uses a placeholder mechanism to keep the formula in version control while allowing CI to compute real checksums from actual builds. Here's the detailed process:

### The Template

The formula file at `publication/homebrew/complexity-guard.rb` contains 4 placeholder strings:
- `PLACEHOLDER_SHA256_AARCH64_MACOS`
- `PLACEHOLDER_SHA256_X86_64_MACOS`
- `PLACEHOLDER_SHA256_AARCH64_LINUX`
- `PLACEHOLDER_SHA256_X86_64_LINUX`

These placeholders are **not** real SHA256 values. They're markers that get replaced during the release process.

### The Replacement

During the `homebrew-update` CI job:

1. The workflow downloads the actual binary archives that were built
2. It computes their SHA256 checksums using `shasum -a 256 <file>`
3. It uses `sed` to replace each placeholder with the real checksum:
   ```sh
   sed -i "s/PLACEHOLDER_SHA256_AARCH64_MACOS/<actual-sha256>/" complexity-guard.rb
   ```
4. The formula version is also updated from the tag

### The Naming Convention

Placeholder names match Zig's cross-compilation target names for consistency:
- `AARCH64_MACOS` matches Zig target `aarch64-macos`
- `X86_64_MACOS` matches Zig target `x86_64-macos`
- `AARCH64_LINUX` matches Zig target `aarch64-linux`
- `X86_64_LINUX` matches Zig target `x86_64-linux`

This makes it easy to see which SHA256 corresponds to which platform build.

### Why Use Placeholders?

**Problem:** You can't know the SHA256 checksum of a binary until after you build it, but the Homebrew formula needs to be in version control.

**Solution:** Keep placeholder values in the template. During CI, compute checksums from the actual builds and replace the placeholders.

**Alternative (not used):** Manually compute checksums after release and update the formula. This is error-prone and easy to forget.

### After the Workflow Runs

The updated formula needs to be manually copied to the Homebrew tap repository (`benvds/homebrew-tap`). This will be automated in a future enhancement using a Personal Access Token to commit directly from CI.

## Version Files

ComplexityGuard's version is stored in multiple files to support different distribution methods. The release script keeps them all in sync.

### Source of Truth

**`src/main.zig`**
- Contains `const version = "X.Y.Z";`
- This is the canonical version
- The release script reads from this file to determine the current version

### Updated by release.sh (Locally)

**`publication/npm/package.json`**
- Main npm package version

**`publication/npm/packages/*/package.json`** (5 files)
- Platform-specific npm package versions
- Must match the main package version

### Updated by release.yml (CI)

**All of the above** are also updated during the CI workflow to ensure consistency if you manually dispatch a release.

### Updated Manually

**`CHANGELOG.md`**
- Human-readable release history
- Follows [Keep a Changelog](https://keepachangelog.com/) 1.1.0 format
- Add entries under `[Unreleased]` section before running `release.sh`
- The release script doesn't touch this file (you control the narrative)

## Pre-Release Checklist

Before running `./scripts/release.sh`, ensure:

- [ ] All tests pass locally (`zig build test`)
- [ ] CHANGELOG.md updated with new entries under `[Unreleased]`
- [ ] You're on the `main` branch (`git branch --show-current`)
- [ ] Working tree is clean (`git status` shows no uncommitted changes)
- [ ] You've pulled latest changes (`git pull origin main`)
- [ ] No pending PRs that should be included in this release
- [ ] You know which bump type you need (major/minor/patch)

## Post-Release Checklist

After pushing the tag, monitor the release and verify completion:

- [ ] GitHub Actions release workflow completed successfully
  - Check: `https://github.com/benvds/complexity-guard/actions`
  - All 5 jobs (validate, build, release, npm-publish, homebrew-update) should be green
- [ ] GitHub release page shows all 5 binary archives
  - Check: `https://github.com/benvds/complexity-guard/releases/tag/vX.Y.Z`
  - Should see: 4 `.tar.gz` files and 1 `.zip` file
- [ ] npm packages published successfully
  - Check: `npm view complexity-guard versions`
  - Check: `npm view @complexity-guard/darwin-arm64 versions`
  - Latest version should appear in the output
- [ ] Copy updated Homebrew formula to tap repository (until automated)
  - Download the formula from CI artifacts or view it in the workflow logs
  - Commit to `benvds/homebrew-tap` repository

## Troubleshooting

### "Tag already exists"

**Problem:** You tried to release a version that's already been released.

**Solution:** The version was already released. Choose the next version based on your changes:
```sh
# If the error was for v0.1.5, and you wanted a patch release:
./scripts/release.sh patch  # Will try v0.1.6 instead
```

If you aborted a previous release attempt and the tag exists locally but wasn't pushed:
```sh
# Delete local tag
git tag -d v0.1.5

# Try release again
./scripts/release.sh patch
```

### Build failure on one target

**Problem:** The build job failed for a specific platform (e.g., aarch64-linux).

**Solution:** Check the Zig cross-compilation logs in the GitHub Actions run. Common causes:
- Platform-specific code using `@import("builtin").os`
- Missing conditional compilation for Windows vs. Unix
- C dependencies that don't cross-compile cleanly

Fix the issue, create a new patch release.

### npm publish fails

**Problem:** The `npm-publish` job failed with authentication error.

**Solution:**
1. Verify the `NPM_TOKEN` secret is set in GitHub repository settings:
   - Go to: Settings → Secrets and variables → Actions
   - Check that `NPM_TOKEN` exists
2. Check if the token has expired:
   - npm tokens expire based on your configuration
   - Generate a new token at `https://www.npmjs.com/settings/<your-username>/tokens`
   - Update the `NPM_TOKEN` secret in GitHub

### SHA256 mismatch in Homebrew

**Problem:** Homebrew users report checksum mismatch when installing.

**Solution:** **Do not** manually edit the SHA256 values in the formula. They must be computed from the actual builds. If there's a mismatch:
1. The CI workflow may have failed during `homebrew-update` job
2. The formula was manually edited with incorrect values
3. Re-run the release or manually trigger the workflow with workflow_dispatch

The checksums in the formula must exactly match the binary archives in the GitHub release.

### Rollback a release

**Problem:** You need to undo a release due to a critical bug.

**Solution:**

**For GitHub release:**
```sh
# Delete the remote tag
git push origin :refs/tags/vX.Y.Z

# Delete the local tag
git tag -d vX.Y.Z

# Delete the GitHub release (via web UI or gh CLI)
gh release delete vX.Y.Z
```

**For npm packages:**
- npm allows unpublishing within 72 hours: `npm unpublish complexity-guard@X.Y.Z`
- After 72 hours, you cannot unpublish. Publish a new patch version with the fix instead.
- **Note:** Unpublishing is discouraged by npm. Prefer deprecating and publishing a fix.

**For Homebrew:**
- Simply don't update the tap with the broken formula
- Or revert the commit in the tap repository

**After rollback:**
- Fix the issue in your code
- Create a new release with a higher version number

## Manual/Alternative Workflows

### Manual Dispatch Trigger

You can trigger the release workflow manually from the GitHub Actions UI instead of using a tag push:

1. Go to: Actions → Release → Run workflow
2. Select the branch (usually `main`)
3. Enter the version (e.g., `0.1.5`)
4. Click "Run workflow"

This is useful if:
- The tag push didn't trigger the workflow
- You want to rebuild a release
- You're testing the workflow without committing a version bump

### Local npm Publish

For testing or emergency scenarios, you can publish to npm from your local machine:

```sh
./scripts/publish.sh
```

**Requirements:**
- Create a `.env` file with `NPM_TOKEN=your-token` (see `.env.example`)
- Have the binaries built locally for all platforms (or manually downloaded)

**Dry run mode** (verify without actually publishing):
```sh
./scripts/publish.sh --dry-run
```

This is useful for:
- Testing the publish process locally
- Emergency publishing if CI is down
- Debugging npm package structure issues

### Direct Binary Distribution

Users can also download binaries directly from GitHub releases without using npm or Homebrew:

```sh
# Linux x64
wget https://github.com/benvds/complexity-guard/releases/download/v0.1.0/complexity-guard-x86_64-linux.tar.gz
tar xzf complexity-guard-x86_64-linux.tar.gz
chmod +x complexity-guard
sudo mv complexity-guard /usr/local/bin/

# macOS ARM64
curl -L https://github.com/benvds/complexity-guard/releases/download/v0.1.0/complexity-guard-aarch64-macos.tar.gz -o complexity-guard.tar.gz
tar xzf complexity-guard.tar.gz
chmod +x complexity-guard
sudo mv complexity-guard /usr/local/bin/
```

This is documented in the README and `docs/getting-started.md`.
