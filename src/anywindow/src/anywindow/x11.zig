const std = @import("std");
const x11 = @import("x11");
const common = @import("common.zig");
const log = std.log.scoped(.any_x11);

const Atoms = struct {
    atom: u32,
    string: u32,
    wm_name: u32,
    wm_protocols: u32,
    wm_delete_window: u32,
};

pub const WindowManager = struct {
    allocator: std.mem.Allocator,

    conn: std.net.Stream,
    atoms: Atoms,
    info: x11.Setup,
    xid: x11.XID,

    net_writer_buffer: []u8,
    net_writer: *std.net.Stream.Writer,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        const conn = try x11.connect(.{});
        const info = try x11.setup(allocator, conn);
        const xid = x11.XID.init(info.resource_id_base, info.resource_id_mask);

        const atoms = Atoms{
            .atom = try x11.internAtom(conn, "ATOM"),
            .string = try x11.internAtom(conn, "STRING"),
            .wm_name = try x11.internAtom(conn, "WM_NAME"),
            .wm_protocols = try x11.internAtom(conn, "WM_PROTOCOLS"),
            .wm_delete_window = try x11.internAtom(conn, "WM_DELETE_WINDOW"),
        };

        const net_writer_buffer: []u8 = try allocator.alloc(u8, 4 * 1024 * 1024);
        const net_writer = try allocator.create(std.net.Stream.Writer);
        net_writer.* = conn.writer(net_writer_buffer);

        return @This(){
            .allocator = allocator,
            .conn = conn,
            .info = info,
            .xid = xid,
            .atoms = atoms,

            .net_writer_buffer = net_writer_buffer,
            .net_writer = net_writer,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.conn.close();
        self.info.deinit();
        self.allocator.free(self.net_writer_buffer);
        self.allocator.destroy(self.net_writer);
    }

    pub fn createWindow(self: *@This(), options: common.WindowOptions) !Window {
        return try Window.init(self, options);
    }

    pub fn receive(self: *@This()) !common.Event {
        if (try x11.receive(self.conn)) |message| {
            switch (message) {
                .Expose => |expose| {
                    return .{
                        .draw = .{
                            .window_id = expose.window_id,
                            .area = common.BBox{
                                .x = 0,
                                .y = 0,
                                .width = 0,
                                .height = 0,
                            },
                        },
                    };
                },
                .ClientMessage => |client_message| {
                    const client_message_data = x11.clientMessageData(client_message);
                    if (client_message_data.u32[0] == self.atoms.wm_delete_window) {
                        return .{ .close = client_message.window_id };
                    }
                    return .{ .nop = {} };
                },
                .KeyRelease => |key_release| {
                    return .{
                        .key_released = .{
                            .window_id = key_release.event_window,
                            .key = key_release.keycode,
                        },
                    };
                },
                .KeyPress => |key_press| {
                    return .{
                        .key_pressed = .{
                            .window_id = key_press.event_window,
                            .key = key_press.keycode,
                        },
                    };
                },
                .ButtonRelease => |button_release| {
                    return .{
                        .mouse_released = .{
                            .window_id = button_release.event_window,
                            .x = button_release.event_x,
                            .y = button_release.event_y,
                            .button = button_release.keycode,
                        },
                    };
                },
                .ButtonPress => |button_press| {
                    return .{
                        .mouse_pressed = .{
                            .window_id = button_press.event_window,
                            .x = button_press.event_x,
                            .y = button_press.event_y,
                            .button = button_press.keycode,
                        },
                    };
                },
                .MotionNotify => |motion_notify| {
                    return .{
                        .mouse_moved = .{
                            .x = motion_notify.event_x,
                            .y = motion_notify.event_y,
                            .window_id = motion_notify.event_window,
                        },
                    };
                },
                else => {
                    return .{ .nop = {} };
                },
            }
        } else {
            return .{ .nop = {} };
        }
    }

    pub fn flush(self: *@This()) !void {
        self.net_writer.interface.flush() catch |err| {
            if (self.net_writer.err) |net_err| {
                log.err("Net error: {any}", .{net_err});
                return net_err;
            } else {
                log.err("Writer error: {any}", .{err});
                return err;
            }
        };
    }
};

/// RGB to BGR
fn commonPixelToX11Pixel(src: [3]u8) u32 {
    const dst: [4]u8 = [4]u8{ 1, src[2], src[1], src[0] };
    return std.mem.bytesToValue(u32, &dst);
}

pub const Window = struct {
    window_id: u32,
    wm: *WindowManager,

    status: common.WindowStatus,

    depth: u8,
    root: u32,
    graphic_context_id: u32,

    redraw_timer: std.time.Timer,

    pub fn init(wm: *WindowManager, options: common.WindowOptions) !@This() {
        const window_id = try wm.xid.genID();
        const event_masks = [_]x11.proto.EventMask{
            .Exposure,
            .StructureNotify,
            .SubstructureNotify,
            .PropertyChange,
            .KeyPress,
            .KeyRelease,
            .ButtonPress,
            .ButtonRelease,
            .PointerMotion,
        };
        const window_values = x11.proto.WindowValue{
            .BackgroundPixel = commonPixelToX11Pixel(options.background),
            .EventMask = x11.mask(&event_masks),
            .Colormap = wm.info.screens[0].colormap,
        };
        const create_window = x11.proto.CreateWindow{
            .window_id = window_id,

            .parent_id = wm.info.screens[0].root,
            .visual_id = wm.info.screens[0].root_visual,
            .depth = wm.info.screens[0].root_depth,

            .x = options.x orelse 10,
            .y = options.y orelse 10,
            .width = options.width orelse 640,
            .height = options.height orelse 480,
            .border_width = 0,
            .window_class = .InputOutput,

            .value_mask = x11.maskFromValues(x11.proto.WindowMask, window_values),
        };
        try x11.sendWithValues(wm.conn, create_window, window_values);

        const set_name_req = x11.proto.ChangeProperty{
            .window_id = window_id,
            .property = wm.atoms.wm_name,
            .property_type = wm.atoms.string,
            .length_of_data = @truncate(options.title.len),
        };
        try x11.sendWithBytes(wm.conn, set_name_req, options.title);

        const set_protocols = x11.proto.ChangeProperty{
            .window_id = window_id,
            .property = wm.atoms.wm_protocols,
            .property_type = wm.atoms.atom,
            .format = 32,
            .length_of_data = 1,
        };
        try x11.sendWithBytes(wm.conn, set_protocols, &std.mem.toBytes(wm.atoms.wm_delete_window));

        const graphic_context_id = try wm.xid.genID();
        const graphic_context_values = x11.proto.GraphicContextValue{
            .Background = wm.info.screens[0].black_pixel,
            .Foreground = wm.info.screens[0].white_pixel,
        };

        const create_gc = x11.proto.CreateGraphicContext{
            .graphic_context_id = graphic_context_id,
            .drawable_id = window_id,
            .value_mask = x11.maskFromValues(x11.proto.GraphicContextMask, graphic_context_values),
        };
        try x11.sendWithValues(wm.conn, create_gc, graphic_context_values);

        const redraw_timer = try std.time.Timer.start();

        return @This(){
            .window_id = window_id,
            .wm = wm,
            .status = .open,

            .root = wm.info.screens[0].root,
            .depth = wm.info.screens[0].root_depth,
            .graphic_context_id = graphic_context_id,

            .redraw_timer = redraw_timer,
        };
    }

    pub fn destroy(self: *@This()) !void {
        try x11.send(self.wm.conn, x11.proto.UnmapWindow{ .window_id = self.window_id });
        try x11.send(self.wm.conn, x11.proto.DestroyWindow{ .window_id = self.window_id });
        self.status = .closed;
    }

    pub fn show(self: *@This()) !void {
        const map_req = x11.proto.MapWindow{ .window_id = self.window_id };
        try x11.send(self.wm.conn, map_req);
    }

    pub fn createImage(self: *@This(), size: common.Size, pixels: []const u8) !Image {
        std.debug.assert(pixels.len % 4 == 0);
        return Image.init(self, size, pixels);
    }

    pub fn clear(self: *@This(), area: common.BBox) !void {
        const clear_area = x11.proto.ClearArea{
            .window_id = self.window_id,
            .x = area.x,
            .y = area.y,
            .height = area.height,
            .width = area.width,
        };

        //try x11.write(&self.wm.net_writer.interface, clear_area);
        try x11.send(self.wm.conn, clear_area);
    }

    pub fn redraw(self: *@This(), area: common.BBox) !void {
        if (self.redraw_timer.lap() < 5 * std.time.ns_per_ms) return;
        const clear_area = x11.proto.ClearArea{
            .window_id = self.window_id,
            .x = area.x,
            .y = area.y,
            .height = area.height,
            .width = area.width,
            .exposures = true,
        };
        try x11.send(self.wm.conn, clear_area);
    }
};

pub const Image = struct {
    window: *Window,
    image_id: u32,
    size: common.Size,

    pub fn init(window: *Window, size: common.Size, pixels: []const u8) !@This() {
        const pixmap_id = try window.wm.xid.genID();

        const pixmap_req = x11.proto.CreatePixmap{
            .pixmap_id = pixmap_id,
            .drawable_id = window.window_id,
            .width = size.width,
            .height = size.height,
            .depth = window.depth,
        };

        try x11.write(&window.wm.net_writer.interface, pixmap_req);

        const self = @This(){
            .image_id = pixmap_id,
            .window = window,
            .size = size,
        };

        if (pixels.len > 0) {
            try self.setPixels(pixels);
        }
        //try window.wm.flush();

        return self;
    }

    fn setPixels(self: @This(), pixels: []const u8) !void {
        std.debug.assert(pixels.len % 4 == 0);

        const image_info = x11.getImageInfo(self.window.wm.info, self.window.root);

        var fixed_reader = std.Io.Reader.fixed(pixels);
        var reader = x11.RgbaToZPixmapReader.init(image_info, &fixed_reader);

        const put_image_req = x11.proto.PutImage{
            .drawable_id = self.image_id,
            .graphic_context_id = self.window.graphic_context_id,
            .width = self.size.width,
            .height = self.size.height,
            .x = 0,
            .y = 0,
            .depth = self.window.depth,
        };

        try x11.stream(&self.window.wm.net_writer.interface, put_image_req, (&reader).interface(), pixels.len);
    }

    pub fn draw(self: @This(), target: common.BBox) !void {
        const copy_area_req = x11.proto.CopyArea{
            .src_drawable_id = self.image_id,
            .dst_drawable_id = self.window.window_id,
            .graphic_context_id = self.window.graphic_context_id,
            .width = target.width,
            .height = target.height,
            .dst_x = target.x,
            .dst_y = target.y,
        };
        try x11.write(&self.window.wm.net_writer.interface, copy_area_req);
        //try x11.send(self.window.wm.conn, copy_area_req);
    }

    pub fn deinit(self: @This()) !void {
        const free_image_req = x11.proto.FreePixmap{
            .pixmap_id = self.image_id,
        };
        try x11.write(&self.window.wm.net_writer.interface, free_image_req);
        //try x11.send(self.window.wm.conn, free_image_req);
    }
};
