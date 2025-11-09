//! Functions to send Requests and receive Responses, Messages and Replies from an X11 socket.
//! This will be part of your core loop.

const std = @import("std");
const proto = @import("proto.zig");

const testing = std.testing;

const log = std.log.scoped(.x11);

pub fn send(conn: std.net.Stream, request: anytype) !void {
    //var write_buffer: [64]u8 = undefined;
    //var conn_writer = conn.writer(&write_buffer);
    //const writer = &conn_writer.interface;
    //return write(writer, request);
    const req_bytes: []const u8 = &std.mem.toBytes(request);
    _ = std.posix.send(conn.handle, req_bytes, 0) catch unreachable;
}

/// Send a request to a socket.
/// Use with any Request struct from proto namespace that does not need extra data.
pub fn write(writer: *std.Io.Writer, request: anytype) !void {
    const req_bytes: []const u8 = &std.mem.toBytes(request);
    log.debug("Sending (size: {d}): {any}", .{ req_bytes.len, request });
    try writer.writeAll(req_bytes);
    try writer.flush();
}

pub fn sendWithBytes(conn: std.net.Stream, request: anytype, bytes: []const u8) !void {
    var write_buffer: [64]u8 = undefined;
    var conn_writer = conn.writer(&write_buffer);
    const writer = &conn_writer.interface;
    //return writeWithBytes(writer, request, bytes);

    var reader = std.Io.Reader.fixed(bytes);

    return stream(writer, request, &reader, bytes.len);
}

/// Send a request to a socket with some extra bytes at the end.
/// It re-calculate the propriate length and add neded padding.
/// Use with Request structs from proto namespace that require additional data to be sent.
pub fn writeWithBytes(writer: *std.Io.Writer, request: anytype, bytes: []const u8) !void {
    // send request with overriden length
    const req_bytes = request_bytes_fixed_len(request, bytes.len);
    try writer.writeAll(&req_bytes);

    // write extra bytes
    try writer.writeAll(bytes);

    // calculate padding and send it
    const pad_len = get_pad_len(bytes.len);
    const padding: [3]u8 = .{ 0, 0, 0 };
    const pad = padding[0..pad_len];
    try writer.writeAll(pad);

    try writer.flush();
}

pub fn sendFromReader(conn: std.net.Stream, request: anytype, reader: *std.Io.Reader, len: usize) !void {
    var write_buffer: [64]u8 = undefined;
    var conn_writer = conn.writer(&write_buffer);
    const writer = &conn_writer.interface;
    return stream(writer, request, reader, len);
}

pub fn stream(writer: *std.Io.Writer, request: anytype, reader: *std.Io.Reader, len: usize) !void {
    // send request with overriden length
    const req_bytes = request_bytes_fixed_len(request, len);
    try writer.writeAll(&req_bytes);

    // write extra bytes
    _ = try reader.stream(writer, .unlimited);

    // calculate padding and send it
    const pad_len = get_pad_len(len);
    const padding: [3]u8 = .{ 0, 0, 0 };
    const pad = padding[0..pad_len];
    try writer.writeAll(pad);

    try writer.flush();
}

fn request_bytes_fixed_len(request: anytype, bytes_len: usize) [@sizeOf(@TypeOf(request))]u8 {
    var req_bytes = std.mem.toBytes(request);

    // re-calc length to include extra data

    // get length including the request, extra bytes and padding needed
    const length = get_padded_len(request, bytes_len);
    // bytes 3 and 4 (a u16) of a request is always length, we can override it to include the total size
    const len_bytes = std.mem.toBytes(length);
    req_bytes[2] = len_bytes[0];
    req_bytes[3] = len_bytes[1];

    log.debug("Sending (size: {d}): {any}", .{ req_bytes.len, request });
    log.debug("Sending extra bytes len  {d}", .{bytes_len});

    return req_bytes;
}

/// Return total length, including padding, that is need for whole data to be a multiple of 4.
fn get_padded_len(request: anytype, src_bytes_len: usize) u16 {
    const req_len: u16 = @sizeOf(@TypeOf(request)) / 4; // size of core request
    const bytes_len: u16 = @intCast(src_bytes_len); // size of extra bytes
    const pad_len: u16 = get_pad_len(bytes_len); // size of padding
    const extra_len: u16 = (bytes_len + pad_len) / 4; // total extra len (bytes + padding)
    const length: u16 = req_len + extra_len; // total request length
    return length;
}

test "Length calc" {
    const change_prop = proto.ChangeProperty{ .window_id = 0, .property = 0, .property_type = 0 };
    const len0 = get_padded_len(change_prop, "");

    try testing.expectEqual(6, len0);

    const len1 = get_padded_len(change_prop, "hello");
    try testing.expectEqual(8, len1);
}

/// Get how much padding is needed for the extra bytes to be multiple of 4.
fn get_pad_len(bytes_len: usize) u16 {
    const missing = bytes_len % 4;
    if (missing == 0) {
        return 0;
    }
    return @as(u16, @intCast(4 - missing));
}

test "padding length" {
    const len0 = get_pad_len("".len);
    try testing.expectEqual(0, len0);

    const len1 = get_pad_len("1234".len);
    try testing.expectEqual(0, len1);

    const len2 = get_pad_len("12345".len);
    try testing.expectEqual(3, len2);

    const len3 = get_pad_len("12345678".len);
    try testing.expectEqual(0, len3);
}

pub fn receive(conn: std.net.Stream) !?Message {
    var read_buffer: [64]u8 = undefined;
    var conn_reader = conn.reader(&read_buffer);
    const reader = conn_reader.interface();

    return read(reader) catch |err| {
        if (conn_reader.getError()) |conn_err| {
            if (conn_err == error.WouldBlock) {
                return null; // just a timeout
            }
        }
        return err;
    };
}

/// Receive next message from X11 server.
pub fn read(reader: *std.Io.Reader) !?Message {
    var message_buffer: [32]u8 = undefined;

    try reader.readSliceAll(&message_buffer);

    var message_stream = std.io.fixedBufferStream(&message_buffer);
    var message_reader = message_stream.reader();

    // The most significant bit in this code is set if the event was generated from a SendEvent
    // So we remove it
    const message_code = message_buffer[0] & 0b01111111;
    const sent_event = message_buffer[0] & 0b10000000 == 0b10000000;

    // Using comptime to map to all known messages
    const message_tag = std.meta.Tag(Message); // Get Tag object of list of possible messages
    const message_values = comptime std.meta.fields(message_tag); // Get all fields of the Tag
    inline for (message_values) |tag| { // For each possible message
        // Here is emitted code
        if (message_code == tag.value) { // The tag value is the same as the received message
            // Return the struct from the bytes and build the union.
            const message = try message_reader.readStruct(@field(proto, tag.name));
            log.debug("Received message ({any}): {any}", .{ sent_event, message });
            return @unionInit(Message, tag.name, message);
        }
    }

    log.warn("Unrecognized message: code={d} bytes={any} sent={any}", .{ message_code, &message_buffer, sent_event });

    return null;
}

/// A Map with all known messages, in order of message code.
pub const Message = union(enum(u8)) {
    ErrorMessage: proto.ErrorMessage,
    Placeholder: proto.Placeholder,
    KeyPress: proto.KeyPress,
    KeyRelease: proto.KeyRelease,
    ButtonPress: proto.ButtonPress,
    ButtonRelease: proto.ButtonRelease,
    MotionNotify: proto.MotionNotify,
    EnterNotify: proto.EnterNotify,
    LeaveNotify: proto.LeaveNotify,
    FocusIn: proto.FocusIn,
    FocusOut: proto.FocusOut,
    KeymapNotify: proto.KeymapNotify,
    Expose: proto.Expose,
    GraphicsExposure: proto.GraphicsExposure,
    NoExposure: proto.NoExposure,
    VisibilityNotify: proto.VisibilityNotify,
    CreateNotify: proto.CreateNotify,
    DestroyNotify: proto.DestroyNotify,
    UnmapNotify: proto.UnmapNotify,
    MapNotify: proto.MapNotify,
    MapRequest: proto.MapRequest,
    ReparentNotify: proto.ReparentNotify,
    ConfigureNotify: proto.ConfigureNotify,
    ConfigureRequest: proto.ConfigureRequest,
    GravityNotify: proto.GravityNotify,
    ResizeRequest: proto.ResizeRequest,
    CirculateNotify: proto.CirculateNotify,
    CirculateRequest: proto.CirculateRequest,
    PropertyNotify: proto.PropertyNotify,
    SelectionClear: proto.SelectionClear,
    SelectionRequest: proto.SelectionRequest,
    SelectionNotify: proto.SelectionNotify,
    ColormapNotify: proto.ColormapNotify,
    ClientMessage: proto.ClientMessage,
    MappingNotify: proto.MappingNotify,
};
