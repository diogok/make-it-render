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

    _ = win.UpdateWindow(window_handle.?);

    var msg: win.Message = undefined;
    while (win.GetMessageW(&msg, null, 0, 0) > 0) {
        _ = win.TranslateMessage(&msg);
        _ = win.DispatchMessageW(&msg);

        _ = win.InvalidateRect(window_handle.?, null, false); // to force full screen redraw
        _ = win.UpdateWindow(window_handle.?); // request a WM_PAINT
    }
}

pub fn windowProc(window_handle: win.WindowHandle, message_type: win.MessageType, wparam: usize, lparam: isize) callconv(.C) isize {
    switch (message_type) {
        .WM_DESTROY => {
            win.PostQuitMessage(0);
        },
        .WM_PAINT => {
            var paint = std.mem.zeroes(win.PaintStruct);
            _ = win.BeginPaint(window_handle, &paint);
            _ = win.EndPaint(window_handle, &paint);

            _ = win.DwmFlush(); // wait for vsync, kinda
        },
        .WM_SIZE => {
            const width = win.loLParam(lparam);
            const height = win.hiLParam(lparam);
            std.debug.print("Size {d}x{d}\n", .{ width, height });
        },
        else => {
            return win.DefWindowProcW(window_handle, message_type, wparam, lparam);
        },
    }
    return 0;
}
