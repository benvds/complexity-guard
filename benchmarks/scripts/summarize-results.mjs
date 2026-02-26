#!/usr/bin/env node
/**
 * Aggregate hyperfine benchmark JSON results into summary tables.
 *
 * Usage:
 *   node summarize-results.mjs <results-dir> [--json <output-path>]
 *
 * Output:
 *   Markdown summary table to stdout.
 *   JSON summary to file if --json <path> is specified.
 *
 * Reads:
 *   *-quick.json, *-full.json, *-stress.json   hyperfine result files
 *   *-subsystems.json                           subsystem timing files (if present)
 *
 * Hyperfine JSON schema:
 *   { results: [
 *     { command, mean, stddev, memory_usage_byte: [int, ...], ... },  // CG
 *   ]}
 */

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

/**
 * Compute mean memory usage in MB from a list of bytes values.
 * @param {number[]} memoryList
 * @returns {number}
 */
function meanMemory(memoryList) {
  if (!memoryList || memoryList.length === 0) return 0.0;
  const total = memoryList.reduce((sum, v) => sum + v, 0);
  return total / memoryList.length / (1024 * 1024);
}

/**
 * Round a number to a given number of decimal places.
 * @param {number} value
 * @param {number} decimals
 * @returns {number}
 */
function round(value, decimals) {
  const factor = Math.pow(10, decimals);
  return Math.round(value * factor) / factor;
}

/**
 * Parse a single hyperfine JSON result file.
 *
 * Returns object with project, suite, cg_mean_ms, cg_stddev_ms, cg_mem_mb,
 * or null on error.
 * @param {string} filepath
 * @returns {object|null}
 */
function parseHyperfineFile(filepath) {
  const filename = path.basename(filepath);
  // Extract project and suite from filename: <project>-<suite>.json
  const nameNoExt = filename.replace(/\.json$/, '');
  const lastDash = nameNoExt.lastIndexOf('-');
  if (lastDash === -1) return null;
  const project = nameNoExt.slice(0, lastDash);
  const suite = nameNoExt.slice(lastDash + 1);

  let data;
  try {
    const content = fs.readFileSync(filepath, 'utf8');
    data = JSON.parse(content);
  } catch (e) {
    process.stderr.write(`Warning: Could not load ${filepath}: ${e.message}\n`);
    return null;
  }

  const results = data.results || [];
  if (results.length < 1) {
    return null;
  }

  const cg = results[0];

  const cgMeanMs = (cg.mean || 0.0) * 1000;
  const cgStddevMs = (cg.stddev || 0.0) * 1000;

  const cgMemList = cg.memory_usage_byte || [];
  const cgMemMb = meanMemory(cgMemList);

  return {
    project,
    suite,
    cg_mean_ms: round(cgMeanMs, 1),
    cg_stddev_ms: round(cgStddevMs, 1),
    cg_mem_mb: round(cgMemMb, 1),
  };
}

/**
 * Parse a CG analysis JSON output file.
 *
 * Extracts file count, function count, metric averages, and health score.
 * @param {string} filepath
 * @returns {object|null}
 */
function parseAnalysisFile(filepath) {
  try {
    const content = fs.readFileSync(filepath, 'utf8');
    const data = JSON.parse(content);
    const summary = data.summary || {};
    const files = data.files || [];

    // Compute average metrics across all functions
    let totalCyclomatic = 0;
    let totalCognitive = 0;
    let totalHalstead = 0;
    let funcCount = 0;

    for (const file of files) {
      for (const fn of file.functions || []) {
        totalCyclomatic += fn.cyclomatic || 0;
        totalCognitive += fn.cognitive || 0;
        totalHalstead += fn.halstead_volume || 0;
        funcCount++;
      }
    }

    const project = path.basename(filepath).replace(/-analysis\.json$/, '');

    return {
      project,
      files_analyzed: summary.files_analyzed || 0,
      total_functions: summary.total_functions || funcCount,
      warnings: summary.warnings || 0,
      errors: summary.errors || 0,
      health_score: round(summary.health_score || 0, 1),
      avg_cyclomatic: funcCount > 0 ? round(totalCyclomatic / funcCount, 1) : 0,
      avg_cognitive: funcCount > 0 ? round(totalCognitive / funcCount, 1) : 0,
      avg_halstead: funcCount > 0 ? round(totalHalstead / funcCount, 0) : 0,
    };
  } catch (e) {
    return null;
  }
}

/**
 * Parse a subsystem benchmark JSON file.
 *
 * Handles two schemas:
 *   - Array schema: { project, subsystems: [{ name, mean_ms, stddev_ms }] }
 *   - Object schema: { project, subsystems: { name: { mean_ms, ... }, ... } }
 * Normalizes to array schema before returning. Returns null on error.
 * @param {string} filepath
 * @returns {object|null}
 */
function parseSubsystemsFile(filepath) {
  try {
    const content = fs.readFileSync(filepath, 'utf8');
    const data = JSON.parse(content);
    // Normalize object-keyed subsystems to array format
    if (data.subsystems && !Array.isArray(data.subsystems) && typeof data.subsystems === 'object') {
      data.subsystems = Object.entries(data.subsystems).map(([name, stats]) => ({
        name,
        mean_ms: stats.mean_ms || 0,
        stddev_ms: stats.stddev_ms || 0,
      }));
    }
    return data;
  } catch (e) {
    process.stderr.write(`Warning: Could not load ${filepath}: ${e.message}\n`);
    return null;
  }
}

/**
 * Pad a string to a given width (left-aligned).
 * @param {string|number} value
 * @param {number} width
 * @returns {string}
 */
function padEnd(value, width) {
  return String(value).padEnd(width);
}

/**
 * Format a markdown table row for the performance table.
 * @param {object} r
 * @param {object|null} analysis
 * @returns {string}
 */
function formatSpeedRow(r, analysis) {
  const cgMsStr = `${Math.round(r.cg_mean_ms)} \u00b1 ${Math.round(r.cg_stddev_ms)}`;

  if (analysis) {
    return (
      `| ${padEnd(r.project, 20)} | ${padEnd(analysis.files_analyzed, 5)} | ${padEnd(analysis.total_functions, 5)} | ${padEnd(cgMsStr, 14)} | ${padEnd(r.cg_mem_mb.toFixed(1), 8)} | ${padEnd(analysis.avg_cyclomatic, 4)} | ${padEnd(analysis.avg_cognitive, 4)} | ${padEnd(analysis.avg_halstead, 7)} | ${padEnd(analysis.warnings, 4)} | ${padEnd(analysis.errors, 4)} | ${padEnd(analysis.health_score, 5)} |`
    );
  }

  return (
    `| ${padEnd(r.project, 20)} | ${padEnd('-', 5)} | ${padEnd('-', 5)} | ${padEnd(cgMsStr, 14)} | ${padEnd(r.cg_mem_mb.toFixed(1), 8)} | ${padEnd('-', 4)} | ${padEnd('-', 4)} | ${padEnd('-', 7)} | ${padEnd('-', 4)} | ${padEnd('-', 4)} | ${padEnd('-', 5)} |`
  );
}

/**
 * Print a markdown performance table.
 * @param {object[]} results
 * @param {string|null} suite
 * @param {Map<string, object>} analysisMap
 */
function printSpeedTable(results, suite = null, analysisMap = new Map()) {
  const filtered = suite === null ? results : results.filter(r => r.suite === suite);
  if (filtered.length === 0) return;

  const suiteLabel = suite || 'all';
  console.log(`\n### Performance (${suiteLabel} suite)\n`);
  console.log(`| ${padEnd('Project', 20)} | ${padEnd('Files', 5)} | ${padEnd('Funcs', 5)} | ${padEnd('CG (ms)', 14)} | ${padEnd('Mem (MB)', 8)} | ${padEnd('Cyc', 4)} | ${padEnd('Cog', 4)} | ${padEnd('Halsted', 7)} | ${padEnd('Warn', 4)} | ${padEnd('Err', 4)} | ${padEnd('Score', 5)} |`);
  console.log(`| ${'-'.repeat(20)} | ${'-'.repeat(5)} | ${'-'.repeat(5)} | ${'-'.repeat(14)} | ${'-'.repeat(8)} | ${'-'.repeat(4)} | ${'-'.repeat(4)} | ${'-'.repeat(7)} | ${'-'.repeat(4)} | ${'-'.repeat(4)} | ${'-'.repeat(5)} |`);

  const sorted = [...filtered].sort((a, b) => a.cg_mean_ms - b.cg_mean_ms);
  for (const r of sorted) {
    const analysis = analysisMap.get(r.project) || null;
    console.log(formatSpeedRow(r, analysis));
  }

  if (filtered.length > 1) {
    const avgMs = filtered.reduce((sum, r) => sum + r.cg_mean_ms, 0) / filtered.length;
    const withMem = filtered.filter(r => r.cg_mem_mb > 0);
    const avgMem = withMem.length > 0
      ? withMem.reduce((sum, r) => sum + r.cg_mem_mb, 0) / withMem.length
      : 0;

    // Compute analysis averages
    const withAnalysis = filtered.filter(r => analysisMap.has(r.project));
    let analysisStats = '';
    if (withAnalysis.length > 0) {
      const avgFiles = Math.round(withAnalysis.reduce((sum, r) => sum + (analysisMap.get(r.project)?.files_analyzed || 0), 0) / withAnalysis.length);
      const avgFuncs = Math.round(withAnalysis.reduce((sum, r) => sum + (analysisMap.get(r.project)?.total_functions || 0), 0) / withAnalysis.length);
      const avgScore = round(withAnalysis.reduce((sum, r) => sum + (analysisMap.get(r.project)?.health_score || 0), 0) / withAnalysis.length, 1);
      analysisStats = ` \u00a0 | \u00a0 **Mean files:** ${avgFiles} \u00a0 | \u00a0 **Mean functions:** ${avgFuncs} \u00a0 | \u00a0 **Mean health score:** ${avgScore}`;
    }
    console.log(`\n**Mean analysis time:** ${Math.round(avgMs)} ms \u00a0 | \u00a0 **Mean memory:** ${avgMem.toFixed(1)} MB${analysisStats}`);
  }
}

function main() {
  const args = process.argv.slice(2);

  if (args.length < 1) {
    process.stderr.write('Usage: summarize-results.mjs <results-dir> [--json <output-path>]\n');
    process.exit(1);
  }

  const resultsDir = args[0];
  let jsonOutputPath = null;

  // Parse --json flag
  for (let i = 1; i < args.length; i++) {
    if (args[i] === '--json' && i + 1 < args.length) {
      jsonOutputPath = args[i + 1];
      i++;
    }
  }

  if (!fs.existsSync(resultsDir) || !fs.statSync(resultsDir).isDirectory()) {
    process.stderr.write(`Error: results directory not found: ${resultsDir}\n`);
    process.exit(1);
  }

  // Discover hyperfine result files
  const allFiles = fs.readdirSync(resultsDir).map(f => path.join(resultsDir, f));
  const suiteFiles = allFiles.filter(f =>
    f.endsWith('-quick.json') || f.endsWith('-normal.json') || f.endsWith('-full.json') || f.endsWith('-stress.json')
  ).sort();

  const benchmarkResults = [];
  for (const filepath of suiteFiles) {
    const r = parseHyperfineFile(filepath);
    if (r !== null) benchmarkResults.push(r);
  }

  if (benchmarkResults.length === 0) {
    process.stderr.write('Warning: No hyperfine benchmark result files found.\n');
  }

  // Discover analysis files
  const analysisFiles = allFiles.filter(f => f.endsWith('-analysis.json')).sort();
  const analysisMap = new Map();
  for (const filepath of analysisFiles) {
    const a = parseAnalysisFile(filepath);
    if (a !== null) analysisMap.set(a.project, a);
  }

  // Discover subsystem files
  const subsystemFiles = allFiles.filter(f => f.endsWith('-subsystems.json')).sort();
  const subsystemData = [];
  for (const filepath of subsystemFiles) {
    const d = parseSubsystemsFile(filepath);
    if (d !== null) subsystemData.push(d);
  }

  // Determine which suites are present
  const suiteSet = new Set(benchmarkResults.map(r => r.suite));
  const suites = [...suiteSet].sort();

  // Load system info if present
  const systemInfoPath = path.join(resultsDir, 'system-info.json');
  let systemInfo = null;
  try {
    systemInfo = JSON.parse(fs.readFileSync(systemInfoPath, 'utf8'));
  } catch (_e) { /* system-info.json not present in older baselines */ }

  // Print markdown output
  console.log('## ComplexityGuard Benchmark Summary\n');
  console.log(`Results from: \`${resultsDir}\`\n`);

  if (systemInfo) {
    console.log('### System\n');
    console.log('| Component | Value |');
    console.log('| --------- | ----- |');
    console.log(`| CPU | ${systemInfo.cpu.model} (${systemInfo.cpu.cores} cores / ${systemInfo.cpu.threads} threads) |`);
    console.log(`| Memory | ${systemInfo.memory.total_gb} GB |`);
    console.log(`| OS | ${systemInfo.os} (kernel ${systemInfo.kernel}) |`);
    console.log(`| Architecture | ${systemInfo.arch} |`);
    console.log('');
  }

  for (const suite of suites) {
    printSpeedTable(benchmarkResults, suite, analysisMap);
  }

  if (suites.length > 1) {
    printSpeedTable(benchmarkResults, null, analysisMap);
  }

  // Subsystem breakdown
  if (subsystemData.length > 0) {
    console.log('\n### CG Subsystem Breakdown\n');
    // Collect all subsystem names across projects
    const allSubsystems = new Set();
    for (const d of subsystemData) {
      for (const s of d.subsystems || []) {
        allSubsystems.add(s.name);
      }
    }
    const subsystemNames = [...allSubsystems].sort();
    const header = '| Project | ' + subsystemNames.join(' | ') + ' |';
    const separator = '| ------- | ' + subsystemNames.map(() => '---').join(' | ') + ' |';
    console.log(header);
    console.log(separator);
    for (const d of subsystemData) {
      const subs = {};
      for (const s of d.subsystems || []) {
        subs[s.name] = s.mean_ms || 0;
      }
      const row = `| ${padEnd(d.project || '?', 20)} | ` +
        subsystemNames.map(n => `${(subs[n] || 0).toFixed(1)} ms`).join(' | ') + ' |';
      console.log(row);
    }
  }

  // Overall summary stats
  if (benchmarkResults.length > 0) {
    const avgMs = benchmarkResults.reduce((sum, r) => sum + r.cg_mean_ms, 0) / benchmarkResults.length;
    const withMem = benchmarkResults.filter(r => r.cg_mem_mb > 0);
    const avgMem = withMem.length > 0
      ? withMem.reduce((sum, r) => sum + r.cg_mem_mb, 0) / withMem.length
      : 0;
    const fastestCg = benchmarkResults.reduce((min, r) => r.cg_mean_ms < min.cg_mean_ms ? r : min);
    const slowestCg = benchmarkResults.reduce((max, r) => r.cg_mean_ms > max.cg_mean_ms ? r : max);

    console.log('\n### Overall Summary\n');
    console.log(`- Projects benchmarked: ${benchmarkResults.length}`);
    console.log(`- Mean analysis time: ${Math.round(avgMs)} ms`);
    console.log(`- Mean memory usage: ${avgMem.toFixed(1)} MB`);
    console.log(`- Fastest project: ${fastestCg.project} (${Math.round(fastestCg.cg_mean_ms)} ms)`);
    console.log(`- Slowest project: ${slowestCg.project} (${Math.round(slowestCg.cg_mean_ms)} ms)`);
  }

  // JSON output
  if (jsonOutputPath) {
    const summary = {
      results_dir: resultsDir,
      system_info: systemInfo,
      benchmark_results: benchmarkResults,
      analysis_data: Object.fromEntries(analysisMap),
      subsystem_data: subsystemData,
    };
    const dir = path.dirname(path.resolve(jsonOutputPath));
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(jsonOutputPath, JSON.stringify(summary, null, 2));
    process.stderr.write(`\n*JSON summary written to: ${jsonOutputPath}*\n`);
  }
}

main();
