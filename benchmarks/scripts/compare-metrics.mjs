#!/usr/bin/env node
/**
 * Compare complexity metrics between ComplexityGuard and FTA for a single project.
 *
 * Usage:
 *   node compare-metrics.mjs <cg-json-path> <fta-json-path> <project-name>
 *
 * Output:
 *   JSON comparison to stdout.
 *   Human-readable summary to stderr.
 *
 * CG JSON schema: { files: [{ path, functions: [{ name, cyclomatic, halstead_volume, ... }] }] }
 * FTA JSON schema: [{ file_name, cyclo, halstead: { volume, ... }, line_count, ... }]
 *
 * Methodology:
 *   CG operates at function-level granularity. To compare with FTA's file-level output,
 *   we aggregate CG values per file by summing per-function values. This produces comparable
 *   totals while preserving CG's higher granularity for other analysis purposes.
 *
 *   Tolerance bands account for parser differences (CG uses tree-sitter, FTA uses SWC)
 *   and aggregation differences:
 *     - cyclomatic: 25% tolerance
 *     - halstead_volume: 30% tolerance (SWC tokenizes differently than tree-sitter)
 *     - line_count: 20% tolerance (different line counting rules)
 */

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const CYCLOMATIC_TOLERANCE = 25.0;
const HALSTEAD_TOLERANCE = 30.0;
const LINE_COUNT_TOLERANCE = 20.0;

/**
 * Extract path relative to the project root from an absolute CG file path.
 *
 * CG produces absolute paths like:
 *   /home/user/.../benchmarks/projects/zod/src/types.ts
 * FTA produces paths relative to the project root like:
 *   src/types.ts
 *
 * This function strips everything up to and including the project name segment
 * so both tools produce comparable relative paths.
 * @param {string} filePath
 * @param {string} projectName
 * @returns {string}
 */
function normalizeCgPath(filePath, projectName) {
  const normalized = filePath.replace(/\\/g, '/');
  const parts = normalized.split('/');
  const idx = parts.indexOf(projectName);
  if (idx === -1) {
    // If project name not found in path, return as-is (already relative or unknown)
    return normalized;
  }
  return parts.slice(idx + 1).join('/');
}

/**
 * Load and aggregate CG output to file-level metrics.
 *
 * Returns object mapping relative_path -> { cyclomatic, halstead_volume, line_count, function_count }
 * @param {string} cgPath
 * @param {string} projectName
 * @returns {object}
 */
function loadCgOutput(cgPath, projectName) {
  const content = fs.readFileSync(cgPath, 'utf8');
  const data = JSON.parse(content);

  const fileMetrics = {};
  for (const fileEntry of data.files || []) {
    const relPath = normalizeCgPath(fileEntry.path || '', projectName);
    const functions = fileEntry.functions || [];

    // Aggregate function-level values to file-level sums
    const totalCyclomatic = functions.reduce((sum, fn) => sum + (fn.cyclomatic || 0), 0);
    const totalHalsteadVolume = functions.reduce((sum, fn) => sum + (fn.halstead_volume || 0.0), 0);

    // file_length is a direct file-level field on the CG file entry
    const lineCount = fileEntry.file_length || 0;

    if (!relPath) continue;

    fileMetrics[relPath] = {
      cyclomatic: totalCyclomatic,
      halstead_volume: totalHalsteadVolume,
      line_count: lineCount,
      function_count: functions.length,
    };
  }

  return fileMetrics;
}

/**
 * Load FTA output and return file-level metrics.
 *
 * FTA produces paths already relative to the project root (e.g., "src/types.ts").
 * No normalization needed beyond forward-slash conversion.
 *
 * Returns object mapping relative_path -> { cyclomatic, halstead_volume, line_count }
 * @param {string} ftaPath
 * @param {string} _projectName
 * @returns {object}
 */
function loadFtaOutput(ftaPath, _projectName) {
  const content = fs.readFileSync(ftaPath, 'utf8');
  const data = JSON.parse(content);

  const fileMetrics = {};
  for (const entry of data) {
    const fileName = (entry.file_name || '').replace(/\\/g, '/');
    const halstead = entry.halstead || {};
    fileMetrics[fileName] = {
      cyclomatic: entry.cyclo || 0,
      halstead_volume: halstead.volume || 0.0,
      line_count: entry.line_count || 0,
    };
  }

  return fileMetrics;
}

/**
 * Compute normalized percentage difference between two values.
 * @param {number} cgVal
 * @param {number} ftaVal
 * @returns {number}
 */
function diffPct(cgVal, ftaVal) {
  const denom = Math.max(Math.abs(cgVal), Math.abs(ftaVal), 1.0);
  return (Math.abs(cgVal - ftaVal) / denom) * 100.0;
}

/**
 * Compute Spearman rank correlation for a metric across common files.
 *
 * Returns correlation coefficient in [-1, 1].
 * @param {object} cgMetrics
 * @param {object} ftaMetrics
 * @param {string} metric
 * @param {string[]} commonFiles
 * @returns {number}
 */
function computeRankingCorrelation(cgMetrics, ftaMetrics, metric, commonFiles) {
  if (commonFiles.length < 2) return 0.0;

  const cgVals = commonFiles.map(f => cgMetrics[f][metric]);
  const ftaVals = commonFiles.map(f => ftaMetrics[f][metric]);

  function rankList(values) {
    const indexed = values.map((v, i) => [i, v]);
    indexed.sort((a, b) => a[1] - b[1]);
    const ranks = new Array(values.length).fill(0.0);
    for (let rank = 0; rank < indexed.length; rank++) {
      ranks[indexed[rank][0]] = rank + 1;
    }
    return ranks;
  }

  const cgRanks = rankList(cgVals);
  const ftaRanks = rankList(ftaVals);

  const n = commonFiles.length;
  const meanCg = cgRanks.reduce((sum, r) => sum + r, 0) / n;
  const meanFta = ftaRanks.reduce((sum, r) => sum + r, 0) / n;

  let num = 0;
  for (let i = 0; i < n; i++) {
    num += (cgRanks[i] - meanCg) * (ftaRanks[i] - meanFta);
  }

  const denomCg = Math.sqrt(cgRanks.reduce((sum, r) => sum + (r - meanCg) ** 2, 0));
  const denomFta = Math.sqrt(ftaRanks.reduce((sum, r) => sum + (r - meanFta) ** 2, 0));

  if (denomCg < 1e-10 || denomFta < 1e-10) return 0.0;

  return num / (denomCg * denomFta);
}

/**
 * Compute comparison stats for a single metric across all common files.
 * @param {object} cgMetrics
 * @param {object} ftaMetrics
 * @param {string} metric
 * @param {number} tolerance
 * @param {string[]} commonFiles
 * @returns {object}
 */
function analyzeMetric(cgMetrics, ftaMetrics, metric, tolerance, commonFiles) {
  const diffs = [];
  let withinToleranceCount = 0;

  for (const filePath of commonFiles) {
    const cgVal = Number(cgMetrics[filePath][metric] || 0);
    const ftaVal = Number(ftaMetrics[filePath][metric] || 0);
    const d = diffPct(cgVal, ftaVal);
    diffs.push(d);
    if (d <= tolerance) withinToleranceCount++;
  }

  const n = commonFiles.length;
  if (n === 0) {
    return {
      within_tolerance_pct: 0.0,
      mean_diff_pct: 0.0,
      ranking_correlation: 0.0,
    };
  }

  const meanDiff = diffs.reduce((sum, d) => sum + d, 0) / n;
  const withinPct = (withinToleranceCount / n) * 100.0;
  const correlation = computeRankingCorrelation(cgMetrics, ftaMetrics, metric, commonFiles);

  return {
    within_tolerance_pct: Math.round(withinPct * 10) / 10,
    mean_diff_pct: Math.round(meanDiff * 10) / 10,
    ranking_correlation: Math.round(correlation * 10000) / 10000,
  };
}

function main() {
  const args = process.argv.slice(2);

  if (args.length !== 3) {
    process.stderr.write('Usage: compare-metrics.mjs <cg-json> <fta-json> <project-name>\n');
    process.exit(1);
  }

  const cgPath = args[0];
  const ftaPath = args[1];
  const projectName = args[2];

  // Load outputs
  let cgMetrics = {};
  try {
    cgMetrics = loadCgOutput(cgPath, projectName);
  } catch (e) {
    process.stderr.write(`Warning: Could not load CG output from ${cgPath}: ${e.message}\n`);
  }

  let ftaMetrics = {};
  try {
    ftaMetrics = loadFtaOutput(ftaPath, projectName);
  } catch (e) {
    process.stderr.write(`Warning: Could not load FTA output from ${ftaPath}: ${e.message}\n`);
  }

  // Find common files
  const cgPaths = new Set(Object.keys(cgMetrics));
  const ftaPaths = new Set(Object.keys(ftaMetrics));
  const commonFiles = [...cgPaths].filter(f => ftaPaths.has(f)).sort();
  const cgOnly = cgPaths.size - commonFiles.length;
  const ftaOnly = ftaPaths.size - commonFiles.length;

  // Analyze each metric
  const cyclomaticStats = analyzeMetric(cgMetrics, ftaMetrics, 'cyclomatic', CYCLOMATIC_TOLERANCE, commonFiles);
  const halsteadStats = analyzeMetric(cgMetrics, ftaMetrics, 'halstead_volume', HALSTEAD_TOLERANCE, commonFiles);
  const lineCountStats = analyzeMetric(cgMetrics, ftaMetrics, 'line_count', LINE_COUNT_TOLERANCE, commonFiles);

  const result = {
    project: projectName,
    files_compared: commonFiles.length,
    files_cg_only: cgOnly,
    files_fta_only: ftaOnly,
    cyclomatic: cyclomaticStats,
    halstead_volume: halsteadStats,
    line_count: lineCountStats,
    methodology: {
      cg_aggregation: 'sum of per-function values',
      fta_granularity: 'file-level',
      cyclomatic_tolerance: CYCLOMATIC_TOLERANCE,
      halstead_tolerance: HALSTEAD_TOLERANCE,
      line_count_tolerance: LINE_COUNT_TOLERANCE,
      note:
        'FTA uses SWC parser; CG uses tree-sitter. ' +
        'Different tokenization rules cause expected divergence. ' +
        'Tolerance bands account for parser and aggregation differences.',
    },
  };

  process.stdout.write(JSON.stringify(result, null, 2) + '\n');

  // Human-readable summary to stderr
  process.stderr.write(`\n--- Metric Accuracy: ${projectName} ---\n`);
  process.stderr.write(`Files compared: ${commonFiles.length} (CG-only: ${cgOnly}, FTA-only: ${ftaOnly})\n`);
  process.stderr.write(
    `Cyclomatic:     ${cyclomaticStats.within_tolerance_pct.toFixed(1).padStart(5)}% within ${CYCLOMATIC_TOLERANCE}% tolerance, ` +
    `mean diff ${cyclomaticStats.mean_diff_pct.toFixed(1)}%, ` +
    `rank corr ${cyclomaticStats.ranking_correlation.toFixed(3)}\n`
  );
  process.stderr.write(
    `Halstead vol:   ${halsteadStats.within_tolerance_pct.toFixed(1).padStart(5)}% within ${HALSTEAD_TOLERANCE}% tolerance, ` +
    `mean diff ${halsteadStats.mean_diff_pct.toFixed(1)}%, ` +
    `rank corr ${halsteadStats.ranking_correlation.toFixed(3)}\n`
  );
  process.stderr.write(
    `Line count:     ${lineCountStats.within_tolerance_pct.toFixed(1).padStart(5)}% within ${LINE_COUNT_TOLERANCE}% tolerance, ` +
    `mean diff ${lineCountStats.mean_diff_pct.toFixed(1)}%, ` +
    `rank corr ${lineCountStats.ranking_correlation.toFixed(3)}\n`
  );
}

main();
