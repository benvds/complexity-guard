---
phase: quick
plan: 10
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/release.sh
  - publication/npm/package.json
autonomous: true
must_haves:
  truths:
    - "Running release.sh updates optionalDependencies versions in publication/npm/package.json to match the new release version"
    - "The current stale optionalDependencies versions (0.1.0) are corrected to match the current package version (0.1.5)"
  artifacts:
    - path: "scripts/release.sh"
      provides: "optionalDependencies version bump logic"
      contains: "optionalDependencies"
    - path: "publication/npm/package.json"
      provides: "Correct optionalDependencies versions matching package version"
  key_links:
    - from: "scripts/release.sh"
      to: "publication/npm/package.json"
      via: "sed replacement of @complexity-guard/* version values"
      pattern: "complexity-guard.*NEW_VERSION"
---

<objective>
Fix the release script to update optionalDependencies versions in publication/npm/package.json, and correct the currently stale values.

Purpose: The optionalDependencies in the root npm package must reference the exact same version as the platform packages. Without this fix, npm install will fail to resolve the correct platform binary versions after a release.

Output: Updated release.sh with optionalDependencies bump logic, and corrected package.json with current versions.
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@scripts/release.sh
@publication/npm/package.json
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix stale optionalDependencies and update release script</name>
  <files>publication/npm/package.json, scripts/release.sh</files>
  <action>
  Two changes needed:

  1. **Fix stale versions in publication/npm/package.json:**
     Update all five `optionalDependencies` version values from `"0.1.0"` to `"0.1.5"` to match the current package version. The entries to fix:
     - `"@complexity-guard/darwin-arm64": "0.1.5"`
     - `"@complexity-guard/darwin-x64": "0.1.5"`
     - `"@complexity-guard/linux-arm64": "0.1.5"`
     - `"@complexity-guard/linux-x64": "0.1.5"`
     - `"@complexity-guard/windows-x64": "0.1.5"`

  2. **Update scripts/release.sh to bump optionalDependencies on future releases:**
     After the existing `sed` command on line 65 that updates `"version"` in `publication/npm/package.json`, add a second `sed` command that updates the `@complexity-guard/*` dependency version values.

     The new sed command should replace version strings on lines containing `@complexity-guard/`:
     ```bash
     sed -i.bak "s/\(\"@complexity-guard\/[^\"]*\": \"\)[^\"]*/\1$NEW_VERSION/" publication/npm/package.json
     rm publication/npm/package.json.bak
     ```

     This targets only lines with `@complexity-guard/` package names, so it won't affect any other version strings in the file.

     Insert the new sed + rm lines between the existing `rm publication/npm/package.json.bak` (line 66) and `git add publication/npm/package.json` (line 67). The git add on line 67 already stages the file, so no additional staging needed.

     Also update the script header comment (line 8) to mention optionalDependencies:
     ```
     #   1. Bumps version in src/main.zig, publication/npm/package.json (including optionalDependencies), and npm platform packages
     ```
  </action>
  <verify>
  Run these checks:
  - `grep "0.1.0" publication/npm/package.json` should return NO output (no stale versions remain)
  - `grep "@complexity-guard" publication/npm/package.json` should show all five entries with version `"0.1.5"`
  - `grep "optionalDependencies" scripts/release.sh` should return at least one line (the comment and/or the sed pattern)
  - `grep "@complexity-guard" scripts/release.sh` should show the new sed command
  - `bash -n scripts/release.sh` should exit 0 (valid bash syntax)
  </verify>
  <done>
  - All five optionalDependencies in publication/npm/package.json show version "0.1.5"
  - scripts/release.sh contains a sed command targeting @complexity-guard/* dependency versions
  - The release script passes bash syntax check
  </done>
</task>

</tasks>

<verification>
- No stale `0.1.0` versions remain in `publication/npm/package.json`
- The release script has valid bash syntax (`bash -n scripts/release.sh`)
- The new sed pattern correctly targets only `@complexity-guard/*` lines
</verification>

<success_criteria>
- publication/npm/package.json optionalDependencies all show "0.1.5"
- scripts/release.sh bumps optionalDependencies versions on future releases
- Release script passes syntax validation
</success_criteria>

<output>
After completion, create `.planning/quick/10-fix-release-script-to-update-optionaldep/10-SUMMARY.md`
</output>
