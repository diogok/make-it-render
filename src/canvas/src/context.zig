//! 2D drawing context inspired by the HTML5 Canvas API.
//! Provides immediate-mode drawing into a pixel buffer with fill, stroke,
//! path operations and text rendering. Obtain a Context from an Image
//! via `getContext()`, draw into it, then call `flush()` to push the
//! pixels to the underlying image.

/// Type-erased flush target. Holds a pointer to the destination surface
/// and a function that writes an RGBA pixel buffer into it.
pub const FlushTarget = struct {
    ptr: *anyopaque,
    flushFn: *const fn (*anyopaque, []const u8) anyerror!void,

    pub fn flush(self: @This(), pixels: []const u8) anyerror!void {
        return self.flushFn(self.ptr, pixels);
    }
};

flush_target: FlushTarget,
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

/// Create a new drawing context, allocating an RGBA pixel buffer.
/// `flush_target` is called by `flush()` to push the buffer to its destination.
pub fn init(flush_target: FlushTarget, width: u32, height: u32, allocator: std.mem.Allocator) !@This() {
    const size = width * height * 4;
    const pixel_buffer = try allocator.alloc(u8, size);
    @memset(pixel_buffer, 0);

    return .{
        .flush_target = flush_target,
        .pixel_buffer = pixel_buffer,
        .width = width,
        .height = height,
        .allocator = allocator,
    };
}

/// Free the pixel buffer and path storage.
pub fn deinit(self: *@This()) void {
    self.allocator.free(self.pixel_buffer);
    self.path.deinit(self.allocator);
}

/// Set the RGBA color used by fill operations.
pub fn setFillColor(self: *@This(), color: [4]u8) void {
    self.fill_color = color;
}

/// Set the RGBA color used by stroke operations.
pub fn setStrokeColor(self: *@This(), color: [4]u8) void {
    self.stroke_color = color;
}

/// Set the line width in pixels for stroke operations.
pub fn setLineWidth(self: *@This(), width: u16) void {
    self.line_width = width;
}

fn setPixel(self: *@This(), x: i32, y: i32, color: [4]u8) void {
    if (x < 0 or y < 0) return;
    const ux: u32 = @intCast(x);
    const uy: u32 = @intCast(y);
    if (ux >= self.width or uy >= self.height) return;
    const offset = (uy * self.width + ux) * 4;

    const src_a = color[3];

    // Fast path: fully opaque, just overwrite
    if (src_a == 255) {
        self.pixel_buffer[offset]     = color[0];
        self.pixel_buffer[offset + 1] = color[1];
        self.pixel_buffer[offset + 2] = color[2];
        self.pixel_buffer[offset + 3] = 255;
        return;
    }

    // Fully transparent: nothing to draw
    if (src_a == 0) return;

    // Alpha blend: source-over compositing
    const dst_r: f32 = @floatFromInt(self.pixel_buffer[offset]);
    const dst_g: f32 = @floatFromInt(self.pixel_buffer[offset + 1]);
    const dst_b: f32 = @floatFromInt(self.pixel_buffer[offset + 2]);
    const dst_a: f32 = @floatFromInt(self.pixel_buffer[offset + 3]);

    const src_r: f32 = @floatFromInt(color[0]);
    const src_g: f32 = @floatFromInt(color[1]);
    const src_b: f32 = @floatFromInt(color[2]);
    const sa: f32 = @as(f32, @floatFromInt(src_a)) / 255.0;
    const da: f32 = dst_a / 255.0;

    const out_a = sa + da * (1.0 - sa);
    if (out_a == 0.0) {
        self.pixel_buffer[offset]     = 0;
        self.pixel_buffer[offset + 1] = 0;
        self.pixel_buffer[offset + 2] = 0;
        self.pixel_buffer[offset + 3] = 0;
        return;
    }

    self.pixel_buffer[offset]     = @intFromFloat((src_r * sa + dst_r * da * (1.0 - sa)) / out_a);
    self.pixel_buffer[offset + 1] = @intFromFloat((src_g * sa + dst_g * da * (1.0 - sa)) / out_a);
    self.pixel_buffer[offset + 2] = @intFromFloat((src_b * sa + dst_b * da * (1.0 - sa)) / out_a);
    self.pixel_buffer[offset + 3] = @intFromFloat(out_a * 255.0);
}

fn fillRectInternal(self: *@This(), x: i32, y: i32, w: u32, h: u32, color: [4]u8) void {
    const x0: u32 = if (x < 0) 0 else @intCast(@min(x, @as(i32, @intCast(self.width))));
    const y0: u32 = if (y < 0) 0 else @intCast(@min(y, @as(i32, @intCast(self.height))));
    const x1: u32 = if (x < 0) @min(w -| @as(u32, @intCast(-x)), self.width) else @min(x0 + w, self.width);
    const y1: u32 = if (y < 0) @min(h -| @as(u32, @intCast(-y)), self.height) else @min(y0 + h, self.height);

    var cy = y0;
    while (cy < y1) : (cy += 1) {
        var cx = x0;
        while (cx < x1) : (cx += 1) {
            self.setPixel(@intCast(cx), @intCast(cy), color);
        }
    }
}

/// Fill a rectangle with the current fill color.
pub fn fillRect(self: *@This(), x: i32, y: i32, w: u32, h: u32) void {
    self.fillRectInternal(x, y, w, h, self.fill_color);
}

/// Clear a rectangle to transparent black.
pub fn clearRect(self: *@This(), x: i32, y: i32, w: u32, h: u32) void {
    const x0: u32 = if (x < 0) 0 else @intCast(@min(x, @as(i32, @intCast(self.width))));
    const y0: u32 = if (y < 0) 0 else @intCast(@min(y, @as(i32, @intCast(self.height))));
    const x1: u32 = if (x < 0) @min(w -| @as(u32, @intCast(-x)), self.width) else @min(x0 + w, self.width);
    const y1: u32 = if (y < 0) @min(h -| @as(u32, @intCast(-y)), self.height) else @min(y0 + h, self.height);

    var cy = y0;
    while (cy < y1) : (cy += 1) {
        const row_start = (cy * self.width + x0) * 4;
        const row_end = (cy * self.width + x1) * 4;
        @memset(self.pixel_buffer[row_start..row_end], 0);
    }
}

/// Draw a rectangle outline with the current stroke color and line width.
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

/// Start a new path, discarding any existing path commands.
pub fn beginPath(self: *@This()) void {
    self.path.clearRetainingCapacity();
}

/// Move the current point without drawing.
pub fn moveTo(self: *@This(), x: f32, y: f32) void {
    self.path.append(self.allocator, .{ .move_to = .{ .x = x, .y = y } }) catch {};
}

/// Add a line segment from the current point to (x, y).
pub fn lineTo(self: *@This(), x: f32, y: f32) void {
    self.path.append(self.allocator, .{ .line_to = .{ .x = x, .y = y } }) catch {};
}

/// Close the current path by drawing a line back to the starting point.
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

/// Stroke the current path using Bresenham's line algorithm.
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

/// Fill the current path using scanline rasterization with even-odd rule.
pub fn fill(self: *@This()) void {
    const color = self.fill_color;

    // Collect edges from path
    var edges: std.ArrayList(Edge) = .empty;
    defer edges.deinit(self.allocator);

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
                    addEdge(&edges, self.allocator, cur, p);
                }
                current = p;
            },
            .close_path => {
                if (current) |cur| {
                    if (start) |s| {
                        addEdge(&edges, self.allocator, cur, s);
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
    var intersections: std.ArrayList(f32) = .empty;
    defer intersections.deinit(self.allocator);

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

/// Draw an RGBA pixel buffer at the given position.
/// Pixels are composited using source-over alpha blending via setPixel.
pub fn drawImage(self: *@This(), pixels: []const u8, width: u16, height: u16, x: i32, y: i32) void {
    for (0..height) |row| {
        for (0..width) |col| {
            const i = (row * width + col) * 4;
            self.setPixel(
                x + @as(i32, @intCast(col)),
                y + @as(i32, @intCast(row)),
                .{ pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3] },
            );
        }
    }
}

/// Draw a 1-bit bitmap at the given position using the current fill color.
pub fn putImage(self: *@This(), bitmap: []const u1, bw: u16, bh: u16, x: i32, y: i32) void {
    for (0..bh) |row| {
        for (0..bw) |col| {
            if (bitmap[row * bw + col] == 1) {
                self.setPixel(x + @as(i32, @intCast(col)), y + @as(i32, @intCast(row)), self.fill_color);
            }
        }
    }
}

/// Measure text dimensions without rendering.
pub fn measureText(_: *@This(), fonts: []const textz.common.Font, text: []const u8) textz.text.TextMetrics {
    return textz.measure(fonts, text);
}

/// Draw text at the given position using the current fill color.
pub fn fillText(self: *@This(), fonts: []const textz.common.Font, text: []const u8, x: i32, y: i32) void {
    var bitmap = textz.render(self.allocator, fonts, text) catch return;
    defer bitmap.deinit();

    self.putImage(bitmap.bitmap, bitmap.width, bitmap.height, x, y);
}

/// Write the pixel buffer to the underlying image.
pub fn flush(self: *@This()) !void {
    try self.flush_target.flush(self.pixel_buffer);
}

const Edge = struct {
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
};

fn addEdge(edges: *std.ArrayList(Edge), allocator: std.mem.Allocator, p0: Point, p1: Point) void {
    // Skip horizontal edges
    if (p0.y == p1.y) return;
    edges.append(allocator, .{
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

    var ctx: @This() = .{
        .flush_target = undefined,
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

    var ctx: @This() = .{
        .flush_target = undefined,
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

    var ctx: @This() = .{
        .flush_target = undefined,
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

    var ctx: @This() = .{
        .flush_target = undefined,
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

    var ctx: @This() = .{
        .flush_target = undefined,
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

    var ctx: @This() = .{
        .flush_target = undefined,
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

    var ctx: @This() = .{
        .flush_target = undefined,
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

    var ctx: @This() = .{
        .flush_target = undefined,
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

    var ctx: @This() = .{
        .flush_target = undefined,
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

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = 10,
        .height = 10,
        .allocator = allocator,
    };
    defer ctx.path.deinit(allocator);

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

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = 5,
        .height = 5,
        .allocator = allocator,
    };
    defer ctx.path.deinit(allocator);

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

test "setPixel opaque src over transparent dst" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 1 * 1 * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = 1,
        .height = 1,
        .allocator = allocator,
    };

    ctx.setPixel(0, 0, .{ 200, 100, 50, 255 });
    try testing.expectEqualSlices(u8, &[_]u8{ 200, 100, 50, 255 }, buf[0..4]);
}

test "setPixel opaque src over opaque dst uses fast path" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 1 * 1 * 4);
    defer allocator.free(buf);
    buf[0] = 10; buf[1] = 20; buf[2] = 30; buf[3] = 255;

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = 1,
        .height = 1,
        .allocator = allocator,
    };

    ctx.setPixel(0, 0, .{ 200, 100, 50, 255 });
    try testing.expectEqualSlices(u8, &[_]u8{ 200, 100, 50, 255 }, buf[0..4]);
}

test "setPixel transparent src leaves dst unchanged" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 1 * 1 * 4);
    defer allocator.free(buf);
    buf[0] = 10; buf[1] = 20; buf[2] = 30; buf[3] = 255;

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = 1,
        .height = 1,
        .allocator = allocator,
    };

    ctx.setPixel(0, 0, .{ 255, 0, 0, 0 });
    try testing.expectEqualSlices(u8, &[_]u8{ 10, 20, 30, 255 }, buf[0..4]);
}

test "setPixel 50% alpha red over opaque white gives pinkish result" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 1 * 1 * 4);
    defer allocator.free(buf);
    // white background
    buf[0] = 255; buf[1] = 255; buf[2] = 255; buf[3] = 255;

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = 1,
        .height = 1,
        .allocator = allocator,
    };

    ctx.setPixel(0, 0, .{ 255, 0, 0, 128 });

    // out_a = 128/255 + 1*(1 - 128/255) = 1.0  → alpha 255
    try testing.expectEqual(@as(u8, 255), buf[3]);
    // red channel: (255*(128/255) + 255*1*(1-128/255)) / 1.0 = 255 → 255
    try testing.expectEqual(@as(u8, 255), buf[0]);
    // green channel: (0*(128/255) + 255*1*(1-128/255)) / 1.0 ≈ 127
    try testing.expect(buf[1] >= 126 and buf[1] <= 128);
    // blue channel same as green
    try testing.expect(buf[2] >= 126 and buf[2] <= 128);
}

test "setPixel 50% alpha red over transparent dst" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 1 * 1 * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = 1,
        .height = 1,
        .allocator = allocator,
    };

    ctx.setPixel(0, 0, .{ 255, 0, 0, 128 });

    // out_a = 128/255 + 0*(1 - 128/255) = 128/255  → ~128
    try testing.expect(buf[3] >= 127 and buf[3] <= 129);
    // out_r = (255*(128/255) + 0) / (128/255) ≈ 255 (f32 rounding may yield 254 or 255)
    try testing.expect(buf[0] >= 254);
    // out_g = out_b = 0
    try testing.expectEqual(@as(u8, 0), buf[1]);
    try testing.expectEqual(@as(u8, 0), buf[2]);
}

test "drawImage 2x2 opaque red onto transparent buffer" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 4 * 4 * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = 4,
        .height = 4,
        .allocator = allocator,
    };

    const pixels = [_]u8{
        255, 0, 0, 255, 255, 0, 0, 255,
        255, 0, 0, 255, 255, 0, 0, 255,
    };
    ctx.drawImage(&pixels, 2, 2, 1, 1);

    // (1,1) should be red
    const offset11 = (1 * 4 + 1) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 0, 255 }, buf[offset11 .. offset11 + 4]);
    // (2,2) should be red
    const offset22 = (2 * 4 + 2) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 0, 255 }, buf[offset22 .. offset22 + 4]);
    // (0,0) should be zero
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[0..4]);
}

test "drawImage 50% alpha over opaque white" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 1 * 1 * 4);
    defer allocator.free(buf);
    buf[0] = 255; buf[1] = 255; buf[2] = 255; buf[3] = 255;

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = 1,
        .height = 1,
        .allocator = allocator,
    };

    const pixels = [_]u8{ 255, 0, 0, 128 };
    ctx.drawImage(&pixels, 1, 1, 0, 0);

    try testing.expectEqual(@as(u8, 255), buf[3]);
    try testing.expectEqual(@as(u8, 255), buf[0]);
    try testing.expect(buf[1] >= 126 and buf[1] <= 128);
    try testing.expect(buf[2] >= 126 and buf[2] <= 128);
}

test "drawImage at negative offset clips without crash" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 2 * 2 * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = 2,
        .height = 2,
        .allocator = allocator,
    };

    const pixels = [_]u8{
        0, 255, 0, 255, 0, 255, 0, 255,
        0, 255, 0, 255, 0, 255, 0, 255,
    };
    ctx.drawImage(&pixels, 2, 2, -1, -1);

    // Only (0,0) should have the bottom-right pixel of the image
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 255, 0, 255 }, buf[0..4]);
    // (1,0) should be zero
    const offset10 = (0 * 2 + 1) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[offset10 .. offset10 + 4]);
}

test "drawImage larger than canvas clips without crash" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 2 * 2 * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = 2,
        .height = 2,
        .allocator = allocator,
    };

    const pixels = [_]u8{
        255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255,
        255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255,
        255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255,
    };
    ctx.drawImage(&pixels, 3, 3, 0, 0);

    // (0,0) should be red
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 0, 255 }, buf[0..4]);
    // (1,0) should be green
    const offset10 = (0 * 2 + 1) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 255, 0, 255 }, buf[offset10 .. offset10 + 4]);
    // (1,1) should be green
    const offset11 = (1 * 2 + 1) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 255, 0, 255 }, buf[offset11 .. offset11 + 4]);
}

const std = @import("std");
const anywin = @import("anywindow");
const textz = @import("text");
const testing = std.testing;
