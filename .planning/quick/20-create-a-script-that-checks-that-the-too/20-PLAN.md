---
phase: quick-20
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/check-memory.sh
  - .github/workflows/test.yml
autonomous: true
requirements: []

must_haves:
  truths:
    - "Running the script locally detects memory leaks if they exist and exits non-zero"
    - "Running the script exercises both single-threaded and multi-threaded code paths"
    - "CI automatically runs memory and thread-safety checks on every push/PR"
    - "CI fails if Valgrind reports any leaks or Helgrind reports data races"
  artifacts:
    - path: "scripts/check-memory.sh"
      provides: "Memory leak and thread-safety verification script"
      contains: "valgrind"
    - path: ".github/workflows/test.yml"
      provides: "CI pipeline with memory check job"
      contains: "check-memory"
  key_links:
    - from: ".github/workflows/test.yml"
      to: "scripts/check-memory.sh"
      via: "bash scripts/check-memory.sh"
      pattern: "scripts/check-memory"
---

<objective>
Create a memory leak and thread-safety verification script and integrate it into CI.

Purpose: Prove ComplexityGuard has zero memory leaks and no data races in both single-threaded and multi-threaded modes. Valgrind (memcheck) catches leaks; Helgrind catches data races in the thread pool introduced in Phase 12.

Output: scripts/check-memory.sh + updated .github/workflows/test.yml
</objective>

<execution_context>
@/home/ben/.claude/get-shit-done/workflows/execute-plan.md
@/home/ben/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@.github/workflows/test.yml
@build.zig
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create memory leak and thread-safety check script</name>
  <files>scripts/check-memory.sh</files>
  <action>
Create `scripts/check-memory.sh` (executable) that does the following:

1. **Build the binary with ReleaseSafe** (keeps safety checks unlike ReleaseSmall):
   ```
   zig build -Doptimize=ReleaseSafe
   ```

2. **Valgrind memcheck -- single-threaded** (baseline, no threading noise):
   ```
   valgrind --leak-check=full --errors-for-leak-kinds=all --error-exitcode=1 \
     ./zig-out/bin/complexity-guard --threads 1 tests/fixtures/typescript/
   ```
   Run against the typescript fixtures directory. Use `--threads 1` to force sequential path.

3. **Valgrind memcheck -- multi-threaded** (exercises thread pool + per-worker arenas):
   ```
   valgrind --leak-check=full --errors-for-leak-kinds=all --error-exitcode=1 \
     ./zig-out/bin/complexity-guard --threads 4 tests/fixtures/typescript/
   ```
   Use `--threads 4` to exercise the parallel analysis path from Phase 12.

4. **Helgrind -- thread-safety check** (detects data races in parallel code):
   ```
   valgrind --tool=helgrind --error-exitcode=1 \
     ./zig-out/bin/complexity-guard --threads 4 tests/fixtures/typescript/
   ```
   Helgrind specifically checks for lock ordering violations, data races, and misuse of POSIX threading APIs.

5. **Stress test with real-world codebase** (optional, only if tests/repos/webpack exists):
   If `tests/repos/webpack` directory exists, run memcheck against it with `--threads 4` to catch leaks that only manifest with hundreds of files. Print a skip message if the directory is not present (it may not be cloned in CI). Use `--fail-on none` flag to suppress non-zero exit from threshold violations (we only care about Valgrind's exit code here).

Script structure:
- Set `set -euo pipefail` at the top
- Use a `BINARY` variable for the path `./zig-out/bin/complexity-guard`
- Print clear section headers (e.g., "=== Valgrind memcheck (single-threaded) ===")
- Track pass/fail count and print summary at the end
- Exit 0 only if ALL checks pass, exit 1 otherwise
- Use `--fail-on none` on all complexity-guard invocations so that Valgrind's exit code (from `--error-exitcode=1`) is what determines pass/fail, not the tool's own threshold exit codes (CG exits 1 when error thresholds are exceeded)
- Important: complexity-guard may exit with code 1 for threshold violations, so we need to capture Valgrind's specific exit behavior. Valgrind forwards the program's exit code unless it detects its own errors. Use `--error-exitcode=99` instead of `--error-exitcode=1` so we can distinguish Valgrind errors (exit 99) from CG threshold errors (exit 1). After each valgrind run, check: if exit code is 99 then it's a Valgrind failure; any other exit code means no memory issues.

Make the script executable (chmod +x).
  </action>
  <verify>
Run `bash scripts/check-memory.sh` locally if valgrind is installed, or verify the script is syntactically valid with `bash -n scripts/check-memory.sh`. The script should be well-structured and handle the case where valgrind is not installed (print error and exit 1).
  </verify>
  <done>scripts/check-memory.sh exists, is executable, contains valgrind memcheck (single + multi-threaded), helgrind, and optional stress test sections. Script exits non-zero on any memory or threading issue.</done>
</task>

<task type="auto">
  <name>Task 2: Add memory check job to CI workflow</name>
  <files>.github/workflows/test.yml</files>
  <action>
Add a new job `memory-check` to `.github/workflows/test.yml` that runs only on `ubuntu-latest` (Valgrind is Linux-only). The job should:

1. Checkout with submodules (needed for tree-sitter vendor)
2. Install Zig 0.15.2 via mlugg/setup-zig@v2
3. Install valgrind: `sudo apt-get update && sudo apt-get install -y valgrind`
4. Run `bash scripts/check-memory.sh`

This job should be independent of the existing `test` job (no `needs` dependency) so they run in parallel.

The job does NOT need the webpack stress test repo -- the script already handles the missing directory gracefully.

Keep the existing `test` job completely unchanged. Only add the new `memory-check` job below it.
  </action>
  <verify>`cat .github/workflows/test.yml` shows both `test` and `memory-check` jobs. The memory-check job installs valgrind, uses Zig 0.15.2, and runs the script.</verify>
  <done>CI workflow has a memory-check job on ubuntu-latest that installs valgrind and runs scripts/check-memory.sh. Job runs in parallel with existing test matrix.</done>
</task>

</tasks>

<verification>
- `bash -n scripts/check-memory.sh` exits 0 (valid syntax)
- `.github/workflows/test.yml` is valid YAML with both `test` and `memory-check` jobs
- The memory-check job installs valgrind and runs the script
- Script handles missing valgrind (error message), missing webpack repo (skip message)
</verification>

<success_criteria>
- scripts/check-memory.sh exists and is executable
- Script runs valgrind memcheck (single-threaded + multi-threaded), helgrind (thread safety), and optional stress test
- .github/workflows/test.yml has a memory-check job on ubuntu-latest
- CI will fail on any memory leak or data race
</success_criteria>

<output>
After completion, create `.planning/quick/20-create-a-script-that-checks-that-the-too/20-SUMMARY.md`
</output>
