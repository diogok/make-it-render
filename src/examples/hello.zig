const std = @import("std");
const x11 = @import("x11");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() != .leak);
    const allocator = gpa.allocator();

    const conn = try x11.connect(.{});
    defer conn.close();

    const info = try x11.setup(allocator, conn);
    defer info.deinit();

    var xID = x11.XID.init(info.resource_id_base, info.resource_id_mask);

    const window_id = try xID.genID();
    const win_req = x11.CreateWindow{
        .window_id = window_id,

        .parent_id = info.screens[0].root,
        .visual_id = info.screens[0].root_visual,
        .depth = info.screens[0].root_depth,

        .x = 10,
        .y = 10,
        .width = 480,
        .height = 240,
        .border_width = 0,
        .window_class = .InputOutput,

        .value_mask = @intFromEnum(x11.WindowMask.colormap) | @intFromEnum(x11.WindowMask.back_pixel),
    };
    const win_values = [_]u32{ info.screens[0].black_pixel, info.screens[0].colormap };
    try x11.sendWithValues(conn, win_req, &win_values);

    const map_req = x11.MapWindow{ .window_id = window_id };
    try x11.send(conn, map_req);

    const pixmap_id = try xID.genID();
    const pixmap_req = x11.CreatePixmap{
        .pixmap_id = pixmap_id,
        .drawable_id = window_id,
        .width = win_req.width,
        .height = win_req.height,
        .depth = win_req.depth,
    };
    try x11.send(conn, pixmap_req);

    const graphic_context_id = try xID.genID();
    try x11.send(conn, x11.CreateGraphicContext{ .graphic_context_id = graphic_context_id, .drawable_id = pixmap_id });

    var yellow_block: [5 * 6 * 4]u8 = undefined;
    var byte_index: usize = 0;
    while (byte_index < yellow_block.len) {
        yellow_block[byte_index] = 255; // red
        yellow_block[byte_index + 1] = 255; // green
        yellow_block[byte_index + 2] = 0; // blue
        yellow_block[byte_index + 3] = 0; // padding or alpha, ignored for now

        byte_index += 4;
    }

    const yellow_block_zpixmap = try x11.rgbaToZPixmapAlloc(allocator, info, &yellow_block);

    const put_image_req = x11.PutImage{
        .drawable_id = pixmap_id,
        .graphic_context_id = graphic_context_id,
        .width = 5,
        .height = 6,
        .x = 100,
        .y = 200,
        .depth = info.screens[0].root_depth,
    };
    try x11.sendWithBytes(conn, put_image_req, yellow_block_zpixmap);

    while (true) {
        const messages = try x11.receiveAll(allocator, conn);
        defer allocator.free(messages);
        for (messages) |message| {
            std.debug.print("Received: {any}\n", .{message});
        }

        const copy_area_req = x11.CopyArea{
            .src_drawable_id = pixmap_id,
            .dst_drawable_id = window_id,
            .graphic_context_id = graphic_context_id,
            .width = pixmap_req.width,
            .height = pixmap_req.height,
        };
        try x11.send(conn, copy_area_req);

        std.time.sleep(2 * std.time.ns_per_s);
    }

    try x11.send(conn, x11.FreeGraphicContext{ .graphic_context_id = graphic_context_id });
    try x11.send(conn, x11.FreePixmap{ .pixmap_id = pixmap_id });
    try x11.send(conn, x11.UnmapWindow{ .window_id = window_id });
    try x11.send(conn, x11.DestroyWindow{ .window_id = window_id });
}
