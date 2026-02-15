---
phase: quick-4
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .github/workflows/release.yml
  - scripts/release.sh
autonomous: true
must_haves:
  truths:
    - "Running scripts/release.sh bumps version, commits, tags, and pushes to remote in one command"
    - "Pushing a v* tag to GitHub triggers the release workflow automatically"
    - "The release workflow skips tag creation when triggered by a tag push"
    - "The release workflow still works via workflow_dispatch as before"
    - "The release script prompts for confirmation before pushing"
  artifacts:
    - path: ".github/workflows/release.yml"
      provides: "Release workflow with dual triggers (tag push + workflow_dispatch)"
      contains: "push:"
    - path: "scripts/release.sh"
      provides: "Unified release script that pushes to remote"
      contains: "git push"
  key_links:
    - from: "scripts/release.sh"
      to: ".github/workflows/release.yml"
      via: "git push --follow-tags triggers on.push.tags"
      pattern: "git push.*--follow-tags"
---

<objective>
Add tag push trigger to the release workflow and make the release script push to remote.

Purpose: Enable a single-command release flow where `scripts/release.sh` bumps version, commits, tags, pushes, and the tag push automatically triggers the full CI release pipeline (builds, GitHub release, npm publish, Homebrew update). The workflow_dispatch trigger is preserved for manual releases.

Output: Updated release.yml with dual triggers and conditional tag step; updated release.sh that pushes with confirmation.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.github/workflows/release.yml
@scripts/release.sh
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add tag push trigger and conditional logic to release workflow</name>
  <files>.github/workflows/release.yml</files>
  <action>
Modify `.github/workflows/release.yml` with these changes:

1. **Add tag push trigger** alongside existing workflow_dispatch:
```yaml
on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to release (e.g., 0.1.0)'
        required: true
        type: string
```

2. **Update the validate job** to handle both trigger types:
   - For `workflow_dispatch`: keep existing validation logic (validate format, check tag doesn't exist)
   - For `push` (tag trigger): extract version from `github.ref_name` by stripping the `v` prefix, skip the "tag already exists" check (since it was just pushed)
   - The version output must work for both paths

   Replace the validate step's run block:
```yaml
      - name: Validate and extract version
        id: validate
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            VERSION="${{ inputs.version }}"
          else
            # Tag push: extract version from tag name (strip 'v' prefix)
            VERSION="${GITHUB_REF_NAME#v}"
          fi

          # Validate semver format (e.g., 0.1.0, 1.2.3)
          if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
            echo "Error: Invalid version format '$VERSION'. Expected semver (e.g., 0.1.0)"
            exit 1
          fi

          # Only check for existing tag on workflow_dispatch (tag push already has the tag)
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            if git tag | grep -q "^v$VERSION$"; then
              echo "Error: Tag v$VERSION already exists. Cannot create duplicate release."
              exit 1
            fi
          fi

          echo "Version validation passed: $VERSION"
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
```

3. **Make the "Create git tag" step conditional** -- only run on workflow_dispatch (tag already exists when triggered by push):
```yaml
      - name: Create git tag
        if: github.event_name == 'workflow_dispatch'
        run: |
          VERSION="${{ needs.validate.outputs.version }}"
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git tag -a "v$VERSION" -m "Release $VERSION"
          git push origin "v$VERSION"
```

4. **Update the workflow header comment** (lines 1-11) to reflect both triggers:
```
# Release workflow - triggered by tag push or manual dispatch
#
# This workflow orchestrates the complete release pipeline:
# 1. Validates semver version (from tag name or manual input)
# 2. Cross-compiles binaries for all 5 target platforms
# 3. Creates GitHub release with binary archives
# 4. Publishes npm packages (main + 5 platform packages)
# 5. Updates Homebrew formula with SHA256 checksums
#
# Triggers:
#   - Tag push: Push a v* tag (e.g., via scripts/release.sh)
#   - Manual: workflow_dispatch via GitHub Actions UI
```
  </action>
  <verify>Run `cat .github/workflows/release.yml` and confirm:
- `on:` block has both `push: tags: ['v*']` and `workflow_dispatch`
- Validate step handles both event types with version extraction
- "Create git tag" step has `if: github.event_name == 'workflow_dispatch'`
- YAML is valid: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"`
  </verify>
  <done>Release workflow triggers on both tag push and workflow_dispatch, extracts version from either source, and skips tag creation when triggered by tag push.</done>
</task>

<task type="auto">
  <name>Task 2: Add confirmation and push to release script</name>
  <files>scripts/release.sh</files>
  <action>
Modify `scripts/release.sh` to add a confirmation prompt and push to remote after tagging.

Replace the final section of the script (after `git tag -a ...`) with:

1. After creating the tag, show a summary and ask for confirmation before pushing:
```bash
echo ""
echo "Release v$NEW_VERSION prepared:"
echo "  - Version bumped: $CURRENT_VERSION -> $NEW_VERSION"
echo "  - Commit created: chore: release v$NEW_VERSION"
echo "  - Tag created: v$NEW_VERSION"
echo ""
echo "This will push to origin and trigger the release workflow."
read -r -p "Push to origin? [y/N] " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Push cancelled. Commit and tag remain local."
  echo "To push manually: git push origin main --follow-tags"
  exit 0
fi

# Push commit and tag to trigger release workflow
git push origin main --follow-tags

echo ""
echo "Release v$NEW_VERSION pushed! The release workflow will run automatically."
echo "Monitor: https://github.com/benvds/complexity-guard/actions"
```

2. Update the script header comment to reflect the full flow:
```bash
# Release script - bumps version, commits, tags, and pushes to trigger release workflow
# Usage: ./scripts/release.sh [major|minor|patch]
#   Defaults to 'patch' if no argument provided
#
# Flow:
#   1. Bumps version in src/main.zig, package.json, and npm packages
#   2. Creates git commit and tag
#   3. Pushes to origin (with confirmation) to trigger GitHub Actions release
```
  </action>
  <verify>Read `scripts/release.sh` and confirm:
- Script has a `read -r -p` confirmation prompt before pushing
- Uses `git push origin main --follow-tags` to push both commit and tag
- Cancellation path exits cleanly without pushing
- Script is executable: `test -x scripts/release.sh`
  </verify>
  <done>Release script prompts for confirmation, then pushes commit and tag to origin, triggering the release workflow automatically. Declining the prompt leaves commit and tag local only.</done>
</task>

</tasks>

<verification>
1. `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"` -- YAML is valid
2. `grep -c 'github.event_name' .github/workflows/release.yml` -- returns 3 (validate step x2, tag step x1)
3. `grep 'git push origin main --follow-tags' scripts/release.sh` -- push command exists
4. `grep 'read -r -p' scripts/release.sh` -- confirmation prompt exists
5. `grep "push:" .github/workflows/release.yml` -- tag push trigger exists
</verification>

<success_criteria>
- Release workflow has two triggers: tag push (v*) and workflow_dispatch
- Validate job extracts version from tag name on push, from input on dispatch
- "Create git tag" step is skipped on tag push trigger
- Release script pushes to origin with --follow-tags after user confirmation
- All existing workflow_dispatch functionality is preserved unchanged
</success_criteria>

<output>
After completion, create `.planning/quick/4-add-tag-push-trigger-to-release-workflow/4-SUMMARY.md`
</output>
