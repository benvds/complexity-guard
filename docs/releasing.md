# Release Process

ComplexityGuard uses a two-step release process: a local **release** step (version bump + tag) followed by automated **publish** (CI builds and distributes).

## Overview

Here's how the complete release flow works from start to finish:

```
Local: release.sh -> bump version in Cargo.toml -> commit -> tag -> push
                                                                     |
CI (release.yml):                                            tag push triggers
                                                                     |
                                                                 validate
                                                                     |
                                                             build (5 targets)
                                                                     |
                                                              release (GitHub)
```

## Concepts: Release vs Publish

It's important to understand the distinction between these two steps:

**Release** = Local action you perform on your machine:
- Bumps the version number in `Cargo.toml`
- Creates a git commit and annotated tag
- Pushes the tag to origin to trigger CI
- Uses the `scripts/release.sh` script
- **This is what YOU do**

**Publish** = Automated CI action triggered by the tag push:
- Builds Rust binaries for all 5 target platforms
- Creates a GitHub Release with binary archives attached
- **This is what GitHub Actions does automatically**

You trigger the process locally with `release.sh`. Everything else happens automatically in CI.

## Release Workflow (`release.yml`)

The `release.yml` workflow is triggered by pushing a `v*` tag or by manual `workflow_dispatch`. It has 3 jobs:

### Job 1: validate

- Extracts version from the tag name (strips the `v` prefix), or from the `workflow_dispatch` input
- Validates semver format with regex `^[0-9]+\.[0-9]+\.[0-9]+$`
- On `workflow_dispatch`: checks that the tag does not already exist
- Outputs `version` for use by downstream jobs

### Job 2: build (5-target matrix)

Builds the Rust binary for all 5 release targets:

| Name | Target | Runner | Method |
|------|--------|--------|--------|
| `linux-x86_64-musl` | `x86_64-unknown-linux-musl` | ubuntu-latest | cargo-zigbuild |
| `linux-aarch64-musl` | `aarch64-unknown-linux-musl` | ubuntu-latest | cargo-zigbuild |
| `macos-x86_64` | `x86_64-apple-darwin` | macos-latest | cargo build |
| `macos-aarch64` | `aarch64-apple-darwin` | macos-latest | cargo build |
| `windows-x86_64` | `x86_64-pc-windows-msvc` | windows-latest | cargo build |

For each target:
1. Builds release binary (cargo-zigbuild for musl targets, native cargo for others)
2. Windows uses static CRT (`-C target-feature=+crt-static`) for a fully self-contained binary
3. Prints binary size via `ls -lh`
4. Creates an archive:
   - Unix: `complexity-guard-{name}.tar.gz`
   - Windows: `complexity-guard-{name}.zip`
5. Uploads the archive as a GitHub Actions artifact

**Archive names:**
- `complexity-guard-linux-x86_64-musl.tar.gz`
- `complexity-guard-linux-aarch64-musl.tar.gz`
- `complexity-guard-macos-x86_64.tar.gz`
- `complexity-guard-macos-aarch64.tar.gz`
- `complexity-guard-windows-x86_64.zip`

### Job 3: release

- Downloads all 5 archives from the build job
- On `workflow_dispatch`: creates the git tag first (for tag pushes the tag already exists)
- Creates a GitHub Release using `softprops/action-gh-release@v2` with:
  - `tag_name: v{version}`
  - `name: complexity-guard@{version}`
  - `generate_release_notes: true`
  - All 5 archives attached

**Result:** Public GitHub Release at `https://github.com/benvds/complexity-guard/releases/tag/vX.Y.Z`

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
   ./scripts/release.sh <major|minor|patch>
   ```
   The bump type is required.

3. **The script reads the current version** from `Cargo.toml` (the source of truth)

4. **The script computes the new version** based on your chosen bump type:
   - `major`: 0.1.0 → 1.0.0 (breaking changes)
   - `minor`: 0.1.0 → 0.2.0 (new features, backward compatible)
   - `patch`: 0.1.0 → 0.1.1 (bug fixes, backward compatible)

5. **The script updates version in all necessary files**:
   - `Cargo.toml`
   - `publication/npm/package.json`
   - `publication/npm/packages/*/package.json` (all 5 platform packages)

6. **The script creates a commit** with message: `chore: release vX.Y.Z`

7. **The script creates an annotated tag**: `vX.Y.Z`

8. **The script asks for confirmation before pushing**
   ```
   This will push to origin and trigger the release workflow.
   Push to origin? [y/N]
   ```

9. **After confirmation, the push triggers `release.yml`** which handles everything else automatically

### Concrete Examples

```sh
# Patch release (0.1.0 -> 0.1.1)
./scripts/release.sh patch

# Minor release (0.1.1 -> 0.2.0)
./scripts/release.sh minor

# Major release (0.2.0 -> 1.0.0)
./scripts/release.sh major
```

## Version Files

ComplexityGuard's version is stored in multiple files to support different distribution methods. The release script keeps them all in sync.

### Source of Truth

**`Cargo.toml`**
- Contains `version = "X.Y.Z"`
- This is the canonical version for the Rust binary
- The release script reads from this file to determine the current version

### Updated by release.sh (Locally)

**`publication/npm/package.json`**
- Main npm package version

**`publication/npm/packages/*/package.json`** (5 files)
- Platform-specific npm package versions
- Must match the main package version

### Updated Manually

**`CHANGELOG.md`**
- Human-readable release history
- Follows [Keep a Changelog](https://keepachangelog.com/) 1.1.0 format
- Add entries under `[Unreleased]` section before running `release.sh`
- The release script doesn't touch this file (you control the narrative)

## Pre-Release Checklist

Before running `./scripts/release.sh`, ensure:

- [ ] All tests pass locally (`cargo test`)
- [ ] CHANGELOG.md updated with new entries under `[Unreleased]`
- [ ] You're on the correct branch (`git branch --show-current`)
- [ ] Working tree is clean (`git status` shows no uncommitted changes)
- [ ] You've pulled latest changes (`git pull`)
- [ ] No pending PRs that should be included in this release
- [ ] You know which bump type you need (major/minor/patch)

## Post-Release Checklist

After pushing the tag, monitor the release and verify completion:

- [ ] GitHub Actions `release.yml` workflow completed successfully
  - Check: `https://github.com/benvds/complexity-guard/actions`
  - All 3 jobs (validate, build, release) should be green
- [ ] GitHub Release page shows all 5 binary archives
  - Check: `https://github.com/benvds/complexity-guard/releases/tag/vX.Y.Z`
  - Should see: 4 `.tar.gz` files and 1 `.zip` file

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

**Problem:** The build job failed for a specific platform.

**Solution:** Check the GitHub Actions run logs. Common causes for Rust cross-compilation:
- Missing `cfg` conditionals for `target_os`
- C FFI dependencies that don't cross-compile with musl
- Windows-specific API differences

Fix the issue and create a new patch release.

### Rollback a release

**Problem:** You need to undo a release due to a critical bug.

**Solution:**

**For GitHub Release:**
```sh
# Delete the remote tag
git push origin :refs/tags/vX.Y.Z

# Delete the local tag
git tag -d vX.Y.Z

# Delete the GitHub Release (via web UI or gh CLI)
gh release delete vX.Y.Z
```

**After rollback:**
- Fix the issue in your code
- Create a new release with a higher version number

## Manual/Alternative Workflows

### Manual Dispatch Trigger

You can trigger `release.yml` manually from the GitHub Actions UI instead of using a tag push:

1. Go to: Actions → Release → Run workflow
2. Select the branch (usually `main`)
3. Enter the version (e.g., `0.8.1`)
4. Click "Run workflow"

This is useful if:
- The tag push didn't trigger the workflow
- You want to rebuild a release for a specific version

### Direct Binary Distribution

Users can download binaries directly from GitHub Releases:

```sh
# Linux x86_64
curl -L https://github.com/benvds/complexity-guard/releases/latest/download/complexity-guard-linux-x86_64-musl.tar.gz -o complexity-guard.tar.gz
tar xzf complexity-guard.tar.gz
chmod +x complexity-guard
sudo mv complexity-guard /usr/local/bin/

# macOS ARM64 (Apple Silicon)
curl -L https://github.com/benvds/complexity-guard/releases/latest/download/complexity-guard-macos-aarch64.tar.gz -o complexity-guard.tar.gz
tar xzf complexity-guard.tar.gz
chmod +x complexity-guard
sudo mv complexity-guard /usr/local/bin/
```

This is documented in the README and `docs/getting-started.md`.
