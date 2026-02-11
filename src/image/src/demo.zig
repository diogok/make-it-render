const pbm_data = @embedFile("demo.pbm");

pub fn demo(allocator: std.mem.Allocator) !common.Bitmap {
    var reader = std.Io.Reader.fixed(pbm_data);
    return pbm.parse(allocator, &reader);
}

const std = @import("std");
const common = @import("common.zig");
const pbm = @import("pbm.zig");
