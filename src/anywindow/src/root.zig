pub const any = @import("anywindow/any.zig");
pub const common = @import("anywindow/common.zig");

pub const WindowManager = any.WindowManager;
pub const Window = any.Window;
pub const Drawable = any.Drawable;

pub const WindowID = common.WindowID;
pub const Image = common.Image;
pub const Height = common.Height;
pub const Width = common.Width;
pub const X = common.X;
pub const Y = common.Y;
pub const Key = common.Key;
pub const MouseButton = common.MouseButton;
pub const BBox = common.BBox;
pub const WindowOptions = common.WindowOptions;
pub const WindowStatus = common.WindowStatus;
pub const Event = common.Event;

test {
    _ = any;
    _ = common;
}
