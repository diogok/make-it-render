const std = @import("std");
const win = @import("windows");
const common = @import("common.zig");

pub const WindowManager = struct {
    allocator: std.mem.Allocator,

    instance: ?win.Instance,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        const instance = win.GetModuleHandleW(null);

        return @This(){
            .allocator = allocator,
            .instance = instance,
        };
    }

    pub fn deinit(_: *@This()) void {
        win.PostQuitMessage(0);
    }

    pub fn createWindow(self: *@This(), options: common.WindowOptions) !Window {
        return try Window.init(self, options);
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

var class_count: usize = 0;

pub const Window = struct {
    wm: *WindowManager,
    handle: win.WindowHandle,
    frame: win.DeviceContext,
    class_name: [:0]u16,

    title: [:0]u16,

    status: common.WindowStatus,

    pub fn init(wm: *WindowManager, options: common.WindowOptions) !@This() {
        const class_name_n = try std.fmt.allocPrint(wm.allocator, "WindowClass_{d}", .{class_count});
        defer wm.allocator.free(class_name_n);
        defer class_count += 1;

        const class_name = try win.W(wm.allocator, class_name_n);
        const cursor = win.LoadCursorW(null, .Arrow);

        const window_class: win.WindowClass = .{
            .style = @intFromEnum(win.ClassStyle.HREDRAW) | @intFromEnum(win.ClassStyle.VREDRAW),
            .window_procedure = windowProc,
            .instance = wm.instance,
            .class_name = class_name,
            .cursor = cursor,
            .background = win.CreateSolidBrush(0x00000000),
        };

        _ = win.RegisterClassExW(&window_class);

        const frame_handle = win.CreateCompatibleDC(null);
        if (frame_handle == null) {
            const err = win.GetLastError();
            log.err("CreateCompatibleDC error: {any}", .{err});
            return error.NoCompatibleDC;
        }
        const title = try win.W(wm.allocator, options.title);

        const handle = win.CreateWindowExW(
            win.ExtendedWindowStyle.OverlappedWindow,
            class_name,
            title,
            win.WindowStyle.OverlappedWindow,
            options.x orelse win.UseDefault,
            options.y orelse win.UseDefault,
            options.width orelse win.UseDefault,
            options.height orelse win.UseDefault,
            null,
            null,
            wm.instance,
            null,
        );
        if (handle == null) {
            return error.CreateWindowError;
        }

        return @This(){
            .wm = wm,
            .handle = handle.?,
            .frame = frame_handle.?,
            .status = .open,
            .title = title,
            .class_name = class_name,
        };
    }

    pub fn destroy(self: *@This()) !void {
        self.wm.allocator.free(self.title);
        self.wm.allocator.free(self.class_name);
        self.status = .closed;
    }

    pub fn show(self: *@This()) !void {
        _ = win.ShowWindow(self.handle, 1);
        while (win.ShowCursor(true) < 1) {}
    }

    pub fn createImage(self: *@This(), size: common.Size, pixels: common.Pixels) !Image {
        return Image.init(self, size, pixels);
    }

    pub fn clear(self: *@This(), _: common.BBox) !void {
        _ = win.InvalidateRect(self.handle, null, true);
    }

    pub fn redraw(self: *@This(), _: common.BBox) !void {
        _ = self; // autofix
        //_ = win.InvalidateRect(self.handle, null, false);
        //_ = win.UpdateWindow(self.handle);
    }
};

pub const Image = struct {
    window: *Window,

    //image_id: u32,
    size: common.Size,

    bitmap: win.Bitmap,
    pixels: [*]u8,

    pub fn init(window: *Window, size: common.Size, src_pixels: common.Pixels) !@This() {
        var pixels: [*]u8 = undefined;
        const bitmap_info = win.BitmapInfo{
            .header = .{
                .width = size.width,
                .height = @as(i32, size.height) * -1,
            },
        };

        const bitmap = win.CreateDIBSection(
            null,
            &bitmap_info,
            .RGB_COLORS,
            &pixels,
            null,
            0,
        );
        if (bitmap == null) {
            const err = win.GetLastError();
            log.err("CreateDIBSection error: {any}", .{err});
            return error.ErrorCreatingImage;
        }

        //_ = win.SelectObject(window.frame, bitmap);

        // RGB to BGR
        var i: usize = 0;
        while (i < src_pixels.len) : (i += 4) {
            pixels[i] = src_pixels[i + 2];
            pixels[i + 1] = src_pixels[i + 1];
            pixels[i + 2] = src_pixels[i];
            pixels[i + 3] = src_pixels[i + 3];
        }

        return @This(){
            .bitmap = bitmap.?,
            .window = window,
            .size = size,
            .pixels = pixels,
        };
    }

    fn setPixels(self: @This(), pixels: common.Pixels) !void {
        _ = self;
        _ = pixels;
    }

    pub fn draw(self: @This(), target: common.BBox) !void {
        _ = win.SelectObject(self.window.frame, self.bitmap);

        const display = win.GetWindowDC(self.window.handle);
        defer {
            const released = win.ReleaseDC(self.window.handle, display);
            if (released != 1) {
                const err = win.GetLastError();
                log.err("ReleaseDC error: {any}", .{err});
            }
        }

        const bitBltResult = win.BitBlt(
            display,
            target.x,
            target.y,
            target.width,
            target.height,
            self.window.frame,
            0,
            0,
            .SRCCOPY,
        );
        if (!bitBltResult) {
            const err = win.GetLastError();
            log.err("BitBlt error: {any}", .{err});
            return error.ErrorBitBlt;
        }
        //_ = win.DwmFlush(); // wait for vsync, kinda
    }

    pub fn deinit(self: @This()) !void {
        _ = win.DeleteObject(self.bitmap);
    }
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
    .{
        .mouse_pressed = .{
            .x = 0,
            .y = 0,
            .button = 0,
            .window_id = 0,
        },
    },
    .{
        .mouse_released = .{
            .x = 0,
            .y = 0,
            .button = 0,
            .window_id = 0,
        },
    },
    .{
        .mouse_moved = .{
            .x = 0,
            .y = 0,
            .window_id = 0,
        },
    },
    .{
        .key_pressed = .{
            .key = 0,
            .window_id = 0,
        },
    },
    .{
        .key_released = .{
            .key = 0,
            .window_id = 0,
        },
    },
};

var active: usize = 0;

pub fn windowProc(
    window_handle: win.WindowHandle,
    message_type: win.MessageType,
    wparam: usize,
    lparam: isize,
) callconv(.winapi) isize {
    const windowID = @intFromPtr(window_handle);
    switch (message_type) {
        .WM_DESTROY => {
            active = 1;
            event[active].close = windowID;
        },
        .WM_PAINT => {
            var rect: win.Rect = std.mem.zeroes(win.Rect);
            _ = win.GetUpdateRect(window_handle, &rect, false);

            if (rect.left != 0 or rect.right != 0 or rect.top != 0 or rect.bottom != 0) {
                active = 2;
                event[active].draw.window_id = windowID;
            }
            _ = win.DwmFlush(); // wait for vsync, kinda
        },
        .WM_LBUTTONDOWN => {
            active = 3;

            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            event[active].mouse_pressed.x = @intCast(x);
            event[active].mouse_pressed.y = @intCast(y);

            event[active].mouse_pressed.button = 1;

            event[active].mouse_pressed.window_id = windowID;
            return 1;
        },
        .WM_LBUTTONUP => {
            active = 4;

            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            event[active].mouse_released.x = @intCast(x);
            event[active].mouse_released.y = @intCast(y);

            event[active].mouse_released.button = 1;

            event[active].mouse_released.window_id = windowID;
        },
        .WM_MBUTTONDOWN => {
            active = 3;

            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            event[active].mouse_pressed.x = @intCast(x);
            event[active].mouse_pressed.y = @intCast(y);

            event[active].mouse_pressed.button = 2;

            event[active].mouse_pressed.window_id = windowID;
        },
        .WM_MBUTTONUP => {
            active = 4;

            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            event[active].mouse_released.x = @intCast(x);
            event[active].mouse_released.y = @intCast(y);

            event[active].mouse_released.button = 2;

            event[active].mouse_released.window_id = windowID;
            return 1;
        },
        .WM_RBUTTONDOWN => {
            active = 3;

            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            event[active].mouse_pressed.x = @intCast(x);
            event[active].mouse_pressed.y = @intCast(y);

            event[active].mouse_pressed.button = 3;

            event[active].mouse_pressed.window_id = windowID;
        },
        .WM_RBUTTONUP => {
            active = 4;

            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            event[active].mouse_released.x = @intCast(x);
            event[active].mouse_released.y = @intCast(y);

            event[active].mouse_released.button = 3;

            event[active].mouse_released.window_id = windowID;
            return 1;
        },
        .WM_MOUSEMOVE => {
            active = 5;

            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            event[active].mouse_moved.x = @intCast(x);
            event[active].mouse_moved.y = @intCast(y);

            event[active].mouse_moved.window_id = windowID;
        },
        .WM_KEYDOWN => {
            active = 6;

            //const key: win.VirtualKeys = @enumFromInt(wparam);
            //event[active].key_pressed.key = @enumFr;

            event[active].key_pressed.window_id = windowID;
        },
        .WM_KEYUP => {
            active = 7;

            //const key: win.VirtualKeys = @enumFromInt(wparam);
            //event[active].key_released.key = key;

            event[active].key_released.window_id = windowID;
        },
        else => {
            //active = 0;
            return win.DefWindowProcW(window_handle, message_type, wparam, lparam);
        },
    }
    return 0;
}

const log = std.log.scoped(.any_win32);
