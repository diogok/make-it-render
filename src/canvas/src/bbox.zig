pub const BBox = struct {
    height: common.Height = 0,
    width: common.Width = 0,
    x: common.X = 0,
    y: common.Y = 0,

    /// Checks is a point in global coordinates is in this BBox.
    pub fn containsPoint(self: @This(), point: common.Point) bool {
        return point.x >= self.x and
            point.x < self.maxX() and
            point.y >= self.y and
            point.y < self.maxY();
    }

    /// Return max Y coordinate that fits this BBox.
    /// This is the limit in global Y axis.
    pub fn maxY(self: @This()) common.Y {
        return self.y + @as(i16, @intCast(self.height));
    }

    /// Return max Y coordinate that fits this BBox.
    /// This is the limit in global X axis.
    pub fn maxX(self: @This()) common.X {
        return self.x + @as(i16, @intCast(self.width));
    }

    /// Converts a global/absolute point to a relative point.
    /// This returns the internal coordinates for an absolute point.
    pub fn internalPoint(self: @This(), point: common.Point) common.Point {
        return .{
            .x = point.x - self.x,
            .y = point.y - self.y,
        };
    }

    /// Checks if this overlaps with another bbox.
    pub fn overlaps(self: @This(), other: @This()) bool {
        return self.x < other.maxX() and
            other.x < self.maxX() and
            self.y < other.maxY() and
            other.y < self.maxY();
    }

    /// Total number of pixels that fit.
    pub fn size(self: @This()) usize {
        return @as(usize, @intCast(self.width)) * @as(usize, @intCast(self.height));
    }
};

test "box overlaps" {
    const bbox0 = BBox{
        .x = 2,
        .y = 2,
        .height = 25,
        .width = 25,
    };

    try testing.expect(bbox0.overlaps(.{ .x = 0, .y = 0, .height = 50, .width = 50 }));
    try testing.expect(bbox0.overlaps(.{ .x = 0, .y = 0, .height = 5, .width = 50 }));
    try testing.expect(bbox0.overlaps(.{ .x = 20, .y = 20, .height = 5, .width = 50 }));
    try testing.expect(!bbox0.overlaps(.{ .x = 28, .y = 28, .height = 5, .width = 5 }));
}

test "bbx internal point" {
    const bbox0 = BBox{
        .x = 0,
        .y = 0,
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
        .x = 25,
        .y = 25,
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
        .x = 0,
        .y = 0,
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
        .x = 25,
        .y = 25,
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

const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
