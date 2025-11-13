pub const Font = struct {
    allocator: std.mem.Allocator,

    glyphs: *GlyphMap,

    ascent: u16 = 0,
    width: u16 = 0,
    height: u16 = 0,

    count: u32 = 0,

    buffer: []u8,

    pub fn deinit(self: @This()) void {
        self.allocator.free(self.buffer);
        self.glyphs.deinit(self.allocator);
        self.allocator.destroy(self.glyphs);
    }

    pub fn get(self: @This(), codepoint: u21) ?Glyph {
        return self.glyphs.get(codepoint);
    }

    pub fn getOrBlank(self: @This(), codepoint: u21) Glyph {
        if (self.glyphs.get(codepoint)) |glyph| {
            return glyph;
        }
        return self.glyphs.get(0).?;
    }
};

pub const GlyphMap = std.AutoHashMapUnmanaged(u32, Glyph);

pub const Glyph = struct {
    encoding: u21,
    bitmap: []const u1,
    advance: u8,
    bbox: BBox,
};

pub const BBox = struct {
    width: u8,
    height: u8,
    x: i8,
    y: i8,
};

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
