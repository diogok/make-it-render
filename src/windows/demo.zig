const std = @import("std");
const win = @import("windows.zig");

pub fn main() !void {
    const instance = win.GetModuleHandleW(null);
    std.debug.print("Called main {any} {any}\n", .{ std.builtin.subsystem, instance });

    const class_name = &[_:0]c_ushort{ 'H', 'e', 'l', 'l', 'o' };

    var window_class: win.WindowClass = .{
        .style = @intFromEnum(win.ClassStyle.HREDRAW) | @intFromEnum(win.ClassStyle.VREDRAW),
        //.hbrBackground = @as(c.HBRUSH,c.GetStockObject(c.WHITE_BRUSH)),
        .window_procedure = windowProc,
        .instance = instance,
        .class_name = class_name,
    };

    const registered_window = win.RegisterClassExW(&window_class);
    if (registered_window == 0) {
        const err = win.GetLastError();
        std.debug.print("Register error: {d}\n", .{err});
        return error.RegisterClassError;
    }

    const window_handle = win.CreateWindowExW(
        win.ExStyle.OVERLAPPEDWINDOW,
        class_name,
        class_name,
        win.Style.OVERLAPPED,
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
        std.debug.print("Create window error: {any}\n", .{err});
        return error.CreateWindowError;
    }

    const show_result = win.ShowWindow(window_handle, 10);
    if (show_result != null) {
        const err = win.GetLastError();
        std.debug.print("ShowWindow error: {any}\n", .{err});
        return error.ShowWindowError;
    }

    var msg: win.Message = undefined;
    while (win.GetMessageW(&msg, null, 0, 0) > 0) {
        const translate_result = win.TranslateMessage(&msg);
        if (translate_result != 0) {
            const err = win.GetLastError();
            std.debug.print("TranslateMessageW error: {any}\n", .{err});
            return error.TranslateMessageW;
        }
        const dispatch_result = win.DispatchMessageW(&msg);
        if (dispatch_result != 0) {
            const err = win.GetLastError();
            std.debug.print("DispatchMessageW error: {any}\n", .{err});
            return error.DispatchMessageW;
        }
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
