const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    switch (target.result.os.tag) {
        .linux => {
            {
                const x11 = b.anonymousDependency("src/windows/x11", @import("src/windows/x11/build.zig"), .{
                    .target = target,
                    .optimize = optimize,
                });

                const exe = x11.artifact("demo");
                b.installArtifact(exe);

                const run_cmd = b.addRunArtifact(exe);
                const run_step = b.step("run-demo-x11", "Run X11 demo");
                run_step.dependOn(&run_cmd.step);
            }
        },
        .windows => {
            {
                const windows = b.anonymousDependency("src/windows/windows", @import("src/windows/windows/build.zig"), .{
                    .target = target,
                    .optimize = optimize,
                });

                const exe = windows.artifact("demo");
                b.installArtifact(exe);

                const run_cmd = b.addRunArtifact(exe);
                const run_step = b.step("run-demo-windows", "Run windows demo");
                run_step.dependOn(&run_cmd.step);
            }
        },
        .macos => {
            {
                const mac = b.anonymousDependency("src/windows/macosx", @import("src/windows/macosx/build.zig"), .{
                    .target = target,
                    .optimize = optimize,
                });

                const exe = mac.artifact("demo");
                b.installArtifact(exe);

                const run_cmd = b.addRunArtifact(exe);
                const run_step = b.step("run-demo-mac", "Run mac demo");
                run_step.dependOn(&run_cmd.step);
            }
        },
        else => {},
    }
}
