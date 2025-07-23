//! X11 client library.

// workaround for documentation

/// Functions to create a connection to X11 server.
pub const connection = @import("x11/connection.zig");

/// After connecting, need to get Setup information.
pub const setup = @import("x11/setup.zig");

/// X11 ID generation mechanism.
pub const xid = @import("x11/xid.zig");

/// All requests, messages, replies and other structs for X11 protocol.
pub const proto = @import("x11/proto.zig");

/// Functions to receive and send data to X11.
pub const io = @import("x11/io.zig");

/// Create and convert images to X11 expected format.
pub const image = @import("x11/image.zig");

/// Random utilities.
pub const utils = @import("x11/utils.zig");
