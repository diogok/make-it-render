const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const common = @import("common.zig");

pub fn parse(allocator: std.mem.Allocator, reader: anytype) !common.Font {
    var tokens = tokenizer(reader);
    var font = common.Font{
        .allocator = allocator,
        .glyphs = common.GlyphMap{},
    };

    var glyph: common.Glyph = undefined;
    var codepoint: u21 = 0;
    var bitmap_pos: usize = 0;

    var prop: enum { none, encoding, dwidth, bbox } = .none;

    while (true) {
        const token = try tokens.next();
        switch (token.type) {
            .char_start => {},
            .char_key => {
                if (std.mem.eql(u8, "ENCODING", token.value)) {
                    prop = .encoding;
                } else if (std.mem.eql(u8, "DWIDTH", token.value)) {
                    prop = .dwidth;
                } else if (std.mem.eql(u8, "BBX", token.value)) {
                    prop = .bbox;
                } else {
                    prop = .none;
                }
            },
            .char_value => {
                switch (prop) {
                    .encoding => {
                        codepoint = try std.fmt.parseInt(u21, token.value, 10);
                    },
                    .dwidth => {
                        var parts = std.mem.splitScalar(u8, token.value, ' ');
                        glyph.advance = try std.fmt.parseInt(u8, parts.first(), 10);
                    },
                    .bbox => {
                        var parts = std.mem.splitScalar(u8, token.value, ' ');
                        glyph.bbox.width = try std.fmt.parseInt(u8, parts.first(), 10);
                        glyph.bbox.height = try std.fmt.parseInt(u8, parts.next().?, 10);
                        glyph.bbox.x = try std.fmt.parseInt(i8, parts.next().?, 10);
                        glyph.bbox.y = try std.fmt.parseInt(i8, parts.next().?, 10);
                    },
                    else => {},
                }
            },
            .bitmap_start => {
                glyph.bitmap = try allocator.alloc(u1, glyph.bbox.width * glyph.bbox.height);
                bitmap_pos = 0;
            },
            .bitmap_value => {
                var buf: [32]u8 = undefined;
                const bytes = try std.fmt.hexToBytes(&buf, token.value);
                // TODO: just save the bytes, I think.
                var i: u8 = 0;
                while (i < glyph.bbox.width) : (i += 1) {
                    const bit = std.mem.readPackedInt(u1, bytes, i, builtin.cpu.arch.endian());
                    glyph.bitmap[bitmap_pos] = bit;
                    bitmap_pos += 1;
                }
            },
            .char_end => {
                try font.glyphs.put(allocator, codepoint, glyph);
            },
            .font_end => {
                break;
            },
            else => {},
        }
    }

    return font;
}

test "parse" {
    var stream = std.io.fixedBufferStream(example);
    const reader = stream.reader();

    var font = try parse(testing.allocator, reader);
    defer font.deinit();

    const char0 = font.glyphs.get(0).?;
    try testing.expectEqual(8, char0.advance);
    try testing.expectEqual(8, char0.bbox.width);
    try testing.expectEqual(16, char0.bbox.height);
    try testing.expectEqual(0, char0.bbox.x);
    try testing.expectEqual(-4, char0.bbox.y);

    const space = font.glyphs.get(32).?;
    try testing.expectEqual(8, space.advance);
    try testing.expectEqual(8, space.bbox.width);
    try testing.expectEqual(16, space.bbox.height);
    try testing.expectEqual(0, space.bbox.x);
    try testing.expectEqual(-4, space.bbox.y);

    const A = font.glyphs.get(65).?;
    try testing.expectEqual(8, A.advance);
    try testing.expectEqual(8, A.bbox.width);
    try testing.expectEqual(16, A.bbox.height);
    try testing.expectEqual(0, A.bbox.x);
    try testing.expectEqual(-2, A.bbox.y);

    const ABitmap = &[8 * 16]u1{
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 1, 1, 0, 0, 0,
        0, 0, 1, 0, 0, 1, 0, 0,
        0, 0, 1, 0, 0, 1, 0, 0,
        0, 1, 0, 0, 0, 0, 1, 0,
        0, 1, 0, 0, 0, 0, 1, 0,
        0, 1, 1, 1, 1, 1, 1, 0,
        0, 1, 0, 0, 0, 0, 1, 0,
        0, 1, 0, 0, 0, 0, 1, 0,
        0, 1, 0, 0, 0, 0, 1, 0,
        0, 1, 0, 0, 0, 0, 1, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    };
    try testing.expectEqualSlices(u1, ABitmap, A.bitmap);
}

const TokenType = enum {
    font_start,
    font_end,
    font_key,
    font_value,
    prop_start,
    prop_key,
    prop_value,
    prop_end,
    chars,
    char_start,
    char_end,
    char_key,
    char_value,
    bitmap_start,
    bitmap_value,
};

const Token = struct {
    type: TokenType,
    value: []const u8 = "",
};

fn Tokenizer(ReaderType: type) type {
    return struct {
        reader: ReaderType,

        buffer: [128]u8 = undefined,
        pos: usize = 0,

        previous: ?TokenType = null,

        pub fn init(reader: ReaderType) @This() {
            return @This(){
                .reader = reader,
            };
        }

        fn nextToken(self: *@This()) ![]const u8 {
            self.pos = 0;
            // TODO: handle comments
            reading: while (true) : (self.pos += 1) {
                if (self.pos >= self.buffer.len) {
                    return error.LineTooBig;
                }
                const char = self.reader.readByte() catch |e| {
                    switch (e) {
                        error.EndOfStream => break :reading,
                        else => return e,
                    }
                };
                if (self.previous) |prev| {
                    switch (prev) {
                        .char_key, .prop_key, .font_key => {
                            if (char == '\n' or char == '\r') {
                                break :reading;
                            }
                        },
                        else => {
                            if (char == '\n' or char == '\r' or char == ' ' or char == '\t') {
                                break :reading;
                            }
                        },
                    }
                } else {
                    if (char == '\n' or char == '\r' or char == ' ' or char == '\t') {
                        break :reading;
                    }
                }
                self.buffer[self.pos] = char;
            }
            return self.buffer[0..self.pos];
        }

        pub fn next(self: *@This()) !Token {
            const text = try self.nextToken();

            if (self.previous == null) {
                _ = try self.reader.readUntilDelimiter(&self.buffer, '\n');
                self.previous = .font_start;
                return .{ .type = .font_start };
            }

            switch (self.previous.?) {
                .font_start => {
                    self.previous = .font_key;
                    return .{ .type = .font_key, .value = text };
                },
                .font_key => {
                    self.previous = .font_value;
                    return .{ .type = .font_value, .value = text };
                },
                .font_value => {
                    if (std.mem.eql(u8, text, "STARTPROPERTIES")) {
                        const value = try self.reader.readUntilDelimiter(&self.buffer, '\n');
                        self.previous = .prop_start;
                        return .{ .type = .prop_start, .value = value };
                    } else {
                        self.previous = .font_key;
                        return .{ .type = .font_key, .value = text };
                    }
                },
                .prop_start => {
                    self.previous = .prop_key;
                    return .{ .type = .prop_key, .value = text };
                },
                .prop_key => {
                    self.previous = .prop_value;
                    return .{ .type = .prop_value, .value = text };
                },
                .prop_value => {
                    if (std.mem.eql(u8, text, "ENDPROPERTIES")) {
                        self.previous = .prop_end;
                        return .{ .type = .prop_end, .value = text };
                    } else {
                        self.previous = .prop_key;
                        return .{ .type = .prop_key, .value = text };
                    }
                },
                .prop_end => {
                    const value = try self.reader.readUntilDelimiter(&self.buffer, '\n');
                    self.previous = .chars;
                    return .{ .type = .chars, .value = value };
                },
                .chars => {
                    const value = try self.reader.readUntilDelimiter(&self.buffer, '\n');
                    self.previous = .char_start;
                    return .{ .type = .char_start, .value = value };
                },
                .char_start => {
                    self.previous = .char_key;
                    return .{ .type = .char_key, .value = text };
                },
                .char_key => {
                    self.previous = .char_value;
                    return .{ .type = .char_value, .value = text };
                },
                .char_value => {
                    if (std.mem.eql(u8, text, "BITMAP")) {
                        self.previous = .bitmap_start;
                        return .{ .type = .bitmap_start, .value = text };
                    } else {
                        self.previous = .char_key;
                        return .{ .type = .char_key, .value = text };
                    }
                },
                .bitmap_start => {
                    self.previous = .bitmap_value;
                    return .{ .type = .bitmap_value, .value = text };
                },
                .bitmap_value => {
                    if (std.mem.eql(u8, "ENDCHAR", text)) {
                        self.previous = .char_end;
                        return .{ .type = .char_end, .value = text };
                    } else {
                        self.previous = .bitmap_value;
                        return .{ .type = .bitmap_value, .value = text };
                    }
                },
                .char_end => {
                    if (std.mem.eql(u8, "ENDFONT", text)) {
                        self.previous = .font_end;
                        return .{ .type = .font_end, .value = text };
                    } else {
                        const value = try self.reader.readUntilDelimiter(&self.buffer, '\n');
                        self.previous = .char_start;
                        return .{ .type = .char_start, .value = value };
                    }
                },
                .font_end => {
                    return error.FontAlreadyEnded;
                },
            }
        }
    };
}

pub fn tokenizer(reader: anytype) Tokenizer(@TypeOf(reader)) {
    return Tokenizer(@TypeOf(reader)).init(reader);
}

test "tokenizer" {
    var stream = std.io.fixedBufferStream(example);
    const reader = stream.reader();

    var tokens = tokenizer(reader);

    const start = try tokens.next();
    try testing.expect(start.type == .font_start);
    const font_key = try tokens.next();
    try testing.expectEqualStrings(font_key.value, "FONT");
    const font_value = try tokens.next();
    try testing.expectEqualStrings(font_value.value, "-xos4-Terminus-Medium-R-Normal--16-160-72-72-C-80-ISO10646-1");

    while ((try tokens.next()).type != .prop_start) {}

    const family_name_key = try tokens.next();
    try testing.expectEqualStrings(family_name_key.value, "FAMILY_NAME");
    const family_name_value = try tokens.next();
    try testing.expectEqualStrings(family_name_value.value, "\"Terminus\"");

    while ((try tokens.next()).type != .prop_end) {}

    const chars = try tokens.next();
    try testing.expectEqualStrings("3", chars.value);

    const char_start = try tokens.next();
    try testing.expectEqualStrings("char0", char_start.value);

    const char_key = try tokens.next();
    try testing.expectEqualStrings("ENCODING", char_key.value);

    const char_val = try tokens.next();
    try testing.expectEqualStrings("0", char_val.value);

    while ((try tokens.next()).type != .bitmap_start) {}

    const bitmap_line = try tokens.next();
    try testing.expectEqualStrings("00", bitmap_line.value);

    while ((try tokens.next()).type != .char_end) {}

    while ((try tokens.next()).type != .font_end) {}
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
    \\DEFAULT_CHAR 0
    \\ENDPROPERTIES
    \\CHARS 3
    \\STARTCHAR char0
    \\ENCODING 0
    \\SWIDTH 500 0
    \\DWIDTH 8 0
    \\BBX 8 16 0 -4
    \\BITMAP
    \\00
    \\00
    \\66
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
