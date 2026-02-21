/// Manages multiple images and composites them onto a window.
pub const Canvas = @import("canvas.zig");
/// A positioned drawable surface within a Canvas.
pub const Image = @import("image.zig");
/// 2D drawing context for an Image, with fill, stroke and path operations.
pub const Context = @import("context.zig");

test {
    _ = Canvas;
    _ = Image;
    _ = Context;
}
