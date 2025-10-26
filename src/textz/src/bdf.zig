pub fn parse(allocator: std.mem.Allocator, reader: *std.Io.Reader) !common.Font {
    const glyphs = try allocator.create(common.GlyphMap);
    glyphs.* = common.GlyphMap.init(allocator);

    var font = common.Font{
        .allocator = allocator,
        .glyphs = glyphs,
    };

    var glyph = common.Glyph{
        .bitmap = &[0]u1{},
        .encoding = 0,
        .advance = 0,
        .bbox = .{
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
        },
    };
    var bitmap: []u1 = &[0]u1{};

    var bitmap_started: bool = false;
    var bitmap_pos: usize = 0;

    while (try reader.takeDelimiter('\n')) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        var tokenizer = std.mem.tokenizeScalar(u8, trimmed, ' ');

        const prop = tokenizer.next().?;

        if (std.mem.eql(u8, prop, "FONTBOUNDINGBOX")) {
            font.width = try std.fmt.parseInt(u16, tokenizer.next().?, 10);
            font.height = try std.fmt.parseInt(u16, tokenizer.next().?, 10);
        } else if (std.mem.eql(u8, prop, "FONT_ASCENT")) {
            font.ascent = try std.fmt.parseInt(u16, tokenizer.next().?, 10);
        } else if (std.mem.eql(u8, prop, "CHARS")) {
            font.count = try std.fmt.parseInt(usize, tokenizer.next().?, 10);
        } else if (std.mem.eql(u8, prop, "ENCODING")) {
            glyph.encoding = try std.fmt.parseInt(u21, tokenizer.next().?, 10);
        } else if (std.mem.eql(u8, prop, "DWIDTH")) {
            glyph.advance = try std.fmt.parseInt(u8, tokenizer.next().?, 10);
        } else if (std.mem.eql(u8, prop, "BBX")) {
            glyph.bbox.width = try std.fmt.parseInt(u8, tokenizer.next().?, 10);
            glyph.bbox.height = try std.fmt.parseInt(u8, tokenizer.next().?, 10);
            glyph.bbox.x = try std.fmt.parseInt(i8, tokenizer.next().?, 10);
            glyph.bbox.y = try std.fmt.parseInt(i8, tokenizer.next().?, 10);

            if (glyph.advance == 0) {
                glyph.advance = glyph.bbox.width;
            }
        } else if (std.mem.eql(u8, prop, "ENDCHAR")) {
            glyph.bitmap = bitmap;
            try font.glyphs.put(glyph.encoding, glyph);
            bitmap_started = false;
        } else if (std.mem.eql(u8, prop, "BITMAP")) {
            const bytes_per_row = (glyph.bbox.width + 7) / 8;
            const bitmap_size = @as(usize, glyph.bbox.height) * bytes_per_row * 8;
            bitmap = try allocator.alloc(u1, bitmap_size);

            bitmap_started = true;
            bitmap_pos = 0;
        } else if (bitmap_started) {
            const hex_value = try std.fmt.parseInt(u32, trimmed, 16);
            const hex_chars = trimmed.len;
            const shift_amount = if (hex_chars < 8) (8 - hex_chars) * 4 else 0;
            const aligned_value = hex_value << @intCast(shift_amount);

            const bytes_per_row = (glyph.bbox.width + 7) / 8;
            for (0..bytes_per_row) |byte_idx| {
                const start_bit = byte_idx * 8;
                const end_bit = @min(start_bit + 8, glyph.bbox.width);

                if (end_bit > start_bit) {
                    for (start_bit..end_bit) |bit| {
                        if (bit < 32) {
                            if ((aligned_value >> @intCast(31 - bit)) & 1 != 0) {
                                bitmap[bitmap_pos] = 1;
                            } else {
                                bitmap[bitmap_pos] = 0;
                            }
                            bitmap_pos += 1;
                        }
                    }
                }
            }
        }
    }

    return font;
}

test "read unifont" {
    const unifont_gz = @embedFile("fonts/unifont-17.0.02.bdf.gz");

    var buffer_reader = std.Io.Reader.fixed(unifont_gz);
    var buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompress = std.compress.flate.Decompress.init(&buffer_reader, .gzip, &buffer);
    const reader = &decompress.reader;

    var font = try parse(testing.allocator, reader);
    defer font.deinit();

    try testing.expectEqual(57086, font.count);

    const char0 = font.glyphs.get(0).?;
    try testing.expectEqual(16, char0.advance);
    try testing.expectEqual(16, char0.bbox.width);
    try testing.expectEqual(16, char0.bbox.height);
    try testing.expectEqual(0, char0.bbox.x);
    try testing.expectEqual(-2, char0.bbox.y);
    try testing.expectEqual(16 * 16, char0.bitmap.len);

    const space = font.glyphs.get(32).?;
    try testing.expectEqual(8, space.advance);
    try testing.expectEqual(8, space.bbox.width);
    try testing.expectEqual(16, space.bbox.height);
    try testing.expectEqual(0, space.bbox.x);
    try testing.expectEqual(-2, space.bbox.y);
    try testing.expectEqual(16 * 8, space.bitmap.len);

    const charA = font.glyphs.get(65).?;
    try testing.expectEqual(8, charA.advance);
    try testing.expectEqual(8, charA.bbox.width);
    try testing.expectEqual(16, charA.bbox.height);
    try testing.expectEqual(0, charA.bbox.x);
    try testing.expectEqual(-2, charA.bbox.y);
    try testing.expectEqual(16 * 8, charA.bitmap.len);

    const ABitmap = &[8 * 16]u1{
        0, 0, 0, 0, 0, 0, 0, 0, //0..7
        0, 0, 0, 0, 0, 0, 0, 0, //8..15
        0, 0, 0, 0, 0, 0, 0, 0, //16..23
        0, 0, 0, 0, 0, 0, 0, 0, //24..31
        0, 0, 0, 1, 1, 0, 0, 0, //32..39
        0, 0, 1, 0, 0, 1, 0, 0, //40..47
        0, 0, 1, 0, 0, 1, 0, 0, //48..55
        0, 1, 0, 0, 0, 0, 1, 0, //56..63
        0, 1, 0, 0, 0, 0, 1, 0, //64..71
        0, 1, 1, 1, 1, 1, 1, 0, //72..79
        0, 1, 0, 0, 0, 0, 1, 0, //80..87
        0, 1, 0, 0, 0, 0, 1, 0, //88..95
        0, 1, 0, 0, 0, 0, 1, 0, //96..103
        0, 1, 0, 0, 0, 0, 1, 0, //104..111
        0, 0, 0, 0, 0, 0, 0, 0, //112..119
        0, 0, 0, 0, 0, 0, 0, 0, //120..128
    };
    try testing.expectEqualSlices(u1, ABitmap, charA.bitmap);
}

const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
