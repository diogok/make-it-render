pub const Tile = struct {
    /// bbox of the tile
    bbox: BBox,
    /// pixels of the tile
    pixels: []u8,
    /// track if tiles has been changed
    dirty: bool = false,

    pub fn init(
        allocator: std.mem.Allocator,
        bbox: BBox,
    ) !@This() {
        const pixels = try allocator.alloc(u8, bbox.size() * 4);
        for (pixels, 0..) |_, i| {
            pixels[i] = 0;
        }
        return @This(){
            .bbox = bbox,
            .pixels = pixels,
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.pixels);
    }

    /// if the points is contained in this tile, set the color for the pixel
    /// returns true if pixel was set, thus contained. returns false otherwise
    pub fn maybeSetPixel(self: *@This(), point: common.Point, pixel: []const u8) bool {
        std.debug.assert(pixel.len % 4 == 0);
        if (self.bbox.containsPoint(point)) {
            self.setPixel(point, pixel);
            return true;
        }
        return false;
    }

    fn setPixel(self: *@This(), point: common.Point, pixel: []const u8) void {
        std.debug.assert(pixel.len % 4 == 0);
        const fixed_point = self.bbox.internalPoint(point);
        const index = indexFromPoint(self.bbox.width, fixed_point);
        std.mem.copyForwards(u8, self.pixels[index .. index + 4], pixel);
        self.dirty = true;
    }
};

fn indexFromPoint(width: common.Width, point: common.Point) usize {
    return @abs(point.y) * width * 4 + @abs(point.x) * 4;
}

test "find index from point" {
    try testing.expectEqual(0, indexFromPoint(25, .{ .x = 0, .y = 0 }));
    try testing.expectEqual(4, indexFromPoint(25, .{ .x = 1, .y = 0 }));
    try testing.expectEqual(100, indexFromPoint(25, .{ .x = 0, .y = 1 }));
    try testing.expectEqual(104, indexFromPoint(25, .{ .x = 1, .y = 1 }));
    try testing.expectEqual(2496, indexFromPoint(25, .{ .x = 24, .y = 24 }));
}

test "Basic tiles" {
    const bbox = BBox{
        .width = 5,
        .height = 5,
        .x = 0,
        .y = 0,
    };
    var tile0 = try Tile.init(testing.allocator, bbox);
    defer testing.allocator.free(tile0.pixels);

    try testing.expect(tile0.maybeSetPixel(.{ .x = 1, .y = 1 }, &[_]u8{ 10, 0, 0, 1 }));
    try testing.expect(tile0.maybeSetPixel(.{ .x = 4, .y = 4 }, &[_]u8{ 20, 0, 0, 1 }));
    try testing.expect(!tile0.maybeSetPixel(.{ .x = 5, .y = 1 }, &[_]u8{ 20, 0, 0, 1 }));
    try testing.expect(!tile0.maybeSetPixel(.{ .x = 0, .y = 5 }, &[_]u8{ 20, 0, 0, 1 }));

    const expected = &[_]u8{
        0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
        0, 0, 0, 0, 10, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
        0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
        0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
        0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 20, 0, 0, 1,
    };

    try testing.expectEqualSlices(u8, expected, tile0.pixels);
}

test "Basic tiles 2" {
    const bbox = BBox{
        .width = 5,
        .height = 5,
        .x = 5,
        .y = 5,
    };
    var tile0 = try Tile.init(testing.allocator, bbox);
    defer testing.allocator.free(tile0.pixels);

    try testing.expect(!tile0.maybeSetPixel(.{ .x = 1, .y = 1 }, &[_]u8{ 10, 0, 0, 1 }));
    try testing.expect(!tile0.maybeSetPixel(.{ .x = 4, .y = 4 }, &[_]u8{ 20, 0, 0, 1 }));
    try testing.expect(!tile0.maybeSetPixel(.{ .x = 5, .y = 1 }, &[_]u8{ 20, 0, 0, 1 }));
    try testing.expect(!tile0.maybeSetPixel(.{ .x = 0, .y = 5 }, &[_]u8{ 20, 0, 0, 1 }));
    try testing.expect(tile0.maybeSetPixel(.{ .x = 5, .y = 5 }, &[_]u8{ 30, 0, 0, 1 }));
    try testing.expect(tile0.maybeSetPixel(.{ .x = 6, .y = 6 }, &[_]u8{ 40, 0, 0, 1 }));

    const expected = &[_]u8{
        30, 0, 0, 1, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0,  0, 0, 0, 40, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0,  0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0,  0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0,  0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };

    try testing.expectEqualSlices(u8, expected, tile0.pixels);
}

pub const TileList = std.ArrayList(Tile);

pub const TileMap = struct {
    allocator: std.mem.Allocator,
    tile_size: common.Size,
    tiles: TileList,

    pub fn init(allocator: std.mem.Allocator, tile_size: common.Size) @This() {
        return @This(){
            .allocator = allocator,
            .tiles = TileList{},
            .tile_size = tile_size,
        };
    }

    pub fn deinit(self: *@This()) void {
        for (self.tiles.items) |*tile| {
            tile.deinit(self.allocator);
        }
        self.tiles.deinit(self.allocator);
    }

    pub fn setPixels(self: *@This(), bbox: BBox, pixels: []const u8) !void {
        std.debug.assert(pixels.len % 4 == 0);
        std.debug.assert(bbox.size() * 4 == pixels.len);

        var y: i16 = 0;
        while (y < bbox.height) : (y += 1) {
            var x: i16 = 0;
            while (x < bbox.width) : (x += 1) {
                const out_point: common.Point = .{ .x = bbox.x + x, .y = bbox.y + y };
                const in_point: common.Point = .{ .x = x, .y = y };
                const index: usize = indexFromPoint(bbox.width, in_point);
                const pixel: []const u8 = pixels[index .. index + 4];
                if (!std.mem.eql(u8, &[_]u8{ 0, 0, 0, 0 }, pixel)) {
                    try self.setPixel(out_point, pixel);
                }
            }
        }
    }

    pub fn setPixel(self: *@This(), point: common.Point, pixel: []const u8) !void {
        std.debug.assert(pixel.len == 4);

        for (self.tiles.items) |*tile| {
            if (tile.maybeSetPixel(point, pixel)) {
                return;
            }
        }

        const origin = self.tileOriginForPoint(point);
        const bbox = BBox{
            .x = origin.x,
            .y = origin.y,
            .height = self.tile_size.height,
            .width = self.tile_size.width,
        };
        var tile = try Tile.init(self.allocator, bbox);
        tile.setPixel(point, pixel);

        try self.tiles.append(self.allocator, tile);
    }

    pub fn iterator(self: *@This(), bbox: ?BBox) TileMapIterator {
        return TileMapIterator{
            .bbox = bbox,
            .tiles = self.tiles.items,
        };
    }

    fn tileOriginForPoint(self: *@This(), point: common.Point) common.Point {
        const a = @divFloor(point.x, @as(i16, @intCast(self.tile_size.height)));
        const x = (a * @as(i16, @intCast(self.tile_size.height)));

        const b = @divFloor(point.y, @as(i16, @intCast(self.tile_size.width)));
        const y = (b * @as(i16, @intCast(self.tile_size.width)));

        return common.Point{
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

pub const TileMapIterator = struct {
    tiles: []Tile,
    bbox: ?BBox,

    pos: usize = 0,

    pub fn next(self: *@This()) ?*Tile {
        while (self.pos < self.tiles.len) {
            defer self.pos += 1;
            var tile = self.tiles[self.pos];
            if (self.bbox) |bbox| {
                if (tile.bbox.overlaps(bbox)) {
                    return &self.tiles[self.pos];
                }
            } else {
                return &self.tiles[self.pos];
            }
        }
        return null;
    }
};

test "Basic tile map" {
    var tiles = TileMap.init(testing.allocator, .{ .width = 5, .height = 5 });
    defer tiles.deinit();

    try tiles.setPixel(.{ .x = 1, .y = 1 }, &[_]u8{ 99, 0, 0, 1 });
    try tiles.setPixel(.{ .x = 18, .y = 18 }, &[_]u8{ 250, 0, 0, 1 });

    var iter = tiles.iterator(.{
        .x = 2,
        .y = 2,
        .height = 100,
        .width = 100,
    });

    const expected0 = &[_]u8{
        0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 99, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    const tile0 = iter.next();
    try testing.expect(tile0 != null);
    try testing.expectEqualSlices(u8, expected0, tile0.?.pixels);

    const expected1 = &[_]u8{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 250, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0,
    };
    const tile1 = iter.next();
    try testing.expect(tile1 != null);
    try testing.expectEqualSlices(u8, expected1, tile1.?.pixels);

    const tile2 = iter.next();
    try testing.expect(tile2 == null);
}

test "Draw pixels tile map" {
    var tiles = TileMap.init(testing.allocator, .{ .width = 2, .height = 2 });
    defer tiles.deinit();

    const pixels = &[_]u8{
        0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 99, 0, 0, 1, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0,
    };
    const pixels_box = BBox{
        .x = 0,
        .y = 0,
        .width = 5,
        .height = 5,
    };
    try tiles.setPixels(pixels_box, pixels);

    var iter = tiles.iterator(pixels_box);

    const expected0 = &[_]u8{
        0, 0, 0, 0, 0,  0, 0, 0,
        0, 0, 0, 0, 99, 0, 0, 1,
    };

    const tile0 = iter.next();
    try testing.expect(tile0 != null);
    try testing.expectEqualSlices(u8, expected0, tile0.?.pixels);

    const expected1 = &[_]u8{
        0, 0, 0, 0, 0, 0,  0, 0,
        0, 0, 0, 0, 0, 10, 0, 1,
    };
    const tile1 = iter.next();
    try testing.expect(tile1 != null);
    try testing.expectEqualSlices(u8, expected1, tile1.?.pixels);

    const tile2 = iter.next();
    try testing.expect(tile2 == null);
}

const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
const BBox = @import("bbox.zig").BBox;

const log = std.log.scoped(.canvas);
