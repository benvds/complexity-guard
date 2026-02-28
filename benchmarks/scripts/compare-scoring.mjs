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

// ---------------------------------------------------------------------------
// Scoring primitives -- exact port of src/metrics/scoring.rs
// ---------------------------------------------------------------------------

/**
 * Piecewise linear score: maps a metric value to 0-100 using warning/error thresholds.
 *
 * - score(0)        = 100
 * - score(warning)  = 80
 * - score(error)    = 60
 * - score(2*error)  = 0
 *
 * @param {number} x       metric value
 * @param {number} warning warning threshold
 * @param {number} error   error threshold
 * @returns {number} score in [0, 100]
 */
function linearScore(x, warning, error) {
  if (x <= 0) return 100;
  if (warning <= 0 || error <= 0 || error <= warning) return 0;
  if (x <= warning) {
    return 100 - 20 * (x / warning);
  } else if (x <= error) {
    return 80 - 20 * ((x - warning) / (error - warning));
  } else {
    return Math.max(0, 60 - 60 * ((x - error) / error));
  }
}

/**
 * Compute a composite function health score from individual metrics using
 * a given linear-score function, weights, and thresholds.
 *
 * @param {object} fn        function metrics { cyclomatic, cognitive, halstead_volume, line_count, params_count, nesting_depth }
 * @param {object} weights   { cyclomatic, cognitive, halstead, structural }
 * @param {object} thresholds threshold object (see DEFAULT_THRESHOLDS)
 * @param {function} scoreFn (x, warn, err) => score -- the per-metric normalization function
 * @returns {number} score in [0, 100]
 */
function computeFunctionScore(fn, weights, thresholds, scoreFn) {
  const cyclScore = scoreFn(fn.cyclomatic, thresholds.cyclomatic_warning, thresholds.cyclomatic_error);
  const cognScore = scoreFn(fn.cognitive, thresholds.cognitive_warning, thresholds.cognitive_error);
  const halScore  = scoreFn(fn.halstead_volume, thresholds.halstead_warning, thresholds.halstead_error);

  const lenScore  = scoreFn(fn.line_count, thresholds.function_length_warning, thresholds.function_length_error);
  const parScore  = scoreFn(fn.params_count, thresholds.params_count_warning, thresholds.params_count_error);
  const nestScore = scoreFn(fn.nesting_depth, thresholds.nesting_depth_warning, thresholds.nesting_depth_error);
  const strScore  = (lenScore + parScore + nestScore) / 3;

  const wCycl = weights.cyclomatic;
  const wCogn = weights.cognitive;
  const wHal  = weights.halstead;
  const wStr  = weights.structural;
  const totalWeight = wCycl + wCogn + wHal + wStr;

  if (totalWeight === 0) {
    return (cyclScore + cognScore + halScore + strScore) / 4;
  }
  return (cyclScore * wCycl + cognScore * wCogn + halScore * wHal + strScore * wStr) / totalWeight;
}

// ---------------------------------------------------------------------------
// Default weights and thresholds -- mirrors src/types.rs ScoringWeights/ScoringThresholds defaults
// ---------------------------------------------------------------------------

/** @type {object} Default scoring weights (Rust defaults). */
const DEFAULT_WEIGHTS = {
  cyclomatic: 0.20,
  cognitive:  0.30,
  halstead:   0.15,
  structural: 0.15,
};

/** @type {object} Default scoring thresholds (Rust defaults). */
const DEFAULT_THRESHOLDS = {
  cyclomatic_warning:       10.0,
  cyclomatic_error:         20.0,
  cognitive_warning:        15.0,
  cognitive_error:          25.0,
  halstead_warning:        500.0,
  halstead_error:         1000.0,
  function_length_warning:  25.0,
  function_length_error:    50.0,
  params_count_warning:      3.0,
  params_count_error:        6.0,
  nesting_depth_warning:     3.0,
  nesting_depth_error:       5.0,
};

// ---------------------------------------------------------------------------
// Aggregation helpers
// ---------------------------------------------------------------------------

/**
 * Arithmetic mean of an array of numbers.
 * Returns 100 for empty arrays (no functions/files = perfect score).
 * @param {number[]} scores
 * @returns {number}
 */
function mean(scores) {
  if (scores.length === 0) return 100;
  return scores.reduce((s, v) => s + v, 0) / scores.length;
}

/**
 * Geometric mean of an array of scores in [0, 100].
 * Returns 100 for empty arrays.
 * A single zero pulls the result to 0.
 * @param {number[]} scores
 * @returns {number}
 */
function geometricMean(scores) {
  if (scores.length === 0) return 100;
  // Work in log space to avoid underflow; add small epsilon to avoid log(0)
  const EPS = 1e-9;
  const logSum = scores.reduce((s, v) => s + Math.log(Math.max(v, EPS)), 0);
  return Math.exp(logSum / scores.length);
}

/**
 * Minimum of an array. Returns 100 for empty arrays.
 * @param {number[]} scores
 * @returns {number}
 */
function minimum(scores) {
  if (scores.length === 0) return 100;
  return Math.min(...scores);
}

/**
 * Weighted mean of file scores using function counts as weights.
 * Returns 100 when total function count is zero.
 * @param {number[]} fileScores
 * @param {number[]} functionCounts
 * @returns {number}
 */
function weightedMean(fileScores, functionCounts) {
  const total = functionCounts.reduce((s, c) => s + c, 0);
  if (total === 0) return 100;
  const weightedSum = fileScores.reduce((s, score, i) => s + score * functionCounts[i], 0);
  return weightedSum / total;
}

/**
 * Percentile value from a sorted array (0-indexed percentile in [0, 1]).
 * @param {number[]} sorted ascending sorted array
 * @param {number} p percentile in [0, 1]
 * @returns {number}
 */
function percentile(sorted, p) {
  if (sorted.length === 0) return 100;
  const idx = p * (sorted.length - 1);
  const lo = Math.floor(idx);
  const hi = Math.ceil(idx);
  if (lo === hi) return sorted[lo];
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (idx - lo);
}

// ---------------------------------------------------------------------------
// Algorithm definitions
//
// Each algorithm is an object with:
//   name            : string  - short identifier
//   description     : string  - one-line explanation
//   linearScore     : (x, warn, err) => number  - per-metric normalization
//   weights         : object  - { cyclomatic, cognitive, halstead, structural }
//   thresholds      : object  - { cyclomatic_warning, cyclomatic_error, ... }
//   functionAggregate: (functionScores) => number  - file score from function scores
//   projectAggregate : (fileScores, functionCounts) => number  - project score from file scores
//   preprocess?     : (allFunctions) => void  - optional first pass over all functions (for percentile-based)
// ---------------------------------------------------------------------------

/** @type {Map<string, object>} */
const ALGORITHMS = new Map();

// --- 1. current: exact replication of Rust defaults ---
ALGORITHMS.set('current', {
  name: 'current',
  description: 'Exact replication of Rust defaults (baseline)',
  linearScore: linearScore,
  weights: { ...DEFAULT_WEIGHTS },
  thresholds: { ...DEFAULT_THRESHOLDS },
  functionAggregate: mean,
  projectAggregate: weightedMean,
});

// --- 2. harsh-thresholds: halve all warning/error thresholds ---
ALGORITHMS.set('harsh-thresholds', {
  name: 'harsh-thresholds',
  description: 'Halve all warning/error thresholds (flags moderate code as problematic)',
  linearScore: linearScore,
  weights: { ...DEFAULT_WEIGHTS },
  thresholds: {
    cyclomatic_warning:      5.0,
    cyclomatic_error:       10.0,
    cognitive_warning:       8.0,
    cognitive_error:        13.0,
    halstead_warning:      250.0,
    halstead_error:        500.0,
    function_length_warning: 12.0,
    function_length_error:   25.0,
    params_count_warning:     2.0,
    params_count_error:       4.0,
    nesting_depth_warning:    2.0,
    nesting_depth_error:      3.0,
  },
  functionAggregate: mean,
  projectAggregate: weightedMean,
});

// --- 3. steep-penalty: same thresholds but steeper linear_score curve ---
ALGORITHMS.set('steep-penalty', {
  name: 'steep-penalty',
  description: 'Halved thresholds + steep penalty curve: score(warn)=60, score(err)=20',
  /**
   * Steeper piecewise linear: score(warn)=60, score(err)=20, score(2*err)=0.
   * @param {number} x
   * @param {number} warning
   * @param {number} error
   * @returns {number}
   */
  linearScore(x, warning, error) {
    if (x <= 0) return 100;
    if (warning <= 0 || error <= 0 || error <= warning) return 0;
    if (x <= warning) {
      return 100 - 40 * (x / warning);
    } else if (x <= error) {
      return 60 - 40 * ((x - warning) / (error - warning));
    } else {
      return Math.max(0, 20 - 20 * ((x - error) / error));
    }
  },
  weights: { ...DEFAULT_WEIGHTS },
  thresholds: {
    cyclomatic_warning:      5.0,
    cyclomatic_error:       10.0,
    cognitive_warning:       8.0,
    cognitive_error:        13.0,
    halstead_warning:      250.0,
    halstead_error:        500.0,
    function_length_warning: 12.0,
    function_length_error:   25.0,
    params_count_warning:     2.0,
    params_count_error:       4.0,
    nesting_depth_warning:    2.0,
    nesting_depth_error:      3.0,
  },
  functionAggregate: mean,
  projectAggregate: weightedMean,
});

// --- 4. cognitive-heavy: cognitive weight=0.50 ---
ALGORITHMS.set('cognitive-heavy', {
  name: 'cognitive-heavy',
  description: 'cognitive weight=0.50, other weights reduced proportionally',
  linearScore: linearScore,
  weights: {
    cyclomatic: 0.20,
    cognitive:  0.50,
    halstead:   0.15,
    structural: 0.15,
  },
  thresholds: { ...DEFAULT_THRESHOLDS },
  functionAggregate: mean,
  projectAggregate: weightedMean,
});

// --- 5. geometric-mean: geometric mean of metric sub-scores ---
ALGORITHMS.set('geometric-mean', {
  name: 'geometric-mean',
  description: 'Geometric mean of per-metric scores (one bad metric drags the whole score down)',
  linearScore: linearScore,
  weights: { ...DEFAULT_WEIGHTS },
  thresholds: { ...DEFAULT_THRESHOLDS },
  /**
   * Compute function score using geometric mean of 4 metric sub-scores.
   * Overrides the standard computeFunctionScore behaviour.
   * @param {object} fn
   * @param {object} weights
   * @param {object} thresholds
   * @param {function} scoreFn
   * @returns {number}
   */
  scoreFn(fn, weights, thresholds, scoreFn) {
    const cyclScore = scoreFn(fn.cyclomatic, thresholds.cyclomatic_warning, thresholds.cyclomatic_error);
    const cognScore = scoreFn(fn.cognitive, thresholds.cognitive_warning, thresholds.cognitive_error);
    const halScore  = scoreFn(fn.halstead_volume, thresholds.halstead_warning, thresholds.halstead_error);

    const lenScore  = scoreFn(fn.line_count, thresholds.function_length_warning, thresholds.function_length_error);
    const parScore  = scoreFn(fn.params_count, thresholds.params_count_warning, thresholds.params_count_error);
    const nestScore = scoreFn(fn.nesting_depth, thresholds.nesting_depth_warning, thresholds.nesting_depth_error);
    const strScore  = (lenScore + parScore + nestScore) / 3;

    return geometricMean([cyclScore, cognScore, halScore, strScore]);
  },
  functionAggregate: mean,
  projectAggregate: weightedMean,
});

// --- 6. worst-metric: file score = min function score; project score = p25 ---
ALGORITHMS.set('worst-metric', {
  name: 'worst-metric',
  description: 'File score=min function score; project score=p25 of file scores',
  linearScore: linearScore,
  weights: { ...DEFAULT_WEIGHTS },
  thresholds: { ...DEFAULT_THRESHOLDS },
  functionAggregate: minimum,
  /**
   * Project score = p25 of all file scores (ignores function counts).
   * @param {number[]} fileScores
   * @param {number[]} _functionCounts
   * @returns {number}
   */
  projectAggregate(fileScores, _functionCounts) {
    if (fileScores.length === 0) return 100;
    const sorted = [...fileScores].sort((a, b) => a - b);
    return percentile(sorted, 0.25);
  },
});

// --- 7. percentile-based: score functions relative to the whole dataset ---
ALGORITHMS.set('percentile-based', {
  name: 'percentile-based',
  description: 'Score functions by percentile rank in dataset (relative, not absolute thresholds)',
  linearScore: linearScore,
  weights: { ...DEFAULT_WEIGHTS },
  thresholds: { ...DEFAULT_THRESHOLDS },
  functionAggregate: mean,
  projectAggregate: weightedMean,

  // State populated during preprocess()
  _cycloValues: [],
  _cognValues: [],
  _halValues: [],
  _lenValues: [],
  _parValues: [],
  _nestValues: [],

  /**
   * First pass: collect all function metric values across the entire dataset.
   * @param {object[]} allFunctions array of function metric objects
   */
  preprocess(allFunctions) {
    this._cycloValues = allFunctions.map(f => f.cyclomatic).sort((a, b) => a - b);
    this._cognValues  = allFunctions.map(f => f.cognitive).sort((a, b) => a - b);
    this._halValues   = allFunctions.map(f => f.halstead_volume).sort((a, b) => a - b);
    this._lenValues   = allFunctions.map(f => f.line_count).sort((a, b) => a - b);
    this._parValues   = allFunctions.map(f => f.params_count).sort((a, b) => a - b);
    this._nestValues  = allFunctions.map(f => f.nesting_depth).sort((a, b) => a - b);
  },

  /**
   * Compute percentile rank of value in a sorted array.
   * Lower value = better percentile rank = higher score.
   * @param {number} value
   * @param {number[]} sorted ascending sorted array
   * @returns {number} score in [0, 100]
   */
  _percentileScore(value, sorted) {
    if (sorted.length === 0) return 100;
    let lo = 0;
    let hi = sorted.length;
    while (lo < hi) {
      const mid = (lo + hi) >>> 1;
      if (sorted[mid] <= value) lo = mid + 1;
      else hi = mid;
    }
    // lo = number of elements <= value
    // rank = fraction of elements that are <= value (0 = best, 1 = worst)
    const rank = lo / sorted.length;
    // Invert: high rank (complex function) => low score
    return (1 - rank) * 100;
  },

  /**
   * Override per-function scoring to use percentile ranks.
   * @param {object} fn
   * @param {object} _weights
   * @param {object} _thresholds
   * @param {function} _scoreFn
   * @returns {number}
   */
  scoreFn(fn, _weights, _thresholds, _scoreFn) {
    const cyclScore = this._percentileScore(fn.cyclomatic, this._cycloValues);
    const cognScore = this._percentileScore(fn.cognitive, this._cognValues);
    const halScore  = this._percentileScore(fn.halstead_volume, this._halValues);
    const lenScore  = this._percentileScore(fn.line_count, this._lenValues);
    const parScore  = this._percentileScore(fn.params_count, this._parValues);
    const nestScore = this._percentileScore(fn.nesting_depth, this._nestValues);
    const strScore  = (lenScore + parScore + nestScore) / 3;

    // Use default weights for final combination
    const w = DEFAULT_WEIGHTS;
    const totalWeight = w.cyclomatic + w.cognitive + w.halstead + w.structural;
    return (cyclScore * w.cyclomatic + cognScore * w.cognitive + halScore * w.halstead + strScore * w.structural) / totalWeight;
  },
});

// --- 8. log-penalty: logarithmic penalty curve ---
ALGORITHMS.set('log-penalty', {
  name: 'log-penalty',
  description: 'Logarithmic penalty: 100 * (1 - log(1+x) / log(1+2*error))',
  /**
   * Logarithmic penalty curve using the error threshold as the scale reference.
   * @param {number} x
   * @param {number} _warning unused (log curve has no piecewise segments)
   * @param {number} error
   * @returns {number}
   */
  linearScore(x, _warning, error) {
    if (x <= 0) return 100;
    if (error <= 0) return 0;
    const denominator = Math.log(1 + 2 * error);
    if (denominator === 0) return 0;
    return Math.max(0, 100 * (1 - Math.log(1 + x) / denominator));
  },
  weights: { ...DEFAULT_WEIGHTS },
  thresholds: { ...DEFAULT_THRESHOLDS },
  functionAggregate: mean,
  projectAggregate: weightedMean,
});

// ---------------------------------------------------------------------------
// Scoring engine
// ---------------------------------------------------------------------------

/**
 * Score a single function using a given algorithm.
 * Delegates to algorithm.scoreFn if present, otherwise uses computeFunctionScore.
 * @param {object} fn        function metric object from analysis JSON
 * @param {object} algorithm algorithm configuration
 * @returns {number} score in [0, 100]
 */
function scoreFunctionWithAlgorithm(fn, algorithm) {
  if (algorithm.scoreFn) {
    return algorithm.scoreFn(fn, algorithm.weights, algorithm.thresholds, algorithm.linearScore);
  }
  return computeFunctionScore(fn, algorithm.weights, algorithm.thresholds, algorithm.linearScore);
}

/**
 * Score a single analysis JSON file's worth of functions and compute a file score.
 * @param {object[]} functions array of function metric objects
 * @param {object} algorithm  algorithm configuration
 * @returns {{ fileScore: number, functionScores: number[], functionCount: number }}
 */
function scoreFile(functions, algorithm) {
  if (!functions || functions.length === 0) {
    return { fileScore: 100, functionScores: [], functionCount: 0 };
  }
  const functionScores = functions.map(fn => scoreFunctionWithAlgorithm(fn, algorithm));
  const fileScore = algorithm.functionAggregate(functionScores);
  return { fileScore, functionScores, functionCount: functions.length };
}

/**
 * Score an entire project (all files) and compute a project score.
 * @param {object} analysisData parsed analysis JSON object
 * @param {object} algorithm    algorithm configuration
 * @returns {{ projectScore: number, fileScores: number[], totalFunctions: number }}
 */
function scoreProject(analysisData, algorithm) {
  const files = analysisData.files || [];
  const fileScores = [];
  const functionCounts = [];

  for (const file of files) {
    const { fileScore, functionCount } = scoreFile(file.functions, algorithm);
    fileScores.push(fileScore);
    functionCounts.push(functionCount);
  }

  const projectScore = algorithm.projectAggregate(fileScores, functionCounts);
  const totalFunctions = functionCounts.reduce((s, c) => s + c, 0);

  return { projectScore, fileScores, totalFunctions };
}

// ---------------------------------------------------------------------------
// Statistics helpers
// ---------------------------------------------------------------------------

/**
 * Compute distribution statistics for an array of scores.
 * @param {number[]} scores
 * @returns {{ min, max, mean, median, p25, p75, stdev, spread, count_gt95, count_gt90, count_gt80, count_gt70 }}
 */
function computeStats(scores) {
  if (scores.length === 0) {
    return { min: 0, max: 0, mean: 0, median: 0, p25: 0, p75: 0, stdev: 0, spread: 0,
      count_gt95: 0, count_gt90: 0, count_gt80: 0, count_gt70: 0 };
  }
  const sorted = [...scores].sort((a, b) => a - b);
  const n = sorted.length;
  const meanVal = scores.reduce((s, v) => s + v, 0) / n;
  const variance = scores.reduce((s, v) => s + (v - meanVal) ** 2, 0) / n;
  const stdev = Math.sqrt(variance);

  return {
    min: sorted[0],
    max: sorted[n - 1],
    mean: meanVal,
    median: percentile(sorted, 0.5),
    p25: percentile(sorted, 0.25),
    p75: percentile(sorted, 0.75),
    stdev,
    spread: sorted[n - 1] - sorted[0],
    count_gt95: scores.filter(s => s > 95).length,
    count_gt90: scores.filter(s => s > 90).length,
    count_gt80: scores.filter(s => s > 80).length,
    count_gt70: scores.filter(s => s > 70).length,
  };
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

/**
 * Round a number to a given number of decimal places.
 * @param {number} value
 * @param {number} decimals
 * @returns {number}
 */
function round(value, decimals) {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}

/**
 * Pad a value left-aligned to a given width.
 * @param {string|number} value
 * @param {number} width
 * @returns {string}
 */
function padEnd(value, width) {
  return String(value).padEnd(width);
}

/**
 * Format a score to 1 decimal place as a fixed-width string.
 * @param {number} value
 * @returns {string}
 */
function fmtScore(value) {
  return round(value, 1).toFixed(1);
}

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

/**
 * Collect all function metric objects across all projects.
 * Used by the percentile-based algorithm's preprocess step.
 * @param {Array<{ project: string, data: object }>} projectDataList
 * @returns {object[]}
 */
function collectAllFunctions(projectDataList) {
  const all = [];
  for (const { data } of projectDataList) {
    for (const file of data.files || []) {
      for (const fn of file.functions || []) {
        all.push(fn);
      }
    }
  }
  return all;
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
