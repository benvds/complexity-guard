---
phase: quick-7
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .github/workflows/test.yml
  - .github/workflows/release.yml
autonomous: true
must_haves:
  truths:
    - "CI test workflow checks out git submodules before building"
    - "Release build workflow checks out git submodules before cross-compiling"
    - "zig build test succeeds in GitHub Actions (no FileNotFound for vendor/tree-sitter/lib/src/lib.c)"
  artifacts:
    - path: ".github/workflows/test.yml"
      provides: "Test workflow with submodule checkout"
      contains: "submodules"
    - path: ".github/workflows/release.yml"
      provides: "Release workflow with submodule checkout in build job"
      contains: "submodules"
  key_links:
    - from: ".github/workflows/test.yml"
      to: "vendor/tree-sitter"
      via: "actions/checkout submodules option"
      pattern: "submodules.*true"
---

<objective>
Fix CI test failure caused by git submodules not being checked out in GitHub Actions workflows.

Purpose: The `zig build test` and `zig build` commands fail with FileNotFound for `vendor/tree-sitter/lib/src/lib.c` because `actions/checkout@v4` does not check out submodules by default. Adding `submodules: true` to checkout steps that precede Zig builds fixes this.

Output: Updated test.yml and release.yml workflows that correctly check out submodules.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.github/workflows/test.yml
@.github/workflows/release.yml
@.gitmodules
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add submodules checkout to test and release workflows</name>
  <files>.github/workflows/test.yml, .github/workflows/release.yml</files>
  <action>
In `.github/workflows/test.yml`:
- Add `with: submodules: true` to the `actions/checkout@v4` step (line 16). This is the only checkout in the file and it precedes both `zig build test` and `zig build -Doptimize=ReleaseSafe`.

In `.github/workflows/release.yml`:
- Add `with: submodules: true` to the checkout step in the `build` job (line 79-80). This job runs `zig build -Dtarget=... -Doptimize=ReleaseSafe` and needs the tree-sitter vendored source files.
- Do NOT add submodules to other checkout steps (validate, release, npm-publish jobs) -- those jobs do not build Zig code and do not need submodule content.

The `with:` block syntax for checkout with submodules is:
```yaml
- uses: actions/checkout@v4
  with:
    submodules: true
```

For the release.yml `build` job, preserve the existing step name "Checkout repository" if present.
  </action>
  <verify>
Verify with grep that `submodules: true` appears in both workflow files:
- `grep -A2 'actions/checkout@v4' .github/workflows/test.yml` should show `submodules: true`
- `grep -B5 -A5 'submodules: true' .github/workflows/release.yml` should show it only in the build job context
- Validate YAML syntax: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/test.yml')); yaml.safe_load(open('.github/workflows/release.yml')); print('YAML valid')"` (or similar)
  </verify>
  <done>
- test.yml checkout step includes `submodules: true`
- release.yml build job checkout step includes `submodules: true`
- release.yml validate, release, and npm-publish checkouts remain unchanged (no submodules)
- Both YAML files are syntactically valid
  </done>
</task>

</tasks>

<verification>
- `grep -c 'submodules: true' .github/workflows/test.yml` returns 1
- `grep -c 'submodules: true' .github/workflows/release.yml` returns 1
- `grep -c 'submodules' .github/workflows/release.yml` returns 1 (only in build job, not in other jobs)
- YAML files parse without errors
</verification>

<success_criteria>
- Both workflow files updated with submodule checkout where Zig builds occur
- No unnecessary submodule checkouts added to jobs that don't build (validate, release, npm-publish)
- CI test workflow will successfully check out vendor/tree-sitter and other submodules before running zig build
</success_criteria>

<output>
After completion, create `.planning/quick/7-fix-ci-test-failure-vendor-tree-sitter-l/7-SUMMARY.md`
</output>
