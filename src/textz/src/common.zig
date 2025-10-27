pub const Font = struct {
    allocator: std.mem.Allocator,

    glyphs: *GlyphMap,

    ascent: u16 = 0,
    width: u16 = 0,
    height: u16 = 0,

    count: u32 = 0,

    buffer: []u8,

    pub fn deinit(self: @This()) void {
        //var iter = self.glyphs.valueIterator();
        //while (iter.next()) |glyph| {
        //self.allocator.free(glyph.bitmap);
        //}
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

    pub fn deinit(self: @This()) void {
        self.allocator.free(self.bitmap);
    }
};

const std = @import("std");
