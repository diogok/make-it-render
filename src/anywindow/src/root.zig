pub const any = @import("anywindow/any.zig");
pub const common = @import("anywindow/common.zig");

pub const WindowManager = any.WindowManager;
pub const Window = any.Window;
pub const Image = any.Image;

pub const WindowID = common.WindowID;
pub const Size = common.Size;
pub const Position = common.Position;
pub const Height = common.Height;
pub const Width = common.Width;
pub const BBox = common.BBox;
pub const X = common.X;
pub const Y = common.Y;
pub const Pixels = common.Pixels;
pub const Key = common.Key;
pub const MouseButton = common.MouseButton;
pub const WindowOptions = common.WindowOptions;
pub const WindowStatus = common.WindowStatus;
pub const Event = common.Event;

test {
    _ = any;
    _ = common;
}
