const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const name = bin_name("hello", b, target, optimize);
    const exe = b.addExecutable(.{
        .name = name,
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/hello.zig" },
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run hello world");
    run_step.dependOn(&run_cmd.step);
}

pub fn bin_name(name: []const u8, b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) []const u8 {
    const triple = target.result.zigTriple(b.allocator) catch unreachable;
    const mode = switch (optimize) {
        .ReleaseFast => "fast",
        .ReleaseSmall => "small",
        .ReleaseSafe => "safe",
        .Debug => "debug",
    };
    return b.fmt("{s}-{s}-{s}", .{ name, triple, mode });
}
