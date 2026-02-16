---
phase: quick-8
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - .github/workflows/test.yml
autonomous: true
must_haves:
  truths:
    - "Test workflow does not run when a v* tag is pushed"
    - "Test workflow still runs on push to main branch"
    - "Test workflow still runs on pull requests to main"
  artifacts:
    - path: ".github/workflows/test.yml"
      provides: "Tag-filtered test workflow"
      contains: "tags-ignore"
  key_links: []
---

<objective>
Skip the test workflow when release tags (v*) are pushed.

Purpose: The release workflow already handles its own builds when a v* tag is pushed. Running the test workflow on the same event is redundant, wastes CI minutes, and clutters the Actions tab.

Output: Updated test.yml that excludes tag pushes matching v*.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.github/workflows/test.yml
@.github/workflows/release.yml
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add tags-ignore filter to test workflow</name>
  <files>.github/workflows/test.yml</files>
  <action>
Add a `tags-ignore` filter under the `push` trigger in `.github/workflows/test.yml` to skip the workflow when a tag matching `v*` is pushed.

Current push trigger:
```yaml
push:
  branches: [main]
```

Change to:
```yaml
push:
  branches: [main]
  tags-ignore:
    - 'v*'
```

This uses GitHub Actions' built-in `tags-ignore` filter. When a v* tag is pushed, even if the commit is on main, the `tags-ignore` filter will prevent the workflow from triggering for the tag push event. The workflow will still trigger normally for regular pushes to main and for pull requests.

Do NOT modify any other part of the workflow file.
  </action>
  <verify>
Verify the YAML is valid:
- Run `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/test.yml'))"` to confirm valid YAML syntax
- Visually confirm the `tags-ignore` block is nested under `push` alongside `branches`
- Confirm no other changes were made to the file
  </verify>
  <done>
The test.yml push trigger includes `tags-ignore: ['v*']`, preventing redundant test runs on release tag pushes while preserving normal push-to-main and PR triggers.
  </done>
</task>

</tasks>

<verification>
- test.yml parses as valid YAML
- push trigger has both `branches: [main]` and `tags-ignore: ['v*']`
- pull_request trigger is unchanged
- jobs section is unchanged
</verification>

<success_criteria>
The test workflow will no longer trigger when a v* tag is pushed. Normal push-to-main and pull request triggers remain unaffected.
</success_criteria>

<output>
After completion, create `.planning/quick/8-skip-test-workflow-on-release-tag-pushes/8-SUMMARY.md`
</output>
