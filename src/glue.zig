pub const Canvas = struct {
    pub const Image = struct {
        image: *anywin.Image,
        bbox: anywin.common.BBox,
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

    pub fn createImage(self: *@This(), bbox: anywin.common.BBox) !*Image {
        const img = try self.allocator.create(anywin.Image);
        errdefer self.allocator.destroy(img);

        img.* = try self.window.createImage(.{ .width = bbox.width, .height = bbox.height });
        try self.window.wm.flush();

        const image = try self.allocator.create(Image);
        image.* = Image{
            .image = img,
            .bbox = bbox,
        };

        try self.images.append(self.allocator, image);

        return image;
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
    }
};

const std = @import("std");

const anywin = @import("anywindow");
const textz = @import("textz");
const canvas = @import("canvas");
