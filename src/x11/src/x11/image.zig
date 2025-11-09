//! Functions to help handle image format for X11.

const std = @import("std");
const xsetup = @import("setup.zig");
const proto = @import("proto.zig");

const log = std.log.scoped(.x11);

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
pub fn rgbaToZPixmapAlloc(allocator: std.mem.Allocator, info: ImageInfo, rgba: []const u8) ![]const u8 {
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

    const pixels = try allocator.alloc(u8, rgba.len);
    var idx: usize = 0;
    while (idx < rgba.len) : (idx += 4) {
        pixels[idx] = rgba[idx + 2];
        pixels[idx + 1] = rgba[idx + 1];
        pixels[idx + 2] = rgba[idx];
        pixels[idx + 3] = 0;
    }

    return pixels;
}

/// Convert an RGBa byte array to a ZPixmap byte array.
/// RGBa format is expected to be in quads of u8.
/// Alpha is ignored.
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

    return pixels;
}
