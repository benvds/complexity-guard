---
phase: quick-19
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - benchmarks/scripts/bench-quick.sh
  - benchmarks/scripts/bench-full.sh
  - benchmarks/scripts/bench-stress.sh
  - benchmarks/scripts/bench-subsystems.sh
  - benchmarks/scripts/summarize-results.mjs
  - benchmarks/results/baseline-2026-02-21/system-info.json
  - benchmarks/README.md
  - docs/benchmarks.md
  - publication/npm/README.md
  - publication/npm/packages/darwin-arm64/README.md
  - publication/npm/packages/darwin-x64/README.md
  - publication/npm/packages/linux-arm64/README.md
  - publication/npm/packages/linux-x64/README.md
  - publication/npm/packages/windows-x64/README.md
autonomous: true
requirements: []

must_haves:
  truths:
    - "Benchmark results directory contains a system-info.json with CPU, memory, OS, and kernel info"
    - "All four bench scripts capture system specs into system-info.json in the results directory"
    - "summarize-results.mjs prints system specs in its markdown output header"
    - "docs/benchmarks.md Hardware section contains actual specs from the baseline-2026-02-21 run"
    - "benchmarks/README.md references system-info.json in its Results Directory Structure section"
  artifacts:
    - path: "benchmarks/results/baseline-2026-02-21/system-info.json"
      provides: "System specs for the existing baseline run"
      contains: "AMD Ryzen 7 5700U"
    - path: "benchmarks/scripts/bench-quick.sh"
      provides: "System spec capture in quick bench script"
      contains: "system-info.json"
    - path: "benchmarks/scripts/summarize-results.mjs"
      provides: "System spec display in summary output"
      contains: "system-info.json"
  key_links:
    - from: "benchmarks/scripts/bench-quick.sh"
      to: "benchmarks/results/baseline-*/system-info.json"
      via: "shell commands writing JSON"
      pattern: "system-info\\.json"
    - from: "benchmarks/scripts/summarize-results.mjs"
      to: "benchmarks/results/baseline-*/system-info.json"
      via: "fs.readFileSync in main()"
      pattern: "system-info\\.json"
---

<objective>
Add system hardware specifications to benchmark results so that benchmark numbers have proper context for reproducibility and comparison.

Purpose: Benchmark results without hardware context are meaningless for cross-machine comparison. System specs make results reproducible and let future Phase 11/12 before/after comparisons confirm they ran on the same hardware.
Output: system-info.json in results directories, updated bench scripts, updated summarize output, updated documentation.
</objective>

<execution_context>
@/home/ben/.claude/get-shit-done/workflows/execute-plan.md
@/home/ben/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@benchmarks/scripts/bench-quick.sh
@benchmarks/scripts/bench-full.sh
@benchmarks/scripts/bench-stress.sh
@benchmarks/scripts/bench-subsystems.sh
@benchmarks/scripts/summarize-results.mjs
@benchmarks/README.md
@docs/benchmarks.md
@benchmarks/results/baseline-2026-02-21/got-quick.json
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add system spec capture to bench scripts and create baseline system-info.json</name>
  <files>
    benchmarks/scripts/bench-quick.sh
    benchmarks/scripts/bench-full.sh
    benchmarks/scripts/bench-stress.sh
    benchmarks/scripts/bench-subsystems.sh
    benchmarks/results/baseline-2026-02-21/system-info.json
  </files>
  <action>
Create a shared shell function (or inline snippet -- since these scripts don't source a common file, use an inline snippet in each) that captures system specs into `$RESULTS_DIR/system-info.json`. Place this capture immediately after `mkdir -p "$RESULTS_DIR"` in each script. If system-info.json already exists in the results dir, skip (don't overwrite -- multiple scripts may write to the same dated directory).

The system-info.json schema:
```json
{
  "hostname": "...",
  "os": "Fedora Linux 43",
  "kernel": "6.18.9-200.fc43.x86_64",
  "arch": "x86_64",
  "cpu": {
    "model": "AMD Ryzen 7 5700U with Radeon Graphics",
    "cores": 8,
    "threads": 16,
    "max_mhz": 4373
  },
  "memory": {
    "total_gb": 13.5
  },
  "captured_at": "2026-02-21T..."
}
```

Use portable commands that work on both Linux and macOS:
- `uname -s` for OS type detection
- Linux: `lscpu` for CPU info, `free` or `/proc/meminfo` for memory, `/etc/os-release` for distro
- macOS: `sysctl -n machdep.cpu.brand_string` for CPU, `sysctl -n hw.ncpu` for threads, `sysctl -n hw.memsize` for memory
- Use `jq -n` to construct JSON (jq is already a required dependency of all bench scripts)

The snippet pattern for each script (after mkdir):
```bash
# Capture system specs (skip if already captured by another bench script)
SYSTEM_INFO="$RESULTS_DIR/system-info.json"
if [[ ! -f "$SYSTEM_INFO" ]]; then
  # ... detection logic ...
  jq -n \
    --arg hostname "$HOSTNAME_VAL" \
    --arg os "$OS_NAME" \
    --arg kernel "$KERNEL_VER" \
    --arg arch "$ARCH" \
    --arg cpu_model "$CPU_MODEL" \
    --argjson cpu_cores "$CPU_CORES" \
    --argjson cpu_threads "$CPU_THREADS" \
    --argjson cpu_max_mhz "$CPU_MAX_MHZ" \
    --argjson mem_total_gb "$MEM_TOTAL_GB" \
    --arg captured_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{hostname: $hostname, os: $os, kernel: $kernel, arch: $arch,
      cpu: {model: $cpu_model, cores: $cpu_cores, threads: $cpu_threads, max_mhz: $cpu_max_mhz},
      memory: {total_gb: $mem_total_gb}, captured_at: $captured_at}' \
    > "$SYSTEM_INFO"
  echo "System info: $SYSTEM_INFO"
fi
```

To avoid duplicating 30+ lines in 4 scripts, extract the capture logic into a reusable function at the top of each script. The function should be named `capture_system_info` and take `$RESULTS_DIR` as argument. Yes, it will be duplicated across 4 files, but each script must remain standalone (no shared sourcing).

Also manually create `benchmarks/results/baseline-2026-02-21/system-info.json` with the actual specs of this machine (AMD Ryzen 7 5700U, 8 cores, 16 threads, ~13.5 GB RAM, Fedora 43, kernel 6.18.9). This retroactively documents the hardware for the existing baseline. Get the exact values by running the detection commands on this system.
  </action>
  <verify>
Run: `bash -n benchmarks/scripts/bench-quick.sh && bash -n benchmarks/scripts/bench-full.sh && bash -n benchmarks/scripts/bench-stress.sh && bash -n benchmarks/scripts/bench-subsystems.sh` (syntax check all four scripts).
Run: `jq . benchmarks/results/baseline-2026-02-21/system-info.json` (valid JSON with expected fields).
Verify system-info.json contains: hostname, os, kernel, arch, cpu.model, cpu.cores, cpu.threads, cpu.max_mhz, memory.total_gb, captured_at.
  </verify>
  <done>All four bench scripts contain system spec capture logic. baseline-2026-02-21/system-info.json exists with accurate hardware specs for this machine.</done>
</task>

<task type="auto">
  <name>Task 2: Update summarize-results.mjs to display system specs and update all documentation</name>
  <files>
    benchmarks/scripts/summarize-results.mjs
    benchmarks/README.md
    docs/benchmarks.md
    README.md
    publication/npm/README.md
    publication/npm/packages/darwin-arm64/README.md
    publication/npm/packages/darwin-x64/README.md
    publication/npm/packages/linux-arm64/README.md
    publication/npm/packages/linux-x64/README.md
    publication/npm/packages/windows-x64/README.md
  </files>
  <action>
**summarize-results.mjs changes:**

1. In `main()`, after loading accuracy data and before printing markdown output, attempt to load `system-info.json` from the results directory:
```javascript
const systemInfoPath = path.join(resultsDir, 'system-info.json');
let systemInfo = null;
try {
  systemInfo = JSON.parse(fs.readFileSync(systemInfoPath, 'utf8'));
} catch (_e) { /* system-info.json not present in older baselines */ }
```

2. Right after printing the "Results from:" line, if systemInfo exists, print a "System" section:
```
### System

| Component | Value |
| --------- | ----- |
| CPU | AMD Ryzen 7 5700U with Radeon Graphics (8 cores / 16 threads) |
| Memory | 13.5 GB |
| OS | Fedora Linux 43 (kernel 6.18.9-200.fc43.x86_64) |
| Architecture | x86_64 |
```

Format: `${systemInfo.cpu.model} (${systemInfo.cpu.cores} cores / ${systemInfo.cpu.threads} threads)`, `${systemInfo.memory.total_gb} GB`, `${systemInfo.os} (kernel ${systemInfo.kernel})`, `${systemInfo.arch}`.

3. Include system info in the JSON output object too (add `system_info: systemInfo` to the summary object when `--json` is used).

**docs/benchmarks.md changes:**

Update the "### Hardware" subsection (currently line 83-85, says "Benchmarks were run on a Linux x86-64 development machine") to include actual specs:

```markdown
### Hardware

Benchmarks were run on the following system:

| Component | Value |
| --------- | ----- |
| CPU | AMD Ryzen 7 5700U with Radeon Graphics (8 cores / 16 threads, up to 4.37 GHz) |
| Memory | 13.5 GB DDR4 |
| OS | Fedora Linux 43 (kernel 6.18.9) |
| Architecture | x86_64 |

For reproducible results on your hardware, run `bash benchmarks/scripts/bench-quick.sh` directly.
System specs are automatically captured in `system-info.json` alongside benchmark results.
```

**benchmarks/README.md changes:**

1. In the "Results Directory Structure" section, add `system-info.json` to the directory tree:
```
benchmarks/results/
  baseline-2026-02-21/
    system-info.json              # Hardware specs captured during benchmark run
    zod-quick.json                # hyperfine JSON: CG vs FTA timings for zod
    ...
```

2. Add a brief "### System Info JSON Schema" subsection after the existing "Metric Accuracy JSON Schema" subsection showing the system-info.json schema.

**README.md:** The main README references benchmarks via "see benchmarks" link. Check if the "Low Memory Footprint" bullet or the benchmarks doc link line need any update. Only update if the wording references "Linux x86-64 machine" or similar vague hardware description. Currently it does not -- the README just links to docs/benchmarks.md, so no change needed to README.md itself.

**Publication READMEs:** Check each publication README. If any reference benchmarks with vague hardware descriptions, update them. If they just link to docs/benchmarks.md, no changes needed. Read each file first to determine.
  </action>
  <verify>
Run: `node benchmarks/scripts/summarize-results.mjs benchmarks/results/baseline-2026-02-21/ 2>/dev/null | head -20` and confirm "System" section with CPU/Memory/OS appears in the output.
Run: `node benchmarks/scripts/summarize-results.mjs benchmarks/results/baseline-2026-02-21/ --json /tmp/test-summary.json 2>/dev/null && jq '.system_info.cpu.model' /tmp/test-summary.json` confirms system_info in JSON output.
Verify docs/benchmarks.md contains "AMD Ryzen 7 5700U" in the Hardware section.
Verify benchmarks/README.md mentions system-info.json in directory structure and schema sections.
  </verify>
  <done>summarize-results.mjs displays system specs in both markdown and JSON output. docs/benchmarks.md Hardware section shows exact specs. benchmarks/README.md documents system-info.json schema. Publication READMEs updated if they contained vague hardware references.</done>
</task>

</tasks>

<verification>
- `jq . benchmarks/results/baseline-2026-02-21/system-info.json` returns valid JSON with all expected fields
- `bash -n benchmarks/scripts/bench-quick.sh` passes (and same for full, stress, subsystems)
- `node benchmarks/scripts/summarize-results.mjs benchmarks/results/baseline-2026-02-21/` output includes System section with hardware specs
- `grep -q "system-info.json" benchmarks/scripts/bench-quick.sh` confirms capture logic present
- `grep -q "AMD Ryzen 7 5700U" docs/benchmarks.md` confirms hardware documented
- `grep -q "system-info.json" benchmarks/README.md` confirms schema documented
</verification>

<success_criteria>
1. Existing baseline (baseline-2026-02-21) has system-info.json with accurate hardware specs
2. Future benchmark runs automatically capture system specs via all four bench scripts
3. summarize-results.mjs displays system specs in both markdown and JSON output
4. docs/benchmarks.md and benchmarks/README.md document the hardware and system-info.json schema
</success_criteria>

<output>
After completion, create `.planning/quick/19-include-system-specs-in-the-benchmarking/19-01-SUMMARY.md`
</output>
