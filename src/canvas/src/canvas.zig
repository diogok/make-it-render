window: *anywin.Window,
images: std.ArrayList(*Image),
allocator: std.mem.Allocator,

/// Create a new Canvas bound to a window.
pub fn init(allocator: std.mem.Allocator, window: *anywin.Window) @This() {
    return @This(){
        .window = window,
        .images = std.ArrayList(*Image){},
        .allocator = allocator,
    };
}

pub fn deinit(self: *@This()) void {
    for (self.images.items) |image| {
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
    const scaled = scaling != 1.0;

    const width: u16 = if (scaled) @intFromFloat(@as(f16, @floatFromInt(bbox.width)) * scaling) else bbox.width;
    const height: u16 = if (scaled) @intFromFloat(@as(f16, @floatFromInt(bbox.height)) * scaling) else bbox.height;
    const x: i16 = if (scaled) @intFromFloat(@as(f16, @floatFromInt(bbox.x)) * scaling) else bbox.x;
    const y: i16 = if (scaled) @intFromFloat(@as(f16, @floatFromInt(bbox.y)) * scaling) else bbox.y;

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
        .scaled = scaled,
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
    self.allocator.destroy(image.image);
    self.allocator.destroy(image);
}

/// Composite all images onto the window, clearing it first.
pub fn draw(self: *@This()) !void {
    try self.window.beginDraw();
    try self.window.clear(.{});
    for (self.images.items) |image| {
        try image.draw();
    }
    try self.window.endDraw();
}

const std = @import("std");
const anywin = @import("anywindow");
const Image = @import("image.zig");
