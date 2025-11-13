pub const WindowManager = switch (builtin.os.tag) {
    .linux => x11.WindowManager,
    .windows => windows.WindowManager,
    else => @compileError("platform not supported"),
};

pub const Window = switch (builtin.os.tag) {
    .linux => x11.Window,
    .windows => windows.Window,
    else => @compileError("platform not supported"),
};

pub const Image = switch (builtin.os.tag) {
    .linux => x11.Image,
    .windows => windows.Image,
    else => @compileError("platform not supported"),
};

test "init" {
    var wm = try WindowManager.init(testing.allocator);
    defer wm.deinit();
}

const std = @import("std");
const testing = std.testing;

const builtin = @import("builtin");

const x11 = @import("x11.zig");
const windows = @import("windows.zig");
