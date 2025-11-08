pub const BBox = struct {
    origin: types.Point,
    size: types.Size,

    pub const empty = BBox{
        .origin = .{ .x = 0, .y = 0 },
        .size = .{ .width = 0, .height = 0 },
    };

    pub fn containsPoint(self: @This(), point: types.Point) bool {
        return point.x >= self.origin.x and
            point.x < self.maxX() and
            point.y >= self.origin.y and
            point.y < self.maxY();
    }

    pub fn maxY(self: @This()) types.Y {
        return self.origin.y + @as(i16, @intCast(self.size.height));
    }

    pub fn maxX(self: @This()) types.X {
        return self.origin.x + @as(i16, @intCast(self.size.width));
    }

    pub fn internalPoint(self: @This(), point: types.Point) types.Point {
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

    pub fn isEmpty(self: @This()) bool {
        return self.origin.x == 0 and self.origin.y == 0 and self.size.height == 0 and self.size.width == 0;
    }
};

test "box overlaps" {
    const bbox0 = BBox{
        .origin = .{
            .x = 2,
            .y = 2,
        },
        .size = .{
            .height = 25,
            .width = 25,
        },
    };

    try testing.expect(bbox0.overlaps(.{ .origin = .{ .x = 0, .y = 0 }, .size = .{ .height = 50, .width = 50 } }));
    try testing.expect(bbox0.overlaps(.{ .origin = .{ .x = 0, .y = 0 }, .size = .{ .height = 5, .width = 50 } }));
    try testing.expect(bbox0.overlaps(.{ .origin = .{ .x = 20, .y = 20 }, .size = .{ .height = 5, .width = 50 } }));
    try testing.expect(!bbox0.overlaps(.{ .origin = .{ .x = 28, .y = 28 }, .size = .{ .height = 5, .width = 5 } }));
}

test "bbx internal point" {
    const bbox0 = BBox{
        .origin = .{
            .x = 0,
            .y = 0,
        },
        .size = .{
            .height = 25,
            .width = 25,
        },
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
        .size = .{
            .height = 25,
            .width = 25,
        },
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
        .size = .{
            .height = 25,
            .width = 25,
        },
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
        .size = .{
            .height = 25,
            .width = 25,
        },
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

const std = @import("std");
const testing = std.testing;

const types = @import("types.zig");
