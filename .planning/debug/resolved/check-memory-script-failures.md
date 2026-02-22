---
status: resolved
trigger: "check-memory script fails with 2 out of 3 checks failing"
created: 2026-02-22T00:00:00Z
updated: 2026-02-22T00:05:00Z
---

## Current Focus

hypothesis: RESOLVED
test: Script passes 3/3 checks consistently
expecting: N/A
next_action: N/A (archived)

## Symptoms

expected: The check-memory script should pass all checks (or skip optional ones gracefully). Result should be PASS.
actual: 2 checks fail, 1 passes. Output shows zod stress test skipped, 1 passed, 2 failed.
errors: RESULT: FAIL — 2 check(s) failed
reproduction: Run `scripts/check-memory.sh`
started: Script was created in quick task 20 (commit 439edc9). May have worked initially but fails now.

## Eliminated

## Evidence

- timestamp: 2026-02-22T00:00:00Z
  checked: scripts/check-memory.sh source
  found: Script runs 3 checks (single-threaded memcheck, multi-threaded memcheck, helgrind) + optional zod stress test. Fails only on valgrind exit code 99.
  implication: The 2 failing checks are getting exit code 99 from valgrind, meaning valgrind is detecting errors.

- timestamp: 2026-02-22T00:00:10Z
  checked: Full script output (all 3 checks)
  found: Check 1 (single-threaded memcheck) FAILS with memory leak. Check 2 (multi-threaded) PASSES. Check 3 (Helgrind) FAILS with "More than 100 errors detected".
  implication: Two distinct bugs - a real memory leak in single-threaded path, and false positives in Helgrind.

- timestamp: 2026-02-22T00:00:20Z
  checked: Valgrind memcheck leak trace for Bug 1
  found: "definitely lost: 320 bytes in 10 blocks" via ts_tree_new -> parseString -> parseFile -> parseFiles -> main.main (sequential path at main.zig:284)
  implication: TSTree objects allocated via ts_malloc (C heap) are never freed in the sequential path. ParseSummary.deinit() is never called.

- timestamp: 2026-02-22T00:00:30Z
  checked: src/main.zig lines 281-431 (sequential path) and parse.zig ParseSummary.deinit()
  found: Comment "Note: no defer deinit — the arena allocator cleans everything up" is WRONG. Arena only frees Zig allocations. ts_tree_delete() must be called explicitly to free C heap TSTree objects.
  implication: Need to call tree.deinit() for each file after processing it in the sequential for loop.

- timestamp: 2026-02-22T00:00:40Z
  checked: Function name borrowing - cyclomatic.zig line 401 sets function_name = source[start_byte..end_byte]
  found: function_name slices borrow from source buffer. Cannot call ParseSummary.deinit() (which frees source) while cycl_results referencing those slices are still in use. Fix: defer tree.deinit() per iteration instead of full summary deinit.
  implication: Must free only the tree (not source) after each file's analysis loop iteration.

- timestamp: 2026-02-22T00:00:50Z
  checked: Helgrind error traces - 1382 errors, all involving SinglyLinkedList.prepend/popFirst vs Pool.zig operations
  found: Zig's std.Thread.Mutex uses FutexImpl on Linux (raw futex syscalls, not pthread_mutex). Helgrind only tracks happens-before via pthread_mutex_lock/unlock wrappers. So ALL mutex-protected accesses appear as data races to Helgrind.
  implication: All Helgrind errors are false positives. The code is correctly synchronized but Helgrind cannot see it.

- timestamp: 2026-02-22T00:01:00Z
  checked: Generated suppressions via --gen-suppressions=all across 10+ runs
  found: 30+ unique error patterns, all non-deterministic (depend on thread scheduling). Broad suppressions using ... wildcard with worker/waitAndWork terminal frames fully suppress all false positives.
  implication: Suppression file approach is correct; needed broad ... wildcards for thread-scheduling-dependent patterns.

## Resolution

root_cause: |
  Bug 1 (memory leak, single-threaded check): The sequential path in main.zig calls parse.parseFiles()
  but never calls seq_parse_summary.deinit() nor tree.deinit() on each ParseResult. The comment
  "the arena allocator cleans everything up" is incorrect — arena.deinit() only frees Zig allocations.
  TSTree objects are allocated by tree-sitter via ts_malloc (C heap malloc) and require explicit
  ts_tree_delete() calls via tree.deinit(). 10 files × 1 tree each = 10 leaked TSTree objects
  (320 bytes direct + 360,896 bytes indirect = 361,216 bytes total).

  Bug 2 (Helgrind false positives): Zig's std.Thread.Mutex uses FutexImpl on Linux (raw futex
  syscalls), not pthread_mutex_*. Helgrind tracks happens-before relationships exclusively through
  pthread wrapper calls. The parallel code is correctly synchronized but Helgrind cannot observe it,
  producing 1382+ false positive data race reports. The specific patterns are non-deterministic
  (depend on thread scheduling) so a broad suppression file is needed.

fix: |
  Bug 1: Added `defer if (result.tree) |tree| tree.deinit();` inside the sequential for loop in
  main.zig, freeing each TSTree via ts_tree_delete immediately after analysis of that file.
  Cannot call full ParseSummary.deinit() because function_name slices borrow from source.
  Result: "All heap blocks were freed -- no leaks are possible".

  Bug 2: Created .valgrind.supp with 40+ targeted suppressions covering all Helgrind false positive
  patterns from the thread pool (both worker-thread and waitAndWork paths). Added broad ... wildcard
  suppressions to handle non-deterministic scheduling-dependent patterns. Updated check-memory.sh
  to pass --suppressions=.valgrind.supp to the Helgrind check.

verification: |
  Ran `bash scripts/check-memory.sh` 6 consecutive times. All runs show:
  - PASS: Valgrind memcheck (single-threaded)  -- 0 errors, all blocks freed
  - PASS: Valgrind memcheck (multi-threaded)   -- 0 errors, all blocks freed
  - PASS: Helgrind thread-safety               -- 0 unsuppressed errors
  - SKIP: Stress test (zod)                    -- expected (repo not cloned)
  - RESULT: PASS — all checks clean

  All existing unit tests still pass: `zig build test` exits 0.

files_changed:
  - src/main.zig (added defer tree.deinit() in sequential path)
  - scripts/check-memory.sh (added SUPPRESSIONS var + --suppressions flag to Helgrind check + comment)
  - .valgrind.supp (new file: 40+ suppressions for Zig futex-based mutex false positives)
