# Deferred Items — Phase 21

## Out-of-scope issues found during 21-01 execution

### Pre-existing console test failures (not caused by 21-01 changes)

**Found during:** Task 2 final test run
**Files:** `rust/src/output/console.rs`
**Issue:** Two tests fail in the current working tree:
- `output::console::tests::test_render_console_single_line_per_function` — expects 1 line per function (Zig consolidated format), but current renderer outputs 3
- `output::console::tests::test_render_console_no_verbose_hides_ok_functions` — expects file sections to be hidden for clean files

**Root cause:** `console.rs` has 916 lines in working tree vs 661 at last commit (b4c28a5). It was being rewritten to match Zig ESLint-style format (per Deviation 4 / OUT-01 requirement). The new Zig-format tests in the working tree are testing behavior not yet fully implemented.

**Impact:** These failures pre-existed before Plan 21-01 work started and are unrelated to config.rs, cognitive.rs, json_output.rs, or types.rs changes.

**Resolution:** These should be fixed when the console renderer rewrite (Deviation 4, OUT-01) is completed — expected in a later plan within Phase 21 or Phase 22.
