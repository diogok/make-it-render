const std = @import("std");

pub const PutImageOptions = struct {
    format: ImageFormat = .ZPixmap,
    drawable_id: u32 = 0,
    graphic_context_id: u32 = 0,
    width: u16 = 640,
    height: u16 = 480,
    x: i16 = 0,
    y: i16 = 0,
    left_pad: u8 = 0,
    depth: u8 = 24,
};

pub fn putImage(writer: anytype, data: []const u8, options: PutImageOptions) !void {
    std.debug.print("putImage {any} ({d})\n", .{ options, data.len });

    const data_len: u16 = @intCast(data.len / 4);
    const default_length: u16 = @sizeOf(PutImageRequest) / 4;
    const request = PutImageRequest{
        .length = default_length + data_len,
        .format = @intFromEnum(options.format),
        .drawable_id = options.drawable_id,
        .graphic_context_id = options.graphic_context_id,
        .height = options.height,
        .width = options.width,
        .y = options.y,
        .x = options.x,
        .left_pad = options.left_pad,
    };

    std.debug.print("PutImageRequest: {any}\n", .{request});

    try writer.writeAll(&std.mem.toBytes(request));

    try writer.writeAll(data);
    const pad: [3]u8 = .{ 0, 0, 0 };
    try writer.writeAll(pad[0..(data.len % 4)]);

    std.debug.print("PutImageRequest sent\n", .{});
}

const PutImageRequest = extern struct {
    opcode: u8 = 72,
    format: u8 = 0,
    length: u16 = (@sizeOf(@This()) / 4),
    drawable_id: u32 = 0,
    graphic_context_id: u32 = 0,
    width: u16 = 0,
    height: u16 = 0,
    x: i16 = 0,
    y: i16 = 0,
    left_pad: u8 = 0,
    depth: u8 = 24,
    pad: u16 = 0,
};

const ImageFormat = enum(u8) {
    XYBitmap = 0,
    XYPixmap = 1,
    ZPixmap = 2,
};

pub const CopyAreaOptions = struct {
    src_drawable_id: u32 = 0,
    dst_drawable_id: u32 = 0,
    graphic_context_id: u32 = 0,
    src_x: i16 = 0,
    src_y: i16 = 0,
    dst_x: i16 = 0,
    dst_y: i16 = 0,
    width: u16 = 0,
    height: u16 = 0,
};

pub fn copyArea(writer: anytype, options: CopyAreaOptions) !void {
    std.debug.print("copyArea {any}\n", .{options});

    const request = CopyAreaRequest{
        .src_drawable_id = options.src_drawable_id,
        .dst_drawable_id = options.dst_drawable_id,
        .graphic_context_id = options.graphic_context_id,
        .src_x = options.src_x,
        .src_y = options.src_y,
        .dst_x = options.dst_x,
        .dst_y = options.dst_y,
        .width = options.width,
        .height = options.height,
    };

    std.debug.print("CopyAreaRequest: {any}\n", .{request});

    try writer.writeAll(&std.mem.toBytes(request));

    std.debug.print("CopyAreaRequest sent\n", .{});
}

const CopyAreaRequest = extern struct {
    opcode: u8 = 62,
    pad: u8 = 0,
    length: u16 = (@sizeOf(@This()) / 4),
    src_drawable_id: u32 = 0,
    dst_drawable_id: u32 = 0,
    graphic_context_id: u32 = 0,
    src_x: i16 = 0,
    src_y: i16 = 0,
    dst_x: i16 = 0,
    dst_y: i16 = 0,
    width: u16 = 0,
    height: u16 = 0,
};
