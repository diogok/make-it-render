//! Event source adapter for use with the generic event loop.
//! Wraps a WindowManager to conform to the poll/stop interface.

wm: *@import("../root.zig").WindowManager,
running: bool = true,

pub const Event = @import("common.zig").Event;

pub fn poll(self: *@This()) ?Event {
    while (self.running) {
        const event = self.wm.receive() catch return null;
        switch (event) {
            .nop => continue,
            else => return event,
        }
    }
    return null;
}

pub fn stop(self: *@This()) void {
    self.running = false;
}
