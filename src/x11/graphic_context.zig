const std = @import("std");

// TODO: logger

pub const GraphicContextOptions = struct {
    drawable_id: u32 = 0,
    value_mask: []const ValueMask = &[_]ValueMask{},
};

pub const ValueMask = struct {
    mask: GraphicContextAttribute,
    value: u32,
};

pub fn createGraphicContext(writer: anytype, graphic_context_id: u32, options: GraphicContextOptions) !void {
    std.debug.print("createGraphicContext {d}, options: {any}\n", .{ graphic_context_id, options });

    var value_mask: u32 = 0;
    for (options.value_mask) |event_mask| {
        value_mask = value_mask | @intFromEnum(event_mask.mask);
    }

    const value_mask_len: u16 = @intCast(options.value_mask.len);
    const default_length: u16 = @sizeOf(CreateGraphicContextRequest) / 4;

    const request = CreateGraphicContextRequest{
        .length = default_length + value_mask_len,
        .graphic_context_id = graphic_context_id,
        .drawable_id = options.drawable_id,
        .value_mask = value_mask,
    };

    std.debug.print("createGraphicContextRequest: {any}\n", .{request});

    try writer.writeAll(&std.mem.toBytes(request));

    for (options.value_mask) |event_mask| {
        try writer.writeAll(&std.mem.toBytes(event_mask.value));
    }

    std.debug.print("createGraphicContextRequest sent\n", .{});
}

const CreateGraphicContextRequest = extern struct {
    opcode: u8 = 55,
    pad: u8 = 0,
    length: u16 = (@sizeOf(@This()) / 4),
    graphic_context_id: u32,
    drawable_id: u32,
    value_mask: u32 = 0,
};

pub const GraphicContextAttribute = enum(u32) {
    Nothig,
};

pub fn freeGraphicContext(writer: anytype, graphic_context_id: u32) !void {
    std.debug.print("FreeGraphicContextRequest {d}\n", .{graphic_context_id});
    const request = FreeGraphicContextRequest{ .graphic_context_id = graphic_context_id };
    std.debug.print("FreeGraphicContextRequest: {any}\n", .{request});
    try writer.writeAll(&std.mem.toBytes(request));
}

const FreeGraphicContextRequest = extern struct {
    opcode: u8 = 60,
    pad0: u8 = 0,
    length: u16 = @sizeOf(@This()) / 4, // length=2
    graphic_context_id: u32,
};
