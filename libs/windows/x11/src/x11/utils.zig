//! Utilities to make some common tasks easier.
//! Not part of standard.

const std = @import("std");
const proto = @import("proto.zig");
const io = @import("io.zig");

const testing = std.testing;

const log = std.log.scoped(.x11);

/// Build a mask as expected from, example, CreateWindow.eventMask.
pub fn mask(values: anytype) u32 {
    var value_mask: u32 = 0;
    for (values) |value| {
        value_mask |= @intFromEnum(value);
    }
    return value_mask;
}

test "mask" {}

/// Build a mask as expected from, example, CreateWindow.eventMask.
/// Based of values you will pass.
pub fn maskFromValues(comptime MaskType: type, values: anytype) u32 {
    var value_mask: u32 = 0;
    inline for (@typeInfo(@TypeOf(values)).Struct.fields) |field| {
        const value = @field(values, field.name);
        if (value) |_| {
            value_mask |= @intFromEnum(@field(MaskType, field.name));
        }
    }
    return value_mask;
}

test "mask from values" {
    const result = maskFromValues(proto.WindowMask, proto.WindowValue{
        .Colormap = 2,
        .BackgroundPixel = 1,
        .EventMask = 0b1,
    });
    const expected: u32 = @intFromEnum(proto.WindowMask.BackgroundPixel) | @intFromEnum(proto.WindowMask.EventMask) | @intFromEnum(proto.WindowMask.Colormap);
    try testing.expectEqual(expected, result);
}

fn bufferFor(MaskType: type) [@typeInfo(MaskType).Struct.fields.len * 4]u8 {
    return undefined;
}

fn bytesFromValues(buffer: []u8, values: anytype) []const u8 {
    var bytes_len: usize = 0;
    inline for (@typeInfo(@TypeOf(values)).Struct.fields) |field| {
        const value = @field(values, field.name);
        if (value) |v| {
            std.mem.copyForwards(u8, buffer[bytes_len..], std.mem.asBytes(&v));
            bytes_len += @sizeOf(@TypeOf(v));
        }
    }
    return buffer[0..bytes_len];
}

test "bytesFromValues" {
    const values = proto.WindowValue{
        .Colormap = 2,
        .BackgroundPixel = 3,
        .EventMask = 0b1,
    };
    var buffer = bufferFor(proto.WindowValue);
    const bytes = bytesFromValues(&buffer, values);
    const expected = [_]u8{
        0b11, 0b0, 0b0, 0b0, // BackgroundPixel
        0b1, 0b0, 0b0, 0b0, // EventMask
        0b10, 0b0, 0b0, 0b0, // Colormap
    };
    try testing.expectEqualSlices(u8, &expected, bytes);
}

/// Like io.sendWithBytes, but this build the bytes based on values.
/// Example is CreateWindow WindowValue (to go with WindowMasks).
pub fn sendWithValues(writer: anytype, request: anytype, values: anytype) !void {
    var buffer = bufferFor(@TypeOf(values));
    const bytes = bytesFromValues(&buffer, values);
    try io.sendWithBytes(writer, request, bytes);
}

/// Utility to get ID of an Atom.
/// This is naive because it expects that the next message is always the reply.
/// Works fine before you create a window.
pub fn internAtom(conn: anytype, name: []const u8) !u32 {
    const request = proto.InternAtom{ .length_of_name = @truncate(name.len) };
    try io.sendWithBytes(conn, request, name);

    const reply = try receiveReply(conn, proto.InternAtomReply);
    if (reply) |r| {
        return r.atom;
    }

    return error.FailedToInternAtom;
}

/// ClientMessage.data values can depend on the format.
/// This return already in the right format.
pub fn clientMessageData(clientMesage: proto.ClientMessage) ClientMessageData {
    switch (clientMesage.format) {
        8 => {
            return ClientMessageData{ .u8 = clientMesage.data };
        },
        16 => {
            return ClientMessageData{ .u16 = std.mem.bytesToValue([10]u16, &clientMesage.data) };
        },
        32 => {
            return ClientMessageData{ .u32 = std.mem.bytesToValue([5]u32, &clientMesage.data) };
        },
        else => {
            return ClientMessageData{ .u8 = clientMesage.data };
        },
    }
}

/// Union to use the right byte format for a ClientMessage
pub const ClientMessageData = union(enum) {
    u8: [20]u8,
    u16: [10]u16,
    u32: [5]u32,
};

/// Same a io.Receive, but for specific replies.
/// Replies don't follow quite the same rules as regular Messages,
/// It cannot be identified by first code.
/// So here we explicitly wait for a reply.
pub fn receiveReply(reader: anytype, ReplyType: type) !?ReplyType {
    var message_buffer: [32]u8 = undefined;
    _ = reader.read(&message_buffer) catch |err| {
        switch (err) {
            error.WouldBlock => return null,
            else => return err,
        }
    };

    var message_stream = std.io.fixedBufferStream(&message_buffer);
    var message_reader = message_stream.reader();

    const message = try message_reader.readStruct(ReplyType);

    return message;
}
