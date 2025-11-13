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
        if (event_n != 0) {
            event_n -= 1;
            return event_queue[event_n];
        }
        var msg: win.Message = undefined;
        if (win.GetMessageW(&msg, null, 0, 0) > 0) {
            _ = win.TranslateMessage(&msg);
            _ = win.DispatchMessageW(&msg);
        }
        if (event_n != 0) {
            event_n -= 1;
            return event_queue[event_n];
        } else {
            return .{ .nop = {} };
        }
    }

    pub fn flush(_: *@This()) !void {
        _ = win.DwmFlush();
    }
};

pub const Window = struct {
    wm: *WindowManager,
    handle: win.WindowHandle,
    frame: win.DeviceContext,
    class_name: [:0]u16,

    title: [:0]u16,

    status: common.WindowStatus,

    display: ?win.DeviceContext = null,
    bg: ?win.BrushHandler = null,

    pub fn init(wm: *WindowManager, options: common.WindowOptions) !@This() {
        const class_name_n = try std.fmt.allocPrint(wm.allocator, "WindowClass_{d}", .{class_count});
        defer wm.allocator.free(class_name_n);
        defer class_count += 1;

        const class_name = try win.W(wm.allocator, class_name_n);
        const cursor = win.LoadCursorW(null, .Arrow);
        const bg = win.CreateSolidBrush(commonPixelToWinPixel(options.background));

        const window_class: win.WindowClass = .{
            .style = @intFromEnum(win.ClassStyle.HREDRAW) | @intFromEnum(win.ClassStyle.VREDRAW),
            .window_procedure = windowProc,
            .instance = wm.instance,
            .class_name = class_name,
            .cursor = cursor,
            .background = bg,
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
            .bg = bg,
        };
    }

    pub fn deinit(self: *@This()) !void {
        self.wm.allocator.free(self.title);
        self.wm.allocator.free(self.class_name);
        self.status = .closed;
    }

    pub fn show(self: *@This()) !void {
        _ = win.ShowWindow(self.handle, 1);
        while (win.ShowCursor(true) < 1) {}
    }

    pub fn createImage(self: *@This(), size: common.Size, pixels: []const u8) !Image {
        return Image.init(self, size, pixels);
    }

    pub fn clear(self: *@This(), _: common.BBox) !void {
        //_ = win.InvalidateRect(self.handle, null, true);
        if (self.display) |_| {
            var rect = win.Rect{};
            _ = win.GetWindowRect(self.handle, &rect);
            _ = win.FillRect(self.display, &rect, self.bg);
        }
    }

    pub fn redraw(self: *@This(), _: common.BBox) !void {
        //var rect: win.Rect = std.mem.zeroes(win.Rect);
        //_ = win.InvalidateRect(self.handle, null, false);
        //_ = win.UpdateWindow(self.handle);
        const window_id = @intFromPtr(self.handle);
        event_queue[event_n] = .{
            .draw = .{
                .window_id = window_id,
                .area = .{},
            },
        };
        event_n += 1;
    }

    pub fn beginDraw(self: *@This()) !void {
        self.display = win.GetWindowDC(self.handle);
    }

    pub fn endDraw(self: *@This()) !void {
        const released = win.ReleaseDC(self.handle, self.display);
        if (released != 1) {
            const err = win.GetLastError();
            log.err("ReleaseDC error: {any}", .{err});
        }
    }
};

pub const Image = struct {
    window: *Window,
    size: common.Size,

    bitmap: win.Bitmap,
    pixels: [*]u8,

    pub fn init(window: *Window, size: common.Size, src_pixels: []const u8) !@This() {
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

        var self = @This(){
            .bitmap = bitmap.?,
            .window = window,
            .size = size,
            .pixels = pixels,
        };

        if (src_pixels.len != 0) {
            try self.setPixels(src_pixels);
        }

        return self;
    }

    pub fn setPixels(self: @This(), src_pixels: []const u8) !void {
        std.debug.assert(src_pixels.len % 4 == 0);
        std.debug.assert(src_pixels.len == self.size.height * self.size.width * 4);

        var i: usize = 0;
        while (i < src_pixels.len) : (i += 4) {
            // RGB to BGR
            self.pixels[i] = src_pixels[i + 2];
            self.pixels[i + 1] = src_pixels[i + 1];
            self.pixels[i + 2] = src_pixels[i];
            self.pixels[i + 3] = src_pixels[i + 3];
        }
    }

    pub fn draw(self: @This(), target: common.BBox) !void {
        _ = win.SelectObject(self.window.frame, self.bitmap);

        const bitBltResult = win.BitBlt(
            self.window.display,
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
    }

    pub fn deinit(self: @This()) !void {
        _ = win.DeleteObject(self.bitmap);
    }
};

var class_count: usize = 0;

var event_n: u8 = 0;
var event_queue: [256]common.Event = undefined;

pub fn windowProc(
    window_handle: win.WindowHandle,
    message_type: win.MessageType,
    wparam: usize,
    lparam: isize,
) callconv(.winapi) isize {
    defer event_n += 1;

    const window_id = @intFromPtr(window_handle);
    switch (message_type) {
        .WM_DESTROY => {
            event_queue[event_n] = .{ .close = window_id };
        },
        .WM_ERASEBKGND => {
            event_queue[event_n] = .{ .nop = {} };
        },
        .WM_PAINT => {
            var rect: win.Rect = std.mem.zeroes(win.Rect);
            _ = win.GetUpdateRect(window_handle, &rect, false);

            event_queue[event_n] = .{
                .draw = .{
                    .window_id = window_id,
                    .area = .{},
                },
            };

            var paint = std.mem.zeroes(win.Paint);
            const hdc = win.BeginPaint(window_handle, &paint);
            const hMemDC = win.CreateCompatibleDC(hdc);

            // TODO: paint in here

            _ = win.EndPaint(window_handle, &paint);
            _ = win.DeleteObject(hMemDC);

            _ = win.DwmFlush();
        },
        .WM_LBUTTONDOWN => {
            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            event_queue[event_n] = .{
                .mouse_pressed = .{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .button = 1,
                    .window_id = window_id,
                },
            };
        },
        .WM_LBUTTONUP => {
            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            event_queue[event_n] = .{
                .mouse_released = .{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .button = 1,
                    .window_id = window_id,
                },
            };
        },
        .WM_MBUTTONDOWN => {
            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            event_queue[event_n] = .{
                .mouse_pressed = .{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .button = 2,
                    .window_id = window_id,
                },
            };
        },
        .WM_MBUTTONUP => {
            const x = win.loword(lparam);
            const y = win.hiword(lparam);
            event_queue[event_n] = .{
                .mouse_released = .{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .button = 2,
                    .window_id = window_id,
                },
            };
        },
        .WM_RBUTTONDOWN => {
            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            event_queue[event_n] = .{
                .mouse_pressed = .{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .button = 3,
                    .window_id = window_id,
                },
            };
        },
        .WM_RBUTTONUP => {
            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            event_queue[event_n] = .{
                .mouse_released = .{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .button = 3,
                    .window_id = window_id,
                },
            };
        },
        .WM_MOUSEMOVE => {
            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            event_queue[event_n] = .{
                .mouse_moved = .{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .window_id = window_id,
                },
            };
        },
        .WM_KEYDOWN => {
            //const key: win.VirtualKeys = @enumFromInt(wparam);
            //event[event_n].key_pressed.key = @enumFr;

            event_queue[event_n] = .{
                .key_pressed = .{
                    .key = 0,
                    .window_id = window_id,
                },
            };
        },
        .WM_KEYUP => {
            event_queue[event_n] = .{
                .key_released = .{
                    .key = 0,
                    .window_id = window_id,
                },
            };
        },
        else => {
            event_queue[event_n] = .{ .nop = {} };
            return win.DefWindowProcW(window_handle, message_type, wparam, lparam);
        },
    }
    return 1;
}

/// RGB to ABGR
fn commonPixelToWinPixel(src: [3]u8) u32 {
    const dst: [4]u8 = [4]u8{ 0, src[2], src[1], src[0] };
    return std.mem.bytesToValue(u32, &dst);
}

const std = @import("std");
const win = @import("windows");
const common = @import("common.zig");

const log = std.log.scoped(.any_win32);
