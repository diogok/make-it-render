const std = @import("std");
const testing = std.testing;

pub const Intensity = u8;

pub const RGBA = packed struct {
    red: Intensity = 0,
    green: Intensity = 0,
    blue: Intensity = 0,
    alpha: Intensity = 0,
};

pub const Pixels = []const RGBA;

// size on the Y coordinates
pub const Height = u16;
// size on the X coordinates
pub const Width = u16;
// Y represents vertical coordinates
pub const X = i16;
// X represents horizontal coordinates
pub const Y = i16;

pub const Point = packed struct {
    x: X,
    y: Y,
};

pub const Size = packed struct {
    height: Height,
    width: Width,
};
