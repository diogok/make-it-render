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

test "nearestNeighbor 2x upscale" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // 2x2 source image: red, green, blue, white
    const src = [_]u8{
        255, 0,   0,   255, // red
        0,   255, 0,   255, // green
        0,   0,   255, 255, // blue
        255, 255, 255, 255, // white
    };

    var src_reader = std.Io.Reader.fixed(&src);
    var allocating = std.Io.Writer.Allocating.init(allocator);
    defer allocating.deinit();
    const dst_writer = &allocating.writer;

    // Scale 2x2 -> 4x4
    try nearestNeighbor(2, 2, 4, 4, &src_reader, dst_writer, allocator);

    const result = allocating.written();
    // 4x4 = 16 pixels * 4 bytes = 64 bytes
    try testing.expectEqual(@as(usize, 64), result.len);

    // Top-left quadrant should be red (first pixel repeated)
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 0, 255 }, result[0..4]); // (0,0)
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 0, 255 }, result[4..8]); // (1,0)
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 0, 255 }, result[16..20]); // (0,1)
}

test "nearestNeighbor identity (no scaling)" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // 2x2 source
    const src = [_]u8{
        1, 2, 3, 4,
        5, 6, 7, 8,
        9, 10, 11, 12,
        13, 14, 15, 16,
    };

    var src_reader = std.Io.Reader.fixed(&src);
    var allocating = std.Io.Writer.Allocating.init(allocator);
    defer allocating.deinit();
    const dst_writer = &allocating.writer;

    // Same size: 2x2 -> 2x2
    try nearestNeighbor(2, 2, 2, 2, &src_reader, dst_writer, allocator);

    const result = allocating.written();
    try testing.expectEqualSlices(u8, &src, result);
}

test "nearestNeighbor 2x downscale" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // 4x4 source image
    const src = [_]u8{
        // Row 0
        255, 0,   0,   255, // red
        255, 0,   0,   255, // red
        0,   255, 0,   255, // green
        0,   255, 0,   255, // green
        // Row 1
        255, 0,   0,   255, // red
        255, 0,   0,   255, // red
        0,   255, 0,   255, // green
        0,   255, 0,   255, // green
        // Row 2
        0,   0,   255, 255, // blue
        0,   0,   255, 255, // blue
        255, 255, 255, 255, // white
        255, 255, 255, 255, // white
        // Row 3
        0,   0,   255, 255, // blue
        0,   0,   255, 255, // blue
        255, 255, 255, 255, // white
        255, 255, 255, 255, // white
    };

    var src_reader = std.Io.Reader.fixed(&src);
    var allocating = std.Io.Writer.Allocating.init(allocator);
    defer allocating.deinit();
    const dst_writer = &allocating.writer;

    // Scale 4x4 -> 2x2
    try nearestNeighbor(4, 4, 2, 2, &src_reader, dst_writer, allocator);

    const result = allocating.written();
    // 2x2 = 4 pixels * 4 bytes = 16 bytes
    try testing.expectEqual(@as(usize, 16), result.len);

    // Should sample corners: red, green, blue, white
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 0, 255 }, result[0..4]); // red
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 255, 0, 255 }, result[4..8]); // green
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 255, 255 }, result[8..12]); // blue
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 255, 255, 255 }, result[12..16]); // white
}

test "nearestNeighbor single pixel upscale" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // 1x1 source
    const src = [_]u8{ 128, 64, 32, 255 };

    var src_reader = std.Io.Reader.fixed(&src);
    var allocating = std.Io.Writer.Allocating.init(allocator);
    defer allocating.deinit();
    const dst_writer = &allocating.writer;

    // Scale 1x1 -> 3x3
    try nearestNeighbor(1, 1, 3, 3, &src_reader, dst_writer, allocator);

    const result = allocating.written();
    // 3x3 = 9 pixels * 4 bytes = 36 bytes
    try testing.expectEqual(@as(usize, 36), result.len);

    // All pixels should be the same color
    var i: usize = 0;
    while (i < 9) : (i += 1) {
        try testing.expectEqualSlices(u8, &src, result[i * 4 .. i * 4 + 4]);
    }
}
