const std = @import("std");

const xconnection = @import("connection.zig");
const xauth = @import("auth.zig");
const xsetup = @import("setup.zig");
const id_generator = @import("id_generator.zig");
const xwindow = @import("window.zig");
const xgraphic_context = @import("graphic_context.zig");
const xpixmap = @import("pixmap.zig");
const xdraw = @import("draw.zig");

const X11Options = struct {};

// TODO: Add logger

// TODO: probably should be single threaded

const X11 = struct {
    options: X11Options = .{},
    allocator: std.mem.Allocator,

    connection: ?std.net.Stream = null,
    xdata: ?xsetup.Setup = null,
    id_gen: ?id_generator.IDGenerator = null,

    pub fn init(allocator: std.mem.Allocator, options: X11Options) @This() {
        return .{
            .allocator = allocator,
            .options = options,
        };
    }

    pub fn deinit(self: *@This()) void {
        if (self.connection) |conn| {
            conn.close();
        }
    }

    pub fn connect(self: *@This()) !void {
        self.connection = try xconnection.connect(.{.read_timeout=5000});
    }

    pub fn setup(self: *@This()) !void {
        if (self.connection) |conn| {
            self.xdata = try xsetup.setup(self.allocator, conn);
            self.id_gen = id_generator.IDGenerator.init(self.xdata.?.resource_id_base, self.xdata.?.resource_id_mask);
        } else {
            return error.NotConnected;
        }
    }

    pub fn genID(self: *@This()) !u32 {
        return self.id_gen.?.genID();
    }

    pub fn createWindow(self: *@This(), src_options: xwindow.WindowOptions) !u32 {
        const options = withDefaultWindowOptions(self.xdata.?.screens[0], src_options);
        const window_id = try self.genID();
        try xwindow.createWindowRequest(self.connection.?, window_id, options);
        return window_id;
    }

    pub fn destroyWindow(self: *@This(), window_id: u32) !void {
        try xwindow.mapWindowRequest(self.connection.?, window_id);
    }

    pub fn mapWindow(self: *@This(), window_id: u32) !void {
        try xwindow.mapWindowRequest(self.connection.?, window_id);
    }

    pub fn unmapWindow(self: *@This(), window_id: u32) !void {
        try xwindow.unmapWindowRequest(self.connection.?, window_id);
    }

    pub fn createGraphicContext(self: *@This(), options: xgraphic_context.GraphicContextOptions) !u32 {
        const graphic_context_id = try self.genID();
        try xgraphic_context.createGraphicContext(self.connection.?, graphic_context_id,options);
        return graphic_context_id;
    }

    pub fn freeGraphicContext(self: *@This(), graphic_context_id: u32) !void {
        try xgraphic_context.freeGraphicContext(self.connection.?, graphic_context_id);
    }

    pub fn createPixmap(self: *@This(), options: xpixmap.PixmapOptions) !u32 {
        const pixmap_id = try self.genID();
        try xpixmap.createPixmap(self.connection.?,pixmap_id, options);
        return pixmap_id;
    }

    pub fn freePixmap(self: *@This(), pixmap_id: u32) !void {
        try xpixmap.freePixmap(self.connection.?, pixmap_id);
    }

    pub fn putImage(self: *@This(), data: []const u8, options: xdraw.PutImageOptions) !void {
        try xdraw.putImage(self.connection.?,data, options);
    }

    pub fn copyArea(self: *@This(), options: xdraw.CopyAreaOptions) !void {
        try xdraw.copyArea(self.connection.?, options);
    }

    pub fn receive(self: *@This()) !?Message {
        if (self.connection) |conn| {
            return readMessage(self.allocator, conn);
        } else {
            return error.NotConnected;
        }
    }
};

pub const init = X11.init;

fn withDefaultWindowOptions(screen: xsetup.Screen, _: xwindow.WindowOptions) xwindow.WindowOptions {
    var options = xwindow.WindowOptions{};

    options.parent_window = screen.root;
    options.depth = screen.root_depth;
    options.visual_id = screen.root_visual;

    // TODO: override from src

    return options;
}

fn readMessage(_: std.mem.Allocator, reader: anytype) !?Message {
    std.debug.print("Reading message...\n", .{});
    var message: [32]u8 = undefined;
    const read = reader.read(&message) catch |err| {
        switch (err) {
            error.WouldBlock => return null,
            else => return err,
        }
    };
    std.debug.print("Bytes read: {d}\n", .{read});

    const message_type = message[0];
    std.debug.print("Message type: {d}\n", .{message_type});

    switch (message_type) {
        0 => {
            const error_message = std.mem.bytesAsValue(ErrorMessage, message[0..@sizeOf(ErrorMessage)]);
            std.debug.print("Error: {any}\n", .{error_message});
            return Message{ .error_message = error_message.* };
        },
        else => return null,
    }
    return null;
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
    //pad: [21]u8, // error messages always have 32 bytes total
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
