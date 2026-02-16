---
phase: quick-14
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .github/workflows/release.yml
autonomous: true
must_haves:
  truths:
    - "GitHub release name shows complexity-guard@version format instead of Release version"
  artifacts:
    - path: ".github/workflows/release.yml"
      provides: "Release workflow with corrected release name"
      contains: "complexity-guard@"
  key_links: []
---

<objective>
Fix the GitHub release name to display as `complexity-guard@{version}` instead of `Release {version}`.

Purpose: The current release name ("Release 0.1.8") is generic and unhelpful in GitHub's sidebar. Using the `package@version` convention (e.g., `complexity-guard@0.1.8`) matches industry standard naming used by TanStack and others, making releases immediately identifiable.
Output: Updated release workflow with corrected name format.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.github/workflows/release.yml
</context>

<tasks>

<task type="auto">
  <name>Task 1: Update release name format in workflow</name>
  <files>.github/workflows/release.yml</files>
  <action>
In `.github/workflows/release.yml`, in the "Create GitHub release" step (line ~153), change:

```yaml
name: Release ${{ needs.validate.outputs.version }}
```

to:

```yaml
name: complexity-guard@${{ needs.validate.outputs.version }}
```

This is the only change needed. Do not modify any other lines.
  </action>
  <verify>grep "name: complexity-guard@" .github/workflows/release.yml</verify>
  <done>The release workflow name field uses `complexity-guard@{version}` format. No other changes to the file.</done>
</task>

</tasks>

<verification>
- `grep "name: complexity-guard@" .github/workflows/release.yml` returns the updated line
- `grep "name: Release " .github/workflows/release.yml` returns NO matches from the release step (note: the top-level workflow `name: Release` on line 14 is unrelated and should remain unchanged)
</verification>

<success_criteria>
The release workflow will create GitHub releases named `complexity-guard@0.1.9` (etc.) instead of `Release 0.1.9`.
</success_criteria>

<output>
After completion, create `.planning/quick/14-fix-github-release-name-to-show-package-/14-SUMMARY.md`
</output>
