const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const canvas = b.addModule("canvas", .{ .root_source_file = .{ .path = "canvas.zig" } });

    {
        const exe = b.addExecutable(.{
            .name = "demo",
            .target = target,
            .optimize = optimize,
            .root_source_file = .{ .path = "demo.zig" },
        });

        exe.root_module.addImport("canvas", canvas);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step("run-demo", "Run demo");
        run_step.dependOn(&run_cmd.step);
    }

    {
        const tests = b.addTest(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = .{ .path = "canvas.zig" },
        });

        tests.root_module.addImport("canvas", canvas);

        const run_tests = b.addRunArtifact(tests);
        const run_test_step = b.step("test", "Run tests");
        run_test_step.dependOn(&run_tests.step);
    }
}
