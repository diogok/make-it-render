const std = @import("std");
const testing = std.testing;

const fontz = @import("fonts/formats/common.zig");
const terminus = @import("fonts/terminus.zig");

pub const Mask = struct {
    width: u16,
    bitmap: []u1,
};

pub fn render(allocator: std.mem.Allocator, font: fontz.Font, text: []const u8) !Mask {
    var utf8 = try std.unicode.Utf8View.init(text);
    var iter = utf8.iterator();

    var width: u16 = 0;
    var maxHeight: u16 = 0;
    while (iter.nextCodepoint()) |codepoint| {
        const glyph = font.getOrNull(codepoint);

        width += glyph.advance;
        width += glyph.bbox.width;
        maxHeight = @max(maxHeight, glyph.bbox.height);
    }

    iter.i = 0;

    const bitmap = try allocator.alloc(u1, width * maxHeight);

    while (iter.nextCodepoint()) |codepoint| {
        const glyph = font.getOrBlank(codepoint);
        _ = glyph; // autofix
    }

    return Mask{ .width = width, .bitmap = bitmap };
}

test "basic mask" {
    const font = terminus.getFont(testing.allocator, .@"32", .normal);
    defer font.deinit();
    const mask = try render(testing.allocator, font, "hello, world");
    defer testing.allocator.free(mask.bitmap);
}
