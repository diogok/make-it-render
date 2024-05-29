const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const common = @import("common.zig");

pub fn load_font(allocator: std.mem.Allocator, reader: anytype) !common.Font {
    const name = try get_name(allocator, reader);
    const glyphs = try get_glyphs(allocator, reader);

    return common.Font{
        .allocator = allocator,
        .glyphs = glyphs,
        .name = name,
    };
}

test "Load font" {
    const allocator = testing.allocator;

    var stream = std.io.fixedBufferStream(example);
    const reader = stream.reader();

    var font = try load_font(allocator, reader);
    defer font.deinit();

    try testing.expectEqualStrings("-xos4-Terminus-Medium-R-Normal--16-160-72-72-C-80-ISO10646-1", font.name);
    //try testing.expectEqual(3,font.glyphs.entries.len);
}

pub fn get_name(allocator: std.mem.Allocator, reader: anytype) ![]const u8 {
    while (true) {
        const token = try next_token(allocator, reader);
        switch (token) {
            .key_value => |kv| {
                if (std.mem.eql(u8, kv[0], "FONT")) {
                    allocator.free(kv[0]);
                    return kv[1];
                }
            },
            .end => {
                break;
            },
            else => {},
        }
        token.deinit(allocator);
    }
    return error.FontNameNotFound;
}

test "Get name" {
    const allocator = testing.allocator;

    var stream = std.io.fixedBufferStream(example);
    const reader = stream.reader();

    const font_name = try get_name(allocator, reader);
    defer allocator.free(font_name);

    try testing.expectEqualStrings("-xos4-Terminus-Medium-R-Normal--16-160-72-72-C-80-ISO10646-1", font_name);
}

test "Get name" {
    const allocator = testing.allocator;

    var stream = std.io.fixedBufferStream(example);
    const reader = stream.reader();

    const font_name = try get_name(allocator, reader);
    defer allocator.free(font_name);

    try testing.expectEqualStrings("-xos4-Terminus-Medium-R-Normal--16-160-72-72-C-80-ISO10646-1", font_name);
}

pub fn get_glyphs(allocator: std.mem.Allocator, reader: anytype) !common.Glyphs {
    var glyphs = common.Glyphs.init(allocator);

    var bitmap = std.ArrayList(u1).init(allocator);
    defer bitmap.deinit();

    var encoding: usize = 0;
    while (true) {
        const token = try next_token(allocator, reader);
        switch (token) {
            .key_only => |key| {
                if (std.mem.eql(u8, key, "ENDCHAR")) {
                    const glyph = common.Glyph{
                        .width = 0,
                        .height = 0,
                        .bitmap = try bitmap.toOwnedSlice(),
                    };
                    try glyphs.put(encoding, glyph);
                }
            },
            .key_value => |kv| {
                if (std.mem.eql(u8, kv[0], "ENCODING")) {
                    encoding = try std.fmt.parseInt(usize, kv[1], 10);
                }
            },
            .bitmap_value => |val| {
                var buffer: [8]u8 = undefined;
                const bytes = try std.fmt.hexToBytes(&buffer, val);

                var i: usize = 0;
                while (i < bytes.len * 8) : (i += 1) {
                    try bitmap.append(std.mem.readPackedInt(u1, bytes, i, builtin.cpu.arch.endian()));
                }
            },
            .end => {
                break;
            },
        }
        token.deinit(allocator);
    }

    return glyphs;
}

test "Get Glyphs" {
    const allocator = testing.allocator;

    var stream = std.io.fixedBufferStream(example);
    const reader = stream.reader();

    var glyphs = try get_glyphs(allocator, reader);
    defer common.free_glyphs(&glyphs);

    const char0 = glyphs.get(0);
    try testing.expect(char0 != null);
    try testing.expectEqual(128, char0.?.bitmap.len);

    // check random line
    const charA = glyphs.get(65);
    try testing.expect(charA != null);
    try testing.expectEqual(128, charA.?.bitmap.len);
    try testing.expectEqualSlices(u1, &[_]u1{ 0, 1, 1, 1, 1, 1, 1, 0 }, charA.?.bitmap[8 * 9 .. 8 * 10]);

    const not_found = glyphs.get(99);
    try testing.expect(not_found == null);
}

const Token = union(enum) {
    end: void,
    key_only: []const u8,
    key_value: [2][]const u8,
    bitmap_value: []const u8,

    fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        switch (self) {
            .end => {},
            .key_only => |key| {
                allocator.free(key);
            },
            .key_value => |kv| {
                allocator.free(kv[0]);
                allocator.free(kv[1]);
            },
            .bitmap_value => |val| {
                allocator.free(val);
            },
        }
    }
};

fn next_token(allocator: std.mem.Allocator, reader: anytype) !Token {
    var firstByte = true;
    var isBitmapValue = false;
    var isKeyValue = false;
    var noData = true;
    var buffer0: [128]u8 = undefined;
    var buffer1: [128]u8 = undefined;
    var c0: usize = 0;
    var c1: usize = 0;

    while (true) {
        const byte = reader.readByte() catch break; // EOF
        if ('\n' == byte or '\r' == byte or '#' == byte) { // END OF TOKEN
            break;
        }
        noData = false;
        if (firstByte) {
            if (std.ascii.isDigit(byte)) {
                isBitmapValue = true;
            }
            firstByte = false;
        }
        if (byte == ' ') {
            isKeyValue = !isBitmapValue;
            continue;
        }
        if (!isKeyValue) {
            buffer0[c0] = byte;
            c0 += 1;
        } else {
            buffer1[c1] = byte;
            c1 += 1;
        }
    }

    if (noData) {
        return Token{ .end = {} };
    } else if (isBitmapValue) {
        const value = try allocator.alloc(u8, c0);
        std.mem.copyForwards(u8, value, buffer0[0..c0]);
        return Token{ .bitmap_value = value };
    } else if (isKeyValue) {
        const key = try allocator.alloc(u8, c0);
        std.mem.copyForwards(u8, key, buffer0[0..c0]);
        const value = try allocator.alloc(u8, c1);
        std.mem.copyForwards(u8, value, buffer1[0..c1]);
        return Token{ .key_value = [2][]const u8{ key, value } };
    } else {
        const key = try allocator.alloc(u8, c0);
        std.mem.copyForwards(u8, key, buffer0[0..c0]);
        return Token{ .key_only = key };
    }
}

test "Tokenizer" {
    const allocator = testing.allocator;
    var stream = std.io.fixedBufferStream(example);
    const reader = stream.reader();

    const startfont = try next_token(allocator, reader);
    defer startfont.deinit(allocator);
    try testing.expectEqualStrings(startfont.key_value[0], "STARTFONT");
    try testing.expectEqualStrings(startfont.key_value[1], "2.1");

    const font = try next_token(allocator, reader);
    defer font.deinit(allocator);
    try testing.expectEqualStrings(font.key_value[0], "FONT");
    try testing.expectEqualStrings(font.key_value[1], "-xos4-Terminus-Medium-R-Normal--16-160-72-72-C-80-ISO10646-1");

    var skip: usize = 0;
    while (skip < 30) : (skip += 1) {
        const token = try next_token(allocator, reader);
        token.deinit(allocator);
    }

    const bitmap = try next_token(allocator, reader);
    defer bitmap.deinit(allocator);
    try testing.expectEqualStrings(bitmap.key_only, "BITMAP");

    const bitmap_val_0 = try next_token(allocator, reader);
    defer bitmap_val_0.deinit(allocator);
    try testing.expectEqualStrings(bitmap_val_0.bitmap_value, "00");

    const bitmap_val_1 = try next_token(allocator, reader);
    defer bitmap_val_1.deinit(allocator);
    try testing.expectEqualStrings(bitmap_val_1.bitmap_value, "00");

    const bitmap_val_2 = try next_token(allocator, reader);
    defer bitmap_val_2.deinit(allocator);
    try testing.expectEqualStrings(bitmap_val_2.bitmap_value, "66"); //ignore a comment
}

const example =
    \\STARTFONT 2.1
    \\FONT -xos4-Terminus-Medium-R-Normal--16-160-72-72-C-80-ISO10646-1
    \\SIZE 16 72 72
    \\FONTBOUNDINGBOX 8 16 0 -4
    \\STARTPROPERTIES 20
    \\FAMILY_NAME "Terminus"
    \\FOUNDRY "xos4"
    \\SETWIDTH_NAME "Normal"
    \\ADD_STYLE_NAME ""
    \\COPYRIGHT "Copyright (C) 2020 Dimitar Toshkov Zhekov"
    \\NOTICE "Licensed under the SIL Open Font License, Version 1.1"
    \\WEIGHT_NAME "Medium"
    \\SLANT "R"
    \\PIXEL_SIZE 16
    \\POINT_SIZE 160
    \\RESOLUTION_X 72
    \\RESOLUTION_Y 72
    \\SPACING "C"
    \\AVERAGE_WIDTH 80
    \\CHARSET_REGISTRY "ISO10646"
    \\CHARSET_ENCODING "1"
    \\MIN_SPACE 8
    \\FONT_ASCENT 12
    \\FONT_DESCENT 4
    \\DEFAULT_CHAR 65533
    \\ENDPROPERTIES
    \\CHARS 1356
    \\STARTCHAR char0
    \\ENCODING 0
    \\SWIDTH 500 0
    \\DWIDTH 8 0
    \\BBX 8 16 0 -4
    \\BITMAP
    \\00
    \\00
    \\66 # a comment
    \\42
    \\00
    \\42
    \\42
    \\42
    \\00
    \\42
    \\42
    \\66
    \\00
    \\00
    \\00
    \\00
    \\ENDCHAR
    \\STARTCHAR space
    \\ENCODING 32
    \\SWIDTH 500 0
    \\DWIDTH 8 0
    \\BBX 8 16 0 -4
    \\BITMAP
    \\00
    \\00
    \\00
    \\00
    \\00
    \\00
    \\00
    \\00
    \\00
    \\00
    \\00
    \\00
    \\00
    \\00
    \\00
    \\00
    \\ENDCHAR
    \\STARTCHAR U+0041
    \\ENCODING 65
    \\SWIDTH 500 0
    \\DWIDTH 8 0
    \\BBX 8 16 0 -2
    \\BITMAP
    \\00
    \\00
    \\00
    \\00
    \\18
    \\24
    \\24
    \\42
    \\42
    \\7E
    \\42
    \\42
    \\42
    \\42
    \\00
    \\00
    \\ENDCHAR
    \\ENDFONT
;
