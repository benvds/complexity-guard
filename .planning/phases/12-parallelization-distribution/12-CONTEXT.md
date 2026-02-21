# Phase 12: Parallelization & Distribution - Context

**Gathered:** 2026-02-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Multi-threaded file processing via thread pool for sub-2-second analysis of 10,000+ file codebases, plus cross-compilation to all target platforms (x86_64-linux, aarch64-linux, x86_64-macos, aarch64-macos, x86_64-windows). New metrics or output formats are out of scope.

</domain>

<decisions>
## Implementation Decisions

### Thread control
- Default thread count: auto-detect CPU cores (use all available)
- Flag: `--threads N` for explicit thread count
- `--threads 1` bypasses the thread pool entirely (single-threaded mode, no pool overhead) — useful for debugging
- Thread count is also configurable in `.complexityguard.json` (`threads` field); flag overrides config

### Output determinism
- Output order is always deterministic regardless of thread scheduling — results sorted by file path before output
- JSON output structure stays identical to current schema — parallelization is invisible to consumers, files array sorted by path
- No thread metadata in the main output structure

### Performance feedback
- Timing information (e.g., "Analyzed 1,234 files in 0.8s") shown only with `--verbose`
- Total elapsed time only — no per-stage breakdown
- JSON output includes `elapsed_ms` and `thread_count` in metadata section (for CI performance tracking)
- No progress indicator (spinner/bar) — tool targets sub-2s execution, progress display is unnecessary

### Claude's Discretion
- Error handling strategy for parallel parse failures (continue vs fail-fast, error collection approach)
- Thread pool implementation details (work-stealing, fixed queue, etc.)
- Memory management strategy for parallel allocations
- Cross-compilation build configuration details
- Binary size optimization if parallelization adds weight

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-parallelization-distribution*
*Context gathered: 2026-02-21*
