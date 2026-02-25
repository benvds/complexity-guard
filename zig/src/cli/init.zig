const std = @import("std");
const config = @import("config.zig");

const ThresholdPair = config.ThresholdPair;
const ThresholdsConfig = config.ThresholdsConfig;

/// Run configuration setup. Generates a complete default config file covering all options.
pub fn runInit(allocator: std.mem.Allocator) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    // Welcome message
    try stdout.writeAll("ComplexityGuard Configuration Setup\n\n");
    try stdout.writeAll("Creating default configuration...\n\n");

    const filename = ".complexityguard.json";

    // Generate JSON config with all defaults
    try generateJsonConfig(allocator, filename);

    // Success message
    try stdout.print("Created {s}\n", .{filename});
}

/// Generate a complete JSON config file covering all available options.
fn generateJsonConfig(
    allocator: std.mem.Allocator,
    filename: []const u8,
) !void {
    var content = std.ArrayList(u8).empty;
    defer content.deinit(allocator);

    const writer = content.writer(allocator);

    try writer.writeAll("{\n");
    try writer.writeAll("  \"output\": {\n");
    try writer.writeAll("    \"format\": \"console\"\n");
    try writer.writeAll("  },\n");
    try writer.writeAll("  \"analysis\": {\n");
    try writer.writeAll("    \"metrics\": [\"cyclomatic\", \"cognitive\", \"halstead\", \"nesting\", \"line_count\", \"params_count\"],\n");
    try writer.writeAll("    \"thresholds\": {\n");
    try writer.writeAll("      \"cyclomatic\": { \"warning\": 10, \"error\": 20 },\n");
    try writer.writeAll("      \"cognitive\": { \"warning\": 15, \"error\": 25 },\n");
    try writer.writeAll("      \"halstead_volume\": { \"warning\": 500, \"error\": 1000 },\n");
    try writer.writeAll("      \"halstead_difficulty\": { \"warning\": 10, \"error\": 20 },\n");
    try writer.writeAll("      \"halstead_effort\": { \"warning\": 5000, \"error\": 10000 },\n");
    try writer.writeAll("      \"halstead_bugs\": { \"warning\": 1, \"error\": 2 },\n");
    try writer.writeAll("      \"nesting_depth\": { \"warning\": 3, \"error\": 5 },\n");
    try writer.writeAll("      \"line_count\": { \"warning\": 25, \"error\": 50 },\n");
    try writer.writeAll("      \"params_count\": { \"warning\": 3, \"error\": 6 },\n");
    try writer.writeAll("      \"file_length\": { \"warning\": 300, \"error\": 600 },\n");
    try writer.writeAll("      \"export_count\": { \"warning\": 15, \"error\": 30 },\n");
    try writer.writeAll("      \"duplication\": {\n");
    try writer.writeAll("        \"file_warning\": 15.0,\n");
    try writer.writeAll("        \"file_error\": 25.0,\n");
    try writer.writeAll("        \"project_warning\": 5.0,\n");
    try writer.writeAll("        \"project_error\": 10.0\n");
    try writer.writeAll("      }\n");
    try writer.writeAll("    }\n");
    try writer.writeAll("  },\n");
    try writer.writeAll("  \"files\": {\n");
    try writer.writeAll("    \"include\": [\"**/*.ts\", \"**/*.tsx\", \"**/*.js\", \"**/*.jsx\"],\n");
    try writer.writeAll("    \"exclude\": [\"node_modules\", \"dist\", \"build\", \".git\"]\n");
    try writer.writeAll("  },\n");
    try writer.writeAll("  \"weights\": {\n");
    try writer.writeAll("    \"cognitive\": 0.30,\n");
    try writer.writeAll("    \"cyclomatic\": 0.20,\n");
    try writer.writeAll("    \"duplication\": 0.20,\n");
    try writer.writeAll("    \"halstead\": 0.15,\n");
    try writer.writeAll("    \"structural\": 0.15\n");
    try writer.writeAll("  },\n");
    try writer.writeAll("  \"baseline\": null\n");
    try writer.writeAll("}\n");

    try std.fs.cwd().writeFile(.{ .sub_path = filename, .data = content.items });
}

/// Generate a complete TOML config file covering all available options.
fn generateTomlConfig(
    allocator: std.mem.Allocator,
    filename: []const u8,
) !void {
    var content = std.ArrayList(u8).empty;
    defer content.deinit(allocator);

    const writer = content.writer(allocator);

    try writer.writeAll("# ComplexityGuard Configuration\n\n");

    try writer.writeAll("[output]\n");
    try writer.writeAll("format = \"console\"\n\n");

    try writer.writeAll("[analysis]\n");
    try writer.writeAll("metrics = [\"cyclomatic\", \"cognitive\", \"halstead\", \"nesting\", \"line_count\", \"params_count\"]\n\n");

    try writer.writeAll("[analysis.thresholds.cyclomatic]\n");
    try writer.writeAll("warning = 10\n");
    try writer.writeAll("error = 20\n\n");

    try writer.writeAll("[analysis.thresholds.cognitive]\n");
    try writer.writeAll("warning = 15\n");
    try writer.writeAll("error = 25\n\n");

    try writer.writeAll("[analysis.thresholds.halstead_volume]\n");
    try writer.writeAll("warning = 500\n");
    try writer.writeAll("error = 1000\n\n");

    try writer.writeAll("[analysis.thresholds.halstead_difficulty]\n");
    try writer.writeAll("warning = 10\n");
    try writer.writeAll("error = 20\n\n");

    try writer.writeAll("[analysis.thresholds.halstead_effort]\n");
    try writer.writeAll("warning = 5000\n");
    try writer.writeAll("error = 10000\n\n");

    try writer.writeAll("[analysis.thresholds.halstead_bugs]\n");
    try writer.writeAll("warning = 1\n");
    try writer.writeAll("error = 2\n\n");

    try writer.writeAll("[analysis.thresholds.nesting_depth]\n");
    try writer.writeAll("warning = 3\n");
    try writer.writeAll("error = 5\n\n");

    try writer.writeAll("[analysis.thresholds.line_count]\n");
    try writer.writeAll("warning = 25\n");
    try writer.writeAll("error = 50\n\n");

    try writer.writeAll("[analysis.thresholds.params_count]\n");
    try writer.writeAll("warning = 3\n");
    try writer.writeAll("error = 6\n\n");

    try writer.writeAll("[analysis.thresholds.file_length]\n");
    try writer.writeAll("warning = 300\n");
    try writer.writeAll("error = 600\n\n");

    try writer.writeAll("[analysis.thresholds.export_count]\n");
    try writer.writeAll("warning = 15\n");
    try writer.writeAll("error = 30\n\n");

    try writer.writeAll("[analysis.thresholds.duplication]\n");
    try writer.writeAll("file_warning = 15.0\n");
    try writer.writeAll("file_error = 25.0\n");
    try writer.writeAll("project_warning = 5.0\n");
    try writer.writeAll("project_error = 10.0\n\n");

    try writer.writeAll("[files]\n");
    try writer.writeAll("include = [\"**/*.ts\", \"**/*.tsx\", \"**/*.js\", \"**/*.jsx\"]\n");
    try writer.writeAll("exclude = [\"node_modules\", \"dist\", \"build\", \".git\"]\n\n");

    try writer.writeAll("[weights]\n");
    try writer.writeAll("cognitive = 0.30\n");
    try writer.writeAll("cyclomatic = 0.20\n");
    try writer.writeAll("duplication = 0.20\n");
    try writer.writeAll("halstead = 0.15\n");
    try writer.writeAll("structural = 0.15\n\n");

    try writer.writeAll("# baseline = 75.0\n");

    try std.fs.cwd().writeFile(.{ .sub_path = filename, .data = content.items });
}

// TESTS

test "generateJsonConfig produces valid JSON structure" {
    const allocator = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Change to temp dir
    const original_cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(original_cwd);
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);
    try std.posix.chdir(tmp_path);
    defer std.posix.chdir(original_cwd) catch {};

    try generateJsonConfig(allocator, "test.json");

    // Read back and verify it has all expected content
    const content = try std.fs.cwd().readFileAlloc(allocator, "test.json", 1024 * 1024);
    defer allocator.free(content);

    try std.testing.expect(content.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"output\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"analysis\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"files\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"halstead_volume\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"nesting_depth\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"file_length\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"duplication\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"include\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"baseline\"") != null);
}

test "generateTomlConfig produces valid TOML structure" {
    const allocator = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Change to temp dir
    const original_cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(original_cwd);
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);
    try std.posix.chdir(tmp_path);
    defer std.posix.chdir(original_cwd) catch {};

    try generateTomlConfig(allocator, "test.toml");

    // Read back and verify it has TOML structure
    const content = try std.fs.cwd().readFileAlloc(allocator, "test.toml", 1024 * 1024);
    defer allocator.free(content);

    try std.testing.expect(content.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, content, "[output]") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "[analysis]") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "[files]") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "halstead_volume") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "nesting_depth") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "file_length") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "duplication") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "include") != null);
}
