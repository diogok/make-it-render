image: *Image,
pixel_buffer: []u8,
width: u32,
height: u32,
allocator: std.mem.Allocator,

fill_color: [4]u8 = .{ 0, 0, 0, 255 },
stroke_color: [4]u8 = .{ 0, 0, 0, 255 },
line_width: u16 = 1,

path: std.ArrayList(PathCommand) = .empty,

const PathCommand = union(enum) {
    move_to: Point,
    line_to: Point,
    close_path: void,
};

const Point = struct {
    x: f32,
    y: f32,
};

pub fn init(image: *Image, allocator: std.mem.Allocator) !@This() {
    const width: u32 = image.src_bbox.width;
    const height: u32 = image.src_bbox.height;
    const size = width * height * 4;
    const pixel_buffer = try allocator.alloc(u8, size);
    @memset(pixel_buffer, 0);

    return .{
        .image = image,
        .pixel_buffer = pixel_buffer,
        .width = width,
        .height = height,
        .allocator = allocator,
    };
}

pub fn deinit(self: *@This()) void {
    self.allocator.free(self.pixel_buffer);
    self.path.deinit(self.allocator);
}

pub fn setFillColor(self: *@This(), color: [4]u8) void {
    self.fill_color = color;
}

pub fn setStrokeColor(self: *@This(), color: [4]u8) void {
    self.stroke_color = color;
}

pub fn setLineWidth(self: *@This(), width: u16) void {
    self.line_width = width;
}

fn setPixel(self: *@This(), x: i32, y: i32, color: [4]u8) void {
    if (x < 0 or y < 0) return;
    const ux: u32 = @intCast(x);
    const uy: u32 = @intCast(y);
    if (ux >= self.width or uy >= self.height) return;
    const offset = (uy * self.width + ux) * 4;
    self.pixel_buffer[offset] = color[0];
    self.pixel_buffer[offset + 1] = color[1];
    self.pixel_buffer[offset + 2] = color[2];
    self.pixel_buffer[offset + 3] = color[3];
}

fn fillRectInternal(self: *@This(), x: i32, y: i32, w: u32, h: u32, color: [4]u8) void {
    const x0: u32 = if (x < 0) 0 else @intCast(@min(x, @as(i32, @intCast(self.width))));
    const y0: u32 = if (y < 0) 0 else @intCast(@min(y, @as(i32, @intCast(self.height))));
    const x1: u32 = if (x < 0) @min(w -| @as(u32, @intCast(-x)), self.width) else @min(x0 + w, self.width);
    const y1: u32 = if (y < 0) @min(h -| @as(u32, @intCast(-y)), self.height) else @min(y0 + h, self.height);

    var cy = y0;
    while (cy < y1) : (cy += 1) {
        const row_start = (cy * self.width + x0) * 4;
        const row_end = (cy * self.width + x1) * 4;
        var row = self.pixel_buffer[row_start..row_end];
        var i: usize = 0;
        while (i < row.len) : (i += 4) {
            row[i] = color[0];
            row[i + 1] = color[1];
            row[i + 2] = color[2];
            row[i + 3] = color[3];
        }
    }
}

pub fn fillRect(self: *@This(), x: i32, y: i32, w: u32, h: u32) void {
    self.fillRectInternal(x, y, w, h, self.fill_color);
}

pub fn clearRect(self: *@This(), x: i32, y: i32, w: u32, h: u32) void {
    self.fillRectInternal(x, y, w, h, .{ 0, 0, 0, 0 });
}

pub fn strokeRect(self: *@This(), x: i32, y: i32, w: u32, h: u32) void {
    const lw = self.line_width;
    const color = self.stroke_color;
    // top
    self.fillRectInternal(x, y, w, lw, color);
    // bottom
    self.fillRectInternal(x, y + @as(i32, @intCast(h)) - @as(i32, lw), w, lw, color);
    // left
    self.fillRectInternal(x, y, lw, h, color);
    // right
    self.fillRectInternal(x + @as(i32, @intCast(w)) - @as(i32, lw), y, lw, h, color);
}

pub fn beginPath(self: *@This()) void {
    self.path.clearRetainingCapacity();
}

pub fn moveTo(self: *@This(), x: f32, y: f32) void {
    self.path.append(self.allocator, .{ .move_to = .{ .x = x, .y = y } }) catch {};
}

pub fn lineTo(self: *@This(), x: f32, y: f32) void {
    self.path.append(self.allocator, .{ .line_to = .{ .x = x, .y = y } }) catch {};
}

pub fn closePath(self: *@This()) void {
    self.path.append(self.allocator, .close_path) catch {};
}

fn drawLine(self: *@This(), x0: i32, y0: i32, x1: i32, y1: i32, color: [4]u8) void {
    const dx: i32 = if (x1 > x0) x1 - x0 else x0 - x1;
    const dy: i32 = -(if (y1 > y0) y1 - y0 else y0 - y1);
    const sx: i32 = if (x0 < x1) 1 else -1;
    const sy: i32 = if (y0 < y1) 1 else -1;
    var err = dx + dy;

    var cx = x0;
    var cy = y0;

    while (true) {
        if (self.line_width <= 1) {
            self.setPixel(cx, cy, color);
        } else {
            const half: i32 = @as(i32, self.line_width) >> 1;
            self.fillRectInternal(cx - half, cy - half, self.line_width, self.line_width, color);
        }
        if (cx == x1 and cy == y1) break;
        const e2 = 2 * err;
        if (e2 >= dy) {
            err += dy;
            cx += sx;
        }
        if (e2 <= dx) {
            err += dx;
            cy += sy;
        }
    }
}

pub fn stroke(self: *@This()) void {
    const color = self.stroke_color;
    var start: ?Point = null;
    var current: ?Point = null;

    for (self.path.items) |cmd| {
        switch (cmd) {
            .move_to => |p| {
                start = p;
                current = p;
            },
            .line_to => |p| {
                if (current) |cur| {
                    self.drawLine(
                        @intFromFloat(cur.x),
                        @intFromFloat(cur.y),
                        @intFromFloat(p.x),
                        @intFromFloat(p.y),
                        color,
                    );
                }
                current = p;
            },
            .close_path => {
                if (current) |cur| {
                    if (start) |s| {
                        self.drawLine(
                            @intFromFloat(cur.x),
                            @intFromFloat(cur.y),
                            @intFromFloat(s.x),
                            @intFromFloat(s.y),
                            color,
                        );
                    }
                }
                current = start;
            },
        }
    }
}

pub fn fill(self: *@This()) void {
    const color = self.fill_color;

    // Collect edges from path
    var edges = std.ArrayList(Edge).init(self.allocator);
    defer edges.deinit();

    var start: ?Point = null;
    var current: ?Point = null;

    for (self.path.items) |cmd| {
        switch (cmd) {
            .move_to => |p| {
                start = p;
                current = p;
            },
            .line_to => |p| {
                if (current) |cur| {
                    addEdge(&edges, cur, p);
                }
                current = p;
            },
            .close_path => {
                if (current) |cur| {
                    if (start) |s| {
                        addEdge(&edges, cur, s);
                    }
                }
                current = start;
            },
        }
    }

    if (edges.items.len == 0) return;

    // Find Y bounding box
    var min_y: f32 = edges.items[0].y0;
    var max_y: f32 = edges.items[0].y0;
    for (edges.items) |edge| {
        min_y = @min(min_y, @min(edge.y0, edge.y1));
        max_y = @max(max_y, @max(edge.y0, edge.y1));
    }

    const start_y: i32 = @max(0, @as(i32, @intFromFloat(@floor(min_y))));
    const end_y: i32 = @min(@as(i32, @intCast(self.height)), @as(i32, @intFromFloat(@ceil(max_y))));

    // Intersection buffer
    var intersections = std.ArrayList(f32).init(self.allocator);
    defer intersections.deinit();

    // Scanline fill
    var y = start_y;
    while (y < end_y) : (y += 1) {
        intersections.clearRetainingCapacity();
        const scanline: f32 = @as(f32, @floatFromInt(y)) + 0.5;

        for (edges.items) |edge| {
            const ey_min = @min(edge.y0, edge.y1);
            const ey_max = @max(edge.y0, edge.y1);
            if (scanline >= ey_min and scanline < ey_max) {
                const x_intersect = edge.x0 + (scanline - edge.y0) * (edge.x1 - edge.x0) / (edge.y1 - edge.y0);
                intersections.append(self.allocator, x_intersect) catch return;
            }
        }

        // Sort intersections
        std.sort.block(f32, intersections.items, {}, std.sort.asc(f32));

        // Fill between pairs (even-odd rule)
        var i: usize = 0;
        while (i + 1 < intersections.items.len) : (i += 2) {
            const x_start: i32 = @max(0, @as(i32, @intFromFloat(@ceil(intersections.items[i]))));
            const x_end: i32 = @min(@as(i32, @intCast(self.width)), @as(i32, @intFromFloat(@floor(intersections.items[i + 1]))));
            var x = x_start;
            while (x <= x_end) : (x += 1) {
                self.setPixel(x, y, color);
            }
        }
    }
}

pub fn flush(self: *@This()) !void {
    var reader = std.Io.Reader.fixed(self.pixel_buffer);
    try self.image.setPixels(&reader);
}

const Edge = struct {
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
};

fn addEdge(edges: *std.ArrayList(Edge), p0: Point, p1: Point) void {
    // Skip horizontal edges
    if (p0.y == p1.y) return;
    edges.append(edges.allocator, .{
        .x0 = p0.x,
        .y0 = p0.y,
        .x1 = p1.x,
        .y1 = p1.y,
    }) catch {};
}

// Tests

test "setPixel within bounds" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 4 * 4 * 4); // 4x4
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx = @This(){
        .image = undefined,
        .pixel_buffer = buf,
        .width = 4,
        .height = 4,
        .allocator = allocator,
    };

    ctx.setPixel(1, 2, .{ 255, 0, 0, 255 });

    const offset = (2 * 4 + 1) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 0, 255 }, buf[offset .. offset + 4]);
    // (0,0) still zero
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[0..4]);
}

test "setPixel out of bounds is ignored" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 2 * 2 * 4); // 2x2
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx = @This(){
        .image = undefined,
        .pixel_buffer = buf,
        .width = 2,
        .height = 2,
        .allocator = allocator,
    };

    ctx.setPixel(-1, 0, .{ 255, 0, 0, 255 });
    ctx.setPixel(0, -1, .{ 255, 0, 0, 255 });
    ctx.setPixel(2, 0, .{ 255, 0, 0, 255 });
    ctx.setPixel(0, 2, .{ 255, 0, 0, 255 });

    // All pixels still zero
    for (buf) |b| {
        try testing.expectEqual(@as(u8, 0), b);
    }
}

test "fillRect fills correct region" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 4 * 4 * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx = @This(){
        .image = undefined,
        .pixel_buffer = buf,
        .width = 4,
        .height = 4,
        .allocator = allocator,
    };

    ctx.setFillColor(.{ 255, 0, 0, 255 });
    ctx.fillRect(1, 1, 2, 2);

    // (1,1) should be red
    const offset11 = (1 * 4 + 1) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 0, 255 }, buf[offset11 .. offset11 + 4]);
    // (2,2) should be red
    const offset22 = (2 * 4 + 2) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 0, 255 }, buf[offset22 .. offset22 + 4]);
    // (0,0) should be zero
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[0..4]);
    // (3,3) should be zero
    const offset33 = (3 * 4 + 3) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[offset33 .. offset33 + 4]);
}

test "fillRect clips to bounds" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 4 * 4 * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx = @This(){
        .image = undefined,
        .pixel_buffer = buf,
        .width = 4,
        .height = 4,
        .allocator = allocator,
    };

    ctx.setFillColor(.{ 0, 255, 0, 255 });
    // extends past right and bottom
    ctx.fillRect(3, 3, 10, 10);

    // (3,3) should be green
    const offset33 = (3 * 4 + 3) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 255, 0, 255 }, buf[offset33 .. offset33 + 4]);
    // (2,2) should be zero
    const offset22 = (2 * 4 + 2) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[offset22 .. offset22 + 4]);
}

test "clearRect zeroes region" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 4 * 4 * 4);
    defer allocator.free(buf);
    @memset(buf, 255);

    var ctx = @This(){
        .image = undefined,
        .pixel_buffer = buf,
        .width = 4,
        .height = 4,
        .allocator = allocator,
    };

    ctx.clearRect(1, 1, 2, 2);

    const offset11 = (1 * 4 + 1) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[offset11 .. offset11 + 4]);
    // (0,0) should still be 255
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 255, 255, 255 }, buf[0..4]);
}

test "strokeRect draws outline only" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 6 * 6 * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx = @This(){
        .image = undefined,
        .pixel_buffer = buf,
        .width = 6,
        .height = 6,
        .allocator = allocator,
    };

    ctx.setStrokeColor(.{ 255, 0, 0, 255 });
    ctx.strokeRect(1, 1, 4, 4);

    // top edge (1,1) should be red
    const offset11 = (1 * 6 + 1) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 0, 255 }, buf[offset11 .. offset11 + 4]);
    // interior (2,2) should be zero
    const offset22 = (2 * 6 + 2) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[offset22 .. offset22 + 4]);
    // bottom edge (4,1) should be red
    const offset41 = (4 * 6 + 1) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 0, 255 }, buf[offset41 .. offset41 + 4]);
}

test "drawLine horizontal" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 5 * 1 * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx = @This(){
        .image = undefined,
        .pixel_buffer = buf,
        .width = 5,
        .height = 1,
        .allocator = allocator,
    };

    ctx.drawLine(1, 0, 3, 0, .{ 255, 0, 0, 255 });

    // pixels 1,2,3 should be red
    for (1..4) |x| {
        const offset = x * 4;
        try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 0, 255 }, buf[offset .. offset + 4]);
    }
    // pixel 0 should be zero
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[0..4]);
}

test "drawLine vertical" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 1 * 5 * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx = @This(){
        .image = undefined,
        .pixel_buffer = buf,
        .width = 1,
        .height = 5,
        .allocator = allocator,
    };

    ctx.drawLine(0, 1, 0, 3, .{ 0, 255, 0, 255 });

    for (1..4) |y| {
        const offset = y * 4;
        try testing.expectEqualSlices(u8, &[_]u8{ 0, 255, 0, 255 }, buf[offset .. offset + 4]);
    }
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[0..4]);
}

test "drawLine diagonal" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 4 * 4 * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx = @This(){
        .image = undefined,
        .pixel_buffer = buf,
        .width = 4,
        .height = 4,
        .allocator = allocator,
    };

    ctx.drawLine(0, 0, 3, 3, .{ 0, 0, 255, 255 });

    // diagonal pixels should be blue
    for (0..4) |i| {
        const offset = (i * 4 + i) * 4;
        try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 255, 255 }, buf[offset .. offset + 4]);
    }
    // off-diagonal should be zero
    const offset01 = (0 * 4 + 1) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[offset01 .. offset01 + 4]);
}

test "fill triangle" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 10 * 10 * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx = @This(){
        .image = undefined,
        .pixel_buffer = buf,
        .width = 10,
        .height = 10,
        .allocator = allocator,
    };

    ctx.setFillColor(.{ 255, 0, 0, 255 });
    ctx.moveTo(5, 1);
    ctx.lineTo(1, 8);
    ctx.lineTo(9, 8);
    ctx.closePath();
    ctx.fill();

    // center of triangle (5, 5) should be filled
    const offset55 = (5 * 10 + 5) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 0, 255 }, buf[offset55 .. offset55 + 4]);
    // outside (0, 0) should be empty
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[0..4]);
    // outside (9, 1) should be empty
    const offset19 = (1 * 10 + 9) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[offset19 .. offset19 + 4]);
}

test "stroke path" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 5 * 5 * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx = @This(){
        .image = undefined,
        .pixel_buffer = buf,
        .width = 5,
        .height = 5,
        .allocator = allocator,
    };

    ctx.setStrokeColor(.{ 0, 255, 0, 255 });
    ctx.moveTo(0, 0);
    ctx.lineTo(4, 0);
    ctx.stroke();

    // top row should be green
    for (0..5) |x| {
        const offset = x * 4;
        try testing.expectEqualSlices(u8, &[_]u8{ 0, 255, 0, 255 }, buf[offset .. offset + 4]);
    }
    // second row should be empty
    const offset10 = (1 * 5 + 0) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[offset10 .. offset10 + 4]);
}

const std = @import("std");
const anywin = @import("anywindow");
const Image = @import("image.zig");
const testing = std.testing;
