---
phase: quick-5
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/release.sh
  - docs/releasing.md
autonomous: true
must_haves:
  truths:
    - "Running release.sh without arguments shows usage and exits with error"
    - "Running release.sh with patch, minor, or major works as before"
    - "Documentation reflects that bump type is required"
  artifacts:
    - path: "scripts/release.sh"
      provides: "Release script with required bump type argument"
      contains: "Usage:"
    - path: "docs/releasing.md"
      provides: "Updated release documentation"
  key_links: []
---

<objective>
Remove the default `patch` bump type from `scripts/release.sh` so it always requires an explicit `patch`, `minor`, or `major` argument. Update documentation to match.

Purpose: Prevent accidental patch releases when no argument is provided.
Output: Updated release script and documentation.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@scripts/release.sh
@docs/releasing.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Remove default and require bump type argument</name>
  <files>scripts/release.sh, docs/releasing.md</files>
  <action>
In `scripts/release.sh`:
- Replace line `BUMP_TYPE="${1:-patch}"` with `BUMP_TYPE="${1:-}"` (no default).
- Add a check immediately after: if `BUMP_TYPE` is empty, print a usage message showing the required syntax and exit 1. The usage message should be:
  ```
  Usage: ./scripts/release.sh <major|minor|patch>
  Error: Bump type is required. Must be: major, minor, or patch
  ```
- Update the comment at the top from `Usage: ./scripts/release.sh [major|minor|patch]` (brackets = optional) to `Usage: ./scripts/release.sh <major|minor|patch>` (angle brackets = required).
- Remove the line `#   Defaults to 'patch' if no argument provided`.

In `docs/releasing.md`:
- Line 57: Change `./scripts/release.sh [major|minor|patch]` to `./scripts/release.sh <major|minor|patch>` (angle brackets indicate required).
- Line 58: Remove or replace the sentence "The bump type defaults to `patch` if not specified." with "The bump type is required."
- Lines 96-98: Remove the "Default behavior" example block that shows `./scripts/release.sh` with no argument. Remove both the comment line and the bare command line.
  </action>
  <verify>
Run `bash -n scripts/release.sh` to confirm no syntax errors. Grep for "patch" default pattern to confirm removal: `grep 'patch}' scripts/release.sh` should return nothing. Grep for "required" in the script to confirm new messaging.
  </verify>
  <done>Running `./scripts/release.sh` with no args prints usage and exits 1. Running with `patch`, `minor`, or `major` works normally. Documentation no longer mentions default behavior.</done>
</task>

</tasks>

<verification>
- `bash -n scripts/release.sh` exits cleanly (no syntax errors)
- `grep -c 'Defaults to' scripts/release.sh` returns 0
- `grep -c 'required' scripts/release.sh` returns at least 1
- `grep -c 'defaults to' docs/releasing.md` returns 0
- `grep -c 'Default behavior' docs/releasing.md` returns 0
</verification>

<success_criteria>
Release script requires explicit bump type argument with clear error message on missing argument. Documentation accurately reflects the required argument.
</success_criteria>

<output>
After completion, create `.planning/quick/5-update-the-release-script-to-have-no-def/5-SUMMARY.md`
</output>
