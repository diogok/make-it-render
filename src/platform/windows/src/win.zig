// === Base functions

/// An Instance of your module, you program. Retrieve it with GetModuleHandleW.
pub const Instance = *anyopaque;

pub const String = [*:0]const u16;

/// For allocated (non comptime known) Strings
pub const W = @import("std").unicode.utf8ToUtf16LeWithNull;
/// For comptime known Strings
pub const W2 = @import("std").unicode.utf8ToUtf16LeStringLiteral;

/// Return your program module Instance.
pub extern "kernel32" fn GetModuleHandleW(moduleName: ?String) callconv(.C) ?Instance;
/// Return the last error number, check on MS documentation what the code means.
pub extern "kernel32" fn GetLastError() callconv(.C) u32;

pub fn loword(lParam: isize) u16 {
    const value: usize = @bitCast(lParam);
    return @intCast(0xffff & value);
}

pub fn hiword(lParam: isize) u16 {
    const value: usize = @bitCast(lParam);
    return @intCast(0xffff & (value >> 16));
}

// === Window & messages

pub extern "user32" fn RegisterClassExW(
    window_class: ?*const WindowClass,
) callconv(.C) WindowClassAtom;

pub extern "user32" fn CreateWindowExW(
    ex_style: ExtendedWindowStyle,
    class_name: ?String,
    title: ?String,
    style: WindowStyle,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    parent: ?WindowHandle,
    menu: ?MenuHandler,
    instance: ?Instance,
    lpParam: ?*anyopaque,
) callconv(.C) ?WindowHandle;

pub extern "user32" fn ShowWindow(
    window_handle: ?WindowHandle,
    display: u32,
) callconv(.C) ?WindowHandle;

pub extern "user32" fn GetMessageW(
    message: ?*Message,
    window_handle: ?WindowHandle,
    filter_min: u32,
    filter_max: u32,
) callconv(.C) i32;

pub extern "user32" fn TranslateMessage(
    message: ?*const Message,
) callconv(.C) c_int;

pub extern "user32" fn DispatchMessageW(
    lpMsg: ?*const Message,
) callconv(.C) isize;

/// End the program.
pub extern "user32" fn PostQuitMessage(
    val: i32,
) callconv(.C) void;

/// WindowProcedure is the function signature to handle window messages.
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

/// This is the default handler for windows procedures/messages.
/// Use it to handle messages that your application will not handle,
/// to ensure all messages are handled.
pub extern "user32" fn DefWindowProcW(
    window_handle: WindowHandle,
    message_type: MessageType,
    wParam: usize,
    lParam: isize,
) callconv(.C) isize;

pub const WindowHandle = *anyopaque;
pub const WindowClassAtom = u16;

pub const IconHandler = *anyopaque;
pub const BrushHandler = *anyopaque;
pub const MenuHandler = *anyopaque;

pub const CursorName = enum(u32) {
    Arrow = 32512,
    Beam = 32513,
    Wait = 32514,
};

pub const WindowClass = extern struct {
    size: u32 = @sizeOf(@This()),
    style: u32 = @intFromEnum(ClassStyle.HREDRAW) | @intFromEnum(ClassStyle.VREDRAW),
    window_procedure: ?WindowProcedure = DefWindowProcW,
    class_extra: i32 = 0,
    window_extra: i32 = 0,
    instance: ?Instance,
    icon: ?IconHandler = null,
    cursor: ?CursorHandler = null,
    background: ?BrushHandler = null,
    menu_name: ?String = null,
    class_name: ?String,
    icon_small: ?IconHandler = null,
};

pub const ExtendedWindowStyle = enum(u32) {
    OverlappedWindow = 0x00000300,
    ClientEdge = 0x00000200,
    WindowEdge = 0x00000100,
};

pub const WindowStyle = enum(u32) {
    Border = 0x00800000,
    Caption = 0x00C00000,
    Maximize = 0x01000000,
    MaximizeBox = 0x00010000,
    Minimize = 0x20000000,
    MinimizeBox = 0x00020000,
    SysMenu = 0x00080000,
    ThickFrame = 0x00040000,
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

pub const UseDefault = @as(i32, -2147483648);

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
    WM_CREATE = 0x0001,
    WM_DESTROY = 0x0002,
    WM_SIZE = 0x0005,
    WM_PAINT = 0x000F, //15,
    WM_KEYDOWN = 0x0100,
    WM_KEYUP = 0x0101,
    WM_SYSKEYUP = 0x0105,
    WM_SYSKEYDOWN = 0x0104,
    WM_LBUTTONDOWN = 0x0201,
    WM_LBUTTONUP = 0x0202,
    WM_LBUTTONDBLCLK = 0x0203,
    WM_RBUTTONDOWN = 0x0204,
    WM_RBUTTONUP = 0x0205,
    WM_RBUTTONDBLCLK = 0x0206,
    WM_MBUTTONDOWN = 0x0207,
    WM_MBUTTONUP = 0x0208,
    WM_MBUTTONDBLCLK = 0x0209,
    WM_MOUSEMOVE = 0x0200,
    WM_MOUSEWHEEL = 0x020A,
    WM_XBUTTONDOWN = 0x020B,
    WM_XBUTTONUP = 0x020C,
    WM_XBUTTONDBLCLK = 0x02D,
    WM_MOUSEHWHEEL = 0x020E,
    _,
};

/// Used to check wParam from messages, as a mask(?).
pub const ControlKeys = enum(u32) {
    MK_LBUTTON = 0x0001,
    MK_RBUTTON = 0x0002,
    MK_SHIFT = 0x0004,
    MK_CONTROL = 0x0008,
    MK_MBUTTON = 0x0010,
    MK_XBUTTON1 = 0x0020,
    MK_XBUTTON2 = 0x0040,
};

// === Cursors

pub extern "user32" fn LoadCursorW(
    instance: ?Instance,
    cursor: CursorName,
) callconv(.C) ?CursorHandler;

pub extern "user32" fn ShowCursor(
    show: bool,
) callconv(.C) i32;

pub extern "user32" fn SetCursor(
    cursor: ?CursorHandler,
) callconv(.C) ?CursorHandler;

pub const CursorHandler = *anyopaque;

// === Drawing

pub extern "user32" fn UpdateWindow(
    window_handle: ?WindowHandle,
) callconv(.C) bool;

pub extern "dwmapi" fn DwmFlush() callconv(.C) isize;

pub extern "user32" fn InvalidateRect(
    window_handle: ?WindowHandle,
    rect: ?*Rect,
    erase: bool,
) callconv(.C) bool;

pub extern "user32" fn BeginPaint(
    window_handle: WindowHandle,
    paint: *Paint,
) callconv(.C) ?DeviceContext;

pub extern "user32" fn EndPaint(
    window_handle: WindowHandle,
    lpPaint: *Paint,
) callconv(.C) bool;

pub extern "user32" fn GetDC(
    handle: ?WindowHandle,
) callconv(.C) ?DeviceContext;

pub extern "user32" fn ReleaseDC(
    window: ?WindowHandle,
    handle: ?DeviceContext,
) callconv(.C) c_int;

pub extern "user32" fn BitBlt(
    dstHDC: ?DeviceContext,
    dstX: i32,
    dstY: i32,
    dstWidth: i32,
    dstHeight: i32,
    srcHdc: ?DeviceContext,
    srcX: i32,
    srcY: i32,
    op: RasterOperation,
) callconv(.C) bool;

pub extern "gdi32" fn CreateCompatibleDC(
    handle: ?DeviceContext,
) callconv(.C) ?DeviceContext;

pub extern "user32" fn SelectObject(
    handle0: ?DeviceContext,
    handle1: ?Bitmap,
) callconv(.C) DeviceContext;

pub extern "gdi32" fn DeleteObject(
    handle: ?Bitmap,
) callconv(.C) bool;

pub extern "gdi32" fn CreateDIBSection(
    handle: ?DeviceContext,
    pbmi: ?*const BitmapInfo,
    usage: DIBUsage,
    ppvBits: *[*]u8,
    hSection: ?*anyopaque,
    offset: u32,
) callconv(.C) ?Bitmap;

pub const DeviceContext = *anyopaque;
pub const Bitmap = *anyopaque;

pub const Paint = extern struct {
    device_context: usize,
    erase: bool = false,
    rect: Rect = Rect{},
    restore: bool = false,
    incUpdate: bool = false,
    rgbReserved: [32]u8 = undefined,
};

pub const Rect = extern struct {
    left: c_long = 0,
    top: c_long = 0,
    right: c_long = 0,
    bottom: c_long = 0,
};

pub const BitmapInfo = extern struct {
    header: BitmapInfoHeader = .{},
    colors: extern struct {
        blue: u8 = 0,
        green: u8 = 0,
        red: u8 = 0,
        reserved: u8 = 0,
    } = .{},
};

pub const BitmapInfoHeader = extern struct {
    size: u32 = @sizeOf(@This()),
    width: i32 = 0,
    height: i32 = 0,
    planes: u16 = 1,
    bitCount: u16 = 32,
    compression: u32 = 0,
    sizeImage: u32 = 0,
    xPelsPerMeter: i32 = 0,
    yPelsPerMeter: i32 = 0,
    clrUsed: u32 = 0,
    clrImportant: u32 = 0,
};

pub const DIBUsage = enum(u32) {
    RGB_COLORS = 0,
    PAL_COLORS = 1,
};

pub const RasterOperation = enum(u32) {
    BLACKNESS = 0b100001,
    CAPTUREBLT,
    DSTINVER,
    MERGECOPY,
    MERGEPAINT,
    NOMIRRORBITMAP,
    NOTSRCOPY,
    NOTSRCEARE,
    PATCOPY,
    PATINVERT,
    PATPAINT,
    SRCAND,
    SRCCOPY = 13369376,
    SRCERASE,
    SRCINVERT,
    SRCPAINT,
    WHITENESS,
};
