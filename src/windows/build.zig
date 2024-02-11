const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //const win32 = b.addModule("x11", .{ .root_source_file = .{ .path = "core.zig" } });
    {
        const exe = b.addExecutable(.{
            .name = "demo-windows",
            .target = target,
            .optimize = optimize,
            .root_source_file = .{ .path = "demo.zig" },
            //.link_libc = true,
        });
        exe.subsystem = .Windows;

        //exe.root_module.addImport("win32", win32);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step("run-demo-windows", "Run demo for windows");
        run_step.dependOn(&run_cmd.step);
    }
}
