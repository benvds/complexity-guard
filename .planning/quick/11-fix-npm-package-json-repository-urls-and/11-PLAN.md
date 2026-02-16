---
phase: quick-11
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - publication/npm/packages/darwin-arm64/package.json
  - publication/npm/packages/darwin-x64/package.json
  - publication/npm/packages/linux-arm64/package.json
  - publication/npm/packages/linux-x64/package.json
  - publication/npm/packages/windows-x64/package.json
  - .github/workflows/release.yml
autonomous: true
must_haves:
  truths:
    - "All npm platform package.json files use git+https://...git repository URL format"
    - "Release workflow uses npm trusted publishing via OIDC (no NPM_TOKEN secret needed)"
    - "Both npm publish commands include --provenance flag"
  artifacts:
    - path: "publication/npm/packages/darwin-arm64/package.json"
      provides: "Corrected repository URL"
      contains: "git+https://github.com/benvds/complexity-guard.git"
    - path: "publication/npm/packages/darwin-x64/package.json"
      provides: "Corrected repository URL"
      contains: "git+https://github.com/benvds/complexity-guard.git"
    - path: "publication/npm/packages/linux-arm64/package.json"
      provides: "Corrected repository URL"
      contains: "git+https://github.com/benvds/complexity-guard.git"
    - path: "publication/npm/packages/linux-x64/package.json"
      provides: "Corrected repository URL"
      contains: "git+https://github.com/benvds/complexity-guard.git"
    - path: "publication/npm/packages/windows-x64/package.json"
      provides: "Corrected repository URL"
      contains: "git+https://github.com/benvds/complexity-guard.git"
    - path: ".github/workflows/release.yml"
      provides: "Trusted publishing workflow"
      contains: "--provenance"
  key_links:
    - from: ".github/workflows/release.yml"
      to: "npm registry OIDC"
      via: "id-token: write permission + --provenance flag (no NODE_AUTH_TOKEN)"
      pattern: "id-token: write"
---

<objective>
Fix npm package.json repository URLs to use canonical git+https format and switch the release workflow to npm trusted publishing (OIDC-based, no secret token needed).

Purpose: Correct npm metadata for proper package linking and adopt npm trusted publishing for better supply chain security and no dependency on the NPM_TOKEN secret.
Output: Committed fixes to 5 package.json files and release workflow.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.github/workflows/release.yml
@publication/npm/packages/darwin-arm64/package.json
</context>

<tasks>

<task type="auto">
  <name>Task 1: Commit repository URL fixes already applied to package.json files</name>
  <files>
    publication/npm/packages/darwin-arm64/package.json
    publication/npm/packages/darwin-x64/package.json
    publication/npm/packages/linux-arm64/package.json
    publication/npm/packages/linux-x64/package.json
    publication/npm/packages/windows-x64/package.json
  </files>
  <action>
    The repository URL fixes have ALREADY been applied to all 5 platform package.json files
    (changing `https://github.com/benvds/complexity-guard` to `git+https://github.com/benvds/complexity-guard.git`).

    Stage and commit these 5 files with message: "fix: normalize npm package.json repository URLs to git+https format"

    Do NOT stage or commit the release.yml changes yet -- those go in Task 2.
  </action>
  <verify>
    Run `git log --oneline -1` to confirm commit was created.
    Run `git diff --name-only` to confirm only release.yml remains as unstaged change.
  </verify>
  <done>All 5 package.json files committed with correct repository URLs. Only release.yml remains uncommitted.</done>
</task>

<task type="auto">
  <name>Task 2: Update release workflow for npm trusted publishing</name>
  <files>.github/workflows/release.yml</files>
  <action>
    Edit `.github/workflows/release.yml` to complete the trusted publishing switch:

    1. In the `npm-publish` job, add a step AFTER "Setup Node.js" and BEFORE "Download all artifacts":
       ```yaml
       - name: Update npm for provenance support
         run: npm install -g npm@latest
       ```

    2. Remove the `env: NODE_AUTH_TOKEN: ...` blocks from BOTH publish steps:
       - "Publish platform packages to npm" -- remove the `env` block (lines with NODE_AUTH_TOKEN)
       - "Publish main package to npm" -- remove the `env` block (lines with NODE_AUTH_TOKEN)

    3. Update the OIDC comment from:
       `id-token: write # Required for OIDC trusted publishing (future)`
       to:
       `id-token: write # Required for OIDC trusted publishing`

    The `--provenance` flag is already present on both publish commands -- keep those as-is.

    Stage and commit with message: "feat: switch npm publish to OIDC trusted publishing (no token needed)"
  </action>
  <verify>
    Run `grep -n "NODE_AUTH_TOKEN" .github/workflows/release.yml` -- should return no matches.
    Run `grep -n "provenance" .github/workflows/release.yml` -- should show --provenance on both publish commands.
    Run `grep -n "npm install -g npm@latest" .github/workflows/release.yml` -- should show the new step.
    Run `grep "future" .github/workflows/release.yml` -- should return no matches (OIDC comment updated).
    Run `git status` to confirm clean working tree.
  </verify>
  <done>Release workflow uses OIDC trusted publishing. No NODE_AUTH_TOKEN references remain. npm is updated to latest before publishing. Working tree is clean.</done>
</task>

</tasks>

<verification>
- All 5 platform package.json files have `git+https://github.com/benvds/complexity-guard.git` repository URL
- Release workflow has `id-token: write` permission (already present)
- Release workflow has `--provenance` flag on both npm publish commands
- Release workflow has NO `NODE_AUTH_TOKEN` environment variable references
- Release workflow has `npm install -g npm@latest` step before publish
- Working tree is clean (all changes committed)
</verification>

<success_criteria>
Two commits created: one for package.json URL fixes, one for trusted publishing switch. No NODE_AUTH_TOKEN references remain in release.yml. All package.json files use canonical git+https URL format.
</success_criteria>

<output>
After completion, create `.planning/quick/11-fix-npm-package-json-repository-urls-and/11-SUMMARY.md`
</output>
