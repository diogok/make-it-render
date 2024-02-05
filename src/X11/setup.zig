const std = @import("std");
const endian = @import("builtin").cpu.arch.endian();
const xauth = @import("auth.zig");

pub fn setup(allocator: std.mem.Allocator, connection: std.net.Stream) !Setup {
    const auth = try xauth.get_auth(allocator);
    defer auth.deinit();

    const reader = connection.reader();

    try setupRequest(connection, auth.name, auth.data);
    const xdata = try setupReply(allocator, reader);

    return xdata;
}

fn setupRequest(writer: anytype, auth_name: []const u8, auth_data: []const u8) !void {
    const request_base = SetupRequest{
        .auth_name_len = @intCast(auth_name.len),
        .auth_data_len = @intCast(auth_data.len),
    };
    try writer.writeAll(&std.mem.toBytes(request_base));

    const pad: [3]u8 = .{ 0, 0, 0 };
    try writer.writeAll(auth_name);
    try writer.writeAll(pad[0..(auth_name.len % 4)]);

    try writer.writeAll(auth_data);
    try writer.writeAll(pad[0..(auth_data.len % 4)]);
}

const SetupRequest = extern struct {
    byte_order: u8 = switch (endian) {
        .big => 'B',
        .little => 'l',
    },
    pad0: u8 = 0,
    protocol_major_version: u16 = 11,
    procotol_minor_version: u16 = 0,
    auth_name_len: u16,
    auth_data_len: u16,
    pad1: u16 = 0,
};

fn setupReply(allocator: std.mem.Allocator, reader: anytype) !Setup {
    std.debug.print("Reply Setup\n", .{});
    const status: u8 = try reader.readByte();
    std.debug.print("Setup status: {d}\n", .{status});

    try reader.skipBytes(1, .{}); // skip padding

    const major = try reader.readInt(u16, endian);
    const minor = try reader.readInt(u16, endian);
    std.debug.print("Major: {d}, Minor: {d}\n", .{ major, minor });

    const reply_len = try reader.readInt(u16, endian); // size of rest of data
    std.debug.print("Size of response: {d} * 4 = {d}\n", .{ reply_len, reply_len * 4 });

    const reply = try allocator.alloc(u8, reply_len * 4);
    defer allocator.free(reply);
    const read_len = try reader.read(reply); // read rest of response
    std.debug.print("Read from reply {d}\n", .{read_len});

    switch (status) {
        0 => return error.SetupFailed,
        1 => {}, // success, continue
        2 => return error.AuthenticationFailed,
        else => return error.InvalidSetupStatus,
    }

    var reply_stream = std.io.fixedBufferStream(reply);
    var reply_reader = reply_stream.reader();
    std.debug.print("Reply len: {d}\n", .{reply.len});

    _ = try reply_reader.readInt(u32, endian); // skip release_number

    const resource_id_base = try reply_reader.readInt(u32, endian);
    const resource_id_mask = try reply_reader.readInt(u32, endian);

    _ = try reply_reader.readInt(u32, endian); // skip motion_buffer_size
    const vendor_len = try reply_reader.readInt(u16, endian);

    const maximum_request_length = try reply_reader.readInt(u16, endian);
    const roots_len = try reply_reader.readInt(u8, endian);
    const pixmap_formats_len = try reply_reader.readInt(u8, endian);

    _ = try reply_reader.readInt(u8, endian); // image_byte_order
    _ = try reply_reader.readInt(u8, endian); // bitmap_format_bit_order
    _ = try reply_reader.readInt(u8, endian); // bitmap_format_scanline_unit
    _ = try reply_reader.readInt(u8, endian); // bitmap_format_scanline_pad

    const min_keycode = try reply_reader.readInt(u8, endian);
    const max_keycode = try reply_reader.readInt(u8, endian);

    try reply_reader.skipBytes(4, .{}); // padding
    try reply_reader.skipBytes(vendor_len, .{}); // skip vendor

    // FORMAT: { depth: u8, bits_per_pixel: u8, scanline_pad: u8: pad:[5]u8}
    try reply_reader.skipBytes(pixmap_formats_len * 8, .{}); // skip pixmap

    if (roots_len == 0) {
        return error.NoRootScreen;
    }

    std.debug.print("Roots len {d}\n", .{roots_len});

    const root = try reply_reader.readInt(u32, endian);
    const colormap = try reply_reader.readInt(u32, endian);
    const white_pixel = try reply_reader.readInt(u32, endian);
    const black_pixel = try reply_reader.readInt(u32, endian);

    _ = try reply_reader.readInt(u32, endian); // current_input_masks
    _ = try reply_reader.readInt(u16, endian); // width_in_pixels
    _ = try reply_reader.readInt(u16, endian); // height_in_pixels
    _ = try reply_reader.readInt(u16, endian); // width_in_millimeters
    _ = try reply_reader.readInt(u16, endian); // height_in_millimeters
    _ = try reply_reader.readInt(u16, endian); // min_installed_maps
    _ = try reply_reader.readInt(u16, endian); // max_installed_maps

    const root_visual = try reply_reader.readInt(u32, endian);

    _ = try reply_reader.readInt(u8, endian); // backing_stores
    _ = try reply_reader.readInt(u8, endian); // save_unders

    const root_depth = try reply_reader.readInt(u8, endian);
    const allowed_depths_len = try reply_reader.readInt(u8, endian);
    try reply_reader.skipBytes(allowed_depths_len, .{}); // skip allowed_depths

    // TODO: read rest of screens

    const result = Setup{
        .resource_id_base = resource_id_base,
        .resource_id_mask = resource_id_mask,
        .maximum_request_length = maximum_request_length,
        .min_keycode = min_keycode,
        .max_keycode = max_keycode,
        .screen = Screen{
            .root = root,
            .colormap = colormap,
            .white_pixel = white_pixel,
            .black_pixel = black_pixel,
            .root_visual = root_visual,
            .root_depth = root_depth,
        },
    };

    std.debug.print("Setup reply: {any}\n", .{result});

    return result;
}

pub const Setup = struct {
    resource_id_base: u32,
    resource_id_mask: u32,
    maximum_request_length: u16,
    min_keycode: u8,
    max_keycode: u8,
    screen: Screen,
};

pub const Screen = struct {
    root: u32,
    colormap: u32,
    white_pixel: u32,
    black_pixel: u32,
    root_visual: u32,
    root_depth: u8,
};
