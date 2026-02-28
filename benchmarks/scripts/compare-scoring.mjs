#!/usr/bin/env node
/**
 * Scoring algorithm comparison tool.
 *
 * Re-scores all benchmark project analysis results using multiple configurable
 * scoring algorithms, so the user can tune health score weights and thresholds
 * to find a better distribution.
 *
 * Usage:
 *   node benchmarks/scripts/compare-scoring.mjs [results-dir]
 *   node benchmarks/scripts/compare-scoring.mjs benchmarks/results/baseline-2026-02-26
 *   node benchmarks/scripts/compare-scoring.mjs benchmarks/results/baseline-2026-02-26 --json scoring-comparison.json
 *
 * If no results-dir given, auto-detects the latest benchmarks/results/baseline-* directory.
 */

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

import {
  ALGORITHMS,
  scoreProject,
  collectAllFunctions,
  computeStats,
  round,
  fmtScore,
  padEnd,
} from './scoring-algorithms.mjs';

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

/**
 * Auto-detect the latest baseline-* directory under benchmarks/results/.
 * @returns {string|null}
 */
function detectLatestResultsDir() {
  // Try relative to cwd (typical: run from project root)
  const candidates = [
    path.join(process.cwd(), 'benchmarks', 'results'),
    path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'results'),
  ];
  for (const base of candidates) {
    if (!fs.existsSync(base)) continue;
    const entries = fs.readdirSync(base)
      .filter(e => e.startsWith('baseline-'))
      .sort()
      .reverse();
    if (entries.length > 0) {
      return path.join(base, entries[0]);
    }
  }
  return null;
}

/**
 * Load all analysis JSON files from a results directory.
 * Returns an array of { project, data } objects.
 * @param {string} resultsDir
 * @returns {Array<{ project: string, data: object }>}
 */
function loadAnalysisFiles(resultsDir) {
  const allFiles = fs.readdirSync(resultsDir)
    .filter(f => f.endsWith('-analysis.json'))
    .sort()
    .map(f => path.join(resultsDir, f));

  const results = [];
  for (const filepath of allFiles) {
    try {
      const content = fs.readFileSync(filepath, 'utf8');
      const data = JSON.parse(content);
      const project = path.basename(filepath).replace(/-analysis\.json$/, '');
      results.push({ project, data });
    } catch (e) {
      process.stderr.write(`Warning: Could not parse ${filepath}: ${e.message}\n`);
    }
  }
  return results;
}

function main() {
  const args = process.argv.slice(2);

  let resultsDir = null;
  let jsonOutputPath = null;

  // Parse arguments
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--json' && i + 1 < args.length) {
      jsonOutputPath = args[i + 1];
      i++;
    } else if (!args[i].startsWith('--')) {
      resultsDir = args[i];
    }
  }

  // Auto-detect if not provided
  if (!resultsDir) {
    resultsDir = detectLatestResultsDir();
    if (!resultsDir) {
      process.stderr.write('Error: Could not auto-detect results directory. Pass it as an argument.\n');
      process.stderr.write('Usage: node compare-scoring.mjs [results-dir] [--json output.json]\n');
      process.exit(1);
    }
    process.stderr.write(`Auto-detected results directory: ${resultsDir}\n`);
  }

  if (!fs.existsSync(resultsDir) || !fs.statSync(resultsDir).isDirectory()) {
    process.stderr.write(`Error: results directory not found: ${resultsDir}\n`);
    process.exit(1);
  }

  // Load analysis files
  const projectDataList = loadAnalysisFiles(resultsDir);
  if (projectDataList.length === 0) {
    process.stderr.write(`Error: No *-analysis.json files found in ${resultsDir}\n`);
    process.exit(1);
  }
  process.stderr.write(`Loaded ${projectDataList.length} project analysis files.\n`);

  // Preprocess for algorithms that need a first pass (percentile-based)
  const allFunctions = collectAllFunctions(projectDataList);
  for (const algorithm of ALGORITHMS.values()) {
    if (algorithm.preprocess) {
      algorithm.preprocess(allFunctions);
    }
  }

  // Compute per-project scores for each algorithm
  const algorithmNames = [...ALGORITHMS.keys()];

  /** @type {Map<string, Map<string, number>>} project -> algorithm -> score */
  const projectScores = new Map();
  /** @type {Map<string, number>} project -> original health_score from JSON */
  const originalScores = new Map();

  for (const { project, data } of projectDataList) {
    const scores = new Map();
    for (const [algoName, algorithm] of ALGORITHMS) {
      const { projectScore } = scoreProject(data, algorithm);
      scores.set(algoName, projectScore);
    }
    projectScores.set(project, scores);
    originalScores.set(project, data.summary?.health_score ?? null);
  }

  // Sort projects by 'current' algorithm score ascending
  const sortedProjects = [...projectScores.keys()].sort((a, b) => {
    return projectScores.get(a).get('current') - projectScores.get(b).get('current');
  });

  // ---------------------------------------------------------------------------
  // Output: header
  // ---------------------------------------------------------------------------
  console.log('## Scoring Algorithm Comparison\n');
  console.log(`Results from: \`${resultsDir}\``);
  console.log(`Projects: ${sortedProjects.length}   Functions: ${allFunctions.length}\n`);

  // ---------------------------------------------------------------------------
  // Output: algorithm legend
  // ---------------------------------------------------------------------------
  console.log('### Algorithms\n');
  console.log('| Algorithm | Description |');
  console.log('| --------- | ----------- |');
  for (const [name, algo] of ALGORITHMS) {
    console.log(`| \`${name}\` | ${algo.description} |`);
  }
  console.log('');

  // ---------------------------------------------------------------------------
  // Output: comparison table
  // ---------------------------------------------------------------------------
  const COL_PROJECT = 30;
  const COL_SCORE = 8;

  // Header row
  const headerCells = [padEnd('Project', COL_PROJECT), ...algorithmNames.map(n => padEnd(n, COL_SCORE))];
  console.log('### Per-Project Scores (sorted by `current` ascending)\n');
  console.log(`| ${headerCells.join(' | ')} |`);
  const sepCells = ['-'.repeat(COL_PROJECT), ...algorithmNames.map(() => '-'.repeat(COL_SCORE))];
  console.log(`| ${sepCells.join(' | ')} |`);

  for (const project of sortedProjects) {
    const scores = projectScores.get(project);
    const cells = [
      padEnd(project, COL_PROJECT),
      ...algorithmNames.map(n => padEnd(fmtScore(scores.get(n)), COL_SCORE)),
    ];
    console.log(`| ${cells.join(' | ')} |`);
  }
  console.log('');

  // ---------------------------------------------------------------------------
  // Output: distribution statistics
  // ---------------------------------------------------------------------------
  console.log('### Distribution Statistics\n');
  console.log('Higher Spread = better differentiation between projects.\n');

  const statsTable = algorithmNames.map(algoName => {
    const scores = sortedProjects.map(p => projectScores.get(p).get(algoName));
    return { algoName, stats: computeStats(scores) };
  });

  const STAT_COL_ALGO   = 20;
  const STAT_COL_SPREAD =  7;
  const STAT_COL_STDEV  =  7;
  const STAT_COL_MIN    =  6;
  const STAT_COL_P25    =  6;
  const STAT_COL_MEDIAN =  6;
  const STAT_COL_P75    =  6;
  const STAT_COL_MAX    =  6;
  const STAT_COL_GT95   =  5;
  const STAT_COL_GT90   =  5;
  const STAT_COL_GT80   =  5;
  const STAT_COL_GT70   =  5;

  console.log(
    `| ${padEnd('Algorithm', STAT_COL_ALGO)} ` +
    `| ${padEnd('Spread', STAT_COL_SPREAD)} ` +
    `| ${padEnd('StdDev', STAT_COL_STDEV)} ` +
    `| ${padEnd('Min', STAT_COL_MIN)} ` +
    `| ${padEnd('P25', STAT_COL_P25)} ` +
    `| ${padEnd('Median', STAT_COL_MEDIAN)} ` +
    `| ${padEnd('P75', STAT_COL_P75)} ` +
    `| ${padEnd('Max', STAT_COL_MAX)} ` +
    `| ${padEnd('>95', STAT_COL_GT95)} ` +
    `| ${padEnd('>90', STAT_COL_GT90)} ` +
    `| ${padEnd('>80', STAT_COL_GT80)} ` +
    `| ${padEnd('>70', STAT_COL_GT70)} |`
  );
  console.log(
    `| ${'-'.repeat(STAT_COL_ALGO)} ` +
    `| ${'-'.repeat(STAT_COL_SPREAD)} ` +
    `| ${'-'.repeat(STAT_COL_STDEV)} ` +
    `| ${'-'.repeat(STAT_COL_MIN)} ` +
    `| ${'-'.repeat(STAT_COL_P25)} ` +
    `| ${'-'.repeat(STAT_COL_MEDIAN)} ` +
    `| ${'-'.repeat(STAT_COL_P75)} ` +
    `| ${'-'.repeat(STAT_COL_MAX)} ` +
    `| ${'-'.repeat(STAT_COL_GT95)} ` +
    `| ${'-'.repeat(STAT_COL_GT90)} ` +
    `| ${'-'.repeat(STAT_COL_GT80)} ` +
    `| ${'-'.repeat(STAT_COL_GT70)} |`
  );

  for (const { algoName, stats } of statsTable) {
    console.log(
      `| ${padEnd(algoName, STAT_COL_ALGO)} ` +
      `| ${padEnd(fmtScore(stats.spread), STAT_COL_SPREAD)} ` +
      `| ${padEnd(fmtScore(stats.stdev), STAT_COL_STDEV)} ` +
      `| ${padEnd(fmtScore(stats.min), STAT_COL_MIN)} ` +
      `| ${padEnd(fmtScore(stats.p25), STAT_COL_P25)} ` +
      `| ${padEnd(fmtScore(stats.median), STAT_COL_MEDIAN)} ` +
      `| ${padEnd(fmtScore(stats.p75), STAT_COL_P75)} ` +
      `| ${padEnd(fmtScore(stats.max), STAT_COL_MAX)} ` +
      `| ${padEnd(stats.count_gt95, STAT_COL_GT95)} ` +
      `| ${padEnd(stats.count_gt90, STAT_COL_GT90)} ` +
      `| ${padEnd(stats.count_gt80, STAT_COL_GT80)} ` +
      `| ${padEnd(stats.count_gt70, STAT_COL_GT70)} |`
    );
  }
  console.log('');

  // ---------------------------------------------------------------------------
  // Output: 'current' vs original health_score validation spot-check
  // ---------------------------------------------------------------------------
  console.log('### Validation: `current` algorithm vs JSON health_score\n');
  console.log('Spot-checking that the JS replication matches the Rust output (tolerance: 0.5).\n');
  console.log('| Project | JSON health_score | current (JS) | Delta | Status |');
  console.log('| ------- | ----------------- | ------------ | ----- | ------ |');

  let allMatch = true;
  for (const project of sortedProjects) {
    const original = originalScores.get(project);
    if (original === null) continue;
    const computed = projectScores.get(project).get('current');
    const delta = Math.abs(computed - original);
    const status = delta < 0.5 ? 'OK' : 'MISMATCH';
    if (status === 'MISMATCH') allMatch = false;
    // Only show rows with noticeable deltas or first/last few
    const showRow = delta >= 0.1 || project === sortedProjects[0] || project === sortedProjects[sortedProjects.length - 1];
    if (showRow) {
      console.log(`| ${padEnd(project, 28)} | ${padEnd(fmtScore(original), 17)} | ${padEnd(fmtScore(computed), 12)} | ${padEnd(fmtScore(delta), 5) } | ${status} |`);
    }
  }
  if (allMatch) {
    console.log('\n**All projects match within 0.5 tolerance.**\n');
  } else {
    console.log('\n**WARNING: Some projects exceed 0.5 tolerance.**\n');
  }

  // ---------------------------------------------------------------------------
  // JSON output
  // ---------------------------------------------------------------------------
  if (jsonOutputPath) {
    const output = {
      results_dir: resultsDir,
      projects: sortedProjects.length,
      total_functions: allFunctions.length,
      algorithms: algorithmNames.map(name => ({
        name,
        description: ALGORITHMS.get(name).description,
        stats: computeStats(sortedProjects.map(p => projectScores.get(p).get(name))),
      })),
      per_project: sortedProjects.map(project => {
        const scores = {};
        for (const algoName of algorithmNames) {
          scores[algoName] = round(projectScores.get(project).get(algoName), 4);
        }
        return {
          project,
          original_health_score: originalScores.get(project),
          scores,
        };
      }),
    };
    const dir = path.dirname(path.resolve(jsonOutputPath));
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(jsonOutputPath, JSON.stringify(output, null, 2));
    process.stderr.write(`\nJSON output written to: ${jsonOutputPath}\n`);
  }
}

main();
