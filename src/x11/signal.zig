const std = @import("std");
const builtin = @import("builtin");

const log = std.log.scoped(.signal);

pub var defaultSignal = Signal.init();

pub const Signal = struct {
    value: std.atomic.Atomic(u32),

    pub fn init() @This() {
        var value = std.atomic.Atomic(u32).init(0);
        return @This(){
            .value = value,
        };
    }

    pub fn signal(self: *@This()) void {
        _ = self.value.swap(1, .Monotonic);
        std.Thread.Futex.wake(&self.value, 2);
    }

    pub fn received(self: *@This()) bool {
        return self.value.load(.Monotonic) != 0;
    }

    pub fn wait(self: *@This()) void {
        std.Thread.Futex.wait(&self.value, 0);
    }

    pub fn registerSignal(_: *@This(), signal) !void {
        if (builtin.os.tag == .linux) {
            try std.os.sigaction(std.os.SIG.INT, &std.os.Sigaction{
                .handler = .{ .handler = stop },
                .mask = std.os.empty_sigset,
                .flags = 0,
            }, null);
        }
    }

    pub fn registerSigInt(_: *@This()) !void {
        if (builtin.os.tag == .linux) {
            self.registerSignal(std.os.SIG.INT);
        }
    }
};

fn handler(_: c_int) callconv(.C) void {
    log.warn("SIGINT", .{});
    defaultSignal.signal();
}
