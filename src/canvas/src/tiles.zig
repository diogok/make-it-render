const std = @import("std");
const testing = std.testing;

const types = @import("types.zig");

pub const Tile = struct {
    allocator: std.mem.Allocator,

    area: types.BBox,
    // pixels of the tile
    pixels: []types.RGBA,

    pub fn init(
        allocator: std.mem.Allocator,
        area: types.BBox,
    ) !@This() {
        const pixels = try allocator.alloc(types.RGBA, area.size.width * area.size.height);
        for (pixels, 0..) |_, i| {
            pixels[i] = std.mem.zeroes(types.RGBA);
        }
        return @This(){
            .allocator = allocator,
            .area = area,
            .pixels = pixels,
        };
    }

    pub fn deinit(self: @This()) void {
        self.allocator.free(self.pixels);
    }

    /// if the points is contained in this tile, set the color for the pixel
    /// returns true if pixel was set, thus contained. returns false otherwise
    pub fn maybeSetPixel(self: @This(), point: types.Point, color: types.RGBA) bool {
        if (self.containsPoint(point)) {
            self.setPixel(point, color);
            return true;
        }
        return false;
    }

    fn containsPoint(self: @This(), point: types.Point) bool {
        return self.area.containsPoint(point);
    }

    fn overlaps(self: @This(), area: types.BBox) bool {
        return self.area.overlaps(area);
    }

    fn setPixel(self: @This(), point: types.Point, color: types.RGBA) void {
        const fixed_point = self.area.internalPoint(point);
        const index = indexFromPoint(self.area.size.width, fixed_point);
        self.pixels[index] = color;
    }
};

fn indexFromPoint(width: types.Width, point: types.Point) usize {
    return point.y * width + point.x;
}

test "find index from point" {
    try testing.expectEqual(0, indexFromPoint(25, .{ .x = 0, .y = 0 }));
    try testing.expectEqual(1, indexFromPoint(25, .{ .x = 1, .y = 0 }));
    try testing.expectEqual(25, indexFromPoint(25, .{ .x = 0, .y = 1 }));
    try testing.expectEqual(26, indexFromPoint(25, .{ .x = 1, .y = 1 }));
    try testing.expectEqual(624, indexFromPoint(25, .{ .x = 24, .y = 24 }));
}
test "Basic tiles" {
    const bbox = types.BBox{
        .size = .{
            .width = 5,
            .height = 5,
        },
        .origin = .{
            .x = 0,
            .y = 0,
        },
    };
    const tile0 = try Tile.init(testing.allocator, bbox);
    defer tile0.deinit();

    try testing.expect(tile0.maybeSetPixel(.{ .x = 1, .y = 1 }, .{ .red = 10 }));
    try testing.expect(tile0.maybeSetPixel(.{ .x = 4, .y = 4 }, .{ .red = 20 }));
    try testing.expect(!tile0.maybeSetPixel(.{ .x = 5, .y = 1 }, .{ .red = 20 }));
    try testing.expect(!tile0.maybeSetPixel(.{ .x = 0, .y = 5 }, .{ .red = 20 }));

    const expected = &[_]types.RGBA{
        .{}, .{},            .{}, .{}, .{},
        .{}, .{ .red = 10 }, .{}, .{}, .{},
        .{}, .{},            .{}, .{}, .{},
        .{}, .{},            .{}, .{}, .{},
        .{}, .{},            .{}, .{}, .{ .red = 20 },
    };

    try testing.expectEqualSlices(types.RGBA, expected, tile0.pixels);
}

test "Basic tiles 2" {
    const bbox = types.BBox{
        .size = .{
            .width = 5,
            .height = 5,
        },
        .origin = .{
            .x = 5,
            .y = 5,
        },
    };
    const tile0 = try Tile.init(testing.allocator, bbox);
    defer tile0.deinit();

    try testing.expect(!tile0.maybeSetPixel(.{ .x = 1, .y = 1 }, .{ .red = 10 }));
    try testing.expect(!tile0.maybeSetPixel(.{ .x = 4, .y = 4 }, .{ .red = 20 }));
    try testing.expect(!tile0.maybeSetPixel(.{ .x = 5, .y = 1 }, .{ .red = 20 }));
    try testing.expect(!tile0.maybeSetPixel(.{ .x = 0, .y = 5 }, .{ .red = 20 }));
    try testing.expect(tile0.maybeSetPixel(.{ .x = 5, .y = 5 }, .{ .red = 30 }));
    try testing.expect(tile0.maybeSetPixel(.{ .x = 6, .y = 6 }, .{ .red = 40 }));

    const expected = &[_]types.RGBA{
        .{ .red = 30 }, .{},            .{}, .{}, .{},
        .{},            .{ .red = 40 }, .{}, .{}, .{},
        .{},            .{},            .{}, .{}, .{},
        .{},            .{},            .{}, .{}, .{},
        .{},            .{},            .{}, .{}, .{},
    };

    try testing.expectEqualSlices(types.RGBA, expected, tile0.pixels);
}

pub const TileList = std.ArrayList(Tile);

pub const TileMap = struct {
    allocator: std.mem.Allocator,
    tileSize: types.Size,
    tiles: TileList,

    pub fn init(allocator: std.mem.Allocator, tileSize: types.Size) @This() {
        return @This(){
            .allocator = allocator,
            .tiles = TileList.init(allocator),
            .tileSize = tileSize,
        };
    }

    pub fn deinit(self: *@This()) void {
        for (self.tiles.items) |tile| {
            tile.deinit();
        }
        self.tiles.deinit();
    }

    pub fn setPixel(self: *@This(), point: types.Point, color: types.RGBA) !void {
        for (self.tiles.items) |tile| {
            if (tile.maybeSetPixel(point, color)) {
                return;
            }
        }

        const origin = self.tileOriginForPoint(point);
        const bbox = types.BBox{ .size = self.tileSize, .origin = origin };
        const tile = try Tile.init(self.allocator, bbox);
        tile.setPixel(point, color);

        try self.tiles.append(tile);
    }

    pub fn areaIterator(self: *@This(), area: types.BBox) TileAreaIterator {
        return TileAreaIterator{
            .bbox = area,
            .tiles = self.tiles.items,
        };
    }

    fn tileOriginForPoint(self: *@This(), point: types.Point) types.Point {
        const a = @divFloor(point.x, self.tileSize.height);
        const x = (a * self.tileSize.height);

        const b = @divFloor(point.y, self.tileSize.width);
        const y = (b * self.tileSize.width);

        return types.Point{
            .x = x,
            .y = y,
        };
    }
};

test "find origin" {
    var tiles = TileMap.init(testing.allocator, .{ .width = 5, .height = 5 });
    defer tiles.deinit();

    const p0 = tiles.tileOriginForPoint(.{ .x = 0, .y = 0 });
    try testing.expectEqual(0, p0.x);
    try testing.expectEqual(0, p0.y);

    const p1 = tiles.tileOriginForPoint(.{ .x = 1, .y = 1 });
    try testing.expectEqual(0, p1.x);
    try testing.expectEqual(0, p1.y);

    const p2 = tiles.tileOriginForPoint(.{ .x = 5, .y = 0 });
    try testing.expectEqual(5, p2.x);
    try testing.expectEqual(0, p2.y);

    const p3 = tiles.tileOriginForPoint(.{ .x = 0, .y = 6 });
    try testing.expectEqual(0, p3.x);
    try testing.expectEqual(5, p3.y);

    const p4 = tiles.tileOriginForPoint(.{ .x = 12, .y = 9 });
    try testing.expectEqual(10, p4.x);
    try testing.expectEqual(5, p4.y);
}

pub const TileAreaIterator = struct {
    tiles: []const Tile,
    bbox: types.BBox,

    pos: usize = 0,

    pub fn next(self: *@This()) ?Tile {
        while (self.pos < self.tiles.len) : (self.pos += 1) {
            if (self.tiles[self.pos].overlaps(self.bbox)) {
                const tile = self.tiles[self.pos];
                self.pos += 1;
                return tile;
            }
        }
        return null;
    }
};

test "Basic tile map" {
    var tiles = TileMap.init(testing.allocator, .{ .width = 5, .height = 5 });
    defer tiles.deinit();

    try tiles.setPixel(.{ .x = 1, .y = 1 }, .{ .red = 99 });
    try tiles.setPixel(.{ .x = 18, .y = 18 }, .{ .red = 250 });

    var iter = tiles.areaIterator(.{
        .origin = .{ .x = 2, .y = 2 },
        .size = .{
            .height = 100,
            .width = 100,
        },
    });

    const expected0 = &[_]types.RGBA{
        .{}, .{},            .{}, .{}, .{},
        .{}, .{ .red = 99 }, .{}, .{}, .{},
        .{}, .{},            .{}, .{}, .{},
        .{}, .{},            .{}, .{}, .{},
        .{}, .{},            .{}, .{}, .{},
    };

    const tile0 = iter.next();
    try testing.expect(tile0 != null);
    try testing.expectEqualSlices(types.RGBA, expected0, tile0.?.pixels);

    const expected1 = &[_]types.RGBA{
        .{}, .{}, .{}, .{},             .{},
        .{}, .{}, .{}, .{},             .{},
        .{}, .{}, .{}, .{},             .{},
        .{}, .{}, .{}, .{ .red = 250 }, .{},
        .{}, .{}, .{}, .{},             .{},
    };
    const tile1 = iter.next();
    try testing.expect(tile1 != null);
    try testing.expectEqualSlices(types.RGBA, expected1, tile1.?.pixels);

    const tile2 = iter.next();
    try testing.expect(tile2 == null);
}
