
# Replaced by [https://github.com/make-it-render](https://github.com/make-it-render)

# Make it render

A Zig library for cross-platform window handling and CPU-based rendering, without any dependencies.

It is an experimental project with constant changes.

## What this is

- Abstraction between X11, Windows and macOS (soon?)
- Window management, keyboard and mouse input events
- Text rendering with Unicode support (embedded Terminus and Unifont fonts)
- Image loading (PBM format) and scaling
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

- **anywindow** — Window handling abstraction and image display
	- x11: native X11 protocol implementation (no Xlib)
	- windows: Win32 API
	- macos: (planned)
	- image: positioned image with DPI scaling and nearest-neighbor upscaling
- **text** — Font loading, glyph rendering, Unicode support
	- fonts: embedded Unifont and Terminus (multiple sizes)
	- bdf: BDF font format parser (with gzip support)
- **image** — Image loading
	- pbm: PBM format (P1 ASCII and P4 binary)
- **loop** — Generic event loop
	- comptime union generation from multiple event sources
	- thread-per-source polling with thread-safe queue

## Work in progress

Notably missing:

- Wayland support, works using XWayland
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
const anywin = make_it_render.anywindow;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() != .leak);
    const allocator = gpa.allocator();

    var wm = try anywin.WindowManager.init(allocator);
    defer wm.deinit();

    var window = try wm.createWindow(.{ .title = "hello, world." });
    defer window.deinit();

    // create an image and set its pixels
    var img = try anywin.Image.init(allocator, &window, .{ .width = 200, .height = 100, .x = 10, .y = 10 });
    defer img.deinit();

    // render text to RGBA pixels and display it
    const fonts = try make_it_render.text.loadFonts(allocator, .{});
    defer make_it_render.text.freeFonts(allocator, fonts);

    var text = try make_it_render.text.render(allocator, fonts, "hello, world.");
    defer text.deinit();

    const rgba = try text.toRgba(allocator, &[_]u8{ 255, 150, 0, 255 });
    defer allocator.free(rgba);
    try img.setPixels(rgba);

    try window.show();

    // event loop with thread-per-source polling
    var window_source: anywin.EventSource = .{ .wm = &wm };
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
                .draw => {
                    try window.beginDraw();
                    try window.clear(.{});
                    try img.draw();
                    try window.endDraw();
                },
                else => {},
            },
        }
    }
}
```

See [src/demo.zig](src/demo.zig) for a more complete example with text rendering, image loading, mouse tracking, fullscreen toggle and icon.

## License

MIT
