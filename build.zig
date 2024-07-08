const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("hailo", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const status_exe = b.addExecutable(.{
        .name = "hailostatus",
        .root_source_file = b.path("src/hailostatus.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(status_exe);

    const run_status_cmd = b.addRunArtifact(status_exe);
    run_status_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_status_cmd.addArgs(args);
    }

    const run_step = b.step("status", "Run hailostatus");
    run_step.dependOn(&run_status_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
