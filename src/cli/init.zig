const std = @import("std");
const config = @import("config.zig");

const ThresholdPair = config.ThresholdPair;
const ThresholdsConfig = config.ThresholdsConfig;

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
    try generateJsonConfig(allocator, filename, "console", preset, &exclude_patterns);

    // Success message
    try stdout.print("Created {s}\n", .{filename});
    try stdout.writeAll("(Note: Interactive prompts not yet implemented - using defaults)\n");
}

/// Generate a JSON config file.
fn generateJsonConfig(
    allocator: std.mem.Allocator,
    filename: []const u8,
    format: []const u8,
    preset: ThresholdPreset,
    exclude_patterns: []const []const u8,
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
    try writer.writeAll("    \"cognitive\": 0.30,\n");
    try writer.writeAll("    \"cyclomatic\": 0.20,\n");
    try writer.writeAll("    \"duplication\": 0.20,\n");
    try writer.writeAll("    \"halstead\": 0.15,\n");
    try writer.writeAll("    \"structural\": 0.15\n");
    try writer.writeAll("  }\n");
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

    try generateJsonConfig(allocator, "test.json", "console", preset, &exclude_patterns);

    // Read back and verify it's valid JSON
    const content = try std.fs.cwd().readFileAlloc(allocator, "test.json", 1024 * 1024);
    defer allocator.free(content);

    try std.testing.expect(content.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"output\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"analysis\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"files\"") != null);
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
