window: *anywin.Window,
images: std.ArrayList(*Image),
allocator: std.mem.Allocator,

/// Create a new Canvas bound to a window.
pub fn init(allocator: std.mem.Allocator, window: *anywin.Window) @This() {
    return .{
        .window = window,
        .images = .{},
        .allocator = allocator,
    };
}

pub fn deinit(self: *@This()) void {
    for (self.images.items) |image| {
        image.image.deinit();
        self.allocator.destroy(image.image);
        self.allocator.destroy(image);
    }
    self.images.deinit(self.allocator);
}

/// Create a new Image at the given bounding box. Automatically applies
/// DPI scaling when the window has a scaling factor other than 1.0.
pub fn createImage(self: *@This(), bbox: anywin.common.BBox) !*Image {
    const img = try self.allocator.create(anywin.Image);
    errdefer self.allocator.destroy(img);

    const scaling = self.window.scaling;

    const width: u16 = if (scaling != 1.0) @intFromFloat(@as(f16, @floatFromInt(bbox.width)) * scaling) else bbox.width;
    const height: u16 = if (scaling != 1.0) @intFromFloat(@as(f16, @floatFromInt(bbox.height)) * scaling) else bbox.height;
    const x: i16 = if (scaling != 1.0) @intFromFloat(@as(f16, @floatFromInt(bbox.x)) * scaling) else bbox.x;
    const y: i16 = if (scaling != 1.0) @intFromFloat(@as(f16, @floatFromInt(bbox.y)) * scaling) else bbox.y;

    img.* = try self.window.createImage(.{ .width = width, .height = height });
    try self.window.wm.flush();

    const image = try self.allocator.create(Image);
    image.* = Image{
        .image = img,
        .src_bbox = bbox,
        .dst_bbox = .{
            .width = width,
            .height = height,
            .x = x,
            .y = y,
        },
        .scaling = scaling,
        .allocator = self.allocator,
    };

    try self.images.append(self.allocator, image);

    return image;
}

/// Remove an Image from the canvas and free its resources.
pub fn removeImage(self: *@This(), image: *Image) void {
    for (self.images.items, 0..) |img, i| {
        if (img == image) {
            _ = self.images.swapRemove(i);
            break;
        }
    }
    image.image.deinit();
    self.allocator.destroy(image.image);
    self.allocator.destroy(image);
}

/// Composite all images onto the window, clearing it first.
/// Skips the draw if no images are dirty.
pub fn draw(self: *@This()) !void {
    try self.window.beginDraw();
    var any_dirty = false;
    for (self.images.items) |image| {
        if (image.dirty) {
            any_dirty = true;
            break;
        }
    }
    if (any_dirty) {
        std.sort.block(*Image, self.images.items, {}, struct {
            fn lessThan(_: void, a: *Image, b: *Image) bool {
                return a.z_index < b.z_index;
            }
        }.lessThan);
        try self.window.clear(.{});
        for (self.images.items) |image| {
            try image.draw();
        }
    }
    try self.window.endDraw();
}

const std = @import("std");
const anywin = @import("anywindow");
const Image = @import("image.zig");
