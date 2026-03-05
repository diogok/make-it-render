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
    quad_to: struct { cx: f32, cy: f32, x: f32, y: f32 },
    bezier_to: struct { c1x: f32, c1y: f32, c2x: f32, c2y: f32, x: f32, y: f32 },
    arc: struct { cx: f32, cy: f32, r: f32, start: f32, end: f32, ccw: bool },
};

const Point = struct {
    x: f32,
    y: f32,

    fn lerp(a: Point, b: Point, t: f32) Point {
        return .{
            .x = a.x + (b.x - a.x) * t,
            .y = a.y + (b.y - a.y) * t,
        };
    }

    fn distToLine(p: Point, a: Point, b: Point) f32 {
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const len_sq = dx * dx + dy * dy;
        if (len_sq < epsilon_sq) {
            const ex = p.x - a.x;
            const ey = p.y - a.y;
            return @sqrt(ex * ex + ey * ey);
        }
        const cross = @abs((p.x - a.x) * dy - (p.y - a.y) * dx);
        return cross / @sqrt(len_sq);
    }
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
        self.pixel_buffer[offset] = color[0];
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
        self.pixel_buffer[offset] = 0;
        self.pixel_buffer[offset + 1] = 0;
        self.pixel_buffer[offset + 2] = 0;
        self.pixel_buffer[offset + 3] = 0;
        return;
    }

    self.pixel_buffer[offset] = @intFromFloat((src_r * sa + dst_r * da * (1.0 - sa)) / out_a);
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
pub fn moveTo(self: *@This(), x: f32, y: f32) !void {
    try self.path.append(self.allocator, .{ .move_to = .{ .x = x, .y = y } });
}

/// Add a line segment from the current point to (x, y).
pub fn lineTo(self: *@This(), x: f32, y: f32) !void {
    try self.path.append(self.allocator, .{ .line_to = .{ .x = x, .y = y } });
}

/// Close the current path by drawing a line back to the starting point.
pub fn closePath(self: *@This()) !void {
    try self.path.append(self.allocator, .close_path);
}

/// Add a quadratic bezier curve from the current point to (x, y) with control point (cx, cy).
pub fn quadraticCurveTo(self: *@This(), cx: f32, cy: f32, x: f32, y: f32) !void {
    try self.path.append(self.allocator, .{ .quad_to = .{ .cx = cx, .cy = cy, .x = x, .y = y } });
}

/// Add a cubic bezier curve from the current point to (x, y) with control points (c1x, c1y) and (c2x, c2y).
pub fn bezierCurveTo(self: *@This(), c1x: f32, c1y: f32, c2x: f32, c2y: f32, x: f32, y: f32) !void {
    try self.path.append(self.allocator, .{ .bezier_to = .{ .c1x = c1x, .c1y = c1y, .c2x = c2x, .c2y = c2y, .x = x, .y = y } });
}

/// Add an arc to the path. Angles are in radians.
pub fn arc(self: *@This(), cx: f32, cy: f32, r: f32, start_angle: f32, end_angle: f32, ccw: bool) !void {
    try self.path.append(self.allocator, .{ .arc = .{ .cx = cx, .cy = cy, .r = r, .start = start_angle, .end = end_angle, .ccw = ccw } });
}

/// Add an arc between two tangent lines defined by (current→x1,y1) and (x1,y1→x2,y2) with radius r.
pub fn arcTo(self: *@This(), x1: f32, y1: f32, x2: f32, y2: f32, r: f32) !void {
    // Need current point to compute the tangent arc
    const cur = self.currentPoint() orelse return;

    // Vectors from x1,y1 to cur and x1,y1 to x2,y2
    const d1x = cur.x - x1;
    const d1y = cur.y - y1;
    const d2x = x2 - x1;
    const d2y = y2 - y1;

    const len1 = @sqrt(d1x * d1x + d1y * d1y);
    const len2 = @sqrt(d2x * d2x + d2y * d2y);
    if (len1 < epsilon or len2 < epsilon) return;

    // Unit vectors
    const u1x = d1x / len1;
    const u1y = d1y / len1;
    const u2x = d2x / len2;
    const u2y = d2y / len2;

    // Cross product to determine winding
    const cross = u1x * u2y - u1y * u2x;
    if (@abs(cross) < epsilon) {
        // Lines are parallel, just line to x1,y1
        try self.lineTo(x1, y1);
        return;
    }

    // Half-angle between the two vectors
    const dot = u1x * u2x + u1y * u2y;
    const half_angle = std.math.acos(std.math.clamp(dot, -1.0, 1.0)) / 2.0;
    const tan_half = @tan(half_angle);
    if (@abs(tan_half) < epsilon) return;

    // Distance from corner to tangent points
    const dist = r / tan_half;

    // Tangent points
    const t1x = x1 + u1x * dist;
    const t1y = y1 + u1y * dist;
    const t2x = x1 + u2x * dist;
    const t2y = y1 + u2y * dist;

    // Arc center
    const ccw = cross > 0;
    const nx: f32 = if (ccw) -u1y else u1y;
    const ny: f32 = if (ccw) u1x else -u1x;
    const acx = t1x + nx * r;
    const acy = t1y + ny * r;

    // Angles
    const start_angle = std.math.atan2(t1y - acy, t1x - acx);
    const end_angle = std.math.atan2(t2y - acy, t2x - acx);

    // Line to the first tangent point, then arc
    try self.lineTo(t1x, t1y);
    try self.arc(acx, acy, r, start_angle, end_angle, ccw);
}

fn currentPoint(self: *const @This()) ?Point {
    var cur: ?Point = null;
    var sub_start: ?Point = null;
    for (self.path.items) |cmd| {
        switch (cmd) {
            .move_to => |p| {
                cur = p;
                sub_start = p;
            },
            .line_to => |p| cur = p,
            .quad_to => |q| cur = .{ .x = q.x, .y = q.y },
            .bezier_to => |b| cur = .{ .x = b.x, .y = b.y },
            .arc => |a| cur = .{ .x = a.cx + a.r * @cos(a.end), .y = a.cy + a.r * @sin(a.end) },
            .close_path => cur = sub_start,
        }
    }
    return cur;
}

const epsilon = 1e-6;
const epsilon_sq = 1e-12;
const arc_gap_threshold = 0.01;
const max_arc_segment = std.math.pi / 8.0; // tau / 16

const flatten_tolerance = 0.25;
const flatten_max_depth = 20;

fn flattenPath(self: *const @This()) !std.ArrayList(PathCommand) {
    var out: std.ArrayList(PathCommand) = .empty;
    errdefer out.deinit(self.allocator);
    var cur: Point = .{ .x = 0, .y = 0 };
    var sub_start: Point = .{ .x = 0, .y = 0 };

    for (self.path.items) |cmd| {
        switch (cmd) {
            .move_to => |p| {
                try out.append(self.allocator, .{ .move_to = p });
                cur = p;
                sub_start = p;
            },
            .line_to => |p| {
                try out.append(self.allocator, .{ .line_to = p });
                cur = p;
            },
            .close_path => {
                try out.append(self.allocator, .close_path);
                cur = sub_start;
            },
            .quad_to => |q| {
                // Promote quadratic to cubic: CP1 = lerp(start, ctrl, 2/3), CP2 = lerp(end, ctrl, 2/3)
                const ctrl: Point = .{ .x = q.cx, .y = q.cy };
                const end: Point = .{ .x = q.x, .y = q.y };
                const c1 = Point.lerp(cur, ctrl, 2.0 / 3.0);
                const c2 = Point.lerp(end, ctrl, 2.0 / 3.0);
                try flattenCubic(&out, self.allocator, cur, c1, c2, end, 0);
                cur = end;
            },
            .bezier_to => |b| {
                const c1: Point = .{ .x = b.c1x, .y = b.c1y };
                const c2: Point = .{ .x = b.c2x, .y = b.c2y };
                const end: Point = .{ .x = b.x, .y = b.y };
                try flattenCubic(&out, self.allocator, cur, c1, c2, end, 0);
                cur = end;
            },
            .arc => |a| {
                cur = try flattenArc(&out, self.allocator, a, cur);
            },
        }
    }
    return out;
}

fn flattenCubic(out: *std.ArrayList(PathCommand), allocator: std.mem.Allocator, p0: Point, p1: Point, p2: Point, p3: Point, depth: u32) !void {
    if (depth >= flatten_max_depth) {
        try out.append(allocator, .{ .line_to = p3 });
        return;
    }

    // Flatness test: max distance of control points to the chord
    const d1 = Point.distToLine(p1, p0, p3);
    const d2 = Point.distToLine(p2, p0, p3);
    if (@max(d1, d2) <= flatten_tolerance) {
        try out.append(allocator, .{ .line_to = p3 });
        return;
    }

    // De Casteljau split at t=0.5
    const m01 = Point.lerp(p0, p1, 0.5);
    const m12 = Point.lerp(p1, p2, 0.5);
    const m23 = Point.lerp(p2, p3, 0.5);
    const m012 = Point.lerp(m01, m12, 0.5);
    const m123 = Point.lerp(m12, m23, 0.5);
    const mid = Point.lerp(m012, m123, 0.5);

    try flattenCubic(out, allocator, p0, m01, m012, mid, depth + 1);
    try flattenCubic(out, allocator, mid, m123, m23, p3, depth + 1);
}

fn flattenArc(out: *std.ArrayList(PathCommand), allocator: std.mem.Allocator, a: anytype, cur: Point) !Point {
    const tau = 2.0 * std.math.pi;

    var sweep = a.end - a.start;
    if (a.ccw) {
        if (sweep > 0) sweep -= tau;
        if (sweep < -tau) sweep = -tau;
    } else {
        if (sweep < 0) sweep += tau;
        if (sweep > tau) sweep = tau;
    }

    if (@abs(sweep) < epsilon) return cur;

    // Move/line to arc start point
    const start_pt: Point = .{
        .x = a.cx + a.r * @cos(a.start),
        .y = a.cy + a.r * @sin(a.start),
    };

    // If current point differs from arc start, line to it
    const dx = cur.x - start_pt.x;
    const dy = cur.y - start_pt.y;
    if (dx * dx + dy * dy > arc_gap_threshold) {
        try out.append(allocator, .{ .line_to = start_pt });
    }

    // Split into segments of at most tau/16 radians
    const max_seg = max_arc_segment;
    const n_segs_f = @ceil(@abs(sweep) / max_seg);
    const n_segs: u32 = @intFromFloat(@max(1.0, n_segs_f));
    const seg_angle = sweep / @as(f32, @floatFromInt(n_segs));

    var angle = a.start;
    var prev: Point = start_pt;

    for (0..n_segs) |_| {
        const next_angle = angle + seg_angle;

        // Cubic bezier approximation for this arc segment
        const alpha = 4.0 / 3.0 * @tan(seg_angle / 4.0);

        const cos0 = @cos(angle);
        const sin0 = @sin(angle);
        const cos1 = @cos(next_angle);
        const sin1 = @sin(next_angle);

        const p0 = prev;
        const p3: Point = .{
            .x = a.cx + a.r * cos1,
            .y = a.cy + a.r * sin1,
        };
        const c1: Point = .{
            .x = p0.x + alpha * a.r * (-sin0),
            .y = p0.y + alpha * a.r * cos0,
        };
        const c2: Point = .{
            .x = p3.x - alpha * a.r * (-sin1),
            .y = p3.y - alpha * a.r * cos1,
        };

        try flattenCubic(out, allocator, p0, c1, c2, p3, 0);

        prev = p3;
        angle = next_angle;
    }

    return prev;
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
pub fn stroke(self: *@This()) !void {
    const color = self.stroke_color;
    var flat = try self.flattenPath();
    defer flat.deinit(self.allocator);

    var start: ?Point = null;
    var current: ?Point = null;

    for (flat.items) |cmd| {
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
            else => {},
        }
    }
}

/// Fill the current path using scanline rasterization with even-odd rule.
pub fn fill(self: *@This()) !void {
    const color = self.fill_color;

    var flat = try self.flattenPath();
    defer flat.deinit(self.allocator);

    // Collect edges from flattened path
    var edges: std.ArrayList(Edge) = .empty;
    defer edges.deinit(self.allocator);

    var start: ?Point = null;
    var current: ?Point = null;

    for (flat.items) |cmd| {
        switch (cmd) {
            .move_to => |p| {
                start = p;
                current = p;
            },
            .line_to => |p| {
                if (current) |cur| {
                    try addEdge(&edges, self.allocator, cur, p);
                }
                current = p;
            },
            .close_path => {
                if (current) |cur| {
                    if (start) |s| {
                        try addEdge(&edges, self.allocator, cur, s);
                    }
                }
                current = start;
            },
            else => {},
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
                try intersections.append(self.allocator, x_intersect);
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

fn addEdge(edges: *std.ArrayList(Edge), allocator: std.mem.Allocator, p0: Point, p1: Point) !void {
    // Skip horizontal edges
    if (p0.y == p1.y) return;
    try edges.append(allocator, .{
        .x0 = p0.x,
        .y0 = p0.y,
        .x1 = p1.x,
        .y1 = p1.y,
    });
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
    try ctx.moveTo(5, 1);
    try ctx.lineTo(1, 8);
    try ctx.lineTo(9, 8);
    try ctx.closePath();
    try ctx.fill();

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
    try ctx.moveTo(0, 0);
    try ctx.lineTo(4, 0);
    try ctx.stroke();

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
    buf[0] = 10;
    buf[1] = 20;
    buf[2] = 30;
    buf[3] = 255;

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
    buf[0] = 10;
    buf[1] = 20;
    buf[2] = 30;
    buf[3] = 255;

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
    buf[0] = 255;
    buf[1] = 255;
    buf[2] = 255;
    buf[3] = 255;

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
    buf[0] = 255;
    buf[1] = 255;
    buf[2] = 255;
    buf[3] = 255;

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

test "quadraticCurveTo produces smooth curve" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 20 * 20 * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = 20,
        .height = 20,
        .allocator = allocator,
    };
    defer ctx.path.deinit(allocator);

    ctx.setFillColor(.{ 255, 0, 0, 255 });
    try ctx.moveTo(0, 10);
    try ctx.quadraticCurveTo(10, 0, 19, 10);
    try ctx.lineTo(19, 19);
    try ctx.lineTo(0, 19);
    try ctx.closePath();
    try ctx.fill();

    // Interior pixel under the curve should be filled
    const offset = (15 * 20 + 10) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 0, 255 }, buf[offset .. offset + 4]);
    // Pixel above the curve peak should be empty
    const offset_top = (1 * 20 + 10) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[offset_top .. offset_top + 4]);
}

test "bezierCurveTo S-curve" {
    const allocator = testing.allocator;
    const buf = try allocator.alloc(u8, 30 * 20 * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = 30,
        .height = 20,
        .allocator = allocator,
    };
    defer ctx.path.deinit(allocator);

    ctx.setFillColor(.{ 0, 255, 0, 255 });
    try ctx.moveTo(0, 10);
    try ctx.bezierCurveTo(10, 0, 20, 19, 29, 10);
    try ctx.lineTo(29, 19);
    try ctx.lineTo(0, 19);
    try ctx.closePath();
    try ctx.fill();

    // Bottom center should be filled
    const offset = (18 * 30 + 15) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 255, 0, 255 }, buf[offset .. offset + 4]);
}

test "arc draws circle" {
    const allocator = testing.allocator;
    const size: u32 = 40;
    const buf = try allocator.alloc(u8, size * size * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = size,
        .height = size,
        .allocator = allocator,
    };
    defer ctx.path.deinit(allocator);

    ctx.setFillColor(.{ 0, 0, 255, 255 });
    try ctx.arc(20, 20, 15, 0, 2.0 * std.math.pi, false);
    try ctx.closePath();
    try ctx.fill();

    // Center should be filled
    const center = (20 * size + 20) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 255, 255 }, buf[center .. center + 4]);
    // Corner (0,0) should be empty
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[0..4]);
    // Corner (39,0) should be empty
    const tr = (0 * size + 39) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[tr .. tr + 4]);
    // Corner (39,39) should be empty
    const br = (39 * size + 39) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[br .. br + 4]);
}

test "arcTo rounded corner" {
    const allocator = testing.allocator;
    const size: u32 = 30;
    const buf = try allocator.alloc(u8, size * size * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = size,
        .height = size,
        .allocator = allocator,
    };
    defer ctx.path.deinit(allocator);

    ctx.setFillColor(.{ 255, 255, 0, 255 });
    // Draw a rounded corner: right edge → corner → bottom edge with radius 10
    try ctx.moveTo(25, 0);
    try ctx.lineTo(25, 10);
    try ctx.arcTo(25, 25, 10, 25, 10);
    try ctx.lineTo(0, 25);
    try ctx.lineTo(0, 0);
    try ctx.closePath();
    try ctx.fill();

    // Interior point should be filled
    const offset = (5 * size + 5) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 255, 0, 255 }, buf[offset .. offset + 4]);
}

test "arc partial quarter circle" {
    const allocator = testing.allocator;
    const size: u32 = 30;
    const buf = try allocator.alloc(u8, size * size * 4);
    defer allocator.free(buf);
    @memset(buf, 0);

    var ctx: @This() = .{
        .flush_target = undefined,
        .pixel_buffer = buf,
        .width = size,
        .height = size,
        .allocator = allocator,
    };
    defer ctx.path.deinit(allocator);

    ctx.setFillColor(.{ 255, 0, 255, 255 });
    // Quarter circle: 0 to pi/2, centered at (15,15), radius 12
    try ctx.moveTo(15, 15);
    try ctx.arc(15, 15, 12, 0, std.math.pi / 2.0, false);
    try ctx.closePath();
    try ctx.fill();

    // Point in the quarter (right-down quadrant) should be filled
    const offset = (20 * size + 22) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 255, 255 }, buf[offset .. offset + 4]);
    // Point in the opposite quadrant (left-up) should be empty
    const offset2 = (5 * size + 5) * 4;
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, buf[offset2 .. offset2 + 4]);
}

const std = @import("std");
const anywin = @import("anywindow");
const textz = @import("text");
const testing = std.testing;
