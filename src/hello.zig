const std = @import("std");
const X11 = @import("X11/core.zig");

pub fn main() !void {
    std.debug.print("Starting...\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() != .leak);
    var allocator = gpa.allocator();

    var x11 = X11.init(allocator, .{}); // connect and setup
    defer x11.deinit();
    try x11.connect();
    try x11.setup();

    const window_id = try x11.createWindow(.{ .x = 10, .y = 50 });
    try x11.mapWindow(123);

    try x11.receive();

    std.time.sleep(3 * std.time.ns_per_s);

    std.debug.print("Closing...\n", .{});

    try x11.unmapWindow(window_id);
    try x11.destroyWindow(window_id);

    std.debug.print("Closed.\n", .{});
}
