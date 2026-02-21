#!/usr/bin/env python3
"""Aggregate hyperfine benchmark JSON results into summary tables.

Usage:
    python3 summarize_results.py <results-dir> [--json <output-path>]

Output:
    Markdown summary table to stdout.
    JSON summary to file if --json <path> is specified.

Reads:
    *-quick.json, *-full.json, *-stress.json   hyperfine result files
    *-subsystems.json                           Zig subsystem timing files (if present)
    metric-accuracy.json                        compare_metrics.py output (if present)

Hyperfine JSON schema:
    { results: [
        { command, mean, stddev, memory_usage_byte: [int, ...], ... },  // CG
        { command, mean, stddev, memory_usage_byte: [int, ...], ... },  // FTA
    ]}
"""

import json
import os
import sys
import glob
from pathlib import Path


def mean_memory(memory_list) -> float:
    """Compute mean memory usage in MB from a list of bytes values."""
    if not memory_list:
        return 0.0
    return sum(memory_list) / len(memory_list) / (1024 * 1024)


def parse_hyperfine_file(filepath: str) -> dict | None:
    """Parse a single hyperfine JSON result file.

    Returns dict with project, suite, cg_mean_ms, cg_stddev_ms, fta_mean_ms,
    fta_stddev_ms, cg_mem_mb, fta_mem_mb, speedup, mem_ratio, or None on error.
    """
    filename = os.path.basename(filepath)
    # Extract project and suite from filename: <project>-<suite>.json
    parts = filename.replace(".json", "").rsplit("-", 1)
    if len(parts) != 2:
        return None
    project, suite = parts[0], parts[1]

    try:
        with open(filepath) as f:
            data = json.load(f)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Warning: Could not load {filepath}: {e}", file=sys.stderr)
        return None

    results = data.get("results", [])
    if len(results) < 2:
        # Some files may have only one result if FTA failed; skip
        if len(results) == 1:
            print(f"Warning: {filename} has only 1 result (expected 2), skipping", file=sys.stderr)
        return None

    cg = results[0]
    fta = results[1]

    cg_mean_ms = cg.get("mean", 0.0) * 1000
    cg_stddev_ms = cg.get("stddev", 0.0) * 1000
    fta_mean_ms = fta.get("mean", 0.0) * 1000
    fta_stddev_ms = fta.get("stddev", 0.0) * 1000

    cg_mem_list = cg.get("memory_usage_byte", [])
    fta_mem_list = fta.get("memory_usage_byte", [])
    cg_mem_mb = mean_memory(cg_mem_list)
    fta_mem_mb = mean_memory(fta_mem_list)

    # speedup > 1.0 means FTA is faster (CG takes longer relative to FTA)
    speedup = cg_mean_ms / fta_mean_ms if fta_mean_ms > 0 else 0.0
    mem_ratio = fta_mem_mb / cg_mem_mb if cg_mem_mb > 0 else 0.0

    return {
        "project": project,
        "suite": suite,
        "cg_mean_ms": round(cg_mean_ms, 1),
        "cg_stddev_ms": round(cg_stddev_ms, 1),
        "fta_mean_ms": round(fta_mean_ms, 1),
        "fta_stddev_ms": round(fta_stddev_ms, 1),
        "cg_mem_mb": round(cg_mem_mb, 1),
        "fta_mem_mb": round(fta_mem_mb, 1),
        "speedup": round(speedup, 2),
        "mem_ratio": round(mem_ratio, 2),
    }


def parse_subsystems_file(filepath: str) -> dict | None:
    """Parse a Zig subsystem benchmark JSON file.

    Expected schema: { project, suite, subsystems: [{ name, mean_ms, stddev_ms }] }
    Returns None on error.
    """
    try:
        with open(filepath) as f:
            data = json.load(f)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Warning: Could not load {filepath}: {e}", file=sys.stderr)
        return None
    return data


def parse_metric_accuracy(filepath: str) -> list | None:
    """Parse metric-accuracy.json produced by compare-metrics.sh.

    Expected schema: [{ project, files_compared, cyclomatic, halstead_volume, ... }]
    Returns None on error.
    """
    try:
        with open(filepath) as f:
            data = json.load(f)
    except (json.JSONDecodeError, FileNotFoundError):
        return None
    return data if isinstance(data, list) else None


def format_speed_row(r: dict) -> str:
    """Format a markdown table row for the speed comparison table.

    speedup = cg_mean / fta_mean: >1.0 means FTA is faster than CG.
    """
    speedup_str = f"{r['speedup']:.1f}x"
    if r["speedup"] > 1.0:
        # FTA is faster
        speedup_label = f"{speedup_str} faster"
    elif r["speedup"] < 0.99:
        # CG is faster
        speedup_label = f"{1/r['speedup']:.1f}x CG faster"
    else:
        speedup_label = "equal"

    cg_ms_str = f"{r['cg_mean_ms']:.0f} ± {r['cg_stddev_ms']:.0f}"
    fta_ms_str = f"{r['fta_mean_ms']:.0f} ± {r['fta_stddev_ms']:.0f}"

    return (
        f"| {r['project']:<20} | {cg_ms_str:<12} | {fta_ms_str:<12} | "
        f"{speedup_label:<12} | {r['cg_mem_mb']:<10.1f} | {r['fta_mem_mb']:<11.1f} | "
        f"{r['mem_ratio']:.1f}x      |"
    )


def print_speed_table(results: list[dict], suite: str | None = None) -> None:
    """Print a markdown speed and memory comparison table."""
    filtered = [r for r in results if suite is None or r["suite"] == suite]
    if not filtered:
        return

    suite_label = suite or "all"
    print(f"\n### Speed and Memory Comparison ({suite_label} suite)\n")
    print(f"| {'Project':<20} | {'CG (ms)':<12} | {'FTA (ms)':<12} | {'Speedup':<12} | {'CG Mem (MB)':<10} | {'FTA Mem (MB)':<11} | Mem Ratio |")
    print(f"| {'-'*20} | {'-'*12} | {'-'*12} | {'-'*12} | {'-'*10} | {'-'*11} | {'-'*9} |")
    for r in sorted(filtered, key=lambda x: x["cg_mean_ms"]):
        print(format_speed_row(r))

    if len(filtered) > 1:
        avg_speedup = sum(r["speedup"] for r in filtered) / len(filtered)
        avg_mem_ratio = sum(r["mem_ratio"] for r in filtered if r["mem_ratio"] > 0) / max(
            sum(1 for r in filtered if r["mem_ratio"] > 0), 1
        )
        print(f"\n**Mean speedup:** {avg_speedup:.1f}x &nbsp; | &nbsp; **Mean memory ratio:** {avg_mem_ratio:.1f}x")
        print(f"*(Speedup = CG time / FTA time; >1.0 means FTA is faster than CG)*")


def print_metric_accuracy_table(accuracy_data: list) -> None:
    """Print a markdown metric accuracy summary table."""
    if not accuracy_data:
        return

    print("\n### Metric Accuracy: CG vs FTA Agreement\n")
    print("| Project | Files | Cyclo Agree | Cyclo Corr | Halstead Agree | Halstead Corr |")
    print("| ------- | ----- | ----------- | ---------- | -------------- | ------------- |")
    for item in accuracy_data:
        project = item.get("project", "?")
        n = item.get("files_compared", 0)
        cyclo = item.get("cyclomatic", {})
        hal = item.get("halstead_volume", {})
        print(
            f"| {project:<20} | {n:<5} | "
            f"{cyclo.get('within_tolerance_pct', 0):.0f}% (±25%)  | "
            f"{cyclo.get('ranking_correlation', 0):.3f}      | "
            f"{hal.get('within_tolerance_pct', 0):.0f}% (±30%)      | "
            f"{hal.get('ranking_correlation', 0):.3f}         |"
        )

    # Overall averages
    if accuracy_data:
        avg_cyclo = sum(d.get("cyclomatic", {}).get("within_tolerance_pct", 0) for d in accuracy_data) / len(accuracy_data)
        avg_hal = sum(d.get("halstead_volume", {}).get("within_tolerance_pct", 0) for d in accuracy_data) / len(accuracy_data)
        print(f"\n**Mean cyclomatic agreement:** {avg_cyclo:.0f}% &nbsp; | &nbsp; **Mean Halstead agreement:** {avg_hal:.0f}%")


def main():
    if len(sys.argv) < 2:
        print("Usage: summarize_results.py <results-dir> [--json <output-path>]", file=sys.stderr)
        sys.exit(1)

    results_dir = sys.argv[1]
    json_output_path = None

    # Parse --json flag
    args = sys.argv[2:]
    i = 0
    while i < len(args):
        if args[i] == "--json" and i + 1 < len(args):
            json_output_path = args[i + 1]
            i += 2
        else:
            i += 1

    if not os.path.isdir(results_dir):
        print(f"Error: results directory not found: {results_dir}", file=sys.stderr)
        sys.exit(1)

    # Discover hyperfine result files
    suite_pattern = os.path.join(results_dir, "*-quick.json")
    suite_files = (
        glob.glob(os.path.join(results_dir, "*-quick.json"))
        + glob.glob(os.path.join(results_dir, "*-full.json"))
        + glob.glob(os.path.join(results_dir, "*-stress.json"))
    )

    benchmark_results = []
    for filepath in sorted(suite_files):
        r = parse_hyperfine_file(filepath)
        if r is not None:
            benchmark_results.append(r)

    if not benchmark_results:
        print("Warning: No hyperfine benchmark result files found.", file=sys.stderr)

    # Discover subsystem files
    subsystem_files = glob.glob(os.path.join(results_dir, "*-subsystems.json"))
    subsystem_data = []
    for filepath in sorted(subsystem_files):
        d = parse_subsystems_file(filepath)
        if d is not None:
            subsystem_data.append(d)

    # Load metric accuracy if present
    accuracy_path = os.path.join(results_dir, "metric-accuracy.json")
    accuracy_data = parse_metric_accuracy(accuracy_path)

    # Determine which suites are present
    suites = sorted(set(r["suite"] for r in benchmark_results))

    # Print markdown output
    print("## ComplexityGuard vs FTA: Benchmark Summary\n")
    print(f"Results from: `{results_dir}`\n")

    for suite in suites:
        print_speed_table(benchmark_results, suite=suite)

    if len(suites) > 1:
        print_speed_table(benchmark_results, suite=None)

    # Subsystem breakdown
    if subsystem_data:
        print("\n### CG Subsystem Breakdown\n")
        # Collect all subsystem names across projects
        all_subsystems = set()
        for d in subsystem_data:
            for s in d.get("subsystems", []):
                all_subsystems.add(s["name"])
        subsystem_names = sorted(all_subsystems)
        header = "| Project | " + " | ".join(subsystem_names) + " |"
        separator = "| ------- | " + " | ".join("---" for _ in subsystem_names) + " |"
        print(header)
        print(separator)
        for d in subsystem_data:
            subs = {s["name"]: s.get("mean_ms", 0) for s in d.get("subsystems", [])}
            row = f"| {d.get('project', '?'):<20} | " + " | ".join(
                f"{subs.get(n, 0):.1f} ms" for n in subsystem_names
            ) + " |"
            print(row)

    # Metric accuracy
    if accuracy_data:
        print_metric_accuracy_table(accuracy_data)
    else:
        print("\n*Metric accuracy data not found. Run `compare-metrics.sh` to generate it.*")

    # Overall summary stats
    if benchmark_results:
        avg_speedup = sum(r["speedup"] for r in benchmark_results) / len(benchmark_results)
        avg_mem = sum(r["mem_ratio"] for r in benchmark_results if r["mem_ratio"] > 0)
        n_mem = sum(1 for r in benchmark_results if r["mem_ratio"] > 0)
        avg_mem_ratio = avg_mem / max(n_mem, 1)
        fastest_cg = min(benchmark_results, key=lambda r: r["cg_mean_ms"])
        slowest_cg = max(benchmark_results, key=lambda r: r["cg_mean_ms"])
        print(f"\n### Overall Summary\n")
        print(f"- Projects benchmarked: {len(benchmark_results)}")
        print(f"- Mean CG/FTA speed ratio: {avg_speedup:.2f}x (>1.0 means FTA is faster than CG)")
        print(f"- Mean FTA/CG memory ratio: {avg_mem_ratio:.2f}x (FTA uses more memory = >1.0)")
        print(f"- Fastest project: {fastest_cg['project']} ({fastest_cg['cg_mean_ms']:.0f} ms CG)")
        print(f"- Slowest project: {slowest_cg['project']} ({slowest_cg['cg_mean_ms']:.0f} ms CG)")

    # JSON output
    if json_output_path:
        summary = {
            "results_dir": results_dir,
            "benchmark_results": benchmark_results,
            "subsystem_data": subsystem_data,
            "accuracy_data": accuracy_data,
        }
        os.makedirs(os.path.dirname(os.path.abspath(json_output_path)), exist_ok=True)
        with open(json_output_path, "w") as f:
            json.dump(summary, f, indent=2)
        print(f"\n*JSON summary written to: {json_output_path}*", file=sys.stderr)


if __name__ == "__main__":
    main()
