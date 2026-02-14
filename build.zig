const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard options for target and optimization
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get dependencies
    const toml_dep = b.dependency("toml", .{
        .target = target,
        .optimize = optimize,
    });
    const known_folders_dep = b.dependency("known_folders", .{
        .target = target,
        .optimize = optimize,
    });

    // Define executable
    const exe = b.addExecutable(.{
        .name = "complexity-guard",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add dependencies to executable
    exe.root_module.addImport("toml", toml_dep.module("toml"));
    exe.root_module.addImport("known-folders", known_folders_dep.module("known-folders"));

    // Install artifact
    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Pass args through (enables `zig build run -- --help`)
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    // Test step
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
        }),
    });

    // Add dependencies to test module
    unit_tests.root_module.addImport("toml", toml_dep.module("toml"));
    unit_tests.root_module.addImport("known-folders", known_folders_dep.module("known-folders"));

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
