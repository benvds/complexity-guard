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
 *   *-subsystems.json                           Zig subsystem timing files (if present)
 *   metric-accuracy.json                        compare-metrics.mjs output (if present)
 *
 * Hyperfine JSON schema:
 *   { results: [
 *     { command, mean, stddev, memory_usage_byte: [int, ...], ... },  // CG
 *     { command, mean, stddev, memory_usage_byte: [int, ...], ... },  // FTA
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
 * Returns object with project, suite, cg_mean_ms, cg_stddev_ms, fta_mean_ms,
 * fta_stddev_ms, cg_mem_mb, fta_mem_mb, speedup, mem_ratio, or null on error.
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
  if (results.length < 2) {
    if (results.length === 1) {
      process.stderr.write(`Warning: ${filename} has only 1 result (expected 2), skipping\n`);
    }
    return null;
  }

  const cg = results[0];
  const fta = results[1];

  const cgMeanMs = (cg.mean || 0.0) * 1000;
  const cgStddevMs = (cg.stddev || 0.0) * 1000;
  const ftaMeanMs = (fta.mean || 0.0) * 1000;
  const ftaStddevMs = (fta.stddev || 0.0) * 1000;

  const cgMemList = cg.memory_usage_byte || [];
  const ftaMemList = fta.memory_usage_byte || [];
  const cgMemMb = meanMemory(cgMemList);
  const ftaMemMb = meanMemory(ftaMemList);

  // speedup > 1.0 means FTA is faster (CG takes longer relative to FTA)
  const speedup = ftaMeanMs > 0 ? cgMeanMs / ftaMeanMs : 0.0;
  const memRatio = cgMemMb > 0 ? ftaMemMb / cgMemMb : 0.0;

  return {
    project,
    suite,
    cg_mean_ms: round(cgMeanMs, 1),
    cg_stddev_ms: round(cgStddevMs, 1),
    fta_mean_ms: round(ftaMeanMs, 1),
    fta_stddev_ms: round(ftaStddevMs, 1),
    cg_mem_mb: round(cgMemMb, 1),
    fta_mem_mb: round(ftaMemMb, 1),
    speedup: round(speedup, 2),
    mem_ratio: round(memRatio, 2),
  };
}

/**
 * Parse a Zig subsystem benchmark JSON file.
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
 * Parse metric-accuracy.json produced by compare-metrics.sh.
 *
 * Expected schema: [{ project, files_compared, cyclomatic, halstead_volume, ... }]
 * Returns null on error.
 * @param {string} filepath
 * @returns {object[]|null}
 */
function parseMetricAccuracy(filepath) {
  try {
    const content = fs.readFileSync(filepath, 'utf8');
    const data = JSON.parse(content);
    return Array.isArray(data) ? data : null;
  } catch (_e) {
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
 * Format a markdown table row for the speed comparison table.
 *
 * speedup = cg_mean / fta_mean: >1.0 means FTA is faster than CG.
 * @param {object} r
 * @returns {string}
 */
function formatSpeedRow(r) {
  let speedupLabel;
  if (r.speedup > 1.0) {
    speedupLabel = `${r.speedup.toFixed(1)}x faster`;
  } else if (r.speedup < 0.99) {
    speedupLabel = `${(1 / r.speedup).toFixed(1)}x CG faster`;
  } else {
    speedupLabel = 'equal';
  }

  const cgMsStr = `${Math.round(r.cg_mean_ms)} \u00b1 ${Math.round(r.cg_stddev_ms)}`;
  const ftaMsStr = `${Math.round(r.fta_mean_ms)} \u00b1 ${Math.round(r.fta_stddev_ms)}`;

  return (
    `| ${padEnd(r.project, 20)} | ${padEnd(cgMsStr, 12)} | ${padEnd(ftaMsStr, 12)} | ` +
    `${padEnd(speedupLabel, 12)} | ${padEnd(r.cg_mem_mb.toFixed(1), 10)} | ${padEnd(r.fta_mem_mb.toFixed(1), 11)} | ` +
    `${r.mem_ratio.toFixed(1)}x      |`
  );
}

/**
 * Print a markdown speed and memory comparison table.
 * @param {object[]} results
 * @param {string|null} suite
 */
function printSpeedTable(results, suite = null) {
  const filtered = suite === null ? results : results.filter(r => r.suite === suite);
  if (filtered.length === 0) return;

  const suiteLabel = suite || 'all';
  console.log(`\n### Speed and Memory Comparison (${suiteLabel} suite)\n`);
  console.log(`| ${padEnd('Project', 20)} | ${padEnd('CG (ms)', 12)} | ${padEnd('FTA (ms)', 12)} | ${padEnd('Speedup', 12)} | ${padEnd('CG Mem (MB)', 10)} | ${padEnd('FTA Mem (MB)', 11)} | Mem Ratio |`);
  console.log(`| ${'-'.repeat(20)} | ${'-'.repeat(12)} | ${'-'.repeat(12)} | ${'-'.repeat(12)} | ${'-'.repeat(10)} | ${'-'.repeat(11)} | ${'-'.repeat(9)} |`);

  const sorted = [...filtered].sort((a, b) => a.cg_mean_ms - b.cg_mean_ms);
  for (const r of sorted) {
    console.log(formatSpeedRow(r));
  }

  if (filtered.length > 1) {
    const avgSpeedup = filtered.reduce((sum, r) => sum + r.speedup, 0) / filtered.length;
    const withMem = filtered.filter(r => r.mem_ratio > 0);
    const avgMemRatio = withMem.length > 0
      ? withMem.reduce((sum, r) => sum + r.mem_ratio, 0) / withMem.length
      : 0;
    console.log(`\n**Mean speedup:** ${avgSpeedup.toFixed(1)}x \u00a0 | \u00a0 **Mean memory ratio:** ${avgMemRatio.toFixed(1)}x`);
    console.log(`*(Speedup = CG time / FTA time; >1.0 means FTA is faster than CG)*`);
  }
}

/**
 * Print a markdown metric accuracy summary table.
 * @param {object[]} accuracyData
 */
function printMetricAccuracyTable(accuracyData) {
  if (!accuracyData || accuracyData.length === 0) return;

  console.log('\n### Metric Accuracy: CG vs FTA Agreement\n');
  console.log('| Project | Files | Cyclo Agree | Cyclo Corr | Halstead Agree | Halstead Corr |');
  console.log('| ------- | ----- | ----------- | ---------- | -------------- | ------------- |');

  for (const item of accuracyData) {
    const project = item.project || '?';
    const n = item.files_compared || 0;
    const cyclo = item.cyclomatic || {};
    const hal = item.halstead_volume || {};
    console.log(
      `| ${padEnd(project, 20)} | ${padEnd(n, 5)} | ` +
      `${(cyclo.within_tolerance_pct || 0).toFixed(0)}% (\u00b125%)  | ` +
      `${(cyclo.ranking_correlation || 0).toFixed(3)}      | ` +
      `${(hal.within_tolerance_pct || 0).toFixed(0)}% (\u00b130%)      | ` +
      `${(hal.ranking_correlation || 0).toFixed(3)}         |`
    );
  }

  if (accuracyData.length > 0) {
    const avgCyclo = accuracyData.reduce((sum, d) => sum + ((d.cyclomatic || {}).within_tolerance_pct || 0), 0) / accuracyData.length;
    const avgHal = accuracyData.reduce((sum, d) => sum + ((d.halstead_volume || {}).within_tolerance_pct || 0), 0) / accuracyData.length;
    console.log(`\n**Mean cyclomatic agreement:** ${avgCyclo.toFixed(0)}% \u00a0 | \u00a0 **Mean Halstead agreement:** ${avgHal.toFixed(0)}%`);
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
    f.endsWith('-quick.json') || f.endsWith('-full.json') || f.endsWith('-stress.json')
  ).sort();

  const benchmarkResults = [];
  for (const filepath of suiteFiles) {
    const r = parseHyperfineFile(filepath);
    if (r !== null) benchmarkResults.push(r);
  }

  if (benchmarkResults.length === 0) {
    process.stderr.write('Warning: No hyperfine benchmark result files found.\n');
  }

  // Discover subsystem files
  const subsystemFiles = allFiles.filter(f => f.endsWith('-subsystems.json')).sort();
  const subsystemData = [];
  for (const filepath of subsystemFiles) {
    const d = parseSubsystemsFile(filepath);
    if (d !== null) subsystemData.push(d);
  }

  // Load metric accuracy if present
  const accuracyPath = path.join(resultsDir, 'metric-accuracy.json');
  const accuracyData = parseMetricAccuracy(accuracyPath);

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
  console.log('## ComplexityGuard vs FTA: Benchmark Summary\n');
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
    printSpeedTable(benchmarkResults, suite);
  }

  if (suites.length > 1) {
    printSpeedTable(benchmarkResults, null);
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

  // Metric accuracy
  if (accuracyData) {
    printMetricAccuracyTable(accuracyData);
  } else {
    console.log('\n*Metric accuracy data not found. Run `compare-metrics.sh` to generate it.*');
  }

  // Overall summary stats
  if (benchmarkResults.length > 0) {
    const avgSpeedup = benchmarkResults.reduce((sum, r) => sum + r.speedup, 0) / benchmarkResults.length;
    const withMem = benchmarkResults.filter(r => r.mem_ratio > 0);
    const avgMemRatio = withMem.length > 0
      ? withMem.reduce((sum, r) => sum + r.mem_ratio, 0) / withMem.length
      : 0;
    const fastestCg = benchmarkResults.reduce((min, r) => r.cg_mean_ms < min.cg_mean_ms ? r : min);
    const slowestCg = benchmarkResults.reduce((max, r) => r.cg_mean_ms > max.cg_mean_ms ? r : max);

    console.log('\n### Overall Summary\n');
    console.log(`- Projects benchmarked: ${benchmarkResults.length}`);
    console.log(`- Mean CG/FTA speed ratio: ${avgSpeedup.toFixed(2)}x (>1.0 means FTA is faster than CG)`);
    console.log(`- Mean FTA/CG memory ratio: ${avgMemRatio.toFixed(2)}x (FTA uses more memory = >1.0)`);
    console.log(`- Fastest project: ${fastestCg.project} (${Math.round(fastestCg.cg_mean_ms)} ms CG)`);
    console.log(`- Slowest project: ${slowestCg.project} (${Math.round(slowestCg.cg_mean_ms)} ms CG)`);
  }

  // JSON output
  if (jsonOutputPath) {
    const summary = {
      results_dir: resultsDir,
      system_info: systemInfo,
      benchmark_results: benchmarkResults,
      subsystem_data: subsystemData,
      accuracy_data: accuracyData,
    };
    const dir = path.dirname(path.resolve(jsonOutputPath));
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(jsonOutputPath, JSON.stringify(summary, null, 2));
    process.stderr.write(`\n*JSON summary written to: ${jsonOutputPath}*\n`);
  }
}

main();
