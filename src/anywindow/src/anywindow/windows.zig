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

var windowIDs: [256]?win.WindowHandle = undefined;

pub const WindowsWindow = struct {
    wm: *WindowsWM,
    handle: win.WindowHandle,

    title: [:0]u16,

    status: common.WindowStatus,

    images: std.ArrayList(ImageHandler),

    pub fn init(wm: *WindowsWM, options: common.WindowOptions) !@This() {
        const title = try win.W(wm.allocator, options.title);

        const handle = win.CreateWindowExW(
            win.ExtendedWindowStyle.OverlappedWindow,
            wm.class_name,
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
            .status = .open,
            .title = title,
            .images = std.ArrayList(ImageHandler).init(wm.allocator),
        };
    }

    pub fn destroy(self: *@This()) !void {
        self.images.deinit();
        self.wm.allocator.free(self.title);
        self.status = .closed;
    }

    pub fn show(self: *@This()) !void {
        _ = win.ShowWindow(self.handle, 1);
        while (win.ShowCursor(true) < 1) {}
    }

    pub fn createImage(self: *@This(), img: common.Image) !common.ImageID {
        const imageID = self.images.items.len;

        var pixels: [*]u8 = undefined;
        const bitmap_info = win.BitmapInfo{
            .header = .{
                .width = img.width,
                .height = img.height,
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
            std.debug.print("CreateDIBSection error: {any}\n", .{err});
            return error.ErrorCreatingImage;
        }

        const frame = win.CreateCompatibleDC(null);
        if (frame == null) {
            const err = win.GetLastError();
            std.debug.print("CreateCompatibleDC error: {any}\n", .{err});
            return error.ErrorCreatingCompatibleDeviceContext;
        }

        _ = win.SelectObject(frame, bitmap);

        // RGB to BGR
        var i: usize = 0;
        while (i < img.pixels.len) : (i += 4) {
            pixels[i] = img.pixels[i + 2];
            pixels[i + 1] = img.pixels[i + 1];
            pixels[i + 2] = img.pixels[i];
            pixels[i + 3] = img.pixels[i + 3];
        }

        const image = ImageHandler{
            .bitmap = bitmap.?,
            .frame = frame.?,
        };
        try self.images.append(image);

        return @truncate(imageID);
    }

    pub fn clear(_: *@This()) !void {}

    pub fn draw(self: *@This(), imageID: common.ImageID, target: common.BBox) !void {
        var paint = std.mem.zeroes(win.Paint);
        const display = win.BeginPaint(self.handle, &paint);
        if (display == null) {
            const err = win.GetLastError();
            std.debug.print("Beginpaint error: {any}\n", .{err});
            return error.ErrorBeginPaint;
        }
        defer _ = win.EndPaint(self.handle, &paint);

        const imageHandler = self.images.items[imageID];

        const bitBltResult = win.BitBlt(
            display,
            target.x,
            target.y,
            target.width,
            target.height,
            imageHandler.frame,
            0,
            0,
            .SRCCOPY,
        );
        if (!bitBltResult) {
            const err = win.GetLastError();
            std.debug.print("BitBlt error: {any}", .{err});
            return error.ErrorBitBlt;
        }
    }
};

const ImageHandler = struct {
    bitmap: win.Bitmap,
    frame: win.DeviceContext,
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
) callconv(.C) isize {
    const windowID = @intFromPtr(window_handle);
    switch (message_type) {
        .WM_DESTROY => {
            active = 1;
            event[active].close = windowID;
        },
        .WM_PAINT => {
            active = 2;
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
