# Make it render

A Zig library for cross-platform window handling and CPU-based rendering, without any dependencies.

It is an experimental project with constant changes.

## What this is

- Abstraction between X11, Windows and macOS (soon?)
- Window management, keyboard and mouse input events
- Text rendering with Unicode support (embedded Terminus and Unifont fonts)
- Image loading (PBM format) and scaling
- 2D drawing Context inspired by HTML5 Canvas API (paths, fills, strokes, text)
- Alpha blending (source-over compositing)
- Generic event loop with comptime union generation and thread-per-source polling
- Fullscreen toggle and window icon support
- Pure Zig — only uses C when linking to Win32 required libraries
- Produces small and performant statically-linked binaries
- No dependencies, all in one

## What this is not

- It is not a GUI library or game engine
- It does not use GPU (no OpenGL nor Vulkan)
- It does not support mobile (no Android nor iOS)

## Structure

Each module is independent and usable by itself.

- **anywindow** — Window handling abstraction
	- x11: native X11 protocol implementation (no Xlib)
	- windows: Win32 API
	- macos: (planned)
- **text** — Font loading, glyph rendering, Unicode support
	- fonts: embedded Unifont and Terminus (multiple sizes)
	- bdf: BDF font format parser (with gzip support)
- **image** — Image loading
	- pbm: PBM format (P1 ASCII and P4 binary)
- **canvas** — Drawing and compositing
	- canvas: layered drawing area with z-order and DPI scaling
	- image: nearest-neighbor scaling, dirty tracking
	- context: 2D drawing context with paths, fills, strokes, text, and alpha blending
- **loop** — Generic event loop
	- comptime union generation from multiple event sources
	- thread-per-source polling with thread-safe queue

## Work in progress

Notably missing:

- Wayland support
- macOS support

## Usage

### Building

```sh
zig build        # build the library and demo
zig build run    # run the demo
zig build test   # run tests
zig build docs   # generate documentation
```

### As a dependency

```sh
zig fetch --save git+https://github.com/diogok/make-it-render
```

Then in your `build.zig`, import the module:

```zig
const make_it_render = b.dependency("make_it_render", .{ .target = target, .optimize = optimize });
exe_mod.addImport("make_it_render", make_it_render.module("make_it_render"));
```

### Example

```zig
const std = @import("std");
const make_it_render = @import("make_it_render");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() != .leak);
    const allocator = gpa.allocator();

    var wm = try make_it_render.anywindow.WindowManager.init(allocator);
    defer wm.deinit();

    var window = try wm.createWindow(.{ .title = "hello, world." });
    defer window.deinit();

    var canvas: make_it_render.canvas.Canvas = .init(allocator, &window);
    defer canvas.deinit();

    // create an image layer and draw on it using the 2D context
    var img = try canvas.createImage(.{ .width = 200, .height = 100, .x = 10, .y = 10 });
    var ctx = try img.getContext();
    defer ctx.deinit();

    ctx.setFillColor(.{ 255, 150, 0, 255 });
    ctx.fillRect(0, 0, 200, 100);
    try ctx.flush();

    try window.show();

    // event loop with thread-per-source polling
    var window_source: make_it_render.anywindow.WindowSource = .{ .wm = &wm };
    var ev_loop = make_it_render.loop.eventLoop(.{ .window = &window_source });
    defer ev_loop.deinit();
    try ev_loop.start();

    while (ev_loop.receive()) |wrapped| {
        switch (wrapped) {
            .window => |event| switch (event) {
                .close => {
                    window.close();
                    ev_loop.stop();
                },
                .draw => try canvas.draw(),
                else => {},
            },
        }
    }
}
```

See [src/demo.zig](src/demo.zig) for a more complete example with text rendering, image loading, mouse tracking, and fullscreen toggle.

## License

MIT
