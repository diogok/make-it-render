const std = @import("std");
const win = @import("std").os.windows;
const c = @import("c.zig");

pub fn main() !void {
    const hInstance = c.GetModuleHandleW(null);
    std.debug.print("Called main {any} {any}\n", .{ std.builtin.subsystem, hInstance });

    const class_name: [*c]const c_ushort = &[_]c_ushort{'H','e','l','l','o'};

    var window_class: c.WNDCLASSEXW = .{
        .cbSize = @sizeOf(c.WNDCLASSEXW),
        .style = c.CS_HREDRAW | c.CS_VREDRAW,
        //.hbrBackground = @as(c.HBRUSH,c.GetStockObject(c.WHITE_BRUSH)),
        .lpfnWndProc = windowProc,
        .hInstance = hInstance,
        .lpszClassName = class_name,
    };

    const registered_window = c.RegisterClassExW(&window_class);
    if(registered_window == 0) {
        const err = c.GetLastError();
        std.debug.print("Register error: {any}\n",.{err});
        return error.RegisterClassError;
    }

    const window_handle = c.CreateWindowExW(
        c.WS_EX_OVERLAPPEDWINDOW,
        class_name,
        class_name,
        c.WS_OVERLAPPEDWINDOW,
        10, 
        10, 
        480, 
        240,
        null,
        null,
        hInstance,
        null,
        );
    if(window_handle == null) {
        const err = c.GetLastError();
        std.debug.print("Create window error: {any}\n",.{err});
        return error.CreateWindowError;
    }

    var result = c.ShowWindow(window_handle,10);
    if(result != 0) {
        const err = c.GetLastError();
        std.debug.print("ShowWindow error: {any}\n",.{err});
        return error.ShowWindowError;
    }
    //result = c.UpdateWindow(window_handle);
    //if(result != 0) {
     //   const err = c.GetLastError();
      //  std.debug.print("UpdateWindow error: {any}\n",.{err});
       // return error.UpdateWindowError;
    //}

    var msg:c.MSG = undefined;
    while(c.GetMessageW(&msg,null,0,0) > 0) {
        result = c.TranslateMessage(&msg);
        if(result != 0) {
            const err = c.GetLastError();
            std.debug.print("TranslateMessageW error: {any}\n",.{err});
            return error.TranslateMessageW;
        }
        const dresult = c.DispatchMessageW(&msg);
        if(dresult != 0) {
            const err = c.GetLastError();
            std.debug.print("DispatchMessageW error: {any}\n",.{err});
            return error.DispatchMessageW;
        }
    }
}

pub fn windowProc(window_handle: c.HWND, message_type: c_uint, wparam: c.WPARAM, lparam: c.LPARAM) callconv(.C) c.LRESULT {
    switch(message_type) {
        c.WM_DESTROY => {
            c.PostQuitMessage(0);
            return 0;
        }, 
        else => {
            return c.DefWindowProcW(window_handle, message_type, wparam, lparam);
        }
    }    
}

var called: bool=false;
//const W = std.unicode.utf8ToUtf16LeStringLiteral;
