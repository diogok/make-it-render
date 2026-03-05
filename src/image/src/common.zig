pub const Bitmap = struct {
    width: u16,
    height: u16,
    bitmap: []const u1,

    allocator: std.mem.Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.bitmap);
    }

    pub fn toRgba(self: *@This(), allocator: std.mem.Allocator, pixel: []const u8) ![]u8 {
        return bitmapToRgba(allocator, self.bitmap, pixel);
    }
};

pub fn bitmapToRgba(allocator: std.mem.Allocator, bitmap: []const u1, pixel: []const u8) ![]u8 {
    std.debug.assert(pixel.len == 4);
    const buffer = try allocator.alloc(u8, bitmap.len * 4);
    for (bitmap, 0..) |b, i| {
        if (b == 1) {
            @memcpy(buffer[i * 4 ..][0..4], pixel);
        } else {
            @memcpy(buffer[i * 4 ..][0..4], &[4]u8{ 0, 0, 0, 0 });
        }
    }
    return buffer;
}

const std = @import("std");
