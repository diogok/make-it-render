const std = @import("std");

pub const Font = struct {
    allocator: std.mem.Allocator,

    name: []const u8,
    glyphs: Glyphs,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.name);
        free_glyphs(&self.glyphs);
    }
};

pub const Glyph = struct {
    bitmap: []u1,
    width: usize,
    height: usize,
};

pub const Glyphs = std.AutoHashMap(usize, Glyph);

pub fn free_glyphs(glyphs: *Glyphs) void {
    var iter = glyphs.valueIterator();
    while (iter.next()) |glyph| {
        glyphs.allocator.free(glyph.bitmap);
    }
    glyphs.deinit();
}