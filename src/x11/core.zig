const xconnection = @import("connection.zig");
const xsetup = @import("setup.zig");
const xid_generator = @import("id_generator.zig");
const xmanager = @import("manager.zig");

pub const connect = xconnection.connect;
pub const ConnectionOptions = xconnection.ConnectionOptions;

pub const setup = xsetup.setup;
pub const XIDGenerator = xid_generator.XIDGenerator;

pub const Manager = xmanager.Manager;
