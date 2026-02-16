---
phase: quick-15
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/release.sh
  - CHANGELOG.md
autonomous: true
must_haves:
  truths:
    - "Running release.sh auto-generates changelog entries from conventional commits"
    - "Only feat: and fix: commits appear in changelog (docs:, chore:, and GSD workflow noise filtered)"
    - "Entries are clean (no conventional commit prefixes or scope markers in changelog text)"
    - "CHANGELOG.md follows Keep a Changelog 1.1.0 format with correct comparison links"
  artifacts:
    - path: "scripts/release.sh"
      provides: "Changelog generation integrated into release flow"
      contains: "generate_changelog"
    - path: "CHANGELOG.md"
      provides: "Complete release history from v0.1.0 through v0.1.8"
      contains: "## [0.1.8]"
  key_links:
    - from: "scripts/release.sh"
      to: "CHANGELOG.md"
      via: "sed insertion between [Unreleased] and previous version"
      pattern: "sed.*Unreleased"
---

<objective>
Add automatic CHANGELOG.md generation from conventional commits to the release script, and backfill the changelog with entries for all releases from v0.1.1 through v0.1.8.

Purpose: Eliminate manual changelog maintenance -- every release automatically gets accurate, well-formatted changelog entries derived from git history.
Output: Updated release script with changelog generation, and a complete CHANGELOG.md covering all releases.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md
@scripts/release.sh
@CHANGELOG.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add changelog generation to release script</name>
  <files>scripts/release.sh</files>
  <action>
Add a `generate_changelog` function to `scripts/release.sh` that runs BEFORE the `git commit` on line 87. The function takes two arguments: `$LAST_TAG` (e.g., `v0.1.8`) and `$NEW_VERSION` (e.g., `0.1.9`).

The function must:

1. **Collect commits since last tag:**
   ```
   git log "$LAST_TAG"..HEAD --oneline --no-decorate
   ```

2. **Filter and categorize commits:**
   - Match lines starting with `feat` (any scope) -> "Added" section
   - Match lines starting with `fix` (any scope) -> "Fixed" section
   - Skip everything else: `docs`, `chore`, `refactor`, `test`, `ci`, `build`, `style`, `perf`, and any line not matching feat/fix
   - This filtering inherently skips GSD workflow noise like `docs(quick-N):` and `chore: release` commits

3. **Clean commit messages:** Strip the conventional commit prefix and scope from each message:
   - `abc1234 feat(quick-13): create main npm package README` -> `Create main npm package README`
   - `abc1234 fix: update optionalDependencies versions` -> `Update optionalDependencies versions`
   - Pattern: remove the leading hash, remove `feat:`, `feat(anything):`, `fix:`, `fix(anything):` prefix, trim whitespace, capitalize first letter

4. **Generate the new section as a string variable:**
   ```
   ## [$NEW_VERSION] - $(date +%Y-%m-%d)

   ### Added

   - Entry one
   - Entry two

   ### Fixed

   - Entry one
   ```
   Only include "### Added" if there are feat commits. Only include "### Fixed" if there are fix commits. If NEITHER exists (only docs/chore commits), print a warning and generate an empty section with just the version header.

5. **Insert into CHANGELOG.md:**
   - Find the line `## [Unreleased]` and insert the new section AFTER it (with a blank line separating them)
   - Use portable sed (sed -i.bak + rm .bak pattern already used in the script)

6. **Update comparison links at the bottom of CHANGELOG.md:**
   - Update the `[Unreleased]` link: change `compare/vOLD...HEAD` to `compare/v$NEW_VERSION...HEAD`
   - Add a new line for the new version: `[$NEW_VERSION]: https://github.com/benvds/complexity-guard/compare/v$PREVIOUS_VERSION...v$NEW_VERSION`
   - The PREVIOUS_VERSION is extracted from $LAST_TAG (strip the leading `v`)

7. **Stage CHANGELOG.md:**
   ```
   git add CHANGELOG.md
   ```

Determine `LAST_TAG` right after computing `NEW_VERSION` (around line 56):
```bash
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
```

Call the function just before the `git commit` line (before line 87):
```bash
if [[ -n "$LAST_TAG" ]]; then
  generate_changelog "$LAST_TAG" "$NEW_VERSION"
else
  echo "Warning: No previous tag found, skipping changelog generation"
fi
```

Also update the summary output at the end to mention CHANGELOG.md was updated.
  </action>
  <verify>
Run `bash -n scripts/release.sh` to verify no syntax errors. Then dry-run test by reviewing the function logic manually -- the actual integration test happens in Task 2 when we backfill.
  </verify>
  <done>release.sh contains a generate_changelog function that collects, filters, cleans, formats, and inserts changelog entries before the release commit, with no syntax errors</done>
</task>

<task type="auto">
  <name>Task 2: Backfill CHANGELOG.md for v0.1.1 through v0.1.8</name>
  <files>CHANGELOG.md</files>
  <action>
Write a temporary backfill script (inline in bash, not a file) that iterates over tags v0.1.1 through v0.1.8 and generates changelog entries for each release using the SAME filtering and formatting logic from Task 1.

For each version pair (e.g., v0.1.0..v0.1.1, v0.1.1..v0.1.2, etc.):
1. Run `git log vPREV..vCURR --oneline --no-decorate`
2. Filter to feat/fix only
3. Clean messages (strip prefix/scope, capitalize)
4. Get the tag date: `git log -1 --format=%ai vX.Y.Z | cut -d' ' -f1`

Then construct the full CHANGELOG.md by writing it fresh with:
- The standard header (Changelog title, format note, semver note)
- `## [Unreleased]` section (empty)
- Each version section from v0.1.8 down to v0.1.0 (newest first)
- Keep the existing v0.1.0 entry exactly as-is (it was hand-written with the initial feature list)
- Comparison links at the bottom for all versions

For versions that have NO feat or fix commits (only docs/chore), include just the version header with no subsections -- or omit them entirely if they add no value. Use your judgment: if a release has zero user-facing changes, a bare `## [0.1.X] - DATE` header is fine.

After writing CHANGELOG.md, verify it looks correct by outputting it.
  </action>
  <verify>
Read the generated CHANGELOG.md and confirm: (1) all versions v0.1.0-v0.1.8 are present, (2) entries are clean (no commit hashes, no `feat:` prefixes, no `(quick-N)` scopes), (3) comparison links are correct, (4) format matches Keep a Changelog 1.1.0.
  </verify>
  <done>CHANGELOG.md contains accurate, well-formatted entries for all releases from v0.1.0 through v0.1.8, with correct comparison links, and the release script is ready to auto-generate entries for future releases</done>
</task>

</tasks>

<verification>
1. `bash -n scripts/release.sh` -- no syntax errors
2. CHANGELOG.md has sections for v0.1.0 through v0.1.8
3. No changelog entry contains raw conventional commit prefixes like `feat:` or `fix:`
4. No changelog entry contains GSD scope markers like `(quick-13):`
5. Comparison links at bottom reference correct version ranges
6. `## [Unreleased]` section exists and links to `compare/v0.1.8...HEAD`
</verification>

<success_criteria>
- Release script auto-generates changelog entries from conventional commits before committing
- Only feat and fix commits appear; docs, chore, and GSD noise are filtered out
- Entries are human-readable (no prefixes, proper capitalization)
- CHANGELOG.md is backfilled with accurate history for all past releases
- Keep a Changelog 1.1.0 format maintained throughout
</success_criteria>

<output>
After completion, create `.planning/quick/15-add-automatic-changelog-md-generation-fr/15-SUMMARY.md`
</output>
