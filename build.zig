// Build script for zelda
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const zelda_module = b.addModule("zelda", .{
        .root_source_file = b.path("src/zelda.zig"),
        .target = target,
        .optimize = optimize,
    });

    const opts = b.addOptions();
    opts.addOption(?u64, "seed", b.option(u64, "seed", "Provide a test seed for reproducing failures"));

    const test_filters = b.option(
        []const []const u8,
        "test-filter",
        "Skip tests that do not match any filter",
    ) orelse &[0][]const u8{};

    const module_unit_tests = b.addTest(.{
        .root_module = zelda_module,
        .filters = test_filters,
    });
    module_unit_tests.root_module.addOptions("options", opts);

    const run_module_unit_tests = b.addRunArtifact(module_unit_tests);
    run_module_unit_tests.has_side_effects = true;

    const test_step = b.step("test", "Run unit tests");

    test_step.dependOn(&run_module_unit_tests.step);

    const addOutputDirectoryArg = comptime if (@import("builtin").zig_version.order(.{ .major = 0, .minor = 13, .patch = 0 }) == .lt)
        std.Build.Step.Run.addOutputFileArg
    else
        std.Build.Step.Run.addOutputDirectoryArg;

    const clean = b.option(bool, "clean", "Do a 'clean' kcov run (no merge)") orelse false;

    const run_kcov = b.addSystemCommand(&.{
        "kcov",
    });
    if (clean) {
        run_kcov.addArg("--clean");
    }
    run_kcov.addArg("--exclude-line=unreachable,errdefer,expect(false),panic(,no-coverage");
    run_kcov.addPrefixedDirectoryArg("--include-pattern=", b.path("src"));
    const coverage_output = addOutputDirectoryArg(run_kcov, ".");
    run_kcov.addArtifactArg(module_unit_tests);

    run_kcov.enableTestRunnerMode();

    const install_coverage = b.addInstallDirectory(.{
        .source_dir = coverage_output,
        .install_dir = .{ .custom = "coverage" },
        .install_subdir = "",
    });

    const coverage_step = b.step("coverage", "Generate coverage (kcov must be installed)");
    coverage_step.dependOn(&install_coverage.step);
}
