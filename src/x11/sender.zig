const std = @import("std");

pub fn send(writer: anytype, request: anytype) !void {
    const req_bytes: []const u8 = &std.mem.toBytes(request);
    try writer.writeAll(req_bytes);
}

pub fn sendWithValues(writer: anytype, request: anytype, values: []const u32) !void {
    const req_bytes: []const u8 = &std.mem.toBytes(request);

    // write data before length, length is always same position
    try writer.writeAll(req_bytes[0..2]);

    // re-calc length to include extra data
    const base_len: u16 = @sizeOf(@TypeOf(request)) / 4;
    const add_len: u16 = @intCast(values.len); // already in groups of 4 bytes
    const length: u16 = base_len + add_len;
    try writer.writeAll(&std.mem.toBytes(length));

    // write data after length
    try writer.writeAll(req_bytes[4..]);

    // write values
    for (values) |value| {
        try writer.writeAll(&std.mem.toBytes(value));
    }
}

pub fn sendWithBytes(writer: anytype, request: anytype, bytes: []const u8) !void {
    const req_bytes: []const u8 = &std.mem.toBytes(request);

    // write data before length, length is always same position
    try writer.writeAll(req_bytes[0..2]);

    // re-calc length to include extra data
    const base_len: u16 = @sizeOf(@TypeOf(request)) / 4;
    const add_len: u16 = @intCast(bytes.len);
    const length: u16 = base_len + add_len / 4;
    try writer.writeAll(&std.mem.toBytes(length));

    // write data after length
    try writer.writeAll(req_bytes[4..]);

    // write extra bytes
    try writer.writeAll(bytes);
}
