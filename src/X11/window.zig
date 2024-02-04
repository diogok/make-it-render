const std = @import("std");
const endian = @import("builtin").cpu.arch.endian();

pub const WindowOptions = struct {
    x: i16 = 0,
    y: i16 = 0,
    depth: u8 = 0,
    width: u16 = 640,
    height: u16 = 480,
    parent_window: u32 = 0,
    visual_id: u32 = 0,
    border_width: u16 = 0,
    window_class: u16 = 1, // TODO: enum
    colormap: u32 = 0,
};

pub fn createWindowRequest(writer: anytype, window_id: u32, options: WindowOptions) !void {
    std.debug.print("CreateWindowRequest {d}, options: {any}\n", .{ window_id, options });

    var request = CreateWindowRequest{
        .depth = options.depth,
        .window_id = window_id,
        .parent_id = options.parent_window,
        .x = options.x,
        .y = options.y,
        .width = options.width,
        .height = options.height,
        .border_width = options.border_width,
        .window_class = options.window_class,
        .visual_id = options.visual_id,
    };

    std.debug.print("CreateWindowRequest: {any}\n", .{request});

    try writer.writeAll(&std.mem.toBytes(request));
}

const CreateWindowRequest = extern struct {
    opcode: u8 = 1,
    depth: u8,
    length: u16 = (@sizeOf(@This()) / 4),
    window_id: u32,
    parent_id: u32,
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    border_width: u16,
    window_class: u16,
    visual_id: u32,
    value_mask: u32 = 0,
};

pub fn destroyWindowRequest(writer: anytype, window_id: u32) !void {
    std.debug.print("DestroyWindowRequest {d}\n", .{window_id});
    var request = DestroyWindowRequest{ .window_id = window_id };
    std.debug.print("DestroyWindowRequest: {any}\n", .{request});
    try writer.writeAll(&std.mem.toBytes(request));
}

const DestroyWindowRequest = extern struct {
    opcode: u8 = 4,
    length: u16 = @sizeOf(@This()) / 4, // length=2
    window_id: u32,
};

pub fn mapWindowRequest(writer: anytype, window_id: u32) !void {
    std.debug.print("MapWindowRequest {d}\n", .{window_id});
    var request = MapWindowRequest{ .window_id = window_id };
    std.debug.print("MapWindowRequest: {any}\n", .{request});
    try writer.writeAll(&std.mem.toBytes(request));
}

const MapWindowRequest = extern struct {
    opcode: u8 = 8,
    length: u16 = @sizeOf(@This()) / 4, // length=2
    window_id: u32,
};

pub fn unmapWindowRequest(writer: anytype, window_id: u32) !void {
    std.debug.print("UnmapWindowRequest {d}\n", .{window_id});
    var request = UnmapWindowRequest{ .window_id = window_id };
    std.debug.print("UnmapWindowRequest: {any}\n", .{request});
    try writer.writeAll(&std.mem.toBytes(request));
}

const UnmapWindowRequest = extern struct {
    opcode: u8 = 10,
    length: u16 = @sizeOf(@This()) / 4, // length=2
    window_id: u32,
};
