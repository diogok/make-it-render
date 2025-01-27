//! X11 expecte it's client to create some IDs
//! Here we have a function to generate it.

const std = @import("std");

const log = std.log.scoped(.x11);

/// Struct to control ID generation.
/// IDs are somewhat sequencial and finite,
/// so we need to keep track of it.
pub const XID = struct {
    base: u32,
    inc: u32,
    max: u32,

    last: u32 = 0,

    /// Initial values are obtained from Setup.
    pub fn init(resource_id_base: u32, resource_id_mask: u32) @This() {
        const imask: i32 = @bitCast(resource_id_mask);
        const inc = imask & -(imask);

        return .{
            .base = resource_id_base,
            .max = resource_id_mask,
            .inc = @bitCast(inc),
        };
    }

    /// Generate next ID.
    pub fn genID(self: *@This()) !u32 {
        if (self.last == self.max) {
            // TODO: request new range of IDs
            return error.NoMoreIDs;
        } else {
            self.last += self.inc;
        }
        return self.last | self.base;
    }
};
