
pub const Instance = *anyopaque{};
pub const Icon = *anyopaque{};
pub const Cursor = *anyopaque{};
pub const Brush = *anyopaque{};
pub const Menu = *anyopaque{};
pub const WindowHandle = *anyopaque{};

pub extern "kernel32" fn GetModuleHandleW(module_name: ?[*:0]const u16) callconv(.C) ?Instance;


pub const WindowClass = extern struct {
    cbSize: u32=@sizeOf(@This()),
    style: u32=0,
    lpfnWndProc: ?WindowProcedure,
    cbClsExtra: i32=0,
    cbWndExtra: i32=0,
    hInstance: ?Instance,
    hIcon: ?Icon=null,
    hCursor: ?Cursor=null,
    hbrBackground: ?Brush=null,
    lpszMenuName: ?[*:0]const u16=null,
    lpszClassName: ?[*:0]const u16,
    hIconSm: ?Icon=null,
};

pub extern "kernel32" fn GetLastError() callconv(.C) u32;// TODO: error enum? Might be too big.

pub extern "user32" fn RegisterClassExW(window_class: ?*const WindowClass) callconv(.C) u16;

const UseDefault = @as(i32, -2147483648);
pub extern "user32" fn CreateWindowExW(
    ex_style: ExStyle,
    class_name: ?[*:0]const u16,
    window_name: ?[*:0]const u16,
    style: Style,
    X: i32=UseDefault, 
    Y: i32=UseDefault,
    width: i32=UseDefault,
    height: i32=UseDefault,
    parent: ?WindowHandle=null,
    menu: ?Menu=null,
    instance: ?Instance,
    lpParam: ?*anyopaque=null,
) callconv(@import("std").os.windows.WINAPI) ?WindowHandle;

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
};

pub extern "user32" fn GetMessageW(message: ?*Message, window_handle: ?WindowHandle, filter_min: u32, filter_max: u32) callconv(.C) i32;
pub extern "user32" fn TranslateMessage(message: ?*const Message) callconv(.C) c_int;
pub extern "user32" fn DispatchMessageW(lpMsg: ?*const Message) callconv(.C) isize;
pub extern "user32" fn PostQuitMessage(val: i32) callconv(.C) void;

pub const ExStyle = enum(u32) {
    DLGMODALFRAME = 1,
    NOPARENTNOTIFY = 4,
    TOPMOST = 8,
    ACCEPTFILES = 16,
    TRANSPARENT = 32,
    MDICHILD = 64,
    TOOLWINDOW = 128,
    WINDOWEDGE = 256,
    CLIENTEDGE = 512,
    CONTEXTHELP = 1024,
    RIGHT = 4096,
    LEFT = 0,
    RTLREADING = 8192,
    // LTRREADING = 0, this enum value conflicts with LEFT
    LEFTSCROLLBAR = 16384,
    // RIGHTSCROLLBAR = 0, this enum value conflicts with LEFT
    CONTROLPARENT = 65536,
    STATICEDGE = 131072,
    APPWINDOW = 262144,
    OVERLAPPEDWINDOW = 768,
    PALETTEWINDOW = 392,
    LAYERED = 524288,
    NOINHERITLAYOUT = 1048576,
    NOREDIRECTIONBITMAP = 2097152,
    LAYOUTRTL = 4194304,
    COMPOSITED = 33554432,
    NOACTIVATE = 134217728,
};

pub const Style = enum(u32) {
    OVERLAPPED = 0,
    POPUP = 2147483648,
    CHILD = 1073741824,
    MINIMIZE = 536870912,
    VISIBLE = 268435456,
    DISABLED = 134217728,
    CLIPSIBLINGS = 67108864,
    CLIPCHILDREN = 33554432,
    MAXIMIZE = 16777216,
    CAPTION = 12582912,
    BORDER = 8388608,
    DLGFRAME = 4194304,
    VSCROLL = 2097152,
    HSCROLL = 1048576,
    SYSMENU = 524288,
    THICKFRAME = 262144,
    GROUP = 131072,
    TABSTOP = 65536,
    // MINIMIZEBOX = 131072, this enum value conflicts with GROUP
    // MAXIMIZEBOX = 65536, this enum value conflicts with TABSTOP
    // TILED = 0, this enum value conflicts with OVERLAPPED
    // ICONIC = 536870912, this enum value conflicts with MINIMIZE
    // SIZEBOX = 262144, this enum value conflicts with THICKFRAME
    TILEDWINDOW = 13565952,
    // OVERLAPPEDWINDOW = 13565952, this enum value conflicts with TILEDWINDOW
    POPUPWINDOW = 2156396544,
    // CHILDWINDOW = 1073741824, this enum value conflicts with CHILD
    ACTIVECAPTION = 1,
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
    .stage1 => fn(
        param0: WindowHandle,
        param1: u32,
        param2: usize,
        param3: isize,
    ) callconv(.C) isize,
    else => *const fn(
        param0: WindowHandle,
        param1: u32,
        param2: usize,
        param3: isize,
    ) callconv(.C) isize,
} ;

pub extern "user32" fn DefWindowProcW(
    hWnd: ?WindowHandle,
    Msg: u32,
    wParam: usize,
    lParam: isize,
) callconv(.C) isize;
