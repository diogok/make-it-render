//! Functions to send Requests and receive Responses, Messages and Replies from an X11 socket.
//! This will be part of your core loop.

const std = @import("std");
const proto = @import("proto.zig");

const testing = std.testing;

const log = std.log.scoped(.x11);

/// Send a request to a socket.
/// Use with any Request struct from proto namespace that does not need extra data.
pub fn send(writer: *std.Io.Writer, request: anytype) !void {
    const req_bytes: []const u8 = &std.mem.toBytes(request);
    log.debug("Sending (size: {d}): {any}", .{ req_bytes.len, request });
    try writer.writeAll(req_bytes);
    try writer.flush();
}

/// Send a request to a socket with some extra bytes at the end.
/// It re-calculate the propriate length and add neded padding.
/// Use with Request structs from proto namespace that require additional data to be sent.
pub fn sendWithBytes(writer: *std.Io.Writer, request: anytype, bytes: []const u8) !void {
    var req_bytes = std.mem.toBytes(request);

    // re-calc length to include extra data

    // get length including the request, extra bytes and padding needed
    const length = get_padded_len(request, bytes);
    // bytes 3 and 4 (a u16) of a request is always length, we can override it to include the total size
    const len_bytes = std.mem.toBytes(length);
    req_bytes[2] = len_bytes[0];
    req_bytes[3] = len_bytes[1];

    log.debug("Sending (size: {d}): {any}", .{ req_bytes.len, request });
    log.debug("Sending extra bytes len  {d}", .{bytes.len});

    // send request with overriden length
    try writer.writeAll(&req_bytes);

    // write extra bytes
    try writer.writeAll(bytes);

    // calculate padding and send it
    const pad_len = get_pad_len(bytes);
    const padding: [3]u8 = .{ 0, 0, 0 };
    const pad = padding[0..pad_len];
    try writer.writeAll(pad);

    try writer.flush();
}

/// Return total length, including padding, that is need for whole data to be a multiple of 4.
fn get_padded_len(request: anytype, bytes: []const u8) u16 {
    const req_len: u16 = @sizeOf(@TypeOf(request)) / 4; // size of core request
    const bytes_len: u16 = @intCast(bytes.len); // size of extra bytes
    const pad_len: u16 = get_pad_len(bytes); // size of padding
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
fn get_pad_len(bytes: []const u8) u16 {
    const missing = bytes.len % 4;
    if (missing == 0) {
        return 0;
    }
    const pad: u16 = @intCast(4 - missing);
    return pad;
}

test "padding length" {
    const len0 = get_pad_len("");
    try testing.expectEqual(0, len0);

    const len1 = get_pad_len("1234");
    try testing.expectEqual(0, len1);

    const len2 = get_pad_len("12345");
    try testing.expectEqual(3, len2);

    const len3 = get_pad_len("12345678");
    try testing.expectEqual(0, len3);
}

/// Receive next message from X11 server.
pub fn receive(reader: *std.Io.Reader, conn_reader: ?*std.net.Stream.Reader) !?Message {
    var message_buffer: [32]u8 = undefined;

    reader.readSliceAll(&message_buffer) catch |err| {
        if (conn_reader) |rdr| {
            if (rdr.getError()) |n_err| {
                if (n_err == error.WouldBlock) {
                    return null; // just a timeout
                }
            }
        }
        return err;
    };

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
