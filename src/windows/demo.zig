const std = @import("std");
const win = @import("windows.zig");

const log = std.log.scoped(.main);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() != .leak);
    const allocator = gpa.allocator();

    //const instance = win.GetModuleHandleW(null);
    const instance = win.GetModuleHandleExW(0,null,null);
    log.debug("Called main {any} {any}", .{ std.builtin.subsystem, instance });

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

    var msg: win.Message = undefined;
    while (win.GetMessageW(&msg, null, 0, 0) > 0) {
        _ = win.TranslateMessage(&msg);
        _ = win.DispatchMessageW(&msg);
    }
}

pub fn windowProc(window_handle: win.WindowHandle, message_type: win.MessageType, wparam: usize, lparam: isize) callconv(.C) isize {
    switch (message_type) {
        .WM_DESTROY => {
            win.PostQuitMessage(0);
            return 0;
        },
        else => {
            return win.DefWindowProcW(window_handle, message_type, wparam, lparam);
        },
    }
}
