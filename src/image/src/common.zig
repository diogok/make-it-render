pub const Bitmap = struct {
    width: u16,
    height: u16,
    bitmap: []const u1,

    allocator: std.mem.Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.bitmap);
    }

    pub fn pixelReader(self: *@This(), pixel: []const u8) !PixelReader {
        std.debug.assert(pixel.len == 4);
        return try PixelReader.init(self.allocator, self.bitmap, pixel);
    }
};

const PixelReader = struct {
    allocator: std.mem.Allocator,
    interface: std.Io.Reader,
    buffer: []u8,

    pub fn init(
        allocator: std.mem.Allocator,
        bitmap: []const u1,
        pixel: []const u8,
    ) !@This() {
        std.debug.assert(pixel.len == 4);
        var buffer = try allocator.alloc(u8, bitmap.len * 4);
        for (bitmap, 0..) |b, i| {
            if (b == 1) {
                std.mem.copyForwards(u8, buffer[i * 4 ..], pixel);
            } else {
                std.mem.copyForwards(u8, buffer[i * 4 ..], &[4]u8{ 0, 0, 0, 0 });
            }
        }
        return @This(){
            .allocator = allocator,
            .interface = std.io.Reader.fixed(buffer),
            .buffer = buffer,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.buffer);
    }
};

const std = @import("std");
