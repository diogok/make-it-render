const std = @import("std");
const types = @import("types.zig");

pub const TileHeight: types.Height = 64;
pub const TileWidth: types.Width = 64;

pub const Tile = struct {
    area: types.BBox,
    data: []types.RGBA,
};

pub const TileList = std.ArrayList(Tile);

pub const TileMap = struct {
    allocator: std.mem.Allocator,
    tiles: TileList,

    pub fn init(allocator: std.mem.Allocator) @This() {
        return @This(){
            .allocator = allocator,
            .tiles = TileList.init(allocator),
        };
    }

    pub fn setPixel(self: *@This(), x: types.X, y: types.Y, data: types.RGBA) !void {
        const maybe_tile = self.findTile(x, y);
        if (maybe_tile) |tile| {
            // TODO: normalize pixel...
            tile.setPixel(x, y, data);
        }

        const point = startOfTile(.{ .x = x, .y = y });
        const tiles = try self.allocator.alloc(types.RGBA, TileHeight * TileWidth);
        const tile = Tile{
            .area = .{
                .x = point.x,
                .y = point.y,
                .height = TileHeight,
                .width = TileWidth,
            },
            .tiles = tiles,
        };
        self.tiles.append(tile);
    }

    fn findTile(self: *@This(), x: isize, y: isize) ?*Tile {
        for (self.tiles.items) |tile| {
            if (bboxContainsPoint(tile.area, x, y)) {
                return tile;
            }
        }
        return null;
    }
};

pub fn startOfTile(pt: types.Point) types.Point {
    const a = @floor(pt.x / TileWidth);
    const x = (a * TileWidth) + a;

    const b = @floor(pt.y / TileHeight);
    const y = (b * TileHeight) + b;

    return types.Point{
        .x = x,
        .y = y,
    };
}

pub fn findCoordinateIndex(bbox: types.BBox, x: types.X, y: types.Y) ?usize {
    const position = y * bbox.width + x;
    if (position > 0 and x < bbox.X and y <= bbox.Y) {
        return @abs(position);
    }
    return null;
}

pub fn bboxContainsPoint(bbox: types.BBox, x: types.X, y: types.Y) bool {
    return x >= bbox.x and x <= bbox.x + bbox.width and y >= bbox.y and y <= bbox.y + bbox.height;
}
