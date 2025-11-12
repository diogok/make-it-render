pub const Canvas = struct {
    allocator: std.mem.Allocator,
    layers: std.AutoHashMapUnmanaged(usize,TileMap),

    pub fn init(allocator: std.mem.Allocator) @This() {
        const layers = std.AutoHashMapUnmanaged(usize,TileMap);
        return @This(){
            .layers = layers,
            .allocator = allocator,
        };
    }

    pub fn getLayer(self: *@This(), n: usize) @This() {
    	if(self.layers.get(n)) |layer| {
    		return layer;
    	} else {
    		
    	}
    }
};

const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
const BBox = @import("bbox.zig").BBox;
const TileMap = @import("bbox.zig").TileMap;

const log = std.log.scoped(.canvas);
