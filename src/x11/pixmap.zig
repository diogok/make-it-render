const std = @import("std");

// TODO: logger

pub const PixmapOptions = struct {
    depth: u8 = 24,
    width: u16 = 640,
    height: u16 = 480,
    drawable_id: u32 = 0,
};

pub fn createPixmap(writer: anytype, pixmap_id: u32, options: PixmapOptions) !void {
    std.debug.print("createPixmap {d}, options: {any}\n", .{ pixmap_id, options });

    const request = CreatePixmapRequest{ .depth = options.depth, .pixmap_id = pixmap_id, .drawable_id = options.drawable_id, .height = options.height, .width = options.width };

    std.debug.print("createPixmapRequest: {any}\n", .{request});

    try writer.writeAll(&std.mem.toBytes(request));

    std.debug.print("createPixmapRequest sent\n", .{});
}

const CreatePixmapRequest = extern struct {
    opcode: u8 = 53,
    depth: u8 = 0,
    length: u16 = (@sizeOf(@This()) / 4),
    pixmap_id: u32,
    drawable_id: u32,
    width: u16,
    height: u16,
};

pub fn freePixmap(writer: anytype, pixmap_id: u32) !void {
    std.debug.print("FreePixmapRequest {d}\n", .{pixmap_id});
    const request = FreePixmapRequest{ .pixmap_id = pixmap_id };
    std.debug.print("FreePixmapRequest: {any}\n", .{request});
    try writer.writeAll(&std.mem.toBytes(request));
}

const FreePixmapRequest = extern struct {
    opcode: u8 = 54,
    pad0: u8 = 0,
    length: u16 = @sizeOf(@This()) / 4,
    pixmap_id: u32,
};
