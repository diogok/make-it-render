const std = @import("std");

pub const IDGenerator = struct {
    base: u32,
    inc: u32,
    max: u32,

    last: u32 = 0,

    pub fn init(resource_id_base: u32, resource_id_mask: u32) @This() {
        const imask: i32 = @bitCast(resource_id_mask);
        const inc = imask & -(imask);

        return .{
            .base = resource_id_base,
            .max = resource_id_mask,
            .inc = @bitCast(inc),
        };
    }

    pub fn genID(self: *@This()) !u32 {
        if (self.last == self.max) {
            // TODO: request new range of IDs
            return error.NoMoreIDs;
        } else {
            self.last += self.inc;
        }
        const xid: u32 = self.last | self.base;
        return xid;
    }
};
