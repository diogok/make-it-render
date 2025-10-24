pub const wm = @import("wm.zig");
pub const common = @import("common.zig");

pub const WM = wm.WM;

pub const WindowID = common.WindowID;
pub const ImageID = common.ImageID;
pub const Height = common.Height;
pub const Width = common.Width;
pub const X = common.X;
pub const Y = common.Y;
pub const Key = common.Key;
pub const MouseButton = common.MouseButton;
pub const BBox = common.BBox;
pub const WindowOptions = common.WindowOptions;
pub const WindowStatus = common.WindowStatus;
pub const Image = common.Image;
pub const Event = common.Event;

test {
    _ = wm;
    _ = common;
}
