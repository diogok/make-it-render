const std = @import("std");

pub fn send(writer: anytype, request: anytype) !void {
    const req_bytes: []const u8 = &std.mem.toBytes(request);
    try writer.writeAll(req_bytes);
}

pub fn sendWithValues(writer: anytype, request: anytype, values: []const u32) !void {
    try sendWithBytes(writer, request, std.mem.sliceAsBytes(values));
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


pub fn receive(_: std.mem.Allocator, reader: anytype) !?Message {
    var message: [32]u8 = undefined;
    _ = reader.read(&message) catch |err| {
        switch (err) {
            error.WouldBlock => return null,
            else => return err,
        }
    };

    var message_stream = std.io.fixedBufferStream(&message);
    var message_reader = message_stream.reader();

    const message_type = message[0];
    switch (message_type) {
        0 => {
            const error_message = try message_reader.readStruct(ErrorMessage);
            return Message{ .error_message = error_message };
        },
        else => return null,
    }
    return null;
}

pub fn receiveAll(allocator: std.mem.Allocator, reader: anytype) ![]const Message {
    var arr = std.ArrayList(Message).init(allocator);

    var message = try receive(allocator, reader);
    while (message) |msg| {
        try arr.append(msg);
        message = try receive(allocator, reader);
    }

    return arr.toOwnedSlice();
}

const Message = union(enum) {
    error_message: ErrorMessage,
};

const ErrorMessage = extern struct {
    result_code: u8, // already read to know it is an error
    error_code: ErrorCodes,
    sequence_number: u16,
    details: u32,
    minor_opcode: u16,
    major_opcode: u8,
    pad: [21]u8, // error messages always have 32 bytes total
};

const ErrorCodes = enum(u8) {
    NoError, // ??
    Request,
    Value,
    Window,
    Pixmap,
    Atom,
    Cursor,
    Font,
    Match,
    Drawable,
    Access,
    Alloc,
    Colormap,
    GContext,
    IDChoice,
    Name,
    Length,
    Implementation,
};
