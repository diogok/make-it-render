const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const canvas = b.addModule(
        "canvas",
        .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        },
    );

    const tests = b.addTest(.{
        .root_module = canvas,
    });

    const run_tests = b.addRunArtifact(tests);
    const run_test_step = b.step("test", "Run tests");
    run_test_step.dependOn(&run_tests.step);
}
