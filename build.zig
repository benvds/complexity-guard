const std = @import("std");

/// Helper function to add tree-sitter C sources to a compile step
fn addTreeSitterSources(b: *std.Build, step: *std.Build.Step.Compile) void {
    step.linkLibC();

    // Tree-sitter core library
    step.addIncludePath(b.path("vendor/tree-sitter/lib/include"));
    step.addIncludePath(b.path("vendor/tree-sitter/lib/src"));
    step.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter/lib/src/lib.c"),
        .flags = &.{ "-std=c11", "-fno-sanitize=undefined", "-D_POSIX_C_SOURCE=200809L", "-D_DEFAULT_SOURCE" },
    });

    // TypeScript parser
    step.addIncludePath(b.path("vendor/tree-sitter-typescript/typescript/src"));
    step.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter-typescript/typescript/src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    step.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter-typescript/typescript/src/scanner.c"),
        .flags = &.{"-std=c11"},
    });

    // TSX parser
    step.addIncludePath(b.path("vendor/tree-sitter-typescript/tsx/src"));
    step.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter-typescript/tsx/src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    step.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter-typescript/tsx/src/scanner.c"),
        .flags = &.{"-std=c11"},
    });

    // JavaScript parser
    step.addIncludePath(b.path("vendor/tree-sitter-javascript/src"));
    step.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter-javascript/src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    step.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter-javascript/src/scanner.c"),
        .flags = &.{"-std=c11"},
    });
}

pub fn build(b: *std.Build) void {
    // Standard options for target and optimization
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get dependencies
    const toml_dep = b.dependency("toml", .{
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

    // Add tree-sitter C sources
    addTreeSitterSources(b, exe);

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

    // Add tree-sitter C sources to tests
    addTreeSitterSources(b, unit_tests);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
