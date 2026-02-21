pub const any = @import("anywindow/any.zig");
pub const common = @import("anywindow/common.zig");
const queue = @import("anywindow/queue.zig");

pub const WindowManager = any.WindowManager;
pub const Window = any.Window;
pub const Image = any.Image;
pub const WindowSource = @import("anywindow/window_source.zig");

pub const WindowID = common.WindowID;
pub const Size = common.Size;
pub const Position = common.Position;
pub const Height = common.Height;
pub const Width = common.Width;
pub const BBox = common.BBox;
pub const X = common.X;
pub const Y = common.Y;
pub const Pixels = common.Pixels;
pub const Scancode = common.Scancode;
pub const Key = common.Key;
pub const Modifiers = common.Modifiers;
pub const MouseButton = common.MouseButton;
pub const Icon = common.Icon;
pub const WindowOptions = common.WindowOptions;
pub const WindowStatus = common.WindowStatus;
pub const Event = common.Event;

test {
    _ = any;
    _ = common;
    _ = queue;
}
