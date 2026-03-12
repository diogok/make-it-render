//! PBM (Portable Bitmap) image parser.
//!
//! Supports P1 (ASCII) and P4 (binary) formats.
//! Returns a `common.Bitmap` — the same type used by the pixel reader pipeline.

pub fn parse(allocator: std.mem.Allocator, reader: *std.Io.Reader) !common.Bitmap {
    // Read magic number
    const format = try readNonCommentLine(reader) orelse return error.InvalidFormat;
    const is_ascii = if (std.mem.eql(u8, format, "P1"))
        true
    else if (std.mem.eql(u8, format, "P4"))
        false
    else
        return error.InvalidFormat;

    // Read width and height
    const dimensions = try readNonCommentLine(reader) orelse return error.InvalidFormat;
    var tokenizer = std.mem.tokenizeAny(u8, dimensions, " \t");
    const width = try std.fmt.parseInt(u16, tokenizer.next() orelse return error.InvalidFormat, 10);
    const height = try std.fmt.parseInt(u16, tokenizer.next() orelse return error.InvalidFormat, 10);

    if (width == 0 or height == 0) return error.InvalidFormat;
    if (width > 16384 or height > 16384) return error.InvalidFormat;

    const bitmap_size = @as(usize, width) * @as(usize, height);
    const bitmap = try allocator.alloc(u1, bitmap_size);
    errdefer allocator.free(bitmap);

    if (is_ascii) {
        // P1: ASCII 0/1 values separated by whitespace
        var pos: usize = 0;
        while (pos < bitmap_size) {
            const line = try reader.takeDelimiter('\n') orelse break;
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            for (trimmed) |c| {
                if (pos >= bitmap_size) break;
                if (c == '0') {
                    bitmap[pos] = 0;
                    pos += 1;
                } else if (c == '1') {
                    bitmap[pos] = 1;
                    pos += 1;
                }
            }
        }
        if (pos != bitmap_size) return error.UnexpectedEof;
    } else {
        // P4: packed binary bits, MSB first, rows padded to byte boundary
        const bytes_per_row = (@as(usize, width) + 7) / 8;
        const total_bytes = bytes_per_row * @as(usize, height);
        const raw = try allocator.alloc(u8, total_bytes);
        defer allocator.free(raw);

        try reader.readSliceAll(raw);

        var pos: usize = 0;
        for (0..height) |row| {
            for (0..width) |col| {
                const byte_idx = row * bytes_per_row + col / 8;
                const bit_idx: u3 = @intCast(7 - (col % 8));
                bitmap[pos] = @intCast((raw[byte_idx] >> bit_idx) & 1);
                pos += 1;
            }
        }
    }

    return common.Bitmap{
        .width = width,
        .height = height,
        .bitmap = bitmap,
        .allocator = allocator,
    };
}

fn readNonCommentLine(reader: *std.Io.Reader) !?[]const u8 {
    while (true) {
        const line = try reader.takeDelimiter('\n') orelse return null;
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;
        return trimmed;
    }
}

test "parse P1" {
    const data =
        \\P1
        \\4 4
        \\0 1 1 0
        \\1 0 0 1
        \\1 0 0 1
        \\0 1 1 0
        \\
    ;
    var reader = std.Io.Reader.fixed(data);
    var bitmap = try parse(testing.allocator, &reader);
    defer bitmap.deinit();

    try testing.expectEqual(4, bitmap.width);
    try testing.expectEqual(4, bitmap.height);
    try testing.expectEqualSlices(u1, &[_]u1{
        0, 1, 1, 0,
        1, 0, 0, 1,
        1, 0, 0, 1,
        0, 1, 1, 0,
    }, bitmap.bitmap);
}

test "parse P1 with comments" {
    const data =
        \\P1
        \\# A test image
        \\# with multiple comments
        \\3 2
        \\1 0 1
        \\0 1 0
        \\
    ;
    var reader = std.Io.Reader.fixed(data);
    var bitmap = try parse(testing.allocator, &reader);
    defer bitmap.deinit();

    try testing.expectEqual(3, bitmap.width);
    try testing.expectEqual(2, bitmap.height);
    try testing.expectEqualSlices(u1, &[_]u1{
        1, 0, 1,
        0, 1, 0,
    }, bitmap.bitmap);
}

test "parse P1 compact" {
    // No spaces between values
    const data =
        \\P1
        \\4 2
        \\0110
        \\1001
        \\
    ;
    var reader = std.Io.Reader.fixed(data);
    var bitmap = try parse(testing.allocator, &reader);
    defer bitmap.deinit();

    try testing.expectEqual(4, bitmap.width);
    try testing.expectEqual(2, bitmap.height);
    try testing.expectEqualSlices(u1, &[_]u1{
        0, 1, 1, 0,
        1, 0, 0, 1,
    }, bitmap.bitmap);
}

test "parse P1 single pixel" {
    const data =
        \\P1
        \\1 1
        \\1
        \\
    ;
    var reader = std.Io.Reader.fixed(data);
    var bitmap = try parse(testing.allocator, &reader);
    defer bitmap.deinit();

    try testing.expectEqual(1, bitmap.width);
    try testing.expectEqual(1, bitmap.height);
    try testing.expectEqualSlices(u1, &[_]u1{1}, bitmap.bitmap);
}

test "parse P4" {
    // 8x2 binary image
    // Row 0: 0xB1 = 10110001
    // Row 1: 0x4E = 01001110
    const data = "P4\n8 2\n\xb1\x4e";
    var reader = std.Io.Reader.fixed(data);
    var bitmap = try parse(testing.allocator, &reader);
    defer bitmap.deinit();

    try testing.expectEqual(8, bitmap.width);
    try testing.expectEqual(2, bitmap.height);
    try testing.expectEqualSlices(u1, &[_]u1{
        1, 0, 1, 1, 0, 0, 0, 1,
        0, 1, 0, 0, 1, 1, 1, 0,
    }, bitmap.bitmap);
}

test "parse P4 non-byte-aligned" {
    // 3x2 binary image (each row padded to 1 byte)
    // Row 0: 0xC0 = 11000000 -> bits 1,1,0 (+ 5 padding)
    // Row 1: 0x40 = 01000000 -> bits 0,1,0 (+ 5 padding)
    const data = "P4\n3 2\n\xc0\x40";
    var reader = std.Io.Reader.fixed(data);
    var bitmap = try parse(testing.allocator, &reader);
    defer bitmap.deinit();

    try testing.expectEqual(3, bitmap.width);
    try testing.expectEqual(2, bitmap.height);
    try testing.expectEqualSlices(u1, &[_]u1{
        1, 1, 0,
        0, 1, 0,
    }, bitmap.bitmap);
}

test "parse P4 with comment" {
    const data = "P4\n# a comment\n8 1\n\xff";
    var reader = std.Io.Reader.fixed(data);
    var bitmap = try parse(testing.allocator, &reader);
    defer bitmap.deinit();

    try testing.expectEqual(8, bitmap.width);
    try testing.expectEqual(1, bitmap.height);
    try testing.expectEqualSlices(u1, &[_]u1{
        1, 1, 1, 1, 1, 1, 1, 1,
    }, bitmap.bitmap);
}

test "invalid magic number" {
    const data =
        \\P2
        \\4 4
        \\0 0 0 0
        \\
    ;
    var reader = std.Io.Reader.fixed(data);
    try testing.expectError(error.InvalidFormat, parse(testing.allocator, &reader));
}

const std = @import("std");
const testing = std.testing;
const common = @import("common.zig");
