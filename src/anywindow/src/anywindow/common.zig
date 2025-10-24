pub const WindowID = usize;
pub const ImageID = usize;

pub const Height = u16;
pub const Width = u16;
pub const X = i16;
pub const Y = i16;
pub const Key = u16;
pub const MouseButton = u8;

pub const BBox = struct {
    height: Height = 0,
    width: Width = 0,
    x: X = 0,
    y: Y = 0,
};

pub const WindowOptions = struct {
    title: []const u8 = "",
    width: ?Width = null,
    height: ?Height = null,
    x: ?X = null,
    y: ?Y = null,
};

pub const WindowStatus = enum {
    open,
    closed,
};

pub const Image = struct {
    width: Width,
    height: Height,
    /// RGBA pixels
    pixels: []u8,
};

pub const Event = union(enum) {
    nop: void,
    close: WindowID,
    draw: struct {
        window_id: WindowID,
        area: BBox,
    },
    mouse_pressed: struct {
        x: X,
        y: Y,
        button: MouseButton,
        window_id: WindowID,
    },
    mouse_released: struct {
        x: X,
        y: Y,
        button: MouseButton,
        window_id: WindowID,
    },
    mouse_moved: struct {
        x: X,
        y: Y,
        window_id: WindowID,
    },
    key_pressed: struct {
        key: Key,
        window_id: WindowID,
    },
    key_released: struct {
        key: Key,
        window_id: WindowID,
    },
};
