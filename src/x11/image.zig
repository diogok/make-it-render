const std = @import("std");
const xsetup = @import("setup.zig");

pub fn rgbaToZPixmapAlloc(_: std.mem.Allocator, info: xsetup.Setup, rgba: []const u8) ![]const u8 {
    const target_depth = info.screens[0].root_depth;

    var format_index: usize = 0;
    for (info.formats, 0..) |iformat, index| {
        if (iformat.depth == target_depth) {
            format_index = index;
        }
    }
    const format = info.formats[format_index];
    std.debug.print("Format: {any}\n", .{format});

    var depth_index: usize = 0;
    for (info.screens[0].allowed_depths, 0..) |idepth, index| {
        if (idepth.depth == target_depth) {
            depth_index = index;
        }
    }
    const allowed_depth = info.screens[0].allowed_depths[depth_index];
    const depth = allowed_depth.depth;

    const target_visual_id = info.screens[0].root_visual;
    var visual_type_index: usize = 0;
    for (allowed_depth.visual_types, 0..) |ivisual_type, index| {
        if (ivisual_type.visual_id == target_visual_id) {
            visual_type_index = index;
        }
    }
    const visual_type = allowed_depth.visual_types[visual_type_index];
    std.debug.print("VisualType: {any}\n", .{visual_type});

    return rgba;
}
