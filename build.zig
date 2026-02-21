const std = @import("std");

/// Helper function to add tree-sitter C sources to a compile step
fn addTreeSitterSources(b: *std.Build, step: *std.Build.Step.Compile) void {
    step.linkLibC();

    // Tree-sitter core library
    step.addIncludePath(b.path("vendor/tree-sitter/lib/include"));
    step.addIncludePath(b.path("vendor/tree-sitter/lib/src"));
    step.addIncludePath(b.path("vendor/tree-sitter/lib/src/unicode"));
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

    // Bench step: Zig subsystem benchmark profiling each pipeline stage independently.
    //
    // All src/ files use relative @import paths and share a single interconnected
    // dependency graph. They're exposed to benchmark.zig via a single "cg" named module
    // rooted at src/lib.zig, which re-exports each pipeline namespace as pub fields.
    // This avoids the "file exists in multiple modules" error that occurs when shared
    // files (e.g. tree_sitter.zig) are reachable via multiple named module paths.
    //
    // The only named package import in the src/ tree is "toml" (in config.zig).
    const bench_exe = b.addExecutable(.{
        .name = "complexity-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benchmarks/src/benchmark.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add tree-sitter C sources (required for parser)
    addTreeSitterSources(b, bench_exe);

    // Single "cg" module exposing all pipeline namespaces via src/lib.zig.
    // All relative imports within src/ resolve correctly from the module root.
    // toml is registered here because scoring.zig -> config.zig -> @import("toml").
    // tree-sitter include paths are added to cg_mod because tree_sitter.zig uses
    // @cImport for tree_sitter/api.h — modules need their own include path setup.
    const cg_mod = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    cg_mod.addImport("toml", toml_dep.module("toml"));
    cg_mod.addIncludePath(b.path("vendor/tree-sitter/lib/include"));
    cg_mod.addIncludePath(b.path("vendor/tree-sitter/lib/src"));
    cg_mod.addIncludePath(b.path("vendor/tree-sitter/lib/src/unicode"));
    bench_exe.root_module.addImport("cg", cg_mod);

    // Install bench binary only when the bench step is explicitly requested.
    // Using addInstallArtifact (not installArtifact) keeps bench isolated from
    // the default install step, so `zig build` and `zig build test` are unaffected.
    const bench_install = b.addInstallArtifact(bench_exe, .{});

    // bench-build: compile and install complexity-bench without running it.
    // Used by bench-subsystems.sh to build the binary before invoking it directly.
    const bench_build_step = b.step("bench-build", "Compile complexity-bench benchmark binary");
    bench_build_step.dependOn(&bench_install.step);

    const bench_run = b.addRunArtifact(bench_exe);
    bench_run.step.dependOn(&bench_install.step);
    if (b.args) |args| bench_run.addArgs(args);

    const bench_step = b.step("bench", "Run subsystem benchmarks");
    bench_step.dependOn(&bench_run.step);
}
