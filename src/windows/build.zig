const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const windows = b.addModule("windows", .{ .root_source_file = b.path("src/win.zig") });

    {
        const mod = b.addModule("demo", .{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/demo.zig"),
            .win32_manifest = b.path("win32.manifest"),
        });

        const exe = b.addExecutable(.{
            .name = "demo",
            .root_module = mod,
        });

        exe.root_module.addImport("windows", windows);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step("run", "Run demo for windows");
        run_step.dependOn(&run_cmd.step);
    }
}
