//pub usingnamespace @cImport({
//    @cDefine("WIN32_LEAN_AND_MEAN", "1");
//    @cDefine("UNICODE", "1");
//    @cInclude("windows.h");
//});

pub const WNDCLASSEXW = extern struct {
    cbSize: u32=@sizeOf(@This()),
    style: u32=0,
    lpfnWndProc: ?WNDPROC,
    cbClsExtra: i32=0,
    cbWndExtra: i32=0,
    hInstance: ?HINSTANCE,
    hIcon: ?HICON=null,
    hCursor: ?HCURSOR=null,
    hbrBackground: ?HBRUSH=null,
    lpszMenuName: ?[*:0]const u16=null,
    lpszClassName: ?[*:0]const u16,
    hIconSm: ?HICON=null,
};

pub const CS_VREDRAW = WNDCLASS_STYLES.VREDRAW;
pub const CS_HREDRAW = WNDCLASS_STYLES.HREDRAW;

pub extern "user32" fn RegisterClassExW(
    param0: ?*const WNDCLASSEXW,
) callconv(@import("std").os.windows.WINAPI) u16;

pub extern "kernel32" fn GetLastError(
) callconv(@import("std").os.windows.WINAPI) u32;

// TODO: this type is limited to platform 'windows5.0'
pub extern "user32" fn CreateWindowExW(
    dwExStyle: WINDOW_EX_STYLE,
    lpClassName: ?[*:0]const u16,
    lpWindowName: ?[*:0]const u16,
    dwStyle: WINDOW_STYLE,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: ?HINSTANCE,
    lpParam: ?*anyopaque,
) callconv(@import("std").os.windows.WINAPI) ?HWND;

pub extern "user32" fn ShowWindow(
     lpModuleName: ?HWND, u32
) callconv(@import("std").os.windows.WINAPI) ?HINSTANCE;

pub const MSG = extern struct {
    hwnd: ?HWND,
    message: u32,
    wParam: WPARAM,
    lParam: LPARAM,
    time: u32,
    pt: POINT,
};

pub const POINT = extern struct {
    x: i32,
    y: i32,
};

pub extern "user32" fn GetMessageW(
    lpMsg: ?*MSG,
    hWnd: ?HWND,
    wMsgFilterMin: u32,
    wMsgFilterMax: u32,
) callconv(@import("std").os.windows.WINAPI) c_int;
pub const WM_DESTROY = @as(u32, 2);

pub extern "user32" fn TranslateMessage(
    lpMsg: ?*const MSG,
) callconv(@import("std").os.windows.WINAPI) c_int;

pub extern "user32" fn DispatchMessageW(
    lpMsg: ?*const MSG,
) callconv(@import("std").os.windows.WINAPI) LRESULT;
pub extern "user32" fn PostQuitMessage(
    val: i32,
) callconv(@import("std").os.windows.WINAPI) void;

pub const WS_EX_OVERLAPPEDWINDOW = WINDOW_EX_STYLE.OVERLAPPEDWINDOW;

pub const HMENU = *opaque{};
pub const HINSTANCE = *opaque{};
pub const HWND = *opaque{};
pub const HICON = *opaque{};
pub const HCURSOR = *opaque{};
pub const HBRUSH = *opaque{};

pub const WINDOW_EX_STYLE = enum(u32) {
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


pub const WS_OVERLAPPEDWINDOW = WINDOW_STYLE.OVERLAPPED;

pub const WINDOW_STYLE = enum(u32) {
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

pub extern "kernel32" fn GetModuleHandleW(
     lpModuleName: ?[*:0]const u16,
) callconv(@import("std").os.windows.WINAPI) ?HINSTANCE;


pub const WNDCLASS_STYLES = enum(u32) {
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


pub const WNDPROC = switch (@import("builtin").zig_backend) {
    .stage1 => fn(
        param0: HWND,
        param1: u32,
        param2: WPARAM,
        param3: LPARAM,
    ) callconv(@import("std").os.windows.WINAPI) LRESULT,
    else => *const fn(
        param0: HWND,
        param1: u32,
        param2: WPARAM,
        param3: LPARAM,
    ) callconv(@import("std").os.windows.WINAPI) LRESULT,
} ;

pub const WPARAM = usize;
pub const LPARAM = isize;
pub const LRESULT = isize;


// TODO: this type is limited to platform 'windows5.0'
pub extern "user32" fn DefWindowProcW(
    hWnd: ?HWND,
    Msg: u32,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(@import("std").os.windows.WINAPI) LRESULT;