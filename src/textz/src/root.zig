pub const common = @import("common.zig");
pub const bdf = @import("bdf.zig");
pub const text = @import("text.zig");

pub const render = text.render;

pub const unifont = @import("fonts/unifont/unifont.zig");
pub const terminus = @import("fonts/terminus/terminus.zig");

test {
    _ = common;
    _ = bdf;
    _ = text;

    _ = unifont;
    _ = terminus;
}
