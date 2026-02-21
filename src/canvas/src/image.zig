//! A positioned drawable surface within a Canvas.
//! Wraps a platform image with logical and physical bounding boxes,
//! handles DPI scaling via nearest-neighbor, and provides a drawing
//! Context for direct pixel operations.

image: *anywin.Image,
dst_bbox: anywin.common.BBox,

src_bbox: anywin.common.BBox,
scaling: f32 = 1.0,
dirty: bool = true,
z_index: i32 = 0,

allocator: std.mem.Allocator,

/// Set pixel data from an RGBA reader. Applies nearest-neighbor scaling if needed.
pub fn setPixels(self: *@This(), src_reader: *std.Io.Reader) !void {
    self.dirty = true;
    if (self.scaling == 1.0) {
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

/// Set the X position in logical coordinates.
pub fn setX(self: *@This(), x: anywin.common.X) void {
    self.src_bbox.x = x;
    self.dst_bbox.x = if (self.scaling != 1.0) @intFromFloat(@as(f32, @floatFromInt(x)) * self.scaling) else x;
    self.dirty = true;
}

/// Set the Y position in logical coordinates.
pub fn setY(self: *@This(), y: anywin.common.Y) void {
    self.src_bbox.y = y;
    self.dst_bbox.y = if (self.scaling != 1.0) @intFromFloat(@as(f32, @floatFromInt(y)) * self.scaling) else y;
    self.dirty = true;
}

/// Set the z-ordering index. Higher values draw on top.
pub fn setZIndex(self: *@This(), z: i32) void {
    self.z_index = z;
    self.dirty = true;
}

/// Obtain a 2D drawing context for this image.
pub fn getContext(self: *@This()) !Context {
    const Self = @This();
    const flush_target = Context.FlushTarget{
        .ptr = self,
        .flushFn = struct {
            fn f(ptr: *anyopaque, pixels: []const u8) anyerror!void {
                const img: *Self = @ptrCast(@alignCast(ptr));
                var reader = std.Io.Reader.fixed(pixels);
                try img.setPixels(&reader);
            }
        }.f,
    };
    return try Context.init(flush_target, self.src_bbox.width, self.src_bbox.height, self.allocator);
}

/// Draw this image to the window at its current position.
pub fn draw(self: *@This()) !void {
    try self.image.draw(.{
        .x = self.dst_bbox.x,
        .y = self.dst_bbox.y,
        .width = self.dst_bbox.width,
        .height = self.dst_bbox.height,
    });
    self.dirty = false;
}

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

test "nearestNeighbor 2x upscale" {
    const allocator = testing.allocator;

    // 2x2 source image: red, green, blue, white
    const src = [_]u8{
        255, 0, 0, 255, // red
        0, 255, 0, 255, // green
        0, 0, 255, 255, // blue
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
    const allocator = testing.allocator;

    // 2x2 source
    const src = [_]u8{
        1,  2,  3,  4,
        5,  6,  7,  8,
        9,  10, 11, 12,
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
    const allocator = testing.allocator;

    // 4x4 source image
    const src = [_]u8{
        // Row 0
        255, 0, 0, 255, // red
        255, 0, 0, 255, // red
        0, 255, 0, 255, // green
        0, 255, 0, 255, // green
        // Row 1
        255, 0, 0, 255, // red
        255, 0, 0, 255, // red
        0, 255, 0, 255, // green
        0, 255, 0, 255, // green
        // Row 2
        0, 0, 255, 255, // blue
        0, 0, 255, 255, // blue
        255, 255, 255, 255, // white
        255, 255, 255, 255, // white
        // Row 3
        0, 0, 255, 255, // blue
        0, 0, 255, 255, // blue
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

const std = @import("std");
const anywin = @import("anywindow");
const Context = @import("context.zig");
const testing = std.testing;
