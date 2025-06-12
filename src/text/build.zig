const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const fonts_dep = b.dependency("fonts", .{});
    const fontz = fonts_dep.module("fontz");
    const fonts = fonts_dep.module("fonts");

    _ = b.addModule("text", .{ .root_source_file = b.path("src/root.zig") });

    {
        const tests = b.addTest(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/root.zig"),
        });

        tests.root_module.addImport("fonts", fonts);
        tests.root_module.addImport("fontz", fontz);

        const run_tests = b.addRunArtifact(tests);

        const run_test_step = b.step("test", "Run tests");
        run_test_step.dependOn(&run_tests.step);
    }
}
