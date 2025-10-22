//! X11 client library.

pub const connection = @import("x11/connection.zig");
pub const setup0 = @import("x11/setup.zig");
pub const xid = @import("x11/xid.zig");
pub const proto = @import("x11/proto.zig");
pub const io = @import("x11/io.zig");
pub const image = @import("x11/image.zig");
pub const utils = @import("x11/utils.zig");

pub const ConnectionOptions = connection.ConnectionOptions;
pub const connect = connection.connect;

pub const setup = setup0.setup;
pub const Setup = setup0.Setup;
pub const Screen = setup0.Screen;
pub const Depth = setup0.Depth;

pub const XID = xid.XID;

pub const send = io.send;
pub const sendWithBytes = io.sendWithBytes;
pub const receive = io.receive;
pub const Message = io.Message;

pub const ImageInfo = image.ImageInfo;
pub const getImageInfo = image.getImageInfo;
pub const rgbaToZPixmapAlloc = image.rgbaToZPixmapAlloc;

pub const mask = utils.mask;
pub const maskFromValues = utils.maskFromValues;
pub const sendWithValues = utils.sendWithValues;
pub const internAtom = utils.internAtom;
pub const clientMessageData = utils.clientMessageData;
pub const ClientMessageData = utils.ClientMessageData;
pub const receiveReply = utils.receiveReply;

test {
    const refAllDecls = @import("std").testing.refAllDecls;
    refAllDecls(@import("x11/auth.zig"));
    refAllDecls(@import("x11/connection.zig"));
    refAllDecls(@import("x11/setup.zig"));
    refAllDecls(@import("x11/xid.zig"));
    refAllDecls(@import("x11/proto.zig"));
    refAllDecls(@import("x11/io.zig"));
    refAllDecls(@import("x11/image.zig"));
    refAllDecls(@import("x11/utils.zig"));
}
