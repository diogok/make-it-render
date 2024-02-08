const std = @import("std");

pub fn send(writer: anytype, request: anytype) !void {
    const req_bytes: []const u8 = &std.mem.toBytes(request);
    try writer.writeAll(req_bytes);
}

pub fn sendWithValues(writer: anytype, request: anytype, values: []const u32) !void {
    var req_bytes = std.mem.toBytes(request);

    // re-calc length to include extra data
    const base_len: u16 = @sizeOf(@TypeOf(request)) / 4;
    const add_len: u16 = @intCast(values.len); // already in groups of 4 bytes
    const length: u16 = base_len + add_len;
    const len_bytes = std.mem.toBytes(length);
    req_bytes[2] = len_bytes[0];
    req_bytes[3] = len_bytes[1];

    // send request with overriden length
    try writer.writeAll(&req_bytes);

    // write values
    for (values) |value| {
        try writer.writeAll(&std.mem.toBytes(value));
    }
}

pub fn sendWithBytes(writer: anytype, request: anytype, bytes: []const u8) !void {
    var req_bytes = std.mem.toBytes(request);

    // re-calc length to include extra data
    const base_len: u16 = @sizeOf(@TypeOf(request)) / 4;
    const add_len: u16 = @intCast(bytes.len + bytes.len % 4); // need to pad
    const length: u16 = base_len + add_len / 4;
    const len_bytes = std.mem.toBytes(length);
    req_bytes[2] = len_bytes[0];
    req_bytes[3] = len_bytes[1];

    // send request with overriden length
    try writer.writeAll(&req_bytes);

    // write extra bytes
    try writer.writeAll(bytes);

    // pad
    const pad: [3]u8 = .{ 0, 0, 0 };
    try writer.writeAll(pad[0..(bytes.len % 4)]);
}
