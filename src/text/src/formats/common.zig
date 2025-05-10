const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

pub const BBox = struct {
    width: u8,
    height: u8,
    x: i8,
    y: i8,
};

pub const Glyph = struct {
    bitmap: []u1,
    advance: u8,
    bbox: BBox,
};

pub const GlyphMap = std.AutoHashMapUnmanaged(u32, Glyph);

pub const Font = struct {
    allocator: std.mem.Allocator,
    glyphs: GlyphMap,

    pub fn deinit(self: *@This()) void {
        var iter = self.glyphs.valueIterator();
        while (iter.next()) |glyph| {
            self.allocator.free(glyph.bitmap);
        }
        self.glyphs.deinit(self.allocator);
    }

    pub fn get(self: *@This(), codepoint: u21) ?Glyph {
        return self.glyphs.get(codepoint);
    }

    pub fn getOrBlank(self: *@This(), codepoint: u21) Glyph {
        return self.glyphs.get(codepoint) or self.glyphs.get(0).?;
    }
};
