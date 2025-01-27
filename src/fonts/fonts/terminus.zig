const std = @import("std");
const testing = std.testing;

const fontz = @import("fontz");

const terminus_tar_gz = @embedFile("terminus.tar.gz");

pub const Weight = enum(u8) {
    bold = 'b',
    normal = 'n',
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

pub fn getFont(allocator: std.mem.Allocator, size: Size, weight: Weight) !fontz.Font {
    var target_buffer: [13]u8 = undefined;
    const target_file = try std.fmt.bufPrint(&target_buffer, "ter-u{d}{c}.bdf", .{ @intFromEnum(size), @intFromEnum(weight) });

    var gz_stream = std.io.fixedBufferStream(terminus_tar_gz);
    var gz_decompressor = std.compress.gzip.decompressor(gz_stream.reader());

    var fn_buffer: [13]u8 = undefined;
    var ln_buffer: [13]u8 = undefined;
    const tar_iter_opts = std.tar.IteratorOptions{
        .file_name_buffer = &fn_buffer,
        .link_name_buffer = &ln_buffer,
    };
    var tar_iter = std.tar.iterator(gz_decompressor.reader(), tar_iter_opts);
    while (try tar_iter.next()) |file| {
        if (std.mem.eql(u8, target_file, file.name)) {
            var file_reader = file.reader();
            return try fontz.bdf.parse(allocator, &file_reader);
        }
    }

    return error.FontNotFound;
}

test "get a font" {
    var font = try getFont(testing.allocator, .@"12", .normal);
    defer font.deinit();

    const A = font.get('a');
    try testing.expect(A != null);
}
