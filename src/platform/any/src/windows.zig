const std = @import("std");
const win = @import("windows");
const common = @import("common.zig");

pub const WindowsWM = struct {
    allocator: std.mem.Allocator,

    instance: ?win.Instance,
    class_name: win.String,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        const instance = win.GetModuleHandleW(null);

        const class_name = win.W2("WindowClass");
        const cursor = win.LoadCursorW(null, .Arrow);

        const self = @This(){
            .allocator = allocator,
            .instance = instance,
            .class_name = class_name,
        };

        const window_class: win.WindowClass = .{
            .style = @intFromEnum(win.ClassStyle.HREDRAW) | @intFromEnum(win.ClassStyle.VREDRAW),
            .window_procedure = windowProc,
            .instance = instance,
            .class_name = class_name,
            .cursor = cursor,
        };

        _ = win.RegisterClassExW(&window_class);
        return self;
    }

    pub fn deinit(_: *@This()) void {
        win.PostQuitMessage(0);
    }

    pub fn createWindow(self: *@This(), options: common.WindowOptions) !WindowsWindow {
        return try WindowsWindow.init(self, options);
    }

    pub fn receive(_: *@This()) !common.Event {
        active = 0;
        var msg: win.Message = undefined;
        if (win.GetMessageW(&msg, null, 0, 0) > 0) {
            _ = win.TranslateMessage(&msg);
            _ = win.DispatchMessageW(&msg);
        }
        return event[active];
    }
};

pub const WindowsWindow = struct {
    wm: *WindowsWM,
    handle: ?win.WindowHandle,

    title: [:0]u16,

    status: common.WindowStatus,

    pub fn init(wm: *WindowsWM, options: common.WindowOptions) !@This() {
        const title = try win.W(wm.allocator, options.title);

        const handle = win.CreateWindowExW(
            win.ExtendedWindowStyle.OverlappedWindow,
            wm.class_name,
            title,
            win.WindowStyle.OverlappedWindow,
            win.UseDefault, // x
            win.UseDefault, // y
            win.UseDefault, // width
            win.UseDefault, // height
            null,
            null,
            wm.instance,
            null,
        );

        _ = win.ShowWindow(handle, 10);
        while (win.ShowCursor(true) < 1) {}

        return @This(){
            .wm = wm,
            .handle = handle,
            .status = .open,
            .title = title,
        };
    }

    pub fn destroy(self: *@This()) !void {
        self.wm.allocator.free(self.title);
        self.status = .closed;
    }

    pub fn createImage(_: *@This(), _: common.Image) !u32 {
        return 0;
    }

    pub fn clear(_: *@This()) !void {}

    pub fn draw(_: *@This(), _: u32, _: common.BBox) !void {}
};

var event = [_]common.Event{
    .{ .nop = {} },
    .{ .close = 0 },
    .{
        .draw = .{
            .area = .{
                .x = 0,
                .y = 0,
                .height = 0,
                .width = 0,
            },
            .window_id = 0,
        },
    },
};
var active: usize = 0;

pub fn windowProc(window_handle: win.WindowHandle, message_type: win.MessageType, wparam: usize, lparam: isize) callconv(.C) isize {
    switch (message_type) {
        .WM_DESTROY => {
            active = 1;
        },
        .WM_PAINT => {
            active = 2;
        },
        else => {
            return win.DefWindowProcW(window_handle, message_type, wparam, lparam);
        },
    }
    return 0;
}
