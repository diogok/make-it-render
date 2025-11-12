//! Functions to help handle image format for X11.

/// Minimal information to be able to convert to/from an X11 image format.
pub const ImageInfo = struct {
    /// Visual type holds information about how to mask RGB values.
    /// Used to convert from RGB to XPixmap, for example.
    visual_type: proto.VisualType,
    /// Format holds how many bits per pixel, and scanpad value.
    format: proto.Format,
};

/// Given a Setup response, extract needed Image information for working with images.
pub fn getImageInfo(info: xsetup.Setup, root: u32) ImageInfo {
    const target_depth = info.screens[0].root_depth;

    // Find the format of the target root window/display.
    var format_index: usize = 0;
    for (info.formats, 0..) |iformat, index| {
        if (iformat.depth == target_depth) {
            format_index = index;
        }
    }
    const format = info.formats[format_index];

    // Find the screen of the target root window/display.
    // Used to find the allowed_depth.
    var screen_index: usize = 0;
    for (info.screens, 0..) |iscreen, index| {
        if (iscreen.root == root) {
            screen_index = index;
        }
    }
    const screen = info.screens[screen_index];

    // Find the allowed depth of the target root window/display.
    // Used to find the visual type.
    var depth_index: usize = 0;
    for (screen.allowed_depths, 0..) |idepth, index| {
        if (idepth.depth == target_depth) {
            depth_index = index;
        }
    }
    const allowed_depth = screen.allowed_depths[depth_index];

    // Find the visual type of the target root window/display.
    const target_visual_id = screen.root_visual;
    var visual_type_index: usize = 0;
    for (allowed_depth.visual_types, 0..) |ivisual_type, index| {
        if (ivisual_type.visual_id == target_visual_id) {
            visual_type_index = index;
        }
    }
    const visual_type = allowed_depth.visual_types[visual_type_index];

    return .{
        .visual_type = visual_type,
        .format = format,
    };
}

/// Convert an RGBa byte array to a ZPixmap byte array.
/// RGBa format is expected to be in quads of u8.
/// Alpha is ignored.
/// Return a new slice owned by caller.
pub fn rgbaToZPixmapAlloc(allocator: std.mem.Allocator, info: ImageInfo, rgba: []const u8) ![]const u8 {
    const pixels = try allocator.dupe(u8, rgba);
    try rgbaToZPixmapInPlace(info, pixels);
    return pixels;
}

/// Convert an RGBa byte array to a ZPixmap byte array.
/// RGBa format is expected to be in quads of u8.
/// Alpha is ignored.
/// Replaces values in the provided slice.
pub fn rgbaToZPixmapInPlace(info: ImageInfo, pixels: []u8) !void {
    // Only support a very specific visual type and format for now
    if (info.visual_type.class != .TrueColor) {
        return error.UnsupportedVisualTypeClass;
    }
    if (info.format.bits_per_pixel != 32) {
        return error.UnsupportedBitsPerPixel;
    }
    if (info.format.bits_per_pixel != info.format.scanline_pad) {
        return error.UnsupportedScanlinePad;
    }

    rgbaToZPixmap(pixels);
}

fn rgbaToZPixmap(pixels: []u8) void {
    var idx: usize = 0;
    while (idx < pixels.len) : (idx += 4) {
        const b = pixels[idx + 2];
        const g = pixels[idx + 1];
        const r = pixels[idx];
        pixels[idx] = b;
        pixels[idx + 1] = g;
        pixels[idx + 2] = r;
        pixels[idx + 3] = 0;
    }
}

pub const RgbaToZPixmapReader = struct {
    reader: *std.Io.Reader,

    interface_state: std.Io.Reader,

    buffer: [1024]u8 = undefined,

    pub fn init(_: ImageInfo, reader: *std.Io.Reader) @This() {
        return @This(){
            //.buffer = undefined,
            .reader = reader,

            .interface_state = .{
                .vtable = &.{
                    .stream = @This().rgbaToZPixmapStream,
                },
                .buffer = &[0]u8{},
                .end = 0,
                .seek = 0,
            },
        };
    }

    pub fn interface(self: *@This()) *std.Io.Reader {
        return &self.interface_state;
    }

    fn rgbaToZPixmapStream(
        reader: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *@This() = @alignCast(@fieldParentPtr("interface_state", reader));

        var len: usize = 0;
        while (len < limit.toInt().?) {
            const buffer = limit.subtract(len).?.slice(&self.buffer);
            try self.reader.readSliceAll(buffer);
            rgbaToZPixmap(buffer);
            if (buffer.len != 0) {
                try writer.writeAll(buffer);
                len += buffer.len;
            } else {
                break;
            }
        }
        return len;
    }
};

const std = @import("std");
const xsetup = @import("setup.zig");
const proto = @import("proto.zig");

const log = std.log.scoped(.x11);
