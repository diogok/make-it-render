const std = @import("std");
const testing = std.testing;

const x11 = @import("x11.zig");

pub const WM = x11.X11WM;

test "init" {
    var wm = try WM.init(testing.allocator);
    defer wm.deinit();
}
