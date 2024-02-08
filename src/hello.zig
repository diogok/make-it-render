const std = @import("std");
const X11 = @import("X11/core.zig");

pub fn main() !void {
    std.debug.print("Starting...\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() != .leak);
    const allocator = gpa.allocator();

    var x11 = X11.init(allocator, .{}); // connect and setup
    defer x11.deinit();
    try x11.connect();
    try x11.setup();

    const window_id = try x11.createWindow(.{ .x = 10, .y = 50 });
    try x11.mapWindow(window_id);

    const pixmap_id = try x11.createPixmap(.{.drawable_id=window_id});
    const graphic_context_id = try x11.createGraphicContext(.{.drawable_id=pixmap_id});

    var image:[5 * 6 * 4]u8 = undefined;
    var i:usize=0;
    while(i < image.len) {
        image[i] = 255; // red
        image[i + 1] = 255; // green
        image[i + 2] = 0; // blue
        image[i + 3] = 0; // padding or alpha, ignored for now

        i += 4;
    }

    while(true) {
        try x11.putImage(&image, .{.drawable_id=pixmap_id,.graphic_context_id=graphic_context_id, .width=5,.height=6, .x=100,.y=50});

        try x11.copyArea(.{
            .src_drawable_id=pixmap_id,
            .dst_drawable_id=window_id,
            .graphic_context_id=graphic_context_id,
            .width=640,
            .height=480,
        }) ;

        var msg = try x11.receive();
        while(msg != null) {
            std.debug.print("Message: {any}\n", .{msg});
            msg = try x11.receive();
        }

        std.time.sleep(2 * std.time.ns_per_s);

        std.debug.print("Closing...\n", .{});

    }
    try x11.freePixmap(pixmap_id);
    try x11.freeGraphicContext(graphic_context_id);
    try x11.unmapWindow(window_id);
    try x11.destroyWindow(window_id);

    std.debug.print("Closed.\n", .{});
}
