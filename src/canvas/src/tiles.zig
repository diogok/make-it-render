pub const Tile = struct {
    area: BBox,
    // pixels of the tile
    pixels: []types.RGBA,

    pub fn init(
        allocator: std.mem.Allocator,
        area: BBox,
    ) !@This() {
        const pixels = try allocator.alloc(types.RGBA, @as(usize, @intCast(area.size.width)) * @as(usize, @intCast(area.size.height)));
        for (pixels, 0..) |_, i| {
            pixels[i] = std.mem.zeroes(types.RGBA);
        }
        return @This(){
            .area = area,
            .pixels = pixels,
        };
    }

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.pixels);
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

    fn overlaps(self: @This(), area: BBox) bool {
        return self.area.overlaps(area);
    }

    fn setPixel(self: @This(), point: types.Point, color: types.RGBA) void {
        const fixed_point = self.area.internalPoint(point);
        const index = indexFromPoint(self.area.size.width, fixed_point);
        self.pixels[index] = color;
    }
};

fn indexFromPoint(width: types.Width, point: types.Point) usize {
    return @abs(point.y) * width + @abs(point.x);
}

test "find index from point" {
    try testing.expectEqual(0, indexFromPoint(25, .{ .x = 0, .y = 0 }));
    try testing.expectEqual(1, indexFromPoint(25, .{ .x = 1, .y = 0 }));
    try testing.expectEqual(25, indexFromPoint(25, .{ .x = 0, .y = 1 }));
    try testing.expectEqual(26, indexFromPoint(25, .{ .x = 1, .y = 1 }));
    try testing.expectEqual(624, indexFromPoint(25, .{ .x = 24, .y = 24 }));
}

test "Basic tiles" {
    const bbox = BBox{
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
    defer testing.allocator.free(tile0.pixels);

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
    const bbox = BBox{
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
    defer testing.allocator.free(tile0.pixels);

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
    tile_size: types.Size,
    tiles: TileList,

    pub fn init(allocator: std.mem.Allocator, tile_size: types.Size) @This() {
        return @This(){
            .allocator = allocator,
            .tiles = TileList{},
            .tile_size = tile_size,
        };
    }

    pub fn deinit(self: *@This()) void {
        for (self.tiles.items) |tile| {
            tile.deinit(self.allocator);
        }
        self.tiles.deinit(self.allocator);
    }

    pub fn setPixels(self: *@This(), area: BBox, pixels: []const types.RGBA) !void {
        var y: i16 = 0;
        while (y < area.size.height) : (y += 1) {
            var x: i16 = 0;
            while (x < area.size.width) : (x += 1) {
                const point = types.Point{ .x = x, .y = y };
                const index = indexFromPoint(area.size.width, point);
                const pixel = pixels[index];
                if (pixel.green > 0 or pixel.red > 0 or pixel.blue > 0 or pixel.alpha > 0) {
                    try self.setPixel(point, pixel);
                }
            }
        }
    }

    pub fn setPixel(self: *@This(), point: types.Point, color: types.RGBA) !void {
        for (self.tiles.items) |tile| {
            if (tile.maybeSetPixel(point, color)) {
                return;
            }
        }

        const origin = self.tileOriginForPoint(point);
        const bbox = BBox{ .size = self.tile_size, .origin = origin };
        const tile = try Tile.init(self.allocator, bbox);
        tile.setPixel(point, color);

        try self.tiles.append(self.allocator, tile);
    }

    pub fn areaIterator(self: *@This(), area: BBox) TileAreaIterator {
        return TileAreaIterator{
            .bbox = area,
            .tiles = self.tiles.items,
        };
    }

    fn tileOriginForPoint(self: *@This(), point: types.Point) types.Point {
        const a = @divFloor(point.x, @as(i16, @intCast(self.tile_size.height)));
        const x = (a * @as(i16, @intCast(self.tile_size.height)));

        const b = @divFloor(point.y, @as(i16, @intCast(self.tile_size.width)));
        const y = (b * @as(i16, @intCast(self.tile_size.width)));

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
    bbox: BBox,

    pos: usize = 0,

    pub fn next(self: *@This()) ?Tile {
        while (self.pos < self.tiles.len) : (self.pos += 1) {
            if (self.tiles[self.pos].overlaps(self.bbox) or self.bbox.isEmpty()) {
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

test "Draw pixels tile map" {
    var tiles = TileMap.init(testing.allocator, .{ .width = 2, .height = 2 });
    defer tiles.deinit();

    const pixels = &[_]types.RGBA{
        .{}, .{},            .{}, .{},              .{},
        .{}, .{ .red = 99 }, .{}, .{},              .{},
        .{}, .{},            .{}, .{},              .{},
        .{}, .{},            .{}, .{ .green = 10 }, .{},
        .{}, .{},            .{}, .{},              .{},
    };
    const pixels_box = BBox{
        .origin = .{
            .x = 0,
            .y = 0,
        },
        .size = .{
            .width = 5,
            .height = 5,
        },
    };
    try tiles.setPixels(pixels_box, pixels);

    var iter = tiles.areaIterator(pixels_box);

    const expected0 = &[_]types.RGBA{
        .{}, .{},
        .{}, .{ .red = 99 },
    };

    const tile0 = iter.next();
    try testing.expect(tile0 != null);
    try testing.expectEqualSlices(types.RGBA, expected0, tile0.?.pixels);

    const expected1 = &[_]types.RGBA{
        .{}, .{},
        .{}, .{ .green = 10 },
    };
    const tile1 = iter.next();
    try testing.expect(tile1 != null);
    try testing.expectEqualSlices(types.RGBA, expected1, tile1.?.pixels);

    const tile2 = iter.next();
    try testing.expect(tile2 == null);
}

const std = @import("std");
const testing = std.testing;

const types = @import("types.zig");
const BBox = @import("bbox.zig").BBox;
