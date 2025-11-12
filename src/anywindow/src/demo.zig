pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() != .leak);
    const allocator = gpa.allocator();

    var wm = try win.WindowManager.init(allocator);
    defer wm.deinit();

    var window = try wm.createWindow(
        .{
            .title = "hello, world.",
        },
    );
    try window.show();

    // Let's make a little yellow triangle
    const y = [4]u8{ 255, 150, 0, 1 };
    const b = [4]u8{ 0, 0, 0, 0 };
    const yellow_block: [5 * 5][4]u8 = [_][4]u8{
        b, b, y, b, b,
        b, y, y, y, b,
        b, y, y, y, b,
        y, y, y, y, y,
        y, y, y, y, y,
    };
    var pixels = std.mem.toBytes(yellow_block);

    var image = try window.createImage(.{ .height = 5, .width = 5 }, &pixels);
    defer image.deinit() catch unreachable;
    try wm.flush();

    var timer = try std.time.Timer.start();

    while (window.status == .open) {
        const event = try wm.receive();
        switch (event) {
            .close => {
                try window.destroy();
            },
            .draw => {
                timer.reset();

                const target = win.BBox{
                    .x = 100,
                    .y = 100,
                    .height = image.size.height,
                    .width = image.size.width,
                };
                try image.draw(target);
                try wm.flush();

                log.info("Time to draw: {d}ms", .{timer.lap() / std.time.us_per_ms});
            },
            .mouse_pressed, .mouse_released, .key_pressed, .key_released => {
                log.debug("{any}", .{event});
                try window.redraw(.{});
            },
            else => {},
        }
    }
}

const std = @import("std");
const win = @import("anywindow");

const log = std.log.scoped(.demo);

pub const std_options: std.Options = .{
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .x11, .level = .warn },
    },
};
