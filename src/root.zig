//! Make things render with only zig

/// Create and manage windows
pub const anywindow = @import("anywindow");
/// Render text into the windows
pub const text = @import("text");
/// Code make things easier
pub const glue = @import("glue.zig");

test {
    _ = @import("glue.zig");
}
