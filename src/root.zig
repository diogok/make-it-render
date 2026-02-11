//! Make things render with only zig

/// Create and manage windows
pub const anywindow = @import("anywindow");
/// Render text into the windows
pub const text = @import("text");
/// Parse images
pub const image = @import("image");
/// Code make things easier
pub const glue = @import("glue.zig");

test {
    _ = @import("glue.zig");
    _ = image;
}
