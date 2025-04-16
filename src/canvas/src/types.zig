const std = @import("std");

pub const Intensity = u8;

pub const RGBA = packed struct {
    red: Intensity = 0,
    green: Intensity = 0,
    blue: Intensity = 0,
    alpha: Intensity = 0,
};

pub const Height = u16;
pub const Width = u16;
pub const X = u16;
pub const Y = u16;

pub const BBox = struct {
    origin: Point,
    height: Height,
    width: Width,
};

pub const Point = struct {
    x: X,
    y: Y,
};
