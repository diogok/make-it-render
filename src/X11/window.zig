const std = @import("std");

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
    value_masks: []const ValueMask = &[_]ValueMask{},
};

pub const ValueMask = struct {
    mask: WindowAttributes,
    value: u32,
};

pub fn createWindowRequest(writer: anytype, window_id: u32, options: WindowOptions) !void {
    std.debug.print("CreateWindowRequest {d}, options: {any}\n", .{ window_id, options });

    var value_mask: u32 = 0;
    for (options.value_masks) |event_mask| {
        value_mask = value_mask | @intFromEnum(event_mask.mask);
    }

    var value_mask_len: u16 = @intCast(options.value_masks.len);
    var default_length: u16 = @sizeOf(CreateWindowRequest) / 4;

    var request = CreateWindowRequest{
        .depth = options.depth,
        .length = default_length + value_mask_len,
        .window_id = window_id,
        .parent_id = options.parent_window,
        .x = options.x,
        .y = options.y,
        .width = options.width,
        .height = options.height,
        .border_width = options.border_width,
        .window_class = options.window_class,
        .visual_id = options.visual_id,
        .value_mask = value_mask,
    };

    std.debug.print("CreateWindowRequest: {any}\n", .{request});

    try writer.writeAll(&std.mem.toBytes(request));

    for (options.value_masks) |event_mask| {
        try writer.writeAll(&std.mem.toBytes(event_mask.value));
    }
    std.debug.print("CreateWindowRequest sent\n", .{});
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

pub const WindowAttributes = enum(u32) {
    back_pixmap = 1,
    back_pixel = 2,
    border_pixmap = 4,
    border_pixel = 8,
    bit_gravity = 16,
    win_gravity = 32,
    backing_store = 64,
    backing_planes = 128,
    backing_pixel = 256,
    override_redirect = 512,
    save_under = 1024,
    event_mask = 2048,
    dont_propagate = 4096,
    colormap = 8192,
    cursor = 16348,
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
