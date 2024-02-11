const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    switch (target.result.os.tag) {
        .linux => {
            {
                const x11 = b.anonymousDependency("src/x11", @import("src/x11/build.zig"), .{
                    .target = target,
                    .optimize = optimize,
                });

                const exe = x11.artifact("demo-x11");
                b.installArtifact(exe);

                const run_cmd = b.addRunArtifact(exe);
                const run_step = b.step("run-demo-x11", "Run X11 demo");
                run_step.dependOn(&run_cmd.step);
            }
        },
        .windows => {
            {
                const windows = b.anonymousDependency("src/windows", @import("src/windows/build.zig"), .{
                    .target = target,
                    .optimize = optimize,
                });

                const exe = windows.artifact("demo-windows");
                b.installArtifact(exe);

                const run_cmd = b.addRunArtifact(exe);
                const run_step = b.step("run-demo-windows", "Run windows demo");
                run_step.dependOn(&run_cmd.step);
            }
        },
        else => {},
    }
}
