const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const x11 = b.addModule("x11", .{ .root_source_file = .{ .path = "x11.zig" } });

    {
        const exe = b.addExecutable(.{
            .name = "demo",
            .target = target,
            .optimize = optimize,
            .root_source_file = .{ .path = "demo.zig" },
        });
        exe.root_module.addImport("x11", x11);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step("run-demo", "Run demo");
        run_step.dependOn(&run_cmd.step);
    }
}
