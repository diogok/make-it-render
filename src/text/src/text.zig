const std = @import("std");
const testing = std.testing;

const fontz = @import("fontz");
const terminus = @import("fonts").terminus;

pub const Mask = struct {
    allocator: std.mem.Allocator,
    width: u16,
    bitmap: []u1,

    pub fn deinit(self: Mask) void {
        self.allocator.free(self.bitmap);
    }
};

pub fn render(allocator: std.mem.Allocator, font: *fontz.Font, text: []const u8) !Mask {
    var utf8 = try std.unicode.Utf8View.init(text);
    var iter = utf8.iterator();

    var width: u16 = 0;
    var maxHeight: u16 = 0;
    while (iter.nextCodepoint()) |codepoint| {
        const glyph = font.getOrBlank(codepoint);

        width += glyph.advance;
        width += glyph.bbox.width;
        maxHeight = @max(maxHeight, glyph.bbox.height);
    }

    iter.i = 0;

    const bitmap = try allocator.alloc(u1, width * maxHeight);

    var x: usize = 0;
    var y: usize = 0;
    while (iter.nextCodepoint()) |codepoint| {
        const glyph = font.getOrBlank(codepoint);
        for (glyph.bitmap) |bit| {
            x += 1;
            if (x > glyph.bbox.width) {
                x = 0;
                y += 1;
            }
            if (bit == 1) {
                bitmap[y * width + x] = 1;
            }
        }
    }

    return Mask{ .allocator = allocator, .width = width, .bitmap = bitmap };
}

test "basic mask" {
    var font = try terminus.getFont(testing.allocator, .@"32", .normal);
    defer font.deinit();

    const mask = try render(testing.allocator, &font, "hello, world");
    defer mask.deinit();

    const expected: []const u1 = &[_]u1{};

    try testing.expectEqual(expected, mask.bitmap);
}
