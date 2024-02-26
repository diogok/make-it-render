pub const CreateWindow = extern struct {
    opcode: u8 = 1,
    depth: u8,
    length: u16 = (@sizeOf(@This()) / 4),
    window_id: u32,
    parent_id: u32,
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    border_width: u16,
    window_class: WindowClass,
    visual_id: u32,
    value_mask: u32 = 0,
};

pub const WindowClass = enum(u16) {
    Parent = 0,
    InputOutput = 1,
    InputOnly = 2,
};

pub const WindowMask = enum(u32) {
    back_pixmap = 1,
    back_pixel = 2,
    border_pixmap = 4,
    border_pixel = 8,
    bit_gravity = 16,
    win_gravity = 32,
    backing_store = 64,
    backing_planes = 128,
    backing_pixel = 256,
    override_redirect = 512,
    save_under = 1024,
    event_mask = 2048,
    dont_propagate = 4096,
    colormap = 8192,
    cursor = 16348,
};

pub const DestroyWindow = extern struct {
    opcode: u8 = 4,
    pad: u8 = 0,
    length: u16 = @sizeOf(@This()) / 4,
    window_id: u32,
};

pub const MapWindow = extern struct {
    opcode: u8 = 8,
    pad: u8 = 0,
    length: u16 = @sizeOf(@This()) / 4,
    window_id: u32,
};

pub const UnmapWindow = extern struct {
    opcode: u8 = 10,
    pad: u8 = 0,
    length: u16 = @sizeOf(@This()) / 4,
    window_id: u32,
};

pub const CreatePixmap = extern struct {
    opcode: u8 = 53,
    depth: u8,
    length: u16 = (@sizeOf(@This()) / 4),
    pixmap_id: u32,
    drawable_id: u32,
    width: u16,
    height: u16,
};

pub const FreePixmap = extern struct {
    opcode: u8 = 54,
    pad0: u8 = 0,
    length: u16 = @sizeOf(@This()) / 4,
    pixmap_id: u32,
};

pub const CreateGraphicContext = extern struct {
    opcode: u8 = 55,
    pad: u8 = 0,
    length: u16 = (@sizeOf(@This()) / 4),
    graphic_context_id: u32,
    drawable_id: u32,
    value_mask: u32 = 0,
};

pub const GraphicContextMask = enum(u32) {
    to_do,
};

pub const FreeGraphicContext = extern struct {
    opcode: u8 = 60,
    pad0: u8 = 0,
    length: u16 = @sizeOf(@This()) / 4,
    graphic_context_id: u32,
};

pub const PutImage = extern struct {
    opcode: u8 = 72,
    format: ImageFormat = .ZPixmap,
    length: u16 = (@sizeOf(@This()) / 4),
    drawable_id: u32,
    graphic_context_id: u32,
    width: u16,
    height: u16,
    x: i16,
    y: i16,
    left_pad: u8 = 0,
    depth: u8,
    pad: [2]u8 = .{ 0, 0 },
};

pub const ImageFormat = enum(u8) {
    XYBitmap = 0,
    XYPixmap = 1,
    ZPixmap = 2,
};

pub const CopyArea = extern struct {
    opcode: u8 = 62,
    pad: u8 = 0,
    length: u16 = (@sizeOf(@This()) / 4),
    src_drawable_id: u32,
    dst_drawable_id: u32,
    graphic_context_id: u32,
    src_x: i16 = 0,
    src_y: i16 = 0,
    dst_x: i16 = 0,
    dst_y: i16 = 0,
    width: u16,
    height: u16,
};
