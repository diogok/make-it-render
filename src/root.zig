//! Make things render with only zig

/// Create and manage windows
pub const anywindow = @import("anywindow");
/// Render text into the windows
pub const textz = @import("textz");

pub const glue = @import("glue.zig");

pub const TextRenderer = glue.TextRenderer;
pub const CreatedImage = glue.CreatedImage;

test {}
