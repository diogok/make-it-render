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
    std.debug.print("Setup Reply\n", .{});

    const status_reply = try reader.readStruct(StatusReply);
    std.debug.print("Setup status {any}\n", .{status_reply});

    const reply = try allocator.alloc(u8, status_reply.reply_len * 4);
    defer allocator.free(reply);
    const read_len = try reader.read(reply); // read rest of response
    std.debug.print("Read from rest of reply {d}\n", .{read_len});

    switch (status_reply.status) {
        0 => return error.SetupFailed,
        1 => {}, // success, continue
        2 => return error.AuthenticationFailed,
        else => return error.InvalidSetupStatus,
    }

    var reply_stream = std.io.fixedBufferStream(reply);
    var reply_reader = reply_stream.reader();
    std.debug.print("Reply len: {d}\n", .{reply.len});

    const base_reply = try reply_reader.readStruct(SetupReply);
    std.debug.print("Reply base: {any}\n", .{base_reply});

    const vendor = try allocator.alloc(u8, base_reply.vendor_len);
    defer allocator.free(vendor);
    _ = try reply_reader.read(vendor);
    _ = try reply_reader.skipBytes(vendor.len % 4, .{}); // pad vendor

    const formats = try allocator.alloc(Format, base_reply.pixmap_formats_len);
    for (formats, 0..) |_, format_index| {
        const format_reply = try reply_reader.readStruct(FormatReply);
        formats[format_index] = Format.initFromReply(format_reply);
    }

    const screens = try allocator.alloc(Screen, base_reply.roots_len);
    for (screens, 0..) |_, screen_index| {
        const root_reply = try reply_reader.readStruct(RootReply);
        screens[screen_index] = Screen.initFromReply(root_reply);

        const allowed_depths = try allocator.alloc(Depth, root_reply.allowed_depths_len);
        for (allowed_depths, 0..) |_, depth_index| {
            const depth_reply = try reply_reader.readStruct(DepthReply);
            allowed_depths[depth_index] = Depth.initFromReply(depth_reply);

            const visual_types = try allocator.alloc(VisualType, depth_reply.visual_type_len);
            for (visual_types, 0..) |_, visual_type_index| {
                const visual_type_reply = try reply_reader.readStruct(VisualTypeReply);
                visual_types[visual_type_index] = VisualType.initFromReply(visual_type_reply);
            }
        }
    }

    var result = Setup.initFromReply(allocator, base_reply);
    result.screens = screens;
    result.formats = formats;

    std.debug.print("Setup reply: {any}\n", .{result});

    return result;
}

const StatusReply = extern struct {
    status: u8,
    pad: u8,
    major_version: u16,
    minor_version: u16,
    reply_len: u16,
};

const SetupReply = extern struct {
    release_number: u32,
    resource_id_base: u32,
    resource_id_mask: u32,
    motion_buffer_size: u32,
    vendor_len: u16,
    maximum_request_length: u16,
    roots_len: u8,
    pixmap_formats_len: u8,
    image_byte_order: ImageByteOrder,
    bitmap_format_bit_order: BitmapFormatBitOrder,
    bitmap_format_scanline_unit: u8,
    bitmap_format_scanline_pad: u8,
    min_keycode: u8,
    max_keycode: u8,
    pad: [4]u8,
};

pub const ImageByteOrder = enum(u8) {
    LSBFirst = 0,
    MSBFirst = 1,
};

pub const BitmapFormatBitOrder = enum(u8) {
    LeastSignificant = 0,
    MostSignificant = 1,
};

pub const Setup = struct {
    allocator: std.mem.Allocator,

    resource_id_base: u32,
    resource_id_mask: u32,

    maximum_request_length: u16,

    min_keycode: u8,
    max_keycode: u8,

    image_byte_order: ImageByteOrder,
    bitmap_format_bit_order: BitmapFormatBitOrder,
    bitmap_format_scanline_unit: u8,
    bitmap_format_scanline_pad: u8,

    formats: []const Format = &[_]Format{},
    screens: []const Screen = &[_]Screen{},

    pub fn initFromReply(allocator: std.mem.Allocator, reply: SetupReply) @This() {
        return .{
            .allocator = allocator,
            .resource_id_base = reply.resource_id_base,
            .resource_id_mask = reply.resource_id_mask,
            .maximum_request_length = reply.maximum_request_length,
            .min_keycode = reply.min_keycode,
            .max_keycode = reply.max_keycode,
            .image_byte_order = reply.image_byte_order,
            .bitmap_format_bit_order = reply.bitmap_format_bit_order,
            .bitmap_format_scanline_unit = reply.bitmap_format_scanline_unit,
            .bitmap_format_scanline_pad = reply.bitmap_format_scanline_pad,
        };
    }

    pub fn deinit(self: @This()) void {
        for (self.screens) |screen| {
            screen.deinit(self.allocator);
        }
        self.allocator.free(self.screens);
        self.allocator.free(self.formats);
    }
};

const FormatReply = extern struct {
    depth: u8,
    bits_per_pixel: u8,
    scanline_pad: u8,
    pad: [5]u8,
};

pub const Format = struct {
    depth: u8,
    bits_per_pixel: u8,
    scanline_pad: u8,

    pub fn initFromReply(reply: FormatReply) @This() {
        return .{
            .depth = reply.depth,
            .bits_per_pixel = reply.bits_per_pixel,
            .scanline_pad = reply.scanline_pad,
        };
    }
};

const RootReply = extern struct {
    root: u32,
    colormap: u32,
    white_pixel: u32,
    black_pixel: u32,

    current_input_masks: u32,
    width_in_pixels: u16,
    height_in_pixels: u16,
    width_in_millimeters: u16,
    height_in_millimeters: u16,
    min_installed_maps: u16,
    max_installed_maps: u16,

    root_visual: u32,

    backing_stores: u8,
    save_unders: u8,

    root_depth: u8,
    allowed_depths_len: u8,
};

pub const Screen = struct {
    root: u32,
    colormap: u32,
    white_pixel: u32,
    black_pixel: u32,
    root_visual: u32,
    root_depth: u8,
    allowed_depths: []const Depth = &[_]Depth{},

    pub fn initFromReply(reply: RootReply) @This() {
        return .{
            .root = reply.root,
            .colormap = reply.colormap,
            .white_pixel = reply.white_pixel,
            .black_pixel = reply.black_pixel,
            .root_visual = reply.root_visual,
            .root_depth = reply.root_depth,
        };
    }

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.allowed_depths);
        for (self.allowed_depths) |depth| {
            depth.deinit(allocator);
        }
    }
};

const DepthReply = extern struct {
    depth: u8,
    pad0: [1]u8,
    visual_type_len: u16,
    pad1: [4]u8,
};

const Depth = struct {
    depth: u8,
    visual_types: []VisualType = &[_]VisualType{},

    pub fn initFromReply(reply: DepthReply) @This() {
        return .{
            .depth = reply.depth,
        };
    }

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.visual_types);
    }
};

const VisualTypeReply = extern struct {
    visual_id: u32,
    class: VisualTypeClass,
    bits_per_rgb_value: u8,
    colormap_entries: u16,
    red_mask: u32,
    green_mask: u32,
    blue_mask: u32,
    pad: [4]u8,
};

const VisualTypeClass = enum(u8) {
    StaticGray = 0,
    GrayScale = 1,
    StaticColor = 2,
    PseudoColor = 3,
    TrueColor = 4,
    DirectColor = 5,
};

const VisualType = struct {
    visual_id: u32,
    class: VisualTypeClass,
    bits_per_rgb_value: u8,
    colormap_entries: u16,
    red_mask: u32,
    green_mask: u32,
    blue_mask: u32,

    pub fn initFromReply(reply: VisualTypeReply) @This() {
        return .{
            .visual_id = reply.visual_id,
            .class = reply.class,
            .bits_per_rgb_value = reply.bits_per_rgb_value,
            .colormap_entries = reply.colormap_entries,
            .red_mask = reply.red_mask,
            .green_mask = reply.green_mask,
            .blue_mask = reply.blue_mask,
        };
    }
};
