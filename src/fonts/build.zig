const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("fonts", .{ .root_source_file = b.path("fonts/root.zig") });
    const fontz = b.addModule("fontz", .{ .root_source_file = b.path("src/root.zig") });

    {
        const run_test_step = b.step("test", "Run tests");
        {
            const tests = b.addTest(.{
                .target = target,
                .optimize = optimize,
                .root_source_file = b.path("src/root.zig"),
            });

            const run_tests = b.addRunArtifact(tests);
            run_test_step.dependOn(&run_tests.step);
        }

        {
            const tests = b.addTest(.{
                .target = target,
                .optimize = optimize,
                .root_source_file = b.path("fonts/root.zig"),
            });
            tests.root_module.addImport("fontz", fontz);

            const run_tests = b.addRunArtifact(tests);
            run_test_step.dependOn(&run_tests.step);
        }
    }
}
