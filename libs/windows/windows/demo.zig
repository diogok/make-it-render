const std = @import("std");
const win = @import("windows");

const log = std.log.scoped(.main);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() != .leak);
    const allocator = gpa.allocator();

    const instance = win.GetModuleHandleExW(0, null, null);
    log.debug("Called main {any} {any}", .{ std.builtin.subsystem, instance });

    //const class_name = win.W2("HelloClass"); // For string literals, comptime known
    const class_name = try win.W(allocator, "HelloClass");
    defer allocator.free(class_name);

    var window_class: win.WindowClass = .{
        .style = @intFromEnum(win.ClassStyle.HREDRAW) | @intFromEnum(win.ClassStyle.VREDRAW),
        //.hbrBackground = @as(c.HBRUSH,c.GetStockObject(c.WHITE_BRUSH)),
        .window_procedure = windowProc,
        .instance = instance,
        .class_name = class_name,
    };

    _ = win.RegisterClassExW(&window_class);

    const window_handle = win.CreateWindowExW(
        win.ExtendedWindowStyle.OverlappedWindow,
        class_name,
        class_name,
        win.WindowStyle.OverlappedWindow,
        win.UseDefault, // x
        win.UseDefault, // y
        win.UseDefault, // width
        win.UseDefault, // height
        null,
        null,
        instance,
        null,
    );
    if (window_handle == null) {
        const err = win.GetLastError();
        log.err("Create window error: {any}", .{err});
        return error.CreateWindowError;
    }

    const show_result = win.ShowWindow(window_handle, 10);
    if (show_result != null) {
        const err = win.GetLastError();
        log.err("ShowWindow error: {any}", .{err});
        return error.ShowWindowError;
    }

    bitmap_info.bmiHeader.biSize = @sizeOf(win.BmiHeader);
    bitmap_info.bmiHeader.biPlanes = 1;
    bitmap_info.bmiHeader.biBitCount = 32;
    bitmap_info.bmiHeader.biCompression = 0;

    frame_handle = win.CreateCompatibleDC(null);
    if (frame_handle == null) {
        const err = win.GetLastError();
        log.err("CreateCompatibleDC error: {any}", .{err});
        return error.NoCompatibleDC;
    }

    _ = win.UpdateWindow(window_handle);

    var msg: win.Message = undefined;
    while (win.GetMessageW(&msg, null, 0, 0) > 0) {
        _ = win.TranslateMessage(&msg);
        _ = win.DispatchMessageW(&msg);

        _ = win.InvalidateRect(window_handle, null, false); // to force full screen redraw
        _ = win.UpdateWindow(window_handle); // request a WM_PAINT
    }
}

var pixels: [*]u8 = undefined;
var bitmap_info = std.mem.zeroes(win.BitmapInfo);
var bitmap: ?*anyopaque = null;
var frame_handle: ?*anyopaque = null;
var width: i32 = 0;
var height: i32 = 0;

pub fn windowProc(
    window_handle: win.WindowHandle,
    message_type: win.MessageType,
    wparam: usize,
    lparam: isize,
) callconv(.C) isize {
    switch (message_type) {
        .WM_DESTROY => {
            win.PostQuitMessage(0);
        },
        .WM_PAINT => {
            std.debug.print("paiting...\n", .{});
            var paint = std.mem.zeroes(win.PaintStruct);
            const display_handle = win.BeginPaint(window_handle, &paint);
            if (display_handle == null) {
                const err = win.GetLastError();
                log.err("Beginpaint error: {any}", .{err});
                return 0;
            }

            var i: usize = 0;
            while (i < (height * width) * 4) : (i += 4) {
                pixels[i] = 0;
                pixels[i + 1] = 0;
                pixels[i + 2] = 255;
                pixels[i + 3] = 0;
            }
            std.debug.print("size {d}\n", .{i});
            std.debug.print("sample {any}\n", .{pixels[0..12]});
            std.debug.print("paint {any}\n", .{paint});

            const r = win.BitBlt(
                display_handle,
                paint.rcPaint.left,
                paint.rcPaint.top,
                paint.rcPaint.right - paint.rcPaint.left,
                paint.rcPaint.bottom - paint.rcPaint.top,
                frame_handle,
                paint.rcPaint.left,
                paint.rcPaint.top,
                .SRCCOPY,
            );
            log.debug("bit {d}", .{r});
            if (r == 0) {
                const err = win.GetLastError();
                log.err("BitBlt error: {any}", .{err});
                return 0;
            }

            const er = win.EndPaint(window_handle, &paint);
            log.debug("ep {d}", .{er});
            if (er == 0) {
                const err = win.GetLastError();
                log.err("EndPaint: {any}", .{err});
                return 0;
            }

            _ = win.DwmFlush(); // wait for vsync, kinda
        },
        .WM_SIZE => {
            width = win.loLParam(lparam);
            height = win.hiLParam(lparam);
            std.debug.print("Size {d}x{d}\n", .{ width, height });

            bitmap_info.bmiHeader.biWidth = width;
            bitmap_info.bmiHeader.biHeight = height * -1;

            if (bitmap != null) _ = win.DeleteObject(bitmap);
            bitmap = win.CreateDIBSection(null, &bitmap_info, .RGB_COLORS, &pixels, null, 0);
            if (bitmap == null) {
                const err = win.GetLastError();
                log.err("CreateDIBSection error: {any}", .{err});
                return 0;
            }
            _ = win.SelectObject(frame_handle, bitmap);
        },
        else => {
            return win.DefWindowProcW(window_handle, message_type, wparam, lparam);
        },
    }
    return 0;
}
