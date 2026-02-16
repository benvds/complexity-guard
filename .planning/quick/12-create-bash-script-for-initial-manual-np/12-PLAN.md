---
phase: quick-12
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/initial-publish.sh
autonomous: true
must_haves:
  truths:
    - "Running the script interactively publishes all 6 npm packages to claim the names"
    - "Script checks npm login status before attempting any publish"
    - "Script provides clear post-publish instructions for setting up trusted publishing"
    - "Script does not require pre-built binaries to succeed"
  artifacts:
    - path: "scripts/initial-publish.sh"
      provides: "Interactive initial npm publish script with 2FA support"
      contains: "npm publish"
  key_links:
    - from: "scripts/initial-publish.sh"
      to: "publication/npm/package.json"
      via: "cd and npm publish"
      pattern: "publication/npm.*npm publish"
    - from: "scripts/initial-publish.sh"
      to: "publication/npm/packages/*/package.json"
      via: "loop over platforms and npm publish"
      pattern: "PLATFORMS.*npm publish"
---

<objective>
Create a bash script for one-time initial npm package publishing that uses interactive npm login (with 2FA/OTP prompts) to claim all 6 package names on the npm registry.

Purpose: The GitHub Actions OIDC trusted publishing workflow cannot run until the packages exist on npm. This script bootstraps that by publishing initial placeholder versions interactively.

Output: `scripts/initial-publish.sh` -- executable bash script
</objective>

<execution_context>
@/Users/benvds/.claude/get-shit-done/workflows/execute-plan.md
@/Users/benvds/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@scripts/publish.sh
@scripts/release.sh
@publication/npm/package.json
@publication/npm/packages/darwin-arm64/package.json
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create initial-publish.sh script</name>
  <files>scripts/initial-publish.sh</files>
  <action>
Create `scripts/initial-publish.sh` with the following structure. Use `scripts/publish.sh` as a style reference but this script is fundamentally different -- it uses interactive login, not NPM_TOKEN.

Header and setup:
- `#!/usr/bin/env bash` with `set -euo pipefail`
- Comment block explaining: this is a ONE-TIME script to claim npm package names. After running, set up OIDC trusted publishing and use CI for future releases.
- Support `--dry-run` flag (same pattern as publish.sh)
- Derive PROJECT_ROOT from script location (same pattern as publish.sh)

Step 1 -- Verify npm login:
- Run `npm whoami` and capture output. If it fails, print instructions to run `npm login` first, then exit 1.
- Print "Logged in as: $USERNAME" on success.

Step 2 -- Check @complexity-guard scope access:
- Run `npm org ls complexity-guard "$USERNAME" 2>/dev/null` and check exit code.
- If the command fails or returns empty, print a warning: "WARNING: You may not have access to the @complexity-guard npm org. If scoped packages fail to publish, create the org at https://www.npmjs.com/org/create and add yourself as a member."
- Do NOT exit on this check -- just warn. The user might be the org owner and the org might not exist yet (npm publish --access public can create scoped packages if the user has the right to the scope).

Step 3 -- Confirm before publishing:
- Print a summary of all 6 packages with their versions (read version from each package.json using `node -p "require('./package.json').version"` or grep).
- Ask for confirmation: `read -r -p "Publish all 6 packages? [y/N] " CONFIRM` and exit if not confirmed.

Step 4 -- Publish platform packages first, then main:
- Same PLATFORMS array as publish.sh: darwin-arm64, darwin-x64, linux-arm64, linux-x64, windows-x64
- For each platform package:
  - Check package.json exists (warn and skip if not)
  - Run `npm publish --access public $DRY_RUN` from the package directory
  - npm will automatically prompt for OTP if 2FA is enabled -- no need to handle this in the script
  - Print success/failure for each
- Then publish the main package from `publication/npm/`
- Use `(cd "$dir" && npm publish --access public $DRY_RUN)` pattern (same as publish.sh)

Step 5 -- Post-publish instructions:
- Print a clear "NEXT STEPS" section:
  1. "For each package, enable OIDC trusted publishing at:"
     - List all 6 package URLs: https://www.npmjs.com/package/PACKAGE_NAME/access
  2. "Configure the GitHub Actions workflow as the trusted publisher"
  3. "After that, CI releases via `scripts/release.sh` will publish automatically"

Make the script executable (the executor should `chmod +x` after writing).

Important: Do NOT use `--otp` flag -- npm handles OTP prompting automatically when 2FA is enabled. Do NOT use `npm set //registry.npmjs.org/:_authToken` -- this script relies on the user's existing interactive npm session.
  </action>
  <verify>
    1. `bash -n scripts/initial-publish.sh` -- syntax check passes
    2. `test -x scripts/initial-publish.sh` -- script is executable
    3. `head -1 scripts/initial-publish.sh` shows `#!/usr/bin/env bash`
    4. `grep -c 'npm publish' scripts/initial-publish.sh` returns 2 (loop + main package)
    5. `grep 'npm whoami' scripts/initial-publish.sh` confirms login check exists
    6. `grep '\-\-dry-run' scripts/initial-publish.sh` confirms dry-run support
    7. `grep 'NEXT STEPS' scripts/initial-publish.sh` confirms post-publish instructions
  </verify>
  <done>
    Script exists at scripts/initial-publish.sh, is executable, passes bash syntax check, includes npm login verification, dry-run support, confirmation prompt, publishes all 6 packages with --access public, and prints post-publish trusted publishing setup instructions.
  </done>
</task>

</tasks>

<verification>
- `bash -n scripts/initial-publish.sh` passes (valid bash syntax)
- `scripts/initial-publish.sh --dry-run` can be run (will fail gracefully if not logged in to npm, showing the login instructions)
- Script follows same patterns as existing `scripts/publish.sh` (PLATFORMS array, cd subshell, dry-run flag)
</verification>

<success_criteria>
- scripts/initial-publish.sh exists and is executable
- Script verifies npm login before publishing
- Script publishes all 5 platform packages then the main package
- Script supports --dry-run
- Script prints trusted publishing setup instructions after successful publish
- Script does not require NPM_TOKEN or pre-built binaries
</success_criteria>

<output>
After completion, create `.planning/quick/12-create-bash-script-for-initial-manual-np/12-SUMMARY.md`
</output>
