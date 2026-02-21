const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const macos = b.addModule(
        "text",
        .{
            .root_source_file = b.path("macos.zig"),
            .target = target,
            .optimize = optimize,
            .strip = optimize == .ReleaseSmall,
        },
    );

    {
        const demo_mod = b.addModule("demo", .{
            .root_source_file = b.path("demo.zig"),
            .target = target,
            .optimize = optimize,
            .strip = optimize == .ReleaseSmall,
        });
        demo_mod.addImport("macos", macos);

        const demo = b.addExecutable(.{
            .name = "demo",
            .root_module = demo_mod,
        });

        b.installArtifact(demo);

        const run_cmd = b.addRunArtifact(demo);
        const run_step = b.step("run", "Run demo");
        run_step.dependOn(&run_cmd.step);
    }

    {
        const tests_mod = b.addModule("tests", .{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("macos.zig"),
        });

        const tests = b.addTest(.{
            .root_module = tests_mod,
        });

        const run_tests = b.addRunArtifact(tests);
        const run_tests_step = b.step("test", "Run tests");
        run_tests_step.dependOn(&run_tests.step);
    }
}
