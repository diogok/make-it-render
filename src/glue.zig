pub fn bitsToColor(
    allocator: std.mem.Allocator,
    color: [3]u8,
    bits: []const u1,
) ![]const u8 {
    const pixels = try allocator.alloc(u8, bits.len * 4);
    var pos: usize = 0;
    for (bits) |bit| {
        if (bit == 1) {
            pixels[pos] = color[0];
            pixels[pos + 1] = color[1];
            pixels[pos + 2] = color[2];
            pixels[pos + 3] = 1;
        } else {
            pixels[pos] = 0;
            pixels[pos + 1] = 0;
            pixels[pos + 2] = 0;
            pixels[pos + 3] = 0;
        }
        pos += 4;
    }
    return pixels;
}

pub fn drawCanvasToWindows(tiles: *canvas.TileMap, window: *anywin.Window) !void {
    var tile_iter = tiles.iterator(null);
    while (tile_iter.next()) |tile| {
        if (!tile.dirty) {
            continue;
        }
        tile.dirty = false;
        const img = try window.createImage(
            .{
                .height = tile.bbox.height,
                .width = tile.bbox.width,
            },
            tile.pixels,
        );
        try img.draw(.{
            .x = tile.bbox.x,
            .y = tile.bbox.y,
            .height = tile.bbox.height,
            .width = tile.bbox.width,
        });
        try img.deinit();
    }
    try window.wm.flush();
}

pub const Canvas = struct {
    pub const Image = struct {
        image: *anywin.Image,
        bbox: anywin.common.BBox,
        pixels: []const u8,
    };

    window: *anywin.Window,
    images: std.ArrayList(*Image),
    allocator: std.mem.Allocator,

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

    pub fn createImage(self: *@This(), bbox: anywin.common.BBox, pixels: []const u8) !*Image {
        const img = try self.allocator.create(anywin.Image);
        errdefer self.allocator.destroy(img);

        img.* = try self.window.createImage(
            .{ .width = bbox.width, .height = bbox.height },
            pixels,
        );
        try self.window.wm.flush();

        const image = try self.allocator.create(Image);
        image.* = Image{
            .image = img,
            .bbox = bbox,
            .pixels = pixels,
        };

        try self.images.append(self.allocator, image);

        return image;
    }

    pub fn updateImage(self: *@This(), image: *Image) !void {
        try image.image.setPixels(image.pixels);
        try self.window.wm.flush();
    }

    pub fn removeImage(self: *@This(), image: *Image) void {
        _ = self;
        _ = image;
    }

    pub fn draw(self: *@This()) !void {
        try self.window.beginDraw();
        try self.window.clear(.{});
        for (self.images.items) |image| {
            try image.image.draw(.{
                .x = image.bbox.x,
                .y = image.bbox.y,
                .width = image.bbox.width,
                .height = image.bbox.height,
            });
        }
        try self.window.endDraw();
        //try self.window.wm.flush();
    }
};

const std = @import("std");

const anywin = @import("anywindow");
const textz = @import("textz");
const canvas = @import("canvas");
