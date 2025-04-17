const std = @import("std");
const testing = std.testing;

pub const Intensity = u8;

pub const RGBA = packed struct {
    red: Intensity = 0,
    green: Intensity = 0,
    blue: Intensity = 0,
    alpha: Intensity = 0,
};

// size on the Y coordinates
pub const Height = u16;
// size on the X coordinates
pub const Width = u16;
// Y represents vertical coordinates
pub const X = u16;
// X represents horizontal coordinates
pub const Y = u16;

pub const BBox = struct {
    origin: Point,
    height: Height,
    width: Width,

    pub fn containsPoint(self: @This(), point: Point) bool {
        return point.x >= self.origin.x and
            point.x < self.maxWidth() and
            point.y >= self.origin.y and
            point.y < self.maxHeight();
    }

    pub fn maxY(self: @This()) Y {
        return self.origin.y + self.height;
    }

    pub fn maxX(self: @This()) X {
        return self.origin.x + self.width;
    }
    pub fn maxHeight(self: @This()) Height {
        return self.origin.y + self.height;
    }

    pub fn maxWidth(self: @This()) Width {
        return self.origin.x + self.width;
    }

    pub fn internalPoint(self: @This(), point: Point) Point {
        return .{
            .x = point.x - self.origin.x,
            .y = point.y - self.origin.y,
        };
    }

    pub fn overlaps(self: @This(), other: @This()) bool {
        return self.origin.x < other.maxX() and
            other.origin.x < self.maxX() and
            self.origin.y < other.maxY() and
            other.origin.y < self.maxY();
    }
};

test "box overlaps" {
    const bbox0 = BBox{
        .origin = .{
            .x = 2,
            .y = 2,
        },
        .height = 25,
        .width = 25,
    };

    try testing.expect(bbox0.overlaps(.{ .origin = .{ .x = 0, .y = 0 }, .height = 50, .width = 50 }));
    try testing.expect(bbox0.overlaps(.{ .origin = .{ .x = 0, .y = 0 }, .height = 5, .width = 50 }));
    try testing.expect(bbox0.overlaps(.{ .origin = .{ .x = 20, .y = 20 }, .height = 5, .width = 50 }));
    try testing.expect(!bbox0.overlaps(.{ .origin = .{ .x = 28, .y = 28 }, .height = 5, .width = 5 }));
}

test "bbx internal point" {
    const bbox0 = BBox{
        .origin = .{
            .x = 0,
            .y = 0,
        },
        .height = 25,
        .width = 25,
    };

    const point0A = bbox0.internalPoint(.{ .x = 0, .y = 0 });
    try testing.expectEqual(0, point0A.x);
    try testing.expectEqual(0, point0A.y);

    const point0B = bbox0.internalPoint(.{ .x = 12, .y = 12 });
    try testing.expectEqual(12, point0B.x);
    try testing.expectEqual(12, point0B.y);

    const bbox1 = BBox{
        .origin = .{
            .x = 25,
            .y = 25,
        },
        .height = 25,
        .width = 25,
    };

    const point1A = bbox1.internalPoint(.{ .x = 25, .y = 25 });
    try testing.expectEqual(0, point1A.x);
    try testing.expectEqual(0, point1A.y);

    const point1B = bbox1.internalPoint(.{ .x = 26, .y = 26 });
    try testing.expectEqual(1, point1B.x);
    try testing.expectEqual(1, point1B.y);

    const point1C = bbox1.internalPoint(.{ .x = 49, .y = 49 });
    try testing.expectEqual(24, point1C.x);
    try testing.expectEqual(24, point1C.y);
}

test "bbox contains point" {
    const bbox0 = BBox{
        .origin = .{
            .x = 0,
            .y = 0,
        },
        .height = 25,
        .width = 25,
    };

    try testing.expect(bbox0.containsPoint(.{ .x = 0, .y = 0 }));
    try testing.expect(bbox0.containsPoint(.{ .x = 1, .y = 1 }));
    try testing.expect(bbox0.containsPoint(.{ .x = 24, .y = 0 }));
    try testing.expect(bbox0.containsPoint(.{ .x = 0, .y = 24 }));
    try testing.expect(bbox0.containsPoint(.{ .x = 24, .y = 24 }));

    try testing.expect(!bbox0.containsPoint(.{ .x = 1, .y = 25 }));
    try testing.expect(!bbox0.containsPoint(.{ .x = 25, .y = 1 }));
    try testing.expect(!bbox0.containsPoint(.{ .x = 25, .y = 25 }));

    const bbox1 = BBox{
        .origin = .{
            .x = 25,
            .y = 25,
        },
        .height = 25,
        .width = 25,
    };

    try testing.expect(!bbox1.containsPoint(.{ .x = 0, .y = 0 }));
    try testing.expect(!bbox1.containsPoint(.{ .x = 1, .y = 1 }));
    try testing.expect(!bbox1.containsPoint(.{ .x = 24, .y = 0 }));
    try testing.expect(!bbox1.containsPoint(.{ .x = 0, .y = 24 }));
    try testing.expect(!bbox1.containsPoint(.{ .x = 24, .y = 24 }));

    try testing.expect(!bbox1.containsPoint(.{ .x = 1, .y = 25 }));
    try testing.expect(!bbox1.containsPoint(.{ .x = 25, .y = 1 }));

    try testing.expect(bbox1.containsPoint(.{ .x = 25, .y = 25 }));
    try testing.expect(bbox1.containsPoint(.{ .x = 25, .y = 26 }));
    try testing.expect(bbox1.containsPoint(.{ .x = 49, .y = 49 }));

    try testing.expect(!bbox1.containsPoint(.{ .x = 50, .y = 50 }));
}

pub const Point = packed struct {
    x: X,
    y: Y,
};

pub fn indexFromPoint(width: Width, point: Point) usize {
    return point.y * width + point.x;
}

test "find index from point" {
    try testing.expectEqual(0, indexFromPoint(25, .{ .x = 0, .y = 0 }));
    try testing.expectEqual(1, indexFromPoint(25, .{ .x = 1, .y = 0 }));
    try testing.expectEqual(25, indexFromPoint(25, .{ .x = 0, .y = 1 }));
    try testing.expectEqual(26, indexFromPoint(25, .{ .x = 1, .y = 1 }));
    try testing.expectEqual(624, indexFromPoint(25, .{ .x = 24, .y = 24 }));
}
