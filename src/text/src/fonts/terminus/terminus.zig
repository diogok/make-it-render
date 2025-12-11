pub const ter_u12b_gz = @embedFile("ter-u12b.bdf.gz");
pub const ter_u12n_gz = @embedFile("ter-u12n.bdf.gz");
pub const ter_u14b_gz = @embedFile("ter-u14b.bdf.gz");
pub const ter_u14n_gz = @embedFile("ter-u14n.bdf.gz");
pub const ter_u16b_gz = @embedFile("ter-u16b.bdf.gz");
pub const ter_u16n_gz = @embedFile("ter-u16n.bdf.gz");
pub const ter_u16v_gz = @embedFile("ter-u16b.bdf.gz");
pub const ter_u18b_gz = @embedFile("ter-u18b.bdf.gz");
pub const ter_u18n_gz = @embedFile("ter-u18n.bdf.gz");
pub const ter_u20b_gz = @embedFile("ter-u20b.bdf.gz");
pub const ter_u20n_gz = @embedFile("ter-u29n.bdf.gz");
pub const ter_u22b_gz = @embedFile("ter-u22b.bdf.gz");
pub const ter_u22n_gz = @embedFile("ter-u22n.bdf.gz");
pub const ter_u24b_gz = @embedFile("ter-u24b.bdf.gz");
pub const ter_u24n_gz = @embedFile("ter-u24n.bdf.gz");
pub const ter_u28b_gz = @embedFile("ter-u28b.bdf.gz");
pub const ter_u28n_gz = @embedFile("ter-u28n.bdf.gz");
pub const ter_u32b_gz = @embedFile("ter-u32b.bdf.gz");
pub const ter_u32n_gz = @embedFile("ter-u32n.bdf.gz");

pub const Weight = enum(u8) {
    b = 'b',
    n = 'n',
};

pub const Size = enum(u8) {
    @"12" = 12,
    @"14" = 14,
    @"16" = 16,
    @"18" = 18,
    @"20" = 20,
    @"22" = 22,
    @"24" = 24,
    @"28" = 28,
    @"32" = 32,
};

pub fn terminus(
    allocator: std.mem.Allocator,
    comptime size: Size,
    comptime weight: Weight,
) !common.Font {
    var buffer_reader = std.Io.Reader.fixed(@embedFile("ter-u" ++ @tagName(size) ++ @tagName(weight) ++ ".bdf.gz"));
    var buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompress = std.compress.flate.Decompress.init(&buffer_reader, .gzip, &buffer);
    const reader = &decompress.reader;

    return bdf.parse(allocator, reader);
}

test "read unifont" {
    var font32n = try terminus(testing.allocator, .@"32", .n);
    defer font32n.deinit();
    try testing.expectEqual(1356, font32n.count);

    var font16b = try terminus(testing.allocator, .@"16", .b);
    defer font16b.deinit();
    try testing.expectEqual(1356, font16b.count);
}

const std = @import("std");
const testing = std.testing;

const common = @import("../../common.zig");
const bdf = @import("../../bdf.zig");
