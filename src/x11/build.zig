const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const x11 = b.addModule("x11", .{ .root_source_file = .{ .path = "core.zig" } });

    {
        //const name = bin_name("demo-x11", b, target, optimize);
        const exe = b.addExecutable(.{
            .name = "demo-x11",
            .target = target,
            .optimize = optimize,
            .root_source_file = .{ .path = "demo.zig" },
        });

        exe.root_module.addImport("x11", x11);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step("run-demo-x11", "Run demo for X11");
        run_step.dependOn(&run_cmd.step);
    }
}

fn bin_name(name: []const u8, b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) []const u8 {
    const triple = target.result.zigTriple(b.allocator) catch unreachable;
    const mode = switch (optimize) {
        .ReleaseFast => "fast",
        .ReleaseSmall => "small",
        .ReleaseSafe => "safe",
        .Debug => "debug",
    };
    return b.fmt("{s}-{s}-{s}", .{ name, triple, mode });
}
