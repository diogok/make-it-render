pub const WindowManager = switch (builtin.os.tag) {
    .linux => x11.WindowManager,
    .windows => windows.WindowManager,
    else => @compileError("platform not supported"),
};

pub const Window = switch (builtin.os.tag) {
    .linux => x11.Window,
    .windows => windows.Window,
    else => @compileError("platform not supported"),
};

pub const PlatformImage = switch (builtin.os.tag) {
    .linux => x11.Image,
    .windows => windows.Image,
    else => @compileError("platform not supported"),
};

pub const Image = @import("image.zig");

/// Event source adapter for use with the generic event loop.
/// Wraps a WindowManager to conform to the poll/stop interface.
pub const EventSource = struct {
    wm: *WindowManager,
    running: bool = true,

    pub const Event = common.Event;

    pub fn poll(self: *@This()) ?common.Event {
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
};

test {
    _ = Image;
}

test "init" {
    var wm = WindowManager.init(testing.allocator) catch |err| switch (err) {
        error.WouldBlock, error.ConnectionRefused, error.FileNotFound => return,
        else => return err,
    };
    defer wm.deinit();
}

const std = @import("std");
const testing = std.testing;

const builtin = @import("builtin");

const x11 = @import("x11.zig");
const windows = @import("windows.zig");

const common = @import("common.zig");
