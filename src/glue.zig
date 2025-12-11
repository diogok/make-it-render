pub const Canvas = struct {
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
            .src_bbox = bbox,
            .dst_bbox = bbox,
            .allocator = self.allocator,
        };

        try self.images.append(self.allocator, image);

        return image;
    }

    pub fn createImageScaled(self: *@This(), bbox: anywin.common.BBox) !*Image {
        const img = try self.allocator.create(anywin.Image);
        errdefer self.allocator.destroy(img);

        const width: u16 = @intFromFloat(@as(f16, @floatFromInt(bbox.width)) * self.window.scaling);
        const height: u16 = @intFromFloat(@as(f16, @floatFromInt(bbox.height)) * self.window.scaling);
        const x: i16 = @intFromFloat(@as(f16, @floatFromInt(bbox.x)) * self.window.scaling);
        const y: i16 = @intFromFloat(@as(f16, @floatFromInt(bbox.y)) * self.window.scaling);

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
            .scaled = true,
            .allocator = self.allocator,
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
            try image.draw();
        }
        try self.window.endDraw();
    }
};

pub const Image = struct {
    image: *anywin.Image,
    dst_bbox: anywin.common.BBox,

    src_bbox: anywin.common.BBox,
    scaled: bool = false,

    allocator: std.mem.Allocator,

    pub fn setPixels(self: *@This(), src_reader: *std.Io.Reader) !void {
        if (!self.scaled) {
            try self.image.setPixels(src_reader);
        } else {
            var allocating = std.Io.Writer.Allocating.init(self.allocator);
            defer allocating.deinit();
            const dst_writer = &allocating.writer;

            try nearestNeighbor(
                self.src_bbox.height,
                self.src_bbox.width,
                self.dst_bbox.height,
                self.dst_bbox.width,
                src_reader,
                dst_writer,
                self.allocator,
            );

            var dst_reader = std.Io.Reader.fixed(allocating.written());

            try self.image.setPixels(&dst_reader);
        }
    }

    pub fn setX(self: *@This(), x: anywin.common.X) void {
        self.src_bbox.x = x;
        if (self.scaled) {
            self.dst_bbox.x = @intFromFloat(@as(f32, @floatFromInt(x)) * self.image.window.scaling);
        } else {
            self.dst_bbox.x = x;
        }
    }

    pub fn setY(self: *@This(), y: anywin.common.Y) void {
        self.src_bbox.y = y;
        if (self.scaled) {
            self.dst_bbox.y = @intFromFloat(@as(f32, @floatFromInt(y)) * self.image.window.scaling);
        } else {
            self.dst_bbox.y = y;
        }
    }

    pub fn draw(self: *@This()) !void {
        try self.image.draw(.{
            .x = self.dst_bbox.x,
            .y = self.dst_bbox.y,
            .width = self.dst_bbox.width,
            .height = self.dst_bbox.height,
        });
    }
};

fn nearestNeighbor(
    src_height: anywin.common.Height,
    src_width: anywin.common.Width,
    dst_height: anywin.common.Height,
    dst_width: anywin.common.Width,
    src_reader: *std.Io.Reader,
    dst_writer: *std.Io.Writer,
    allocator: std.mem.Allocator,
) !void {
    const y_ratio: f64 = @as(f64, @floatFromInt(src_height)) / @as(f64, @floatFromInt(dst_height));
    const x_ratio: f64 = @as(f64, @floatFromInt(src_width)) / @as(f64, @floatFromInt(dst_width));

    // Read all source pixels into memory
    const src_size = src_width * src_height * 4;
    const src_pixels = try allocator.alloc(u8, src_size);
    defer allocator.free(src_pixels);

    try src_reader.readSliceAll(src_pixels);

    var pixel: [4]u8 = undefined;

    // Iterate through destination image
    var dst_y: usize = 0;
    while (dst_y < dst_height) : (dst_y += 1) {
        var dst_x: usize = 0;
        while (dst_x < dst_width) : (dst_x += 1) {
            // Find nearest neighbor in source image
            const src_x = @as(usize, @intFromFloat(@as(f32, @floatFromInt(dst_x)) * x_ratio));
            const src_y = @as(usize, @intFromFloat(@as(f32, @floatFromInt(dst_y)) * y_ratio));

            // Calculate source pixel index (RGBA = 4 bytes per pixel)
            const src_idx = (src_y * src_width + src_x) * 4;

            // Copy RGBA values
            pixel[0] = src_pixels[src_idx + 0]; // R
            pixel[1] = src_pixels[src_idx + 1]; // G
            pixel[2] = src_pixels[src_idx + 2]; // B
            pixel[3] = src_pixels[src_idx + 3]; // A

            // Write pixel to output
            try dst_writer.writeAll(&pixel);
        }
    }
}

const std = @import("std");

const anywin = @import("anywindow");
const textz = @import("text");
