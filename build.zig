const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const anywindow = b.dependency("anywindow", .{ .target = target, .optimize = optimize });

    const make_it_render = b.addModule(
        "make_it_render",
        .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .strip = optimize == .ReleaseSmall,
        },
    );
    make_it_render.addImport("anywindow", anywindow.module("anywindow"));

    {
        const demo_mod = b.addModule("demo", .{
            .root_source_file = b.path("src/demo.zig"),
            .target = target,
            .optimize = optimize,
            .strip = optimize == .ReleaseSmall,
            .link_libc = optimize == .Debug,
        });
        demo_mod.addImport("make_it_render", make_it_render);

        const demo = b.addExecutable(.{
            .name = "demo",
            .root_module = demo_mod,
        });

        b.installArtifact(demo);

        const run_cmd = b.addRunArtifact(demo);
        const run_step = b.step("run", "Run demo");
        run_step.dependOn(&run_cmd.step);
    }

    {
        const tests_mod = b.addModule("tests", .{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/root.zig"),
        });
        tests_mod.addImport("make_it_render", make_it_render);

        const tests = b.addTest(.{
            .root_module = tests_mod,
        });

        const run_tests = b.addRunArtifact(tests);
        const run_tests_step = b.step("test", "Run tests");
        run_tests_step.dependOn(&run_tests.step);
    }

    {
        const docs_mod = b.addModule("docs", .{
            .target = target,
            .optimize = .Debug,
            .root_source_file = b.path("src/root.zig"),
        });
        docs_mod.addImport("make_it_render", make_it_render);

        const docs = b.addObject(.{
            .name = "docs",
            .root_module = docs_mod,
        });

        const install_docs = b.addInstallDirectory(.{
            .source_dir = docs.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = "docs",
        });

        const docs_step = b.step("docs", "Install documentation");
        docs_step.dependOn(&install_docs.step);
    }
}
