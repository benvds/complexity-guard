#!/usr/bin/env python3
"""Compare complexity metrics between ComplexityGuard and FTA for a single project.

Usage:
    python3 compare_metrics.py <cg-json-path> <fta-json-path> <project-name>

Output:
    JSON comparison to stdout.
    Human-readable summary to stderr.

CG JSON schema: { files: [{ path, functions: [{ name, cyclomatic, halstead_volume, ... }] }] }
FTA JSON schema: [{ file_name, cyclo, halstead: { volume, ... }, line_count, ... }]

Methodology:
    CG operates at function-level granularity. To compare with FTA's file-level output,
    we aggregate CG values per file by summing per-function values. This produces comparable
    totals while preserving CG's higher granularity for other analysis purposes.

    Tolerance bands account for parser differences (CG uses tree-sitter, FTA uses SWC)
    and aggregation differences:
      - cyclomatic: 25% tolerance
      - halstead_volume: 30% tolerance (SWC tokenizes differently than tree-sitter)
      - line_count: 20% tolerance (different line counting rules)
"""

import json
import sys
import os
import math


CYCLOMATIC_TOLERANCE = 25.0
HALSTEAD_TOLERANCE = 30.0
LINE_COUNT_TOLERANCE = 20.0


def normalize_cg_path(path: str, project_name: str) -> str:
    """Extract path relative to the project root from an absolute CG file path.

    CG produces absolute paths like:
      /home/user/.../benchmarks/projects/zod/src/types.ts
    FTA produces paths relative to the project root like:
      src/types.ts

    This function strips everything up to and including the project name segment
    so both tools produce comparable relative paths.
    """
    parts = path.replace("\\", "/").split("/")
    try:
        idx = parts.index(project_name)
        return "/".join(parts[idx + 1:])
    except ValueError:
        # If project name not found in path, return as-is (already relative or unknown)
        return path.replace("\\", "/")


def load_cg_output(cg_path: str, project_name: str) -> dict:
    """Load and aggregate CG output to file-level metrics.

    Returns dict mapping relative_path -> { cyclomatic, halstead_volume, line_count }
    """
    with open(cg_path) as f:
        data = json.load(f)

    file_metrics = {}
    for file_entry in data.get("files", []):
        rel_path = normalize_cg_path(file_entry.get("path", ""), project_name)
        functions = file_entry.get("functions", [])

        # Aggregate function-level values to file-level sums
        total_cyclomatic = sum(fn.get("cyclomatic", 0) for fn in functions)
        total_halstead_volume = sum(fn.get("halstead_volume", 0.0) for fn in functions)

        # file_length is a direct file-level field on the CG file entry
        line_count = file_entry.get("file_length", 0)

        if not rel_path:
            continue

        file_metrics[rel_path] = {
            "cyclomatic": total_cyclomatic,
            "halstead_volume": total_halstead_volume,
            "line_count": line_count,
            "function_count": len(functions),
        }

    return file_metrics


def load_fta_output(fta_path: str, project_name: str) -> dict:
    """Load FTA output and return file-level metrics.

    FTA produces paths already relative to the project root (e.g., "src/types.ts").
    No normalization needed beyond forward-slash conversion.

    Returns dict mapping relative_path -> { cyclomatic, halstead_volume, line_count }
    """
    with open(fta_path) as f:
        data = json.load(f)

    file_metrics = {}
    for entry in data:
        # FTA file_name is already relative to project root
        file_name = entry.get("file_name", "").replace("\\", "/")

        halstead = entry.get("halstead", {})
        file_metrics[file_name] = {
            "cyclomatic": entry.get("cyclo", 0),
            "halstead_volume": halstead.get("volume", 0.0),
            "line_count": entry.get("line_count", 0),
        }

    return file_metrics


def diff_pct(cg_val: float, fta_val: float) -> float:
    """Compute normalized percentage difference between two values."""
    denom = max(abs(cg_val), abs(fta_val), 1.0)
    return abs(cg_val - fta_val) / denom * 100.0


def compute_ranking_correlation(cg_metrics: dict, fta_metrics: dict, metric: str,
                                 common_files: list) -> float:
    """Compute Spearman rank correlation for a metric across common files.

    Returns correlation coefficient in [-1, 1].
    """
    if len(common_files) < 2:
        return 0.0

    cg_vals = [cg_metrics[f][metric] for f in common_files]
    fta_vals = [fta_metrics[f][metric] for f in common_files]

    def rank_list(values):
        sorted_vals = sorted(enumerate(values), key=lambda x: x[1])
        ranks = [0.0] * len(values)
        for rank, (orig_idx, _) in enumerate(sorted_vals):
            ranks[orig_idx] = float(rank + 1)
        return ranks

    cg_ranks = rank_list(cg_vals)
    fta_ranks = rank_list(fta_vals)

    n = len(common_files)
    mean_cg = sum(cg_ranks) / n
    mean_fta = sum(fta_ranks) / n

    num = sum((cg_ranks[i] - mean_cg) * (fta_ranks[i] - mean_fta) for i in range(n))
    denom_cg = math.sqrt(sum((r - mean_cg) ** 2 for r in cg_ranks))
    denom_fta = math.sqrt(sum((r - mean_fta) ** 2 for r in fta_ranks))

    if denom_cg < 1e-10 or denom_fta < 1e-10:
        return 0.0

    return num / (denom_cg * denom_fta)


def analyze_metric(cg_metrics: dict, fta_metrics: dict, metric: str,
                   tolerance: float, common_files: list) -> dict:
    """Compute comparison stats for a single metric across all common files."""
    diffs = []
    within_tolerance_count = 0

    for path in common_files:
        cg_val = float(cg_metrics[path].get(metric, 0))
        fta_val = float(fta_metrics[path].get(metric, 0))
        d = diff_pct(cg_val, fta_val)
        diffs.append(d)
        if d <= tolerance:
            within_tolerance_count += 1

    n = len(common_files)
    if n == 0:
        return {
            "within_tolerance_pct": 0.0,
            "mean_diff_pct": 0.0,
            "ranking_correlation": 0.0,
        }

    mean_diff = sum(diffs) / n
    within_pct = within_tolerance_count / n * 100.0
    correlation = compute_ranking_correlation(cg_metrics, fta_metrics, metric, common_files)

    return {
        "within_tolerance_pct": round(within_pct, 1),
        "mean_diff_pct": round(mean_diff, 1),
        "ranking_correlation": round(correlation, 4),
    }


def main():
    if len(sys.argv) != 4:
        print("Usage: compare_metrics.py <cg-json> <fta-json> <project-name>", file=sys.stderr)
        sys.exit(1)

    cg_path = sys.argv[1]
    fta_path = sys.argv[2]
    project_name = sys.argv[3]

    # Load outputs
    try:
        cg_metrics = load_cg_output(cg_path, project_name)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Warning: Could not load CG output from {cg_path}: {e}", file=sys.stderr)
        cg_metrics = {}

    try:
        fta_metrics = load_fta_output(fta_path, project_name)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Warning: Could not load FTA output from {fta_path}: {e}", file=sys.stderr)
        fta_metrics = {}

    # Find common files
    cg_paths = set(cg_metrics.keys())
    fta_paths = set(fta_metrics.keys())
    common_files = sorted(cg_paths & fta_paths)
    cg_only = len(cg_paths - fta_paths)
    fta_only = len(fta_paths - cg_paths)

    # Analyze each metric
    cyclomatic_stats = analyze_metric(
        cg_metrics, fta_metrics, "cyclomatic", CYCLOMATIC_TOLERANCE, common_files
    )
    halstead_stats = analyze_metric(
        cg_metrics, fta_metrics, "halstead_volume", HALSTEAD_TOLERANCE, common_files
    )
    line_count_stats = analyze_metric(
        cg_metrics, fta_metrics, "line_count", LINE_COUNT_TOLERANCE, common_files
    )

    result = {
        "project": project_name,
        "files_compared": len(common_files),
        "files_cg_only": cg_only,
        "files_fta_only": fta_only,
        "cyclomatic": cyclomatic_stats,
        "halstead_volume": halstead_stats,
        "line_count": line_count_stats,
        "methodology": {
            "cg_aggregation": "sum of per-function values",
            "fta_granularity": "file-level",
            "cyclomatic_tolerance": CYCLOMATIC_TOLERANCE,
            "halstead_tolerance": HALSTEAD_TOLERANCE,
            "line_count_tolerance": LINE_COUNT_TOLERANCE,
            "note": (
                "FTA uses SWC parser; CG uses tree-sitter. "
                "Different tokenization rules cause expected divergence. "
                "Tolerance bands account for parser and aggregation differences."
            ),
        },
    }

    print(json.dumps(result, indent=2))

    # Human-readable summary to stderr
    print(f"\n--- Metric Accuracy: {project_name} ---", file=sys.stderr)
    print(f"Files compared: {len(common_files)} (CG-only: {cg_only}, FTA-only: {fta_only})", file=sys.stderr)
    print(f"Cyclomatic:     {cyclomatic_stats['within_tolerance_pct']:5.1f}% within {CYCLOMATIC_TOLERANCE}% tolerance, "
          f"mean diff {cyclomatic_stats['mean_diff_pct']:.1f}%, "
          f"rank corr {cyclomatic_stats['ranking_correlation']:.3f}", file=sys.stderr)
    print(f"Halstead vol:   {halstead_stats['within_tolerance_pct']:5.1f}% within {HALSTEAD_TOLERANCE}% tolerance, "
          f"mean diff {halstead_stats['mean_diff_pct']:.1f}%, "
          f"rank corr {halstead_stats['ranking_correlation']:.3f}", file=sys.stderr)
    print(f"Line count:     {line_count_stats['within_tolerance_pct']:5.1f}% within {LINE_COUNT_TOLERANCE}% tolerance, "
          f"mean diff {line_count_stats['mean_diff_pct']:.1f}%, "
          f"rank corr {line_count_stats['ranking_correlation']:.3f}", file=sys.stderr)


if __name__ == "__main__":
    main()
