const std = @import("std");
const config = @import("config.zig");
const cyclomatic_mod = @import("../metrics/cyclomatic.zig");
const scoring = @import("../metrics/scoring.zig");

const ThresholdPair = config.ThresholdPair;
const ThresholdsConfig = config.ThresholdsConfig;
const ThresholdResult = cyclomatic_mod.ThresholdResult;
const MetricThresholds = scoring.MetricThresholds;
const EffectiveWeights = scoring.EffectiveWeights;

/// Threshold presets based on strictness level.
const ThresholdPreset = struct {
    cyclomatic_warning: u32,
    cyclomatic_error: u32,
    cognitive_warning: u32,
    cognitive_error: u32,
};

/// Get threshold preset by name.
fn getThresholdPreset(name: []const u8) ThresholdPreset {
    if (std.mem.eql(u8, name, "relaxed")) {
        return ThresholdPreset{
            .cyclomatic_warning = 15,
            .cyclomatic_error = 25,
            .cognitive_warning = 20,
            .cognitive_error = 30,
        };
    } else if (std.mem.eql(u8, name, "strict")) {
        return ThresholdPreset{
            .cyclomatic_warning = 5,
            .cyclomatic_error = 10,
            .cognitive_warning = 8,
            .cognitive_error = 15,
        };
    } else {
        // Default to moderate
        return ThresholdPreset{
            .cyclomatic_warning = 10,
            .cyclomatic_error = 20,
            .cognitive_warning = 15,
            .cognitive_error = 25,
        };
    }
}

/// Run interactive configuration setup.
/// For now, generates a default config file (interactive prompts not yet implemented due to Zig 0.15.2 IO API changes).
pub fn runInit(allocator: std.mem.Allocator) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    // Welcome message
    try stdout.writeAll("ComplexityGuard Configuration Setup\n\n");
    try stdout.writeAll("Creating default configuration...\n\n");

    // Use moderate preset with default exclude patterns
    const preset = getThresholdPreset("moderate");
    const exclude_patterns = [_][]const u8{ "node_modules", "dist", "build", ".git" };
    const filename = ".complexityguard.json";

    // Generate JSON config with defaults
    try generateJsonConfig(allocator, filename, "console", preset, &exclude_patterns, null, null);

    // Success message
    try stdout.print("Created {s}\n", .{filename});
    try stdout.writeAll("(Note: Interactive prompts not yet implemented - using defaults)\n");
}

/// Run enhanced --init that analyzes codebase and optimizes weights.
/// Receives pre-computed analysis results and scores for optimization.
pub fn runEnhancedInit(
    allocator: std.mem.Allocator,
    all_results: []const []const ThresholdResult,
    default_score: f64,
    thresholds: MetricThresholds,
) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    // Count total files and functions
    var total_functions: usize = 0;
    for (all_results) |file_results| {
        total_functions += file_results.len;
    }
    const total_files = all_results.len;

    try stdout.writeAll("ComplexityGuard Configuration Setup\n\n");
    try stdout.print("Analyzed {d} files, {d} functions\n\n", .{ total_files, total_functions });

    // Optimize weights via coordinate descent
    const optimized_weights = optimizeWeights(all_results, thresholds);
    const optimized_score = computeScoreWithWeights(all_results, optimized_weights, thresholds);

    try stdout.print("Default weights score: {d:.0}\n", .{default_score});
    try stdout.print("Suggested weights score: {d:.0}\n\n", .{optimized_score});

    try stdout.writeAll("Suggested weights:\n");
    try stdout.print("  cyclomatic: {d:.2}\n", .{optimized_weights.cyclomatic});
    try stdout.print("  cognitive:  {d:.2}\n", .{optimized_weights.cognitive});
    try stdout.print("  halstead:   {d:.2}\n", .{optimized_weights.halstead});
    try stdout.print("  structural: {d:.2}\n\n", .{optimized_weights.structural});

    // Write config with optimized weights and baseline
    const preset = getThresholdPreset("moderate");
    const exclude_patterns = [_][]const u8{ "node_modules", "dist", "build", ".git" };
    const filename = ".complexityguard.json";
    const rounded_baseline = @round(optimized_score * 10.0) / 10.0;

    try generateJsonConfig(allocator, filename, "console", preset, &exclude_patterns, optimized_weights, rounded_baseline);

    try stdout.print("Created {s}\n", .{filename});
    try stdout.writeAll("(Suggested weights and baseline saved. Remove custom weights to use ideal defaults once code improves.)\n");
}

/// Compute project score with given weights over all threshold results.
/// Used for weight optimization without re-analyzing.
fn computeScoreWithWeights(
    all_results: []const []const ThresholdResult,
    weights: EffectiveWeights,
    thresholds: MetricThresholds,
) f64 {
    var total_weighted: f64 = 0.0;
    var total_functions: u32 = 0;

    for (all_results) |file_results| {
        for (file_results) |tr| {
            const breakdown = scoring.computeFunctionScore(tr, weights, thresholds);
            total_weighted += breakdown.total;
            total_functions += 1;
        }
    }

    if (total_functions == 0) return 100.0;
    return total_weighted / @as(f64, @floatFromInt(total_functions));
}

/// Optimize weights via coordinate descent to maximize project score.
/// Tries small perturbations in each weight dimension, keeps improvements.
/// Returns EffectiveWeights (normalized to sum 1.0) that maximize score.
fn optimizeWeights(
    all_results: []const []const ThresholdResult,
    thresholds: MetricThresholds,
) EffectiveWeights {
    // Start with default weights
    var w_cycl: f64 = 0.20;
    var w_cogn: f64 = 0.30;
    var w_hal: f64 = 0.15;
    var w_str: f64 = 0.15;

    const step: f64 = 0.10;
    const max_iterations: usize = 20;

    var iteration: usize = 0;
    while (iteration < max_iterations) : (iteration += 1) {
        var improved = false;

        // Try optimizing each weight dimension independently
        const dims = [_]*f64{ &w_cycl, &w_cogn, &w_hal, &w_str };
        for (dims) |dim| {
            const original = dim.*;
            var best_score = computeScoreWithWeights(all_results, normalizeWeights(w_cycl, w_cogn, w_hal, w_str), thresholds);
            var best_val = original;

            // Try +step
            const plus = @min(1.0, original + step);
            dim.* = plus;
            const score_plus = computeScoreWithWeights(all_results, normalizeWeights(w_cycl, w_cogn, w_hal, w_str), thresholds);
            if (score_plus > best_score + 0.001) {
                best_score = score_plus;
                best_val = plus;
            }
            dim.* = original;

            // Try -step
            const minus = @max(0.0, original - step);
            dim.* = minus;
            const score_minus = computeScoreWithWeights(all_results, normalizeWeights(w_cycl, w_cogn, w_hal, w_str), thresholds);
            if (score_minus > best_score + 0.001) {
                best_score = score_minus;
                best_val = minus;
            }
            dim.* = original;

            if (best_val != original) {
                dim.* = best_val;
                improved = true;
            }
        }

        // Stop if no improvement in this iteration
        if (!improved) break;
    }

    return normalizeWeights(w_cycl, w_cogn, w_hal, w_str);
}

/// Normalize four weight values to sum to 1.0.
/// Falls back to equal weights if all are zero.
fn normalizeWeights(cycl: f64, cogn: f64, hal: f64, str: f64) EffectiveWeights {
    const total = cycl + cogn + hal + str;
    if (total == 0.0) {
        return EffectiveWeights{ .cyclomatic = 0.25, .cognitive = 0.25, .halstead = 0.25, .structural = 0.25 };
    }
    return EffectiveWeights{
        .cyclomatic = cycl / total,
        .cognitive = cogn / total,
        .halstead = hal / total,
        .structural = str / total,
    };
}

/// Generate a JSON config file.
/// Optional weights and baseline allow customization for --init enhanced workflow.
fn generateJsonConfig(
    allocator: std.mem.Allocator,
    filename: []const u8,
    format: []const u8,
    preset: ThresholdPreset,
    exclude_patterns: []const []const u8,
    weights: ?EffectiveWeights,
    baseline: ?f64,
) !void {
    var content = std.ArrayList(u8).empty;
    defer content.deinit(allocator);

    const writer = content.writer(allocator);

    // Write formatted JSON
    try writer.writeAll("{\n");
    try writer.print("  \"output\": {{\n", .{});
    try writer.print("    \"format\": \"{s}\"\n", .{format});
    try writer.writeAll("  },\n");
    try writer.writeAll("  \"analysis\": {\n");
    try writer.writeAll("    \"metrics\": [\"cyclomatic\", \"cognitive\", \"halstead\", \"nesting\", \"line_count\", \"params_count\"],\n");
    try writer.writeAll("    \"thresholds\": {\n");
    try writer.print("      \"cyclomatic\": {{ \"warning\": {d}, \"error\": {d} }},\n", .{ preset.cyclomatic_warning, preset.cyclomatic_error });
    try writer.print("      \"cognitive\": {{ \"warning\": {d}, \"error\": {d} }}\n", .{ preset.cognitive_warning, preset.cognitive_error });
    try writer.writeAll("    }\n");
    try writer.writeAll("  },\n");
    try writer.writeAll("  \"files\": {\n");
    try writer.writeAll("    \"exclude\": [");

    for (exclude_patterns, 0..) |pattern, i| {
        if (i > 0) try writer.writeAll(", ");
        try writer.print("\"{s}\"", .{pattern});
    }

    try writer.writeAll("]\n");
    try writer.writeAll("  },\n");
    try writer.writeAll("  \"weights\": {\n");

    if (weights) |w| {
        try writer.print("    \"cyclomatic\": {d:.2},\n", .{w.cyclomatic});
        try writer.print("    \"cognitive\": {d:.2},\n", .{w.cognitive});
        try writer.print("    \"halstead\": {d:.2},\n", .{w.halstead});
        try writer.print("    \"structural\": {d:.2}\n", .{w.structural});
    } else {
        try writer.writeAll("    \"cognitive\": 0.30,\n");
        try writer.writeAll("    \"cyclomatic\": 0.20,\n");
        try writer.writeAll("    \"duplication\": 0.20,\n");
        try writer.writeAll("    \"halstead\": 0.15,\n");
        try writer.writeAll("    \"structural\": 0.15\n");
    }
    try writer.writeAll("  }");

    if (baseline) |b| {
        try writer.writeAll(",\n");
        try writer.print("  \"baseline\": {d:.1}\n", .{b});
    } else {
        try writer.writeAll("\n");
    }

    try writer.writeAll("}\n");

    try std.fs.cwd().writeFile(.{ .sub_path = filename, .data = content.items });
}

/// Generate a TOML config file.
fn generateTomlConfig(
    allocator: std.mem.Allocator,
    filename: []const u8,
    format: []const u8,
    preset: ThresholdPreset,
    exclude_patterns: []const []const u8,
) !void {
    var content = std.ArrayList(u8).empty;
    defer content.deinit(allocator);

    const writer = content.writer(allocator);

    // Write formatted TOML
    try writer.writeAll("# ComplexityGuard Configuration\n\n");

    try writer.writeAll("[output]\n");
    try writer.print("format = \"{s}\"\n\n", .{format});

    try writer.writeAll("[analysis]\n");
    try writer.writeAll("metrics = [\"cyclomatic\", \"cognitive\", \"halstead\", \"nesting\", \"line_count\", \"params_count\"]\n\n");

    try writer.writeAll("[analysis.thresholds.cyclomatic]\n");
    try writer.print("warning = {d}\n", .{preset.cyclomatic_warning});
    try writer.print("error = {d}\n\n", .{preset.cyclomatic_error});

    try writer.writeAll("[analysis.thresholds.cognitive]\n");
    try writer.print("warning = {d}\n", .{preset.cognitive_warning});
    try writer.print("error = {d}\n\n", .{preset.cognitive_error});

    try writer.writeAll("[files]\n");
    try writer.writeAll("exclude = [");

    for (exclude_patterns, 0..) |pattern, i| {
        if (i > 0) try writer.writeAll(", ");
        try writer.print("\"{s}\"", .{pattern});
    }

    try writer.writeAll("]\n\n");

    try writer.writeAll("[weights]\n");
    try writer.writeAll("cognitive = 0.30\n");
    try writer.writeAll("cyclomatic = 0.20\n");
    try writer.writeAll("duplication = 0.20\n");
    try writer.writeAll("halstead = 0.15\n");
    try writer.writeAll("structural = 0.15\n");

    try std.fs.cwd().writeFile(.{ .sub_path = filename, .data = content.items });
}

// TESTS

test "getThresholdPreset returns all strictness levels" {
    const relaxed = getThresholdPreset("relaxed");
    const moderate = getThresholdPreset("moderate");
    const strict = getThresholdPreset("strict");

    try std.testing.expectEqual(@as(u32, 15), relaxed.cyclomatic_warning);
    try std.testing.expectEqual(@as(u32, 10), moderate.cyclomatic_warning);
    try std.testing.expectEqual(@as(u32, 5), strict.cyclomatic_warning);
}

test "moderate preset has expected values" {
    const preset = getThresholdPreset("moderate");
    try std.testing.expectEqual(@as(u32, 10), preset.cyclomatic_warning);
    try std.testing.expectEqual(@as(u32, 20), preset.cyclomatic_error);
    try std.testing.expectEqual(@as(u32, 15), preset.cognitive_warning);
    try std.testing.expectEqual(@as(u32, 25), preset.cognitive_error);
}

test "generateJsonConfig produces valid JSON structure" {
    const allocator = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const exclude_patterns = [_][]const u8{ "node_modules", "dist", ".git" };
    const preset = getThresholdPreset("moderate");

    // Change to temp dir
    const original_cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(original_cwd);
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);
    try std.posix.chdir(tmp_path);
    defer std.posix.chdir(original_cwd) catch {};

    try generateJsonConfig(allocator, "test.json", "console", preset, &exclude_patterns, null, null);

    // Read back and verify it's valid JSON
    const content = try std.fs.cwd().readFileAlloc(allocator, "test.json", 1024 * 1024);
    defer allocator.free(content);

    try std.testing.expect(content.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"output\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"analysis\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"files\"") != null);
}

test "generateJsonConfig with weights and baseline includes them" {
    const allocator = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const exclude_patterns = [_][]const u8{"node_modules"};
    const preset = getThresholdPreset("moderate");
    const weights = EffectiveWeights{
        .cyclomatic = 0.15,
        .cognitive = 0.20,
        .halstead = 0.30,
        .structural = 0.35,
    };

    const original_cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(original_cwd);
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);
    try std.posix.chdir(tmp_path);
    defer std.posix.chdir(original_cwd) catch {};

    try generateJsonConfig(allocator, "test_weighted.json", "console", preset, &exclude_patterns, weights, 82.5);

    const content = try std.fs.cwd().readFileAlloc(allocator, "test_weighted.json", 1024 * 1024);
    defer allocator.free(content);

    try std.testing.expect(std.mem.indexOf(u8, content, "\"baseline\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "82.5") != null);
}

test "generateTomlConfig produces valid TOML structure" {
    const allocator = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const exclude_patterns = [_][]const u8{ "node_modules", "dist", ".git" };
    const preset = getThresholdPreset("moderate");

    // Change to temp dir
    const original_cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(original_cwd);
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);
    try std.posix.chdir(tmp_path);
    defer std.posix.chdir(original_cwd) catch {};

    try generateTomlConfig(allocator, "test.toml", "console", preset, &exclude_patterns);

    // Read back and verify it has TOML structure
    const content = try std.fs.cwd().readFileAlloc(allocator, "test.toml", 1024 * 1024);
    defer allocator.free(content);

    try std.testing.expect(content.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, content, "[output]") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "[analysis]") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "[files]") != null);
}

test "optimizeWeights returns normalized weights summing to 1.0" {
    // Use an empty results set - optimization should return defaults normalized
    const all_results: []const []const ThresholdResult = &[_][]const ThresholdResult{};
    const thresholds = MetricThresholds{
        .cyclomatic_warning = 10,
        .cyclomatic_error = 20,
        .cognitive_warning = 15,
        .cognitive_error = 25,
        .halstead_warning = 500,
        .halstead_error = 1000,
        .function_length_warning = 30,
        .function_length_error = 60,
        .params_count_warning = 4,
        .params_count_error = 8,
        .nesting_depth_warning = 3,
        .nesting_depth_error = 6,
    };

    const weights = optimizeWeights(all_results, thresholds);
    const total = weights.cyclomatic + weights.cognitive + weights.halstead + weights.structural;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), total, 0.001);
}

test "normalizeWeights sums to 1.0" {
    const w = normalizeWeights(0.2, 0.3, 0.15, 0.15);
    const total = w.cyclomatic + w.cognitive + w.halstead + w.structural;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), total, 0.001);
}

test "normalizeWeights all-zero returns equal weights" {
    const w = normalizeWeights(0.0, 0.0, 0.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), w.cyclomatic, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), w.cognitive, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), w.halstead, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), w.structural, 0.001);
}
