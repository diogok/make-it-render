const std = @import("std");

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
