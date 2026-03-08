# Zig Monorepo Pattern

A pattern for structuring Zig projects as a monorepo of independently buildable
modules with strict, explicit dependencies.

## Structure

```
project/
  build.zig          # root: composes modules into a final artifact
  build.zig.zon      # root: lists direct module dependencies as .path deps
  src/
    root.zig          # root source file, re-exports modules
    demo.zig          # example executable (optional)
    module_a/
      build.zig       # standalone build: exposes a named module + test step
      build.zig.zon   # declares its own name, fingerprint, and dependencies
      src/
        root.zig
    module_b/
      build.zig
      build.zig.zon   # depends on module_a via relative .path
      src/
        root.zig
```

Each module lives under `src/<name>/` and is a fully self-contained Zig package
with its own `build.zig` and `build.zig.zon`. You can `cd src/module_a && zig
build test` at any time.

## Rules

1. **Every module gets its own `build.zig` + `build.zig.zon`.**
   No module is "just files" — each one is a proper package the build system
   understands.

2. **Dependencies are strict and explicit.**
   A module only depends on what it declares in its `build.zig.zon`. If module B
   needs module A, it lists it as a `.path` dependency. There are no implicit
   imports.

3. **Most modules are standalone (zero dependencies).**
   Leaf modules like `image`, `text`, `loop` have `.dependencies = .{}`. They
   can be extracted and dropped into any other project as-is.

4. **The root package composes, not wraps.**
   The root `build.zig.zon` lists the modules it needs. The root `build.zig`
   wires them together into the final module/executable. It doesn't duplicate
   module logic — it just connects things.

5. **Inter-module deps use relative paths.**
   Sibling modules reference each other as `../<sibling>`. This keeps everything
   local with no registry or URL fetching needed.

## Templates

### Standalone module (no dependencies)

`src/my_module/build.zig.zon`:
```zig
.{
    .name = .my_module,
    .fingerprint = 0x...,   // zig build --generate-fingerprint
    .version = "0.0.0",
    .dependencies = .{},
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

`src/my_module/build.zig`:
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule(
        "my_module",
        .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .strip = optimize == .ReleaseSmall,
        },
    );

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/root.zig"),
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const run_tests_step = b.step("test", "Run tests");
    run_tests_step.dependOn(&run_tests.step);
}
```

### Module with dependencies

`src/my_module/build.zig.zon`:
```zig
.{
    .name = .my_module,
    .fingerprint = 0x...,
    .version = "0.0.0",
    .dependencies = .{
        .some_dep = .{
            .path = "../some_dep",
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

`src/my_module/build.zig`:
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const my_module = b.addModule(
        "my_module",
        .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .strip = optimize == .ReleaseSmall,
        },
    );

    const some_dep = b.dependency("some_dep", .{ .target = target, .optimize = optimize });
    my_module.addImport("some_dep", some_dep.module("some_dep"));

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/root.zig"),
        }),
    });
    tests.root_module.addImport("some_dep", some_dep.module("some_dep"));

    const run_tests = b.addRunArtifact(tests);
    const run_tests_step = b.step("test", "Run tests");
    run_tests_step.dependOn(&run_tests.step);
}
```

### Root package (composer)

`build.zig.zon`:
```zig
.{
    .name = .my_project,
    .fingerprint = 0x...,
    .version = "0.0.0",
    .dependencies = .{
        .module_a = .{ .path = "src/module_a" },
        .module_b = .{ .path = "src/module_b" },
    },
    .paths = .{
        "src",
        "build.zig",
        "build.zig.zon",
    },
}
```

`build.zig`:
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the root module that re-exports everything
    const my_project = b.addModule(
        "my_project",
        .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .strip = optimize == .ReleaseSmall,
        },
    );

    // Wire in each sub-module
    const module_a = b.dependency("module_a", .{ .target = target, .optimize = optimize });
    my_project.addImport("module_a", module_a.module("module_a"));

    const module_b = b.dependency("module_b", .{ .target = target, .optimize = optimize });
    my_project.addImport("module_b", module_b.module("module_b"));

    // Executable
    {
        const exe_mod = b.addModule("exe", .{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        exe_mod.addImport("my_project", my_project);

        const exe = b.addExecutable(.{ .name = "my_project", .root_module = exe_mod });
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step("run", "Run");
        run_step.dependOn(&run_cmd.step);
    }

    // Tests
    {
        const tests_mod = b.addModule("tests", .{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/root.zig"),
        });
        tests_mod.addImport("my_project", my_project);
        tests_mod.addImport("module_a", module_a.module("module_a"));
        tests_mod.addImport("module_b", module_b.module("module_b"));

        const tests = b.addTest(.{ .root_module = tests_mod });
        const run_tests = b.addRunArtifact(tests);
        const run_tests_step = b.step("test", "Run tests");
        run_tests_step.dependOn(&run_tests.step);
    }
}
```

## Dependency graph (make-it-render)

```
root (make_it_render)
 ├── anywindow
 │    ├── x11        (standalone)
 │    └── windows    (standalone)
 ├── text            (standalone)
 ├── image           (standalone)
 └── loop            (standalone)
```

5 out of 6 modules have zero dependencies. `anywindow` composes two
platform-specific backends. The rest can be copied into any project with no
changes.

## Extracting a module for reuse

To use a standalone module in another project:

1. Copy `src/<module>/` into the new project (or reference it via path/url).
2. Add it to the new project's `build.zig.zon`:
   ```zig
   .my_module = .{ .path = "src/my_module" },
   // or
   .my_module = .{ .url = "https://...", .hash = "..." },
   ```
3. Wire it in `build.zig`:
   ```zig
   const dep = b.dependency("my_module", .{ .target = target, .optimize = optimize });
   your_module.addImport("my_module", dep.module("my_module"));
   ```

For modules with dependencies, bring those along too — the relative paths in
`build.zig.zon` will need adjusting to match the new layout.
