pub const wm = @import("wm.zig");
pub const common = @import("common.zig");

/// base namespace.
pub usingnamespace wm;
pub usingnamespace common;

test {
    _ = wm;
    _ = common;
}
