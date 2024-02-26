pub const Instance = *anyopaque;
pub const Icon = *anyopaque;
pub const Cursor = *anyopaque;
pub const Brush = *anyopaque;
pub const Menu = *anyopaque;
pub const WindowHandle = *anyopaque;

pub const W =  @import("std").unicode.utf8ToUtf16LeWithNull;
pub const W2 =  @import("std").unicode.utf8ToUtf16LeStringLiteral;

pub extern "kernel32" fn GetModuleHandleExW(flags: u32, module_name: ?[*:0]const u16, module: ?*?Instance) callconv(.C) ?Instance;
pub extern "kernel32" fn GetLastError() callconv(.C) u32;

pub const WindowClass = extern struct {
    size: u32 = @sizeOf(@This()),
    style: u32 = 0,
    window_procedure: ?WindowProcedure,
    class_extra: i32 = 0,
    window_extra: i32 = 0,
    instance: ?Instance,
    icon: ?Icon = null,
    cursor: ?Cursor = null,
    background: ?Brush = null,
    menu_name: ?[*:0]const u16 = null,
    class_name: ?[*:0]const u16,
    icon_small: ?Icon = null,
};


pub extern "user32" fn RegisterClassExW(window_class: ?*const WindowClass) callconv(.C) u16;

pub const UseDefault = @as(i32, -2147483648);
pub extern "user32" fn CreateWindowExW(
    ex_style: ExtendedWindowStyle,
    class_name: ?[*:0]const u16,
    window_name: ?[*:0]const u16,
    style: WindowStyle,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    parent: ?WindowHandle,
    menu: ?Menu,
    instance: ?Instance,
    lpParam: ?*anyopaque,
) callconv(.C) ?WindowHandle;

pub extern "user32" fn ShowWindow(window_handle: ?WindowHandle, display: u32) callconv(.C) ?WindowHandle;

pub const Message = extern struct {
    hwnd: ?WindowHandle,
    message: MessageType,
    wParam: usize,
    lParam: isize,
    time: u32,
    pt: Point,
};

pub const Point = extern struct {
    x: i32,
    y: i32,
};

pub const MessageType = enum(u32) {
    WM_DESTROY = 2,
    _,
};

pub extern "user32" fn GetMessageW(message: ?*Message, window_handle: ?WindowHandle, filter_min: u32, filter_max: u32) callconv(.C) i32;
pub extern "user32" fn TranslateMessage(message: ?*const Message) callconv(.C) c_int;
pub extern "user32" fn DispatchMessageW(lpMsg: ?*const Message) callconv(.C) isize;
pub extern "user32" fn PostQuitMessage(val: i32) callconv(.C) void;

pub const ExtendedWindowStyle = enum(u32) {
    OverlappedWindow = 0x00000300,
    ClientEdge = 0x00000200,
    WindowEdge = 0x00000100,
};

pub const WindowStyle = enum(u32) {
    Border   =    0x00800000,
    Caption  =    0x00C00000,
    Maximize   =  0x01000000,
    MaximizeBox = 0x00010000,
    Minimize    = 0x20000000,
    MinimizeBox = 0x00020000,
    SysMenu  =    0x00080000,
    ThickFrame =  0x00040000,
    OverlappedWindow = 0x00CF0000,
    Overlapped = 0x00000000,
};

pub const ClassStyle = enum(u32) {
    VREDRAW = 1,
    HREDRAW = 2,
    DBLCLKS = 8,
    OWNDC = 32,
    CLASSDC = 64,
    PARENTDC = 128,
    NOCLOSE = 512,
    SAVEBITS = 2048,
    BYTEALIGNCLIENT = 4096,
    BYTEALIGNWINDOW = 8192,
    GLOBALCLASS = 16384,
    IME = 65536,
    DROPSHADOW = 131072,
};

pub const WindowProcedure = switch (@import("builtin").zig_backend) {
    .stage1 => fn (
        window_handle: WindowHandle,
        message_type: MessageType,
        wParam: usize,
        lParam: isize,
    ) callconv(.C) isize,
    else => *const fn (
        window_handle: WindowHandle,
        message_type: MessageType,
        wParam: usize,
        lParam: isize,
    ) callconv(.C) isize,
};

pub extern "user32" fn DefWindowProcW(
    window_handle: WindowHandle,
    message_type: MessageType,
    wParam: usize,
    lParam: isize,
) callconv(.C) isize;
