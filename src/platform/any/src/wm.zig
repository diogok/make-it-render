const std = @import("std");
const testing = std.testing;

const builtin = @import("builtin");

const x11 = @import("x11.zig");
const windows = @import("windows.zig");

pub const WM = switch (builtin.os.tag) {
    .linux => x11.X11WM,
    .windows => windows.WindowsWM,
    else => @compileError("not support platform"),
};

test "init" {
    var wm = try WM.init(testing.allocator);
    defer wm.deinit();
}
