const std = @import("std");

fn get_socket_path(buffer: []u8) ![]const u8 {
    var display = std.os.getenv("DISPLAY") orelse ":0";
    std.debug.print("Display: {s}\n", .{display});

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

pub const ConnectionOptions = struct{
    read_timeout: i32=0, // in microseconds
    write_timeout: i32=0,  // in microseconds
};

pub fn connect(options: ConnectionOptions) !std.net.Stream {
    std.debug.print("Connecting...\n", .{});

    // TODO: assuming unix socket
    var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const socket_path = try get_socket_path(&buffer);
    std.debug.print("Socket path {s}\n", .{socket_path});

    const stream = try std.net.connectUnixSocket(socket_path);
    try setTimeout(stream.handle, options.read_timeout, options.write_timeout);
    std.debug.print("Connected to {s}\n", .{socket_path});

    return stream;
}

fn setTimeout(socket: std.os.socket_t, read_timeout: i32, write_timeout: i32) !void {
    if(read_timeout > 0){
        var timeout: std.os.timeval = undefined;
        timeout.tv_sec = @as(c_long, @intCast(@divTrunc(read_timeout, 1000000)));
        timeout.tv_usec = @as(c_long, @intCast(@mod(read_timeout, 1000000)));
        try std.os.setsockopt(
            socket,
            std.os.SOL.SOCKET,
            std.os.SO.RCVTIMEO,
            std.mem.toBytes(timeout)[0..],
        );
    }

    if(write_timeout > 0) {
        var timeout: std.os.timeval = undefined;
        timeout.tv_sec = @as(c_long, @intCast(@divTrunc(write_timeout, 1000000)));
        timeout.tv_usec = @as(c_long, @intCast(@mod(write_timeout, 1000000)));
        try std.os.setsockopt(
            socket,
            std.os.SOL.SOCKET,
            std.os.SO.SNDTIMEO,
            std.mem.toBytes(timeout)[0..],
        );
    }
}
