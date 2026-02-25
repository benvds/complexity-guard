---
phase: 22-cross-compilation-ci-and-release
plan: 02
subsystem: infra
tags: [github-actions, rust, release, softprops-action-gh-release, cargo, semver, archives]

# Dependency graph
requires:
  - phase: 22-01
    provides: 5-target cross-compilation matrix patterns established in rust-ci.yml (zigbuild, ext field, RUSTFLAGS pattern)
provides:
  - Tag-triggered Rust release workflow (.github/workflows/rust-release.yml) building all 5 targets and publishing GitHub Release
  - Updated release.sh reading/writing version from rust/Cargo.toml instead of src/main.zig
affects: [22-03-docs, 22-04-publication-readmes]

# Tech tracking
tech-stack:
  added: [softprops/action-gh-release@v2]
  patterns: [validate/build/release 3-job pipeline pattern, workflow_dispatch creates tag vs tag-push reuses existing tag, Unix tar.gz + Windows PowerShell zip archive pattern]

key-files:
  created:
    - .github/workflows/rust-release.yml
  modified:
    - scripts/release.sh

key-decisions:
  - "rust-release.yml is a SEPARATE workflow from the Zig release.yml — they coexist for parallel Zig/Rust release paths"
  - "Archive shell handling: Unix steps use shell:bash for tar czf, Windows step uses shell:pwsh for Compress-Archive"
  - "workflow_dispatch creates an annotated git tag and pushes it; tag-push trigger reuses the existing tag in the release job"
  - "release.sh now uses rust/Cargo.toml as single source of truth for version — replaces src/main.zig grep/sed"

patterns-established:
  - "3-job release pipeline: validate (semver check + tag dedup) → build (matrix) → release (gh-release)"
  - "Archive naming: complexity-guard-{matrix.name}.tar.gz (unix) or .zip (windows) — matches rust-ci.yml name field"

requirements-completed: [REL-04, REL-05]

# Metrics
duration: 1min
completed: 2026-02-25
---

# Phase 22 Plan 02: Rust Release Workflow Summary

**Tag-triggered GitHub Actions workflow building all 5 Rust targets, creating binary archives, and publishing a GitHub Release via softprops/action-gh-release@v2 — plus release.sh updated to read version from rust/Cargo.toml**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-25T09:06:36Z
- **Completed:** 2026-02-25T09:07:40Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created `.github/workflows/rust-release.yml` with validate/build/release 3-job pipeline
- Build matrix reuses all 5 targets and patterns from rust-ci.yml (zigbuild for musl, native macOS, Windows MSVC with crt-static)
- Archives created as `.tar.gz` (Unix via bash) and `.zip` (Windows via PowerShell) with `complexity-guard-{name}` naming
- GitHub Release published via `softprops/action-gh-release@v2` with `generate_release_notes: true`
- `release.sh` updated to read and write version from `rust/Cargo.toml` instead of `src/main.zig`

## Task Commits

Each task was committed atomically:

1. **Task 1: Create rust-release.yml workflow** - `a4c8c18` (feat)
2. **Task 2: Update release.sh for Rust version source** - `aea4e29` (feat)

**Plan metadata:** (see final commit)

## Files Created/Modified
- `.github/workflows/rust-release.yml` - New 3-job Rust release workflow: validate (semver), build (5-target matrix with archives), release (softprops/action-gh-release@v2)
- `scripts/release.sh` - Version read/write and git staging updated from src/main.zig to rust/Cargo.toml

## Decisions Made
- `rust-release.yml` is intentionally separate from the existing `release.yml` (Zig workflow) — both workflows coexist to allow parallel release paths during the transition to the Rust binary
- Unix archive creation uses `shell: bash` for the `tar czf` step; Windows archive uses `shell: pwsh` for `Compress-Archive` — conditional on `matrix.ext`
- `workflow_dispatch` path creates and pushes a new annotated git tag; tag-push path skips tag creation (tag already exists)
- `release.sh` keeps all `publication/npm/package.json` update logic unchanged — npm packages still need versioning for future npm distribution

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Rust release workflow is complete and ready to fire on the next `v*` tag push
- `scripts/release.sh` is fully updated for Rust-based versioning
- Ready for Phase 22 plan 03: Documentation updates (README.md, docs/ pages reflecting Rust binary)

---
*Phase: 22-cross-compilation-ci-and-release*
*Completed: 2026-02-25*

## Self-Check: PASSED

- `.github/workflows/rust-release.yml`: FOUND
- `scripts/release.sh`: FOUND
- `.planning/phases/22-cross-compilation-ci-and-release/22-02-SUMMARY.md`: FOUND
- Commit `a4c8c18`: FOUND
- Commit `aea4e29`: FOUND
