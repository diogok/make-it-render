const std = @import("std");
const ThreadSafeQueue = @import("queue.zig").ThreadSafeQueue;

/// Comptime-generic event loop.
///
/// `Sources` is the type of a struct whose fields are pointers to sources:
///   .{ .window = &window_source, .gamepad = &gamepad_source }
///
/// Each source must provide:
///   - `pub const Event = ...;`
///   - `pub fn poll(self: *S) ?Event` — blocks until next event, null = shutdown
///   - Optionally: `pub fn stop(self: *S) void`
pub fn eventLoop(sources: anytype) EventLoop(@TypeOf(sources)) {
    return EventLoop(@TypeOf(sources)).init(sources);
}

pub fn EventLoop(Sources: type) type {
    const source_fields = @typeInfo(Sources).@"struct".fields;

    // Build enum tag type
    const TagEnum = @Type(.{
        .@"enum" = .{
            .tag_type = std.math.IntFittingRange(0, source_fields.len - 1),
            .fields = comptime blk: {
                var fields: [source_fields.len]std.builtin.Type.EnumField = undefined;
                for (source_fields, 0..) |field, i| {
                    fields[i] = .{
                        .name = field.name,
                        .value = i,
                    };
                }
                break :blk &fields;
            },
            .decls = &.{},
            .is_exhaustive = true,
        },
    });

    // Build tagged union of all source events
    const Event = @Type(.{
        .@"union" = .{
            .layout = .auto,
            .tag_type = TagEnum,
            .fields = comptime blk: {
                var fields: [source_fields.len]std.builtin.Type.UnionField = undefined;
                for (source_fields, 0..) |field, i| {
                    const SourcePtr = field.type;
                    const Source = @typeInfo(SourcePtr).pointer.child;
                    fields[i] = .{
                        .name = field.name,
                        .type = Source.Event,
                        .alignment = @alignOf(Source.Event),
                    };
                }
                break :blk &fields;
            },
            .decls = &.{},
        },
    });

    return struct {
        sources: Sources,
        queue: ThreadSafeQueue(Event) = .{},
        threads: [source_fields.len]?std.Thread = [_]?std.Thread{null} ** source_fields.len,
        active_sources: std.atomic.Value(u32) = std.atomic.Value(u32).init(source_fields.len),

        const Self = @This();

        /// The generated tagged union of all source events.
        pub const EventType = Event;

        pub fn init(sources: Sources) Self {
            return .{ .sources = sources };
        }

        /// Spawn one polling thread per source.
        pub fn start(self: *Self) !void {
            inline for (source_fields, 0..) |field, i| {
                self.threads[i] = try std.Thread.spawn(.{}, pollSource(field.name), .{
                    self,
                    @field(self.sources, field.name),
                });
            }
        }

        /// Block until the next event from any source.
        /// Returns null when all sources have shut down and the queue is drained.
        pub fn receive(self: *Self) ?Event {
            return self.queue.receive();
        }

        /// Signal all sources to stop (if they support it).
        pub fn stop(self: *Self) void {
            inline for (source_fields) |field| {
                const source = @field(self.sources, field.name);
                const Source = @typeInfo(@TypeOf(source)).pointer.child;
                if (@hasDecl(Source, "stop")) {
                    source.stop();
                }
            }
        }

        /// Join all threads and close the queue. Call after stop().
        pub fn deinit(self: *Self) void {
            self.queue.close();
            for (&self.threads) |*maybe_thread| {
                if (maybe_thread.*) |thread| {
                    thread.join();
                    maybe_thread.* = null;
                }
            }
        }

        fn pollSource(comptime field_name: []const u8) fn (*Self, anytype) void {
            return struct {
                fn run(self: *Self, source: anytype) void {
                    while (source.poll()) |event| {
                        self.queue.push(@unionInit(Event, field_name, event));
                    }
                    // Last source done → close queue to unblock receive
                    if (self.active_sources.fetchSub(1, .seq_cst) == 1) {
                        self.queue.close();
                    }
                }
            }.run;
        }
    };
}

test "comptime union generation" {
    const SourceA = struct {
        pub const Event = enum { ping };
        pub fn poll(_: *@This()) ?Event {
            return null;
        }
    };
    const SourceB = struct {
        pub const Event = struct { value: u32 };
        pub fn poll(_: *@This()) ?Event {
            return null;
        }
    };

    var a = SourceA{};
    var b = SourceB{};

    const Loop = EventLoop(@TypeOf(.{ .a = &a, .b = &b }));

    const info = @typeInfo(Loop.EventType);
    try std.testing.expectEqual(2, info.@"union".fields.len);
}

test "single source lifecycle" {
    const CountSource = struct {
        remaining: u32 = 3,
        mutex: std.Thread.Mutex = .{},

        pub const Event = u32;

        pub fn poll(self: *@This()) ?Event {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.remaining == 0) return null;
            self.remaining -= 1;
            return self.remaining;
        }
    };

    var src = CountSource{};
    var ev_loop = EventLoop(@TypeOf(.{ .counter = &src })).init(.{ .counter = &src });
    try ev_loop.start();

    var count: u32 = 0;
    while (ev_loop.receive()) |event| {
        switch (event) {
            .counter => |_| count += 1,
        }
    }

    try std.testing.expectEqual(3, count);
    ev_loop.deinit();
}

test "multiple sources" {
    const AlphaSource = struct {
        sent: bool = false,
        mutex: std.Thread.Mutex = .{},

        pub const Event = u8;

        pub fn poll(self: *@This()) ?Event {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.sent) return null;
            self.sent = true;
            return 'A';
        }
    };

    const BetaSource = struct {
        sent: bool = false,
        mutex: std.Thread.Mutex = .{},

        pub const Event = u16;

        pub fn poll(self: *@This()) ?Event {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.sent) return null;
            self.sent = true;
            return 1000;
        }
    };

    var a = AlphaSource{};
    var b = BetaSource{};

    var ev_loop = EventLoop(@TypeOf(.{ .alpha = &a, .beta = &b })).init(.{
        .alpha = &a,
        .beta = &b,
    });
    try ev_loop.start();

    var got_alpha = false;
    var got_beta = false;

    while (ev_loop.receive()) |event| {
        switch (event) {
            .alpha => |v| {
                try std.testing.expectEqual(@as(u8, 'A'), v);
                got_alpha = true;
            },
            .beta => |v| {
                try std.testing.expectEqual(@as(u16, 1000), v);
                got_beta = true;
            },
        }
    }

    try std.testing.expect(got_alpha);
    try std.testing.expect(got_beta);
    ev_loop.deinit();
}

test "stop signals sources" {
    const StoppableSource = struct {
        running: bool = true,
        mutex: std.Thread.Mutex = .{},

        pub const Event = void;

        pub fn poll(self: *@This()) ?Event {
            while (true) {
                self.mutex.lock();
                const r = self.running;
                self.mutex.unlock();
                if (!r) return null;
                std.Thread.sleep(1 * std.time.ns_per_ms);
            }
        }

        pub fn stop(self: *@This()) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.running = false;
        }
    };

    var src = StoppableSource{};
    var ev_loop = EventLoop(@TypeOf(.{ .s = &src })).init(.{ .s = &src });
    try ev_loop.start();

    ev_loop.stop();

    // receive should return null once the source shuts down
    const result = ev_loop.receive();
    try std.testing.expect(result == null);

    ev_loop.deinit();
}
