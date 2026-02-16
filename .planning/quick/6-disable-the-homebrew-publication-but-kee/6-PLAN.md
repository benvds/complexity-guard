---
phase: quick-6
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - .github/workflows/release.yml
  - README.md
  - docs/getting-started.md
  - docs/releasing.md
autonomous: true
must_haves:
  truths:
    - "homebrew-update job does not run during releases"
    - "All Homebrew code and formula remain in the codebase unchanged"
    - "Docs no longer advertise Homebrew as an installation method"
    - "Re-enabling Homebrew requires only uncommenting the job and restoring doc sections"
  artifacts:
    - path: ".github/workflows/release.yml"
      provides: "Release workflow with homebrew-update job commented out"
      contains: "# DISABLED: homebrew-update"
    - path: "publication/homebrew/complexity-guard.rb"
      provides: "Homebrew formula template preserved unchanged"
  key_links:
    - from: ".github/workflows/release.yml"
      to: "publication/homebrew/complexity-guard.rb"
      via: "homebrew-update job (currently disabled)"
      pattern: "# DISABLED"
---

<objective>
Disable the Homebrew publication pipeline so it does not run during releases, while preserving all Homebrew code intact for easy re-enablement.

Purpose: The Homebrew tap is not yet set up/needed, so the homebrew-update job should not run. Keeping the code means re-enabling is a simple uncomment operation.
Output: Release workflow with Homebrew job disabled, docs updated to remove Homebrew install instructions.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.github/workflows/release.yml
@publication/homebrew/complexity-guard.rb
@README.md
@docs/getting-started.md
@docs/releasing.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Disable homebrew-update job in release workflow</name>
  <files>.github/workflows/release.yml</files>
  <action>
Comment out the entire `homebrew-update` job (lines 240-296) in the release workflow. Add a clear marker comment at the top of the commented block:

```yaml
  # DISABLED: homebrew-update job
  # To re-enable Homebrew publication, uncomment this entire job block.
  # See also: README.md, docs/getting-started.md, docs/releasing.md for doc sections to restore.
  #
  # homebrew-update:
  #   runs-on: ubuntu-latest
  #   needs: release
  #   ... (all lines of the job)
```

Comment out every line of the homebrew-update job using `#` prefix. Do NOT delete any lines. The formula file at `publication/homebrew/complexity-guard.rb` must remain completely untouched.

Also update the workflow header comment (lines 1-12) to remove or comment out line 8 about Homebrew:
Change `# 5. Updates Homebrew formula with SHA256 checksums` to `# 5. (DISABLED) Updates Homebrew formula with SHA256 checksums`
  </action>
  <verify>Run `grep -c "^  # " .github/workflows/release.yml` to confirm commented lines exist. Run `grep "DISABLED.*homebrew" .github/workflows/release.yml` to confirm the marker. Verify `publication/homebrew/complexity-guard.rb` is unchanged with `git diff publication/homebrew/`.</verify>
  <done>The homebrew-update job is fully commented out with a DISABLED marker. The formula template file is untouched. The release workflow will skip Homebrew publication when triggered.</done>
</task>

<task type="auto">
  <name>Task 2: Update docs to remove Homebrew installation references</name>
  <files>README.md, docs/getting-started.md, docs/releasing.md</files>
  <action>
**README.md:** Remove the two Homebrew lines from the Quick Start install block (lines 13-14: `# Homebrew (macOS/Linux)` and `brew install benvds/tap/complexity-guard`). Add a comment in the markdown or simply remove them cleanly so the install block flows from npm to direct download.

**docs/getting-started.md:** Remove the entire "Homebrew (macOS/Linux)" section (lines 21-31). This is the `### Homebrew (macOS/Linux)` heading, the code block with `brew install`, and the "Verify the installation" sub-section. Keep the `### Direct Download` section that follows.

**docs/releasing.md:** Add "(DISABLED)" markers to Homebrew references so readers know it is not active, but keep the documentation intact for when it gets re-enabled:
- Line 20: Change `homebrew-update` to `homebrew-update (DISABLED)` in the ASCII diagram
- Line 38: Change the bullet to `- (DISABLED) Updates the Homebrew formula with SHA256 checksums`
- Line 167: Change `### 5. homebrew-update Job` to `### 5. homebrew-update Job (DISABLED)`
- Add a note after the heading: `> **Note:** This job is currently disabled in the workflow. The documentation is preserved for when Homebrew publication is re-enabled.`
- Line 287: Change `homebrew-update` to `homebrew-update (DISABLED)` in the checklist
- Line 295-297: Comment out or mark the Homebrew tap checklist item as `(DISABLED)`

Do NOT remove any content from docs/releasing.md -- only add DISABLED markers and notes.
  </action>
  <verify>Run `grep -i homebrew README.md` should return no results. Run `grep -i homebrew docs/getting-started.md` should return no results. Run `grep "DISABLED" docs/releasing.md` should show the disabled markers. Confirm the releasing.md Homebrew sections are still present (not deleted) with `grep -c "homebrew" docs/releasing.md` returning similar count as before.</verify>
  <done>README.md and getting-started.md no longer advertise Homebrew as an installation option. Releasing docs retain full Homebrew documentation but clearly mark it as DISABLED.</done>
</task>

</tasks>

<verification>
- `publication/homebrew/complexity-guard.rb` is completely unchanged (git diff shows no changes)
- `.github/workflows/release.yml` has the homebrew-update job fully commented out
- `README.md` has no Homebrew references
- `docs/getting-started.md` has no Homebrew section
- `docs/releasing.md` retains Homebrew docs with DISABLED markers
- The workflow YAML is still valid (no syntax errors from commenting)
</verification>

<success_criteria>
- Release workflow runs without executing any Homebrew steps
- All Homebrew code preserved in codebase for easy re-enablement
- User-facing install docs only show npm and direct download
- Re-enabling requires: uncomment workflow job, restore README/getting-started Homebrew lines, remove DISABLED markers from releasing.md
</success_criteria>

<output>
After completion, create `.planning/quick/6-disable-the-homebrew-publication-but-kee/6-SUMMARY.md`
</output>
