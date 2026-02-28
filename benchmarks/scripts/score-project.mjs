#!/usr/bin/env node
/**
 * Single-run scoring comparison script.
 *
 * Runs complexity-guard once on a target directory, then scores the output
 * using all 8 scoring algorithm variants and displays a comparison table.
 *
 * Useful for quickly testing score tuning on any local codebase without
 * needing the full benchmark suite (hyperfine, cloned repos, results directories).
 *
 * Usage:
 *   node benchmarks/scripts/score-project.mjs <target-dir> [--no-build]
 *   node benchmarks/scripts/score-project.mjs src/
 *   node benchmarks/scripts/score-project.mjs tests/fixtures --no-build
 */

import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

import {
  ALGORITHMS,
  scoreProject,
  scoreFile,
  collectAllFunctions,
  computeStats,
  fmtScore,
  padEnd,
  round,
} from './scoring-algorithms.mjs';

// ---------------------------------------------------------------------------
// Path resolution
// ---------------------------------------------------------------------------

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/**
 * Get the project root by running git rev-parse, falling back to two levels up
 * from this script (benchmarks/scripts/ -> project root).
 * @returns {string}
 */
function getProjectRoot() {
  try {
    return execSync('git rev-parse --show-toplevel', { encoding: 'utf8' }).trim();
  } catch {
    return path.resolve(__dirname, '..', '..');
  }
}

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

const args = process.argv.slice(2);

let targetDir = null;
let noBuild = false;

for (const arg of args) {
  if (arg === '--no-build') {
    noBuild = true;
  } else if (!arg.startsWith('--')) {
    targetDir = arg;
  }
}

if (!targetDir) {
  process.stderr.write('Usage: node score-project.mjs <target-dir> [--no-build]\n');
  process.stderr.write('\n');
  process.stderr.write('Arguments:\n');
  process.stderr.write('  <target-dir>  Directory to analyze (required)\n');
  process.stderr.write('  --no-build    Skip `cargo build --release` step\n');
  process.exit(1);
}

if (!fs.existsSync(targetDir) || !fs.statSync(targetDir).isDirectory()) {
  process.stderr.write(`Error: target directory not found: ${targetDir}\n`);
  process.exit(1);
}

// Resolve to absolute path for consistency
targetDir = path.resolve(targetDir);

// ---------------------------------------------------------------------------
// Build step
// ---------------------------------------------------------------------------

const projectRoot = getProjectRoot();
const binaryPath = path.join(projectRoot, 'target', 'release', 'complexity-guard');

if (!noBuild) {
  process.stderr.write('Building ComplexityGuard...\n');
  try {
    execSync('cargo build --release', {
      cwd: projectRoot,
      stdio: 'inherit',
    });
  } catch (e) {
    process.stderr.write(`Error: cargo build --release failed.\n`);
    process.exit(1);
  }
}

if (!fs.existsSync(binaryPath)) {
  process.stderr.write(`Error: binary not found at ${binaryPath}\n`);
  process.stderr.write('Run without --no-build to build it first.\n');
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Run complexity-guard
// ---------------------------------------------------------------------------

const cmd = `${binaryPath} --format json --fail-on none ${targetDir}`;
process.stderr.write(`Running: ${cmd}\n`);

let jsonOutput;
try {
  jsonOutput = execSync(cmd, { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 });
} catch (e) {
  // execSync throws on non-zero exit — but --fail-on none means exit 0 always
  // so this is a genuine error (parse error, missing dir, etc.)
  process.stderr.write(`Error running complexity-guard: ${e.message}\n`);
  if (e.stdout) process.stderr.write(e.stdout);
  process.exit(1);
}

let analysisData;
try {
  analysisData = JSON.parse(jsonOutput);
} catch (e) {
  process.stderr.write(`Error: could not parse complexity-guard JSON output: ${e.message}\n`);
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Collect functions and preprocess algorithms
// ---------------------------------------------------------------------------

const allFunctions = collectAllFunctions(analysisData);
const files = analysisData.files || [];
const totalFiles = files.length;
const totalFunctions = allFunctions.length;

// Preprocess for algorithms that need a first pass (percentile-based)
for (const algorithm of ALGORITHMS.values()) {
  if (algorithm.preprocess) {
    algorithm.preprocess(allFunctions);
  }
}

const algorithmNames = [...ALGORITHMS.keys()];

// ---------------------------------------------------------------------------
// Score with all algorithms
// ---------------------------------------------------------------------------

/** @type {Map<string, number>} algorithmName -> projectScore */
const projectScoreMap = new Map();

/** @type {Map<string, number[]>} algorithmName -> per-file scores */
const fileScoresByAlgo = new Map();

for (const [algoName, algorithm] of ALGORITHMS) {
  const { projectScore, fileScores } = scoreProject(analysisData, algorithm);
  projectScoreMap.set(algoName, projectScore);
  fileScoresByAlgo.set(algoName, fileScores);
}

// Original health_score from JSON output (for comparison)
const jsonHealthScore = analysisData.summary?.health_score ?? null;

// ---------------------------------------------------------------------------
// Output: Summary header
// ---------------------------------------------------------------------------

const dirBasename = path.basename(targetDir);

console.log(`## Scoring Comparison: ${dirBasename}\n`);
console.log(`Files: ${totalFiles}   Functions: ${totalFunctions}\n`);

// ---------------------------------------------------------------------------
// Output: Score comparison table (sorted by score descending)
// ---------------------------------------------------------------------------

console.log('### Algorithm Scores\n');

// Build rows: algorithm scores + json-output row for comparison
const scoreRows = algorithmNames.map(name => ({
  name,
  score: projectScoreMap.get(name),
  description: ALGORITHMS.get(name).description,
}));

if (jsonHealthScore !== null) {
  scoreRows.push({
    name: 'json-output',
    score: jsonHealthScore,
    description: 'Health score reported directly by complexity-guard JSON output',
  });
}

// Sort by score descending
scoreRows.sort((a, b) => b.score - a.score);

const COL_ALGO = 20;
const COL_SCORE = 7;
const COL_DESC = 60;

console.log(`| ${padEnd('Algorithm', COL_ALGO)} | ${padEnd('Score', COL_SCORE)} | Description |`);
console.log(`| ${'-'.repeat(COL_ALGO)} | ${'-'.repeat(COL_SCORE)} | ----------- |`);
for (const { name, score, description } of scoreRows) {
  console.log(`| ${padEnd(name, COL_ALGO)} | ${padEnd(fmtScore(score), COL_SCORE)} | ${description} |`);
}
console.log('');

// ---------------------------------------------------------------------------
// Output: Per-file breakdown
// ---------------------------------------------------------------------------

console.log('### Per-File Scores (sorted by `current` ascending, worst first)\n');

// Short algorithm names for column headers (trim to 10 chars)
const shortNames = algorithmNames.map(n => n.replace(/-/g, '-').slice(0, 10));

// Build file rows
const fileRows = files.map((file, idx) => {
  const relPath = path.relative(targetDir, file.path || '');
  const truncPath = relPath.length > 50 ? '...' + relPath.slice(relPath.length - 47) : relPath;
  const scores = {};
  for (const algoName of algorithmNames) {
    scores[algoName] = fileScoresByAlgo.get(algoName)[idx];
  }
  return { path: truncPath, scores };
});

// Sort by 'current' score ascending (worst files first)
fileRows.sort((a, b) => (a.scores['current'] ?? 100) - (b.scores['current'] ?? 100));

const FILE_COL = 50;
const SCORE_COL = 10;

// Header
const headerCells = [padEnd('File', FILE_COL), ...shortNames.map(n => padEnd(n, SCORE_COL))];
console.log(`| ${headerCells.join(' | ')} |`);
const sepCells = ['-'.repeat(FILE_COL), ...shortNames.map(() => '-'.repeat(SCORE_COL))];
console.log(`| ${sepCells.join(' | ')} |`);

const MAX_ROWS = 30;
const displayRows = fileRows.slice(0, MAX_ROWS);
for (const row of displayRows) {
  const cells = [
    padEnd(row.path, FILE_COL),
    ...algorithmNames.map(n => padEnd(fmtScore(row.scores[n] ?? 100), SCORE_COL)),
  ];
  console.log(`| ${cells.join(' | ')} |`);
}

if (fileRows.length > MAX_ROWS) {
  console.log(`\n... and ${fileRows.length - MAX_ROWS} more files`);
}
console.log('');

// ---------------------------------------------------------------------------
// Output: Distribution statistics per algorithm
// ---------------------------------------------------------------------------

console.log('### Distribution Statistics (per-file scores)\n');
console.log('Higher Spread = better differentiation between files.\n');

const STAT_COL_ALGO   = 20;
const STAT_COL_SPREAD =  7;
const STAT_COL_STDEV  =  7;
const STAT_COL_MIN    =  6;
const STAT_COL_P25    =  6;
const STAT_COL_MEDIAN =  6;
const STAT_COL_P75    =  6;
const STAT_COL_MAX    =  6;

console.log(
  `| ${padEnd('Algorithm', STAT_COL_ALGO)} ` +
  `| ${padEnd('Spread', STAT_COL_SPREAD)} ` +
  `| ${padEnd('StdDev', STAT_COL_STDEV)} ` +
  `| ${padEnd('Min', STAT_COL_MIN)} ` +
  `| ${padEnd('P25', STAT_COL_P25)} ` +
  `| ${padEnd('Median', STAT_COL_MEDIAN)} ` +
  `| ${padEnd('P75', STAT_COL_P75)} ` +
  `| ${padEnd('Max', STAT_COL_MAX)} |`
);
console.log(
  `| ${'-'.repeat(STAT_COL_ALGO)} ` +
  `| ${'-'.repeat(STAT_COL_SPREAD)} ` +
  `| ${'-'.repeat(STAT_COL_STDEV)} ` +
  `| ${'-'.repeat(STAT_COL_MIN)} ` +
  `| ${'-'.repeat(STAT_COL_P25)} ` +
  `| ${'-'.repeat(STAT_COL_MEDIAN)} ` +
  `| ${'-'.repeat(STAT_COL_P75)} ` +
  `| ${'-'.repeat(STAT_COL_MAX)} |`
);

for (const algoName of algorithmNames) {
  const scores = fileScoresByAlgo.get(algoName);
  const stats = computeStats(scores);
  console.log(
    `| ${padEnd(algoName, STAT_COL_ALGO)} ` +
    `| ${padEnd(fmtScore(stats.spread), STAT_COL_SPREAD)} ` +
    `| ${padEnd(fmtScore(stats.stdev), STAT_COL_STDEV)} ` +
    `| ${padEnd(fmtScore(stats.min), STAT_COL_MIN)} ` +
    `| ${padEnd(fmtScore(stats.p25), STAT_COL_P25)} ` +
    `| ${padEnd(fmtScore(stats.median), STAT_COL_MEDIAN)} ` +
    `| ${padEnd(fmtScore(stats.p75), STAT_COL_P75)} ` +
    `| ${padEnd(fmtScore(stats.max), STAT_COL_MAX)} |`
  );
}
console.log('');
