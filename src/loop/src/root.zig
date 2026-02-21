pub const EventLoop = @import("loop.zig").EventLoop;
pub const eventLoop = @import("loop.zig").eventLoop;
pub const ThreadSafeQueue = @import("queue.zig").ThreadSafeQueue;

test {
    _ = @import("loop.zig");
    _ = @import("queue.zig");
}
