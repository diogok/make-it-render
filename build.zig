const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const anywindow_dep = b.dependency("anywindow", .{
        .target = target,
        .optimize = optimize,
    });
    const anywindow = anywindow_dep.module("anywindow");

    {
        const demo = b.addExecutable(.{
            .name = "demo",
            .target = target,
            .optimize = optimize,
            .strip = optimize == .ReleaseSmall,
            .link_libc = optimize == .Debug,
            .root_source_file = b.path("src/demo.zig"),
        });
        demo.root_module.addImport("anywindow", anywindow);

        b.installArtifact(demo);

        const run_cmd = b.addRunArtifact(demo);
        const run_step = b.step("run", "Run demo");
        run_step.dependOn(&run_cmd.step);
    }
}
