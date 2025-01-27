//! Functions to connect to an X11 server.

const std = @import("std");
const os = std.posix;

const log = std.log.scoped(.x11);

/// Options for the X11 connection
pub const ConnectionOptions = struct {
    /// Read timeout in microseconds (5000 => 5ms)
    read_timeout: i32 = 5000, // 5ms in microseconds
    /// Write timeout in microseconds (5000 => 5ms)
    write_timeout: i32 = 5000, // 5ms in microseconds
};

/// Connects to local X11 server.
/// It will look for DISPLAY env variable, or default to :0.
pub fn connect(options: ConnectionOptions) !std.net.Stream {
    var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const socket_path = try get_socket_path(&buffer);

    log.debug("Socket path: {s}", .{socket_path});

    // Assuming unix socket
    const stream = try std.net.connectUnixSocket(socket_path);
    try setTimeout(stream.handle, options.read_timeout, options.write_timeout);

    log.debug("Connected", .{});

    return stream;
}

/// Return the file path for the socket to active display.
/// Look at DISPLAY env var for display, else default to :0
/// Uses provided buffer and return only the needed part.
fn get_socket_path(buffer: []u8) ![]const u8 {
    const display = std.posix.getenv("DISPLAY") orelse ":0";
    log.debug("Display: {s}", .{display});

    const base_socket_path = "/tmp/.X11-unix/X";
    const socket_path_len = base_socket_path.len + display.len - 1;

    if (buffer.len < socket_path_len) {
        return error.SocketPathBufferTooSmall;
    }

    var socket_path = buffer[0..socket_path_len];

    std.mem.copyForwards(u8, socket_path[0..base_socket_path.len], base_socket_path);
    std.mem.copyForwards(u8, socket_path[base_socket_path.len..socket_path_len], display[1..]);

    return socket_path;
}

/// Set read and write timeout on a socket.
/// Timeout units in microseconds (1000 microsecond is 1 millisecond).
fn setTimeout(socket: os.socket_t, read_timeout: i32, write_timeout: i32) !void {
    if (read_timeout > 0) {
        var timeout: os.timeval = undefined;
        timeout.tv_sec = @as(c_long, @intCast(@divTrunc(read_timeout, 1000000)));
        timeout.tv_usec = @as(c_long, @intCast(@mod(read_timeout, 1000000)));
        try os.setsockopt(
            socket,
            os.SOL.SOCKET,
            os.SO.RCVTIMEO,
            std.mem.toBytes(timeout)[0..],
        );
    }

    if (write_timeout > 0) {
        var timeout: os.timeval = undefined;
        timeout.tv_sec = @as(c_long, @intCast(@divTrunc(write_timeout, 1000000)));
        timeout.tv_usec = @as(c_long, @intCast(@mod(write_timeout, 1000000)));
        try os.setsockopt(
            socket,
            os.SOL.SOCKET,
            os.SO.SNDTIMEO,
            std.mem.toBytes(timeout)[0..],
        );
    }
}
