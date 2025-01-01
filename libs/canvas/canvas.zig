const std = @import("std");
const term = @import("termprint.zig");

const expectEqual = std.testing.expectEqual;

pub const Point = struct {
    x: isize, // horizontal position
    y: isize, // vertical position
};

pub const Line = struct {
    start: Point,
    end: Point,
};

pub const RGBA = packed struct {
    red: u8 = 0,
    green: u8 = 0,
    blue: u8 = 0,
    alpha: u8 = 1,
};

// TODO: Dynamic, growing, tiled ImageData?
pub fn ImageData(ColorType: type) type {
    return struct {
        width: isize,
        height: isize,
        data: []ColorType,

        pub fn init(width: isize, height: isize, data: []ColorType) @This() {
            return .{
                .width = width,
                .height = height,
                .data = data,
            };
        }

        pub fn setPixel(self: *@This(), x: isize, y: isize, data: ColorType) void {
            const position = y * self.width + x;
            if (position > 0) {
                self.data[@abs(position)] = data;
            }
        }
    };
}

test "set pixels: rgba" {
    var buffer = [_]RGBA{
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
    };

    var img = ImageData(RGBA){
        .width = 5,
        .height = 4,
        .data = &buffer,
    };

    img.setPixel(1, 0, .{ .red = 255 });
    img.setPixel(0, 1, .{ .green = 255 });
    img.setPixel(3, 2, .{ .blue = 255 });

    try expectEqual(buffer[1].red, 255);
    try expectEqual(buffer[5].green, 255);
    try expectEqual(buffer[13].blue, 255);
}

test "set pixels: bw" {
    var buffer = [_]u1{
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
    };

    var img = ImageData(u1){
        .width = 5,
        .height = 4,
        .data = &buffer,
    };

    img.setPixel(1, 0, 1);
    img.setPixel(0, 1, 1);
    img.setPixel(3, 2, 1);

    try expectEqual(buffer[1], 1);
    try expectEqual(buffer[5], 1);
    try expectEqual(buffer[13], 1);
}

fn incr(a: isize, b: isize) isize {
    if (a < b) {
        return 1;
    } else {
        return -1;
    }
}

// TODO: Anti-alias version
pub fn drawLine(img: anytype, line: Line, color: anytype) void {
    // Bresenham line
    var x0 = line.start.x;
    const x1 = line.end.x;

    var y0 = line.start.y;
    const y1 = line.end.y;

    var dx = x1 - x0;
    if (dx < 0) dx = -dx;
    const sx = incr(x0, x1);

    var dy = y1 - y0;
    if (dy > 0) dy = -dy;
    const sy = incr(y0, y1);

    var e = dx + dy;
    while (true) {
        img.setPixel(x0, y0, color);
        if (x0 == x1 and y0 == y1) break;
        const e2 = 2 * e;
        if (e2 >= dy) {
            if (x0 == x1) break;
            e = e + dy;
            x0 = x0 + sx;
        }
        if (e2 <= dx) {
            if (y0 == y1) break;
            e = e + dx;
            y0 = y0 + sy;
        }
    }
}

fn expectEqualImage(expect: anytype, target: anytype) !void {
    for (expect, 0..) |color, index| {
        try std.testing.expect(std.mem.eql(u8, &std.mem.toBytes(color), &std.mem.toBytes(target[index])));
    }
}

test "draw line: horizontal, left to right" {
    const red = RGBA{ .red = 255 };

    var target = [_]RGBA{
        .{}, .{}, .{}, .{}, .{},
        .{}, red, red, red, .{},
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
    };

    var buffer = [_]RGBA{
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
    };

    var img = ImageData(RGBA){
        .width = 5,
        .height = 4,
        .data = &buffer,
    };

    const line = Line{
        .start = .{
            .x = 1,
            .y = 1,
        },
        .end = .{
            .x = 3,
            .y = 1,
        },
    };
    drawLine(&img, line, red);
    try expectEqualImage(&target, &buffer);
}

test "draw line: horizontal, right to left" {
    const red = RGBA{ .red = 255 };

    var target = [_]RGBA{
        .{}, .{}, .{}, .{}, .{},
        .{}, red, red, red, .{},
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
    };

    var buffer = [_]RGBA{
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
    };

    var img = ImageData(RGBA){
        .width = 5,
        .height = 4,
        .data = &buffer,
    };

    const line = Line{
        .start = .{
            .x = 3,
            .y = 1,
        },
        .end = .{
            .x = 1,
            .y = 1,
        },
    };
    drawLine(&img, line, red);
    try expectEqualImage(&target, &buffer);
}

test "draw line: vertical, top to bottom" {
    const red = RGBA{ .red = 255 };

    var target = [_]RGBA{
        .{}, .{}, .{}, .{}, .{},
        .{}, red, .{}, .{}, .{},
        .{}, red, .{}, .{}, .{},
        .{}, red, .{}, .{}, .{},
    };

    var buffer = [_]RGBA{
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
    };

    var img = ImageData(RGBA){
        .width = 5,
        .height = 4,
        .data = &buffer,
    };

    const line = Line{
        .start = .{
            .x = 1,
            .y = 1,
        },
        .end = .{
            .x = 1,
            .y = 3,
        },
    };
    drawLine(&img, line, red);
    try expectEqualImage(&target, &buffer);
}

test "draw line: vertical, bottom to top" {
    const red = RGBA{ .red = 255 };

    var target = [_]RGBA{
        .{}, .{}, .{}, .{}, .{},
        .{}, red, .{}, .{}, .{},
        .{}, red, .{}, .{}, .{},
        .{}, red, .{}, .{}, .{},
    };

    var buffer = [_]RGBA{
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
        .{}, .{}, .{}, .{}, .{},
    };

    var img = ImageData(RGBA){
        .width = 5,
        .height = 4,
        .data = &buffer,
    };

    const line = Line{
        .start = .{
            .x = 1,
            .y = 1,
        },
        .end = .{
            .x = 1,
            .y = 3,
        },
    };
    drawLine(&img, line, red);
    try expectEqualImage(&target, &buffer);
}

// TODO: Arc
// TODO: Other curves
// TODO: Fill

pub const termprint = term.print;

test {
    _ = @import("termprint.zig");
}
