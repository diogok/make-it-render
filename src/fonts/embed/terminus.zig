const std = @import("std");

const terminus_tar_xz = @embed("terminus.tar.xz");

pub fn listFonts(allocator: std.mem.Allocator) ![][]const u8 {
    const fixed_stream = std.io.fixedStreamReader(terminus_tar_xz);
    defer fixed_stream.close();
    var fixed_reader = fixed_stream.reader();

    var decompressor = try std.compress.xz.decompress(allocator, reader);
    defer decompressor.deinit();

    var xz_reader = decompressor.reader();

    var iterator = std.tar.iterator(xz_reader, null);

    var fonts = std.ArrayList([]const u8).init(allocator);
    while (try iterator.next()) |file| {
        var extension = std.path.extension(file.name);
        if (std.mem.eql(u8, extension, ".bdf")) {
            var file_reader = file.reader();
            var header = try bdf.reader_header(allocator, file_reader);
            fonts.append(header.font);
        }
    }
    return try fonts.toOwnedSlice();
}

pub fn freeFontList(allocator: std.mem.Allocator, fonts: [][]const u8) void {
    for (fonts) |font| {
        allocator.free(font);
    }
    allocator.free(fonts);
}

test "list fonts" {
    std.debug.print(listFonts(std.testing.allocator));
}
