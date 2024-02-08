const std = @import("std");

pub fn build(b: *std.Build) !void {
    _ = b.addModule("x11", .{ .root_source_file = .{ .path = "core.zig" } });
}
