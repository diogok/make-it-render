pub const TextMetrics = struct {
    width: u16,
    height: u16,
};

pub fn measure(fonts: []const common.Font, text: []const u8) !TextMetrics {
    var width: u32 = 0;
    var height: u16 = 0;
    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    while (iter.nextCodepoint()) |char| {
        const glyph = findGlyph(fonts, char);
        width += glyph.advance;
        height = @max(height, glyph.bbox.height);
    }
    if (width > std.math.maxInt(u16)) return error.TextTooLong;
    return .{ .width = @intCast(width), .height = height };
}

pub fn render(
    allocator: std.mem.Allocator,
    fonts: []const common.Font,
    text: []const u8,
) !common.Bitmap {
    const metrics = try measure(fonts, text);
    const width = metrics.width;
    const height = metrics.height;
    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };

    const bitmap = try allocator.alloc(u1, width * height);
    @memset(bitmap, 0);

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
                    const idx = @as(usize, global_x + col) + @as(usize, row) * @as(usize, width);
                    if (idx < bitmap.len) {
                        bitmap[idx] = 1;
                    }
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
    const uni = try @import("fonts/unifont/unifont.zig").unifont(testing.allocator);
    defer uni.deinit();

    const text = "I, am!";
    var result = try render(testing.allocator, &[_]common.Font{uni}, text);
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

test "measure returns correct dimensions" {
    const uni = try @import("fonts/unifont/unifont.zig").unifont(testing.allocator);
    defer uni.deinit();

    const metrics = try measure(&[_]common.Font{uni}, "I, am!");
    try testing.expectEqual(@as(u16, 48), metrics.width);
    try testing.expectEqual(@as(u16, 16), metrics.height);
}

test "measure empty string returns zero" {
    const uni = try @import("fonts/unifont/unifont.zig").unifont(testing.allocator);
    defer uni.deinit();

    const metrics = try measure(&[_]common.Font{uni}, "");
    try testing.expectEqual(@as(u16, 0), metrics.width);
    try testing.expectEqual(@as(u16, 0), metrics.height);
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
