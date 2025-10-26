pub const unifont_gz = @embedFile("unifont-17.0.02.bdf.gz");
pub const unifont_jp_gz = @embedFile("unifont-17.0.02.bdf.gz");

pub fn unifont(allocator: std.mem.Allocator) !common.Font {
    var buffer_reader = std.Io.Reader.fixed(unifont_gz);
    var buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompress = std.compress.flate.Decompress.init(&buffer_reader, .gzip, &buffer);
    const reader = &decompress.reader;

    return bdf.parse(allocator, reader);
}

const std = @import("std");

const common = @import("../common.zig");
const bdf = @import("../bdf.zig");
