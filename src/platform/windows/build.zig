const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const windows = b.addModule("windows", .{ .root_source_file = b.path("src/root.zig") });

    {
        const exe = b.addExecutable(.{
            .name = "demo",
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/demo.zig"),
        });

        exe.root_module.addImport("windows", windows);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step("run", "Run demo for windows");
        run_step.dependOn(&run_cmd.step);
    }
}
