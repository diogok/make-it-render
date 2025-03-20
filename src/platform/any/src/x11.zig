const std = @import("std");
const x11 = @import("x11");
const common = @import("common.zig");

const Atoms = struct {
    atom: u32,
    string: u32,
    wm_name: u32,
    wm_protocols: u32,
    wm_delete_window: u32,
};

pub const X11WM = struct {
    allocator: std.mem.Allocator,

    conn: std.net.Stream,
    atoms: Atoms,
    info: x11.Setup,
    xid: x11.XID,

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

        return @This(){
            .allocator = allocator,
            .conn = conn,
            .info = info,
            .xid = xid,
            .atoms = atoms,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.conn.close();
        self.info.deinit();
    }

    pub fn createWindow(self: *@This(), options: common.WindowOptions) !X11Window {
        return try X11Window.init(self, options);
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
};

pub const X11Window = struct {
    window_id: u32,
    wm: *X11WM,

    status: common.WindowStatus,

    depth: u8,
    root: u32,
    graphic_context_id: u32,

    pub fn init(wm: *X11WM, options: common.WindowOptions) !@This() {
        const window_id = try wm.xid.genID();
        const event_masks = [_]x11.EventMask{
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
        const window_values = x11.WindowValue{
            .BackgroundPixel = wm.info.screens[0].black_pixel,
            .EventMask = x11.mask(&event_masks),
            .Colormap = wm.info.screens[0].colormap,
        };
        const create_window = x11.CreateWindow{
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

            .value_mask = x11.maskFromValues(x11.WindowMask, window_values),
        };
        try x11.sendWithValues(wm.conn, create_window, window_values);

        const map_req = x11.MapWindow{ .window_id = window_id };
        try x11.send(wm.conn, map_req);

        const set_name_req = x11.ChangeProperty{
            .window_id = window_id,
            .property = wm.atoms.wm_name,
            .property_type = wm.atoms.string,
            .length_of_data = @truncate(options.title.len),
        };
        try x11.sendWithBytes(wm.conn, set_name_req, options.title);

        const set_protocols = x11.ChangeProperty{
            .window_id = window_id,
            .property = wm.atoms.wm_protocols,
            .property_type = wm.atoms.atom,
            .format = 32,
            .length_of_data = 1,
        };
        try x11.sendWithBytes(wm.conn, set_protocols, &std.mem.toBytes(wm.atoms.wm_delete_window));

        const graphic_context_id = try wm.xid.genID();
        const graphic_context_values = x11.GraphicContextValue{
            .Background = wm.info.screens[0].black_pixel,
            .Foreground = wm.info.screens[0].white_pixel,
        };

        const create_gc = x11.CreateGraphicContext{
            .graphic_context_id = graphic_context_id,
            .drawable_id = window_id,
            .value_mask = x11.maskFromValues(x11.GraphicContextMask, graphic_context_values),
        };
        try x11.sendWithValues(wm.conn, create_gc, graphic_context_values);

        return @This(){
            .window_id = window_id,
            .wm = wm,
            .status = .open,

            .root = wm.info.screens[0].root,
            .depth = wm.info.screens[0].root_depth,
            .graphic_context_id = graphic_context_id,
        };
    }

    pub fn destroy(self: *@This()) !void {
        try x11.send(self.wm.conn, x11.UnmapWindow{ .window_id = self.window_id });
        try x11.send(self.wm.conn, x11.DestroyWindow{ .window_id = self.window_id });
        self.status = .closed;
    }

    pub fn createImage(self: *@This(), image: common.Image) !common.ImageID {
        const image_info = x11.getImageInfo(self.wm.info, self.root);

        const pixmap_id = try self.wm.xid.genID();
        const pixmap_req = x11.CreatePixmap{
            .pixmap_id = pixmap_id,
            .drawable_id = self.window_id,
            .width = image.width,
            .height = image.height,
            .depth = self.depth,
        };
        try x11.send(self.wm.conn, pixmap_req);

        const zpixmap = try x11.rgbaToZPixmapAlloc(self.wm.allocator, image_info, image.pixels);
        defer self.wm.allocator.free(zpixmap);

        const put_image_req = x11.PutImage{
            .drawable_id = pixmap_id,
            .graphic_context_id = self.graphic_context_id,
            .width = image.width,
            .height = image.height,
            .x = 0,
            .y = 0,
            .depth = pixmap_req.depth,
        };
        try x11.sendWithBytes(self.wm.conn, put_image_req, zpixmap);

        return pixmap_id;
    }

    pub fn clear(self: *@This()) !void {
        const clear_area = x11.ClearArea{
            .window_id = self.window_id,
        };
        try x11.send(self.wm.conn, clear_area);
    }

    pub fn draw(self: *@This(), pixmap_id: common.ImageID, target: common.BBox) !void {
        const copy_area_req = x11.CopyArea{
            .src_drawable_id = pixmap_id,
            .dst_drawable_id = self.window_id,
            .graphic_context_id = self.graphic_context_id,
            .width = target.width,
            .height = target.height,
            .dst_x = target.x,
            .dst_y = target.y,
        };
        try x11.send(self.wm.conn, copy_area_req);
    }
};
