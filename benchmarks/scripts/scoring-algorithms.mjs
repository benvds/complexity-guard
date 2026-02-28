#!/usr/bin/env node
/**
 * Shared scoring primitives, algorithm definitions, and statistics helpers.
 *
 * Exported by both compare-scoring.mjs (multi-project batch) and
 * score-project.mjs (single-run comparison).
 *
 * All scoring logic is an exact port of src/metrics/scoring.rs Rust defaults.
 */

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
export function linearScore(x, warning, error) {
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
export function computeFunctionScore(fn, weights, thresholds, scoreFn) {
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
export const DEFAULT_WEIGHTS = {
  cyclomatic: 0.20,
  cognitive:  0.30,
  halstead:   0.15,
  structural: 0.15,
};

/** @type {object} Default scoring thresholds (Rust defaults). */
export const DEFAULT_THRESHOLDS = {
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
export function mean(scores) {
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
export function geometricMean(scores) {
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
export function minimum(scores) {
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
export function weightedMean(fileScores, functionCounts) {
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
export function percentile(sorted, p) {
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
export const ALGORITHMS = new Map();

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
export function scoreFunctionWithAlgorithm(fn, algorithm) {
  if (algorithm.scoreFn) {
    return algorithm.scoreFn(fn, algorithm.weights, algorithm.thresholds, algorithm.linearScore);
  }
  return computeFunctionScore(fn, algorithm.weights, algorithm.thresholds, algorithm.linearScore);
}

/**
 * Score a single file's worth of functions and compute a file score.
 * @param {object[]} functions array of function metric objects
 * @param {object} algorithm  algorithm configuration
 * @returns {{ fileScore: number, functionScores: number[], functionCount: number }}
 */
export function scoreFile(functions, algorithm) {
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
export function scoreProject(analysisData, algorithm) {
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
export function computeStats(scores) {
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
// Data helpers
// ---------------------------------------------------------------------------

/**
 * Collect all function metric objects across all projects or files.
 * Used by the percentile-based algorithm's preprocess step.
 *
 * Accepts either:
 *   - Array<{ project: string, data: object }>  (batch mode: projectDataList)
 *   - A single analysis JSON object             (single-run mode: analysisData)
 *
 * @param {Array<{ project: string, data: object }>|object} input
 * @returns {object[]}
 */
export function collectAllFunctions(input) {
  const all = [];
  // Single analysis object (has .files directly)
  if (input && !Array.isArray(input) && input.files) {
    for (const file of input.files || []) {
      for (const fn of file.functions || []) {
        all.push(fn);
      }
    }
    return all;
  }
  // Array of { project, data } objects (batch mode)
  for (const { data } of input) {
    for (const file of data.files || []) {
      for (const fn of file.functions || []) {
        all.push(fn);
      }
    }
  }
  return all;
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
export function round(value, decimals) {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}

/**
 * Pad a value left-aligned to a given width.
 * @param {string|number} value
 * @param {number} width
 * @returns {string}
 */
export function padEnd(value, width) {
  return String(value).padEnd(width);
}

/**
 * Format a score to 1 decimal place as a fixed-width string.
 * @param {number} value
 * @returns {string}
 */
export function fmtScore(value) {
  return round(value, 1).toFixed(1);
}
