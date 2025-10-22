//! Functions get authentication information to connect to X11 server.
//! Currently only supports MIT-MAGIC-COOKIE.

const std = @import("std");

const log = std.log.scoped(.x11);

/// Looks for the Xauthority file and open it.
/// Calee should close it after use.
fn open_xauth_file() !std.fs.File {
    if (std.posix.getenv("XAUTHORITY")) |file| {
        log.debug("Xauthority file: {s}", .{file});
        return std.fs.openFileAbsolute(file, .{});
    } else if (std.posix.getenv("HOME")) |home| {
        var dir = try std.fs.openDirAbsolute(home, .{});
        defer dir.close();
        log.debug("Xauthority file: {s}/.Xauthority", .{home});
        return dir.openFile(".Xauthority", .{});
    } else {
        return error.NoAuthorityFileFound;
    }
}

/// Reads the authority file.
/// Only supports MIT-MAGIC-COOKIE method.
/// Ignore address and port, only support local method.
fn read_xauth_file(allocator: std.mem.Allocator, xauth_file: std.fs.File) !XAuth {
    var buffer: [1024]u8 = undefined;

    var xauth_file_reader = xauth_file.reader(&buffer);
    const xauth_reader = &xauth_file_reader.interface;

    // Skip unsupported fields
    try xauth_reader.discardAll(2); // skip family
    const address_len = try xauth_reader.takeInt(u16, .big); // size of address
    try xauth_reader.discardAll(address_len); // skip address
    const number_len = try xauth_reader.takeInt(u16, .big); // size of number
    try xauth_reader.discardAll(number_len); // skip number

    // Read auth name
    const xauth_name_len = try xauth_reader.takeInt(u16, .big); // size of xauth name
    const xauth_name = try allocator.alloc(u8, xauth_name_len);
    errdefer allocator.free(xauth_name);
    try xauth_reader.readSliceAll(xauth_name); // read name

    // Read auth data
    const xauth_data_len = try xauth_reader.takeInt(u16, .big); // size of xauth data
    const xauth_data = try allocator.alloc(u8, xauth_data_len);
    errdefer allocator.free(xauth_data);
    try xauth_reader.readSliceAll(xauth_data); // read data

    if (!std.mem.eql(u8, xauth_name, "MIT-MAGIC-COOKIE-1")) {
        return error.UnsupportedAuth;
    }

    log.debug("Auth name: {s}", .{xauth_name});

    return .{
        .name = xauth_name,
        .data = xauth_data,
        .allocator = allocator,
    };
}

/// Authentication information
pub const XAuth = struct {
    name: []const u8,
    data: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: @This()) void {
        self.allocator.free(self.name);
        self.allocator.free(self.data);
    }
};

/// Return authentication information.
/// It will look at XAUTHORITY env var for location of Xauthority file, next it will look for it at HOME.
/// It returns an XAuth struct that needs to be deinit'd after use.
pub fn get_auth(allocator: std.mem.Allocator) !XAuth {
    const xauth_file = try open_xauth_file();
    defer xauth_file.close();
    const xauth = try read_xauth_file(allocator, xauth_file);
    return xauth;
}
