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
            .strip = optimize == .ReleaseSmall,
        },
    );

    const anywindow = b.dependency("anywindow", .{ .target = target, .optimize = optimize });
    canvas.addImport("anywindow", anywindow.module("anywindow"));

    const text = b.dependency("text", .{ .target = target, .optimize = optimize });
    canvas.addImport("text", text.module("text"));

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/root.zig"),
        }),
    });
    tests.root_module.addImport("anywindow",anywindow.module("anywindow") );
    tests.root_module.addImport("text",text.module("text") );

    const run_tests = b.addRunArtifact(tests);
    const run_tests_step = b.step("test", "Run tests");
    run_tests_step.dependOn(&run_tests.step);
}
