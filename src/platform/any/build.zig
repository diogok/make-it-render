const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const x11_dep = b.dependency("x11", .{
        .target = target,
        .optimize = optimize,
    });
    const x11 = x11_dep.module("x11");

    const windows_dep = b.dependency("windows", .{
        .target = target,
        .optimize = optimize,
    });
    const windows = windows_dep.module("windows");

    const any = b.addModule(
        "anywindow",
        .{
            .root_source_file = b.path("src/root.zig"),
        },
    );
    any.addImport("x11", x11);
    any.addImport("windows", windows);

    {
        const demo = b.addExecutable(.{
            .name = "demo",
            .target = target,
            .optimize = optimize,
            .strip = optimize == .ReleaseSmall,
            .link_libc = optimize == .Debug,
            .root_source_file = b.path("src/demo.zig"),
        });
        demo.root_module.addImport("anywindow", any);

        b.installArtifact(demo);

        const run_cmd = b.addRunArtifact(demo);
        const run_step = b.step("run", "Run demo");
        run_step.dependOn(&run_cmd.step);
    }

    {
        const tests = b.addTest(.{
            .name = "anywindow",
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/root.zig"),
        });
        tests.root_module.addImport("x11", x11);
        tests.root_module.addImport("windows", windows);

        const run_tests = b.addRunArtifact(tests);
        const run_tests_step = b.step("test", "Run tests");
        run_tests_step.dependOn(&run_tests.step);
    }

    {
        const docs = b.addObject(.{
            .name = "docs",
            .target = target,
            .optimize = .Debug,
            .root_source_file = b.path("src/root.zig"),
        });
        docs.root_module.addImport("x11", x11);
        docs.root_module.addImport("windows", windows);

        const install_docs = b.addInstallDirectory(.{
            .source_dir = docs.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = "docs",
        });

        const docs_step = b.step("docs", "Install documentation");
        docs_step.dependOn(&install_docs.step);
    }
}
