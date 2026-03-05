# Coding conventions

Zig conventions used across make-it-render modules.

## Naming

| Kind              | Style        | Examples                                     |
|-------------------|--------------|----------------------------------------------|
| Types / structs   | `PascalCase` | `Canvas`, `Image`, `FlushTarget`, `BBox`     |
| Functions         | `camelCase`  | `setPixels`, `getContext`, `fillText`         |
| Variables / fields| `snake_case` | `fill_color`, `line_width`, `pixel_buffer`   |
| Tagged union tags | `snake_case` | `move_to`, `line_to`, `key_pressed`          |
| Type aliases      | `PascalCase` | `WindowID`, `Height`, `Width`, `Scancode`    |

### Spell out names

Avoid single-letter and cryptic abbreviations. Loop variables should say what
they iterate over.

```zig
// Bad
for (0..n) |i| { ... }

// Good
for (0..config.layers) |layer| { ... }
```

Exception: `i` is fine for pure index iteration in tight arithmetic
(e.g. `for (0..half_dim) |i|`).

## File-as-struct

When a file defines a single primary type, the file _is_ the struct — bare
fields at the top, methods below, no wrapping `pub const Foo = struct { ... }`.

```zig
// canvas.zig — the file IS the Canvas struct
allocator: std.mem.Allocator,
window: *anywin.Window,
images: std.ArrayListUnmanaged(*Image) = .{},

pub fn init(allocator: std.mem.Allocator, window: *anywin.Window) @This() {
    return .{ .window = window, .images = .{}, .allocator = allocator };
}

pub fn deinit(self: *@This()) void { ... }
```

Callers get the type name from the import:
```zig
const Canvas = @import("canvas.zig");
```

When a file exports multiple types (e.g. `common.zig`), use named `pub const`
structs instead.

## @This() usage

Use `@This()` directly in method signatures for file-as-struct modules.
Use `const Self = @This()` when inside a returned generic struct (e.g. from a
`fn Foo(comptime T: type) type` function).

```zig
// File-as-struct — use @This() directly
pub fn init(allocator: std.mem.Allocator) @This() { ... }
pub fn deinit(self: *@This()) void { ... }

// Generic returned struct — Self alias is clearer
pub fn ThreadSafeQueue(Type: type) type {
    return struct {
        const Self = @This();
        pub fn push(self: *Self, item: Type) void { ... }
    };
}
```

## Struct organization

1. Fields (with default values where sensible)
2. `init` / `deinit`
3. Public methods
4. Private helpers

```zig
// Fields
fill_color: [4]u8 = .{ 0, 0, 0, 255 },
stroke_color: [4]u8 = .{ 0, 0, 0, 255 },
line_width: u16 = 1,

// Lifecycle
pub fn init(...) @This() { ... }
pub fn deinit(self: *@This()) void { ... }

// Public API
pub fn setPixels(self: *@This(), pixels: []const u8) !void { ... }
pub fn getContext(self: *@This()) !Context { ... }

// Private
fn nearestNeighbor(...) ![]u8 { ... }
```

## Self parameter conventions

Use `*@This()` for methods that mutate, `@This()` (by value) for pure queries.

```zig
pub fn setX(self: *@This(), x: X) void { self.dst_bbox.x = x; }
pub fn get(self: @This(), codepoint: u21) ?Glyph { return self.glyphs.get(codepoint); }
```

Use `_:` for unused self parameters instead of `_ = self`:

```zig
// Bad
pub fn destroyContext(self: *Self, ctx: *Context) void {
    _ = self;
    ctx.deinit();
}

// Good
pub fn destroyContext(_: *Self, ctx: *Context) void {
    ctx.deinit();
}
```

## Imports

Imports go at the **bottom** of the file (Zig convention for file-as-struct
modules — fields must come first).

```zig
// At the bottom of canvas.zig
const std = @import("std");
const anywin = @import("anywindow");
const Image = @import("image.zig");
const Context = @import("context.zig");
```

## Return values

Prefer `.{}` anonymous struct literal returns:

```zig
pub fn init(allocator: std.mem.Allocator) @This() {
    return .{ .allocator = allocator, .images = .{} };
}
```

## Error handling

- Propagate errors with `!` return types and `try`.
- Use `errdefer` for cleanup on error paths.
- Use `catch |err| switch (err) { ... }` for selective error handling.

```zig
pub fn createImage(self: *@This(), bbox: BBox) !*Image {
    const img = try self.allocator.create(Image);
    errdefer self.allocator.destroy(img);
    img.* = try Image.init(self.allocator, bbox);
    return img;
}
```

## Memory management

- Always pass `std.mem.Allocator` explicitly — no globals.
- Pair every `init` with a `deinit`, every `create` with a `destroy`.
- Use `defer`/`errdefer` at the call site.

```zig
var canvas: Canvas = .init(allocator, &window);
defer canvas.deinit();
```

## Tagged unions and enums

Use tagged unions for event systems and command types:

```zig
pub const Event = union(enum) {
    nop: void,
    close: WindowID,
    draw: struct { window_id: WindowID, area: BBox = .{} },
    mouse_pressed: struct { x: X, y: Y, button: MouseButton, window_id: WindowID },
    key_pressed: struct { scancode: Scancode, key: Key, modifiers: Modifiers, window_id: WindowID },
};
```

## Comptime and generics

Use `anytype` for duck-typed parameters. Use comptime functions that return
`type` for generic containers.

```zig
// anytype for simple generics
pub fn applyScaling(v: anytype, scaling: f32) @TypeOf(v) { ... }

// Comptime function returning a type
pub fn EventLoop(Sources: type) type {
    return struct { ... };
}

// Convenience wrapper
pub fn eventLoop(sources: anytype) EventLoop(@TypeOf(sources)) {
    return EventLoop(@TypeOf(sources)).init(sources);
}
```

Use `inline for` when iterating comptime-known fields:

```zig
inline for (source_fields, 0..) |field, i| {
    self.threads[i] = try std.Thread.spawn(.{}, pollSource(field.name), .{self});
}
```

## Comments

- `//!` for module-level doc comments (top of file).
- `///` for public API doc comments.
- `//` for inline explanations. Only where the code isn't self-evident.

```zig
//! 2D drawing context inspired by the HTML5 Canvas API.

/// Create a new Canvas bound to a window.
pub fn init(allocator: std.mem.Allocator, window: *anywin.Window) @This() { ... }

// P4: packed binary bits, MSB first, rows padded to byte boundary
```

## Tests

Tests live at the bottom of the file they test, after a `test` block:

```zig
test "nearestNeighbor 2x upscale" {
    const allocator = testing.allocator;
    const src = [_]u8{ 0xFF, 0x00, 0xFF, 0xFF, ... };
    const result = try nearestNeighbor(allocator, &src, 2, 2, 4, 4);
    defer allocator.free(result);
    try testing.expectEqual(@as(usize, 64), result.len);
}
```

Use `testing.allocator` (detects leaks) and `std.testing.expect*` assertions.

## Code hygiene

- Remove dead code, unused imports, and unused struct fields — version control
  has them.
- Name magic numbers when the meaning isn't obvious from context.
- Don't keep code "just in case".

## Platform dispatch

Use comptime `switch` on `builtin.os.tag` for platform-specific types:

```zig
pub const WindowManager = switch (builtin.os.tag) {
    .linux => x11.WindowManager,
    .windows => windows.WindowManager,
    else => @compileError("platform not supported"),
};
```
