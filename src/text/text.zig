const std = @import("std");
const fontz = @import("fontz");

pub fn render(allocator: std.mem.Allocator, font: fontz.Font, text: []const u8) ![]u1 {
    const bitmap = std.ArrayList(u1).init(allocator);

    const size:usize = 0;

    for (text) |byte| {
        const glyph = font.get(byte);
        size = size + 
    }

    return try bitmap.toOwnedSlice();
}

pub const PixMap = struct {
    
};

pub const Pix = struct {

};