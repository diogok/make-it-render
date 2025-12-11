pub const WindowManager = struct {
    allocator: std.mem.Allocator,

    instance: ?win.Instance,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        const instance = win.GetModuleHandleW(null);
        if (instance == null) {
            const e = win.GetLastError();
            log.err("Error getting instance {d}", .{e});
            return error.InitError;
        }
        _ = win.SetProcessDPIAware();

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
        if (events.pull()) |event| {
            return event;
        }
        var msg: win.Message = undefined;
        if (win.GetMessageW(&msg, null, 0, 0) > 0) {
            _ = win.TranslateMessage(&msg);
            _ = win.DispatchMessageW(&msg);
        }
        if (events.pull()) |event| {
            return event;
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
    handle: ?win.WindowHandle,
    frame: ?win.DeviceContext,
    class_name: [:0]u16,

    title: [:0]u16,

    status: common.WindowStatus,

    display: ?win.DeviceContext = null,
    background: ?win.BrushHandler = null,

    scaling: f32 = 1.0,

    pub fn init(wm: *WindowManager, options: common.WindowOptions) !@This() {
        const class_name_n = try std.fmt.allocPrint(wm.allocator, "WindowClass_{d}", .{class_count});
        defer wm.allocator.free(class_name_n);
        defer class_count += 1;

        const class_name = try win.W(wm.allocator, class_name_n);
        const cursor = win.LoadCursorW(null, .Arrow);
        const background = win.CreateSolidBrush(commonPixelToWinPixel(options.background));

        const window_class: win.WindowClass = .{
            .style = @intFromEnum(win.ClassStyle.HREDRAW) | @intFromEnum(win.ClassStyle.VREDRAW),
            .window_procedure = windowProc,
            .instance = wm.instance,
            .class_name = class_name,
            .cursor = cursor,
            .background = background,
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

        const dpi = win.GetDpiForWindow(handle);
        const scaling: f32 = @as(f32, @floatFromInt(dpi)) / 96.0;

        return @This(){
            .wm = wm,
            .handle = handle,
            .frame = frame_handle,
            .status = .open,
            .title = title,
            .class_name = class_name,
            .background = background,
            .scaling = scaling,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.wm.allocator.free(self.title);
        self.wm.allocator.free(self.class_name);
    }

    pub fn close(self: *@This()) void {
        self.status = .closed;
    }

    pub fn show(self: *@This()) !void {
        _ = win.ShowWindow(self.handle, 1);
        while (win.ShowCursor(true) < 1) {}
    }

    pub fn createImage(self: *@This(), size: common.Size) !Image {
        return Image.init(self, size);
    }

    pub fn clear(self: *@This(), _: common.BBox) !void {
        //_ = win.InvalidateRect(self.handle, null, true);
        if (self.display) |_| {
            var rect = win.Rect{};
            _ = win.GetWindowRect(self.handle, &rect);
            rect.top = -1;
            rect.left = -1;
            _ = win.FillRect(self.display, &rect, self.background);
        }
    }

    pub fn redraw(self: *@This(), _: common.BBox) !void {
        //var rect: win.Rect = std.mem.zeroes(win.Rect);
        //_ = win.InvalidateRect(self.handle, null, false);
        //_ = win.UpdateWindow(self.handle);
        const window_id = @intFromPtr(self.handle);
        events.push(
            .{
                .draw = .{
                    .window_id = window_id,
                },
            },
        );
    }

    pub fn beginDraw(self: *@This()) !void {
        self.display = win.GetDC(self.handle);
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

    pub fn init(window: *Window, size: common.Size) !@This() {
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

        return @This(){
            .bitmap = bitmap.?,
            .window = window,
            .size = size,
            .pixels = pixels,
        };
    }

    pub fn setPixels(self: @This(), reader: *std.Io.Reader) !void {
        var i: usize = 0;
        while (true) {
            defer i += 4;
            const src_pixels = reader.take(4) catch |err| {
                switch (err) {
                    error.EndOfStream => break,
                    error.ReadFailed => return err,
                }
            };
            // RGB to BGR
            self.pixels[i] = src_pixels[2];
            self.pixels[i + 1] = src_pixels[1];
            self.pixels[i + 2] = src_pixels[0];
            self.pixels[i + 3] = src_pixels[3];
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

    pub fn deinit(self: @This()) void {
        _ = win.DeleteObject(self.bitmap);
    }
};

var class_count: usize = 0;

var events = queue.Queue(common.Event).init();

pub fn windowProc(
    window_handle: win.WindowHandle,
    message_type: win.MessageType,
    wparam: usize,
    lparam: isize,
) callconv(.winapi) isize {
    const window_id = @intFromPtr(window_handle);
    switch (message_type) {
        .WM_CLOSE => {
            events.push(.{ .close = window_id });
        },
        .WM_ERASEBKGND => {
            events.push(.{ .nop = {} });
        },
        .WM_PAINT => {
            var rect: win.Rect = std.mem.zeroes(win.Rect);
            _ = win.GetUpdateRect(window_handle, &rect, false);

            events.push(.{
                .draw = .{
                    .window_id = window_id,
                    .area = .{},
                },
            });

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

            events.push(.{
                .mouse_pressed = .{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .button = 1,
                    .window_id = window_id,
                },
            });
        },
        .WM_LBUTTONUP => {
            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            events.push(.{
                .mouse_released = .{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .button = 1,
                    .window_id = window_id,
                },
            });
        },
        .WM_MBUTTONDOWN => {
            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            events.push(.{
                .mouse_pressed = .{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .button = 2,
                    .window_id = window_id,
                },
            });
        },
        .WM_MBUTTONUP => {
            const x = win.loword(lparam);
            const y = win.hiword(lparam);
            events.push(.{
                .mouse_released = .{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .button = 2,
                    .window_id = window_id,
                },
            });
        },
        .WM_RBUTTONDOWN => {
            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            events.push(.{
                .mouse_pressed = .{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .button = 3,
                    .window_id = window_id,
                },
            });
        },
        .WM_RBUTTONUP => {
            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            events.push(.{
                .mouse_released = .{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .button = 3,
                    .window_id = window_id,
                },
            });
        },
        .WM_MOUSEMOVE => {
            const x = win.loword(lparam);
            const y = win.hiword(lparam);

            events.push(.{
                .mouse_moved = .{
                    .x = @intCast(x),
                    .y = @intCast(y),
                    .window_id = window_id,
                },
            });
        },
        .WM_KEYDOWN => {
            //const key: win.VirtualKeys = @enumFromInt(wparam);
            //event[event_n].key_pressed.key = @enumFr;

            events.push(.{
                .key_pressed = .{
                    .key = 0,
                    .window_id = window_id,
                },
            });
        },
        .WM_KEYUP => {
            events.push(.{
                .key_released = .{
                    .key = 0,
                    .window_id = window_id,
                },
            });
        },
        .WM_CREATE => {
            events.push(.{ .nop = {} });
            return win.DefWindowProcW(window_handle, message_type, wparam, lparam);
        },
        .WM_DPICHANGED => {
            events.push(.{ .nop = {} });
            return win.DefWindowProcW(window_handle, message_type, wparam, lparam);
        },
        // TODO: Resize
        else => {
            events.push(.{ .nop = {} });
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
const queue = @import("queue.zig");

const log = std.log.scoped(.any_win32);
