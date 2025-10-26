pub fn render(
    allocator: std.mem.Allocator,
    fonts: []const common.Font,
    text: []const u8,
) !common.Bitmap {
    var width: u16 = 0;
    var height: u16 = 0;
    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };

    // iterate to get the size of the text
    while (iter.nextCodepoint()) |char| {
        const glyph = findGlyph(fonts, char);
        width += glyph.advance;
        height = @max(height, glyph.bbox.height);
    }
    iter.i = 0;

    const bitmap = try allocator.alloc(u1, width * height);

    // now "render" to the bitmap
    var global_x: u16 = 0;
    while (iter.nextCodepoint()) |char| {
        const glyph = findGlyph(fonts, char);

        var row: u16 = 0;
        while (row < glyph.bbox.height) : (row += 1) {
            var col: u16 = 0;
            while (col < glyph.bbox.width) : (col += 1) {
                const g_index = (row * glyph.bbox.width) + col;
                if (glyph.bitmap[g_index] == 1) {
                    bitmap[(global_x + col) + (row * width)] = 1;
                }
            }
        }

        global_x += glyph.advance;
    }

    return common.Bitmap{
        .allocator = allocator,
        .width = width,
        .height = height,
        .bitmap = bitmap,
    };
}

test "Render a short phrase" {
    const uni = try @import("fonts/unifont.zig").unifont(testing.allocator);
    defer uni.deinit();

    const text = "I, am!";
    const result = try render(testing.allocator, &[_]common.Font{uni}, text);
    defer result.deinit();

    try testing.expectEqual(48, result.width);
    try testing.expectEqual(16, result.height);

    const x = 1;
    const expected: []const u1 = &[_]u1{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 0..47
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 48..97
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 96..143
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 144..198
        0, 0, x, x, x, x, x, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, x, 0, 0, 0, // 192..239
        0, 0, 0, 0, x, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, x, 0, 0, 0, // 240..287
        0, 0, 0, 0, x, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, x, x, x, x, 0, 0, 0, x, x, x, 0, x, x, 0, 0, 0, 0, 0, x, 0, 0, 0, // 288..335
        0, 0, 0, 0, x, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, x, 0, 0, 0, 0, x, 0, 0, x, 0, 0, x, 0, 0, x, 0, 0, 0, 0, x, 0, 0, 0, // 336..383
        0, 0, 0, 0, x, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, x, 0, 0, x, 0, 0, x, 0, 0, x, 0, 0, 0, 0, x, 0, 0, 0, // 384..431
        0, 0, 0, 0, x, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, x, x, x, x, x, 0, 0, x, 0, 0, x, 0, 0, x, 0, 0, 0, 0, x, 0, 0, 0, // 432..479
        0, 0, 0, 0, x, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, x, 0, 0, 0, 0, x, 0, 0, x, 0, 0, x, 0, 0, x, 0, 0, 0, 0, x, 0, 0, 0, // 480..527
        0, 0, 0, 0, x, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, x, 0, 0, 0, 0, x, 0, 0, x, 0, 0, x, 0, 0, x, 0, 0, 0, 0, 0, 0, 0, 0, // 528..275
        0, 0, 0, 0, x, 0, 0, 0, 0, 0, 0, x, x, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, x, 0, 0, 0, x, x, 0, 0, x, 0, 0, x, 0, 0, x, 0, 0, 0, 0, x, 0, 0, 0, // 576..623
        0, 0, x, x, x, x, x, 0, 0, 0, 0, 0, x, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, x, x, x, 0, x, 0, 0, x, 0, 0, x, 0, 0, x, 0, 0, 0, 0, x, 0, 0, 0, // 624..671
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, x, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 672..719
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, x, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 720..767
    };
    try testing.expectEqualSlices(u1, expected, result.bitmap);
}

fn findGlyph(fonts: []const common.Font, codepoint: u21) common.Glyph {
    for (fonts) |font| {
        if (font.get(codepoint)) |glyph| {
            return glyph;
        }
    }
    // no glyph found
    return fonts[0].get(0).?;
}

const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
