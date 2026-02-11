/// Simple single threaded and fixed size queue.
pub fn Queue(Type: type) type {
    return struct {
        data: [256]?Type = [_]?Type{null} ** 256,
        head: u8 = 0,
        tail: u8 = 0,

        pub fn init() @This() {
            return .{};
        }

        pub fn push(self: *@This(), item: Type) void {
            self.data[self.tail] = item;
            self.tail = self.tail +% 1;
        }

        pub fn pull(self: *@This()) ?Type {
            if (self.data[self.head]) |item| {
                self.data[self.head] = null;
                self.head = self.head +% 1;
                return item;
            }
            return null;
        }
    };
}

test "Basic queue" {
    const testing = @import("std").testing;

    var queue = Queue(u8).init();

    try testing.expect(queue.pull() == null);

    queue.push(1);
    queue.push(2);

    try testing.expectEqual(1, queue.pull().?);
    try testing.expectEqual(2, queue.pull().?);
}

test "Queue wraparound" {
    const testing = @import("std").testing;

    var queue = Queue(u8).init();

    // Fill the queue completely (256 items)
    for (0..256) |i| {
        queue.push(@truncate(i));
    }

    // Verify tail wrapped around to 0
    try testing.expectEqual(@as(u8, 0), queue.tail);
    try testing.expectEqual(@as(u8, 0), queue.head);

    // Pull all items - should get 0..255
    for (0..256) |i| {
        const val = queue.pull();
        try testing.expectEqual(@as(u8, @truncate(i)), val.?);
    }

    // Queue should be empty now
    try testing.expect(queue.pull() == null);
}

test "Queue head wraparound" {
    const testing = @import("std").testing;

    var queue = Queue(u8).init();

    // Push and pull to move head forward
    for (0..200) |i| {
        queue.push(@truncate(i));
        _ = queue.pull();
    }

    // Now head and tail are both at 200
    try testing.expectEqual(@as(u8, 200), queue.head);
    try testing.expectEqual(@as(u8, 200), queue.tail);

    // Push 100 more items - tail wraps around to 44
    for (0..100) |i| {
        queue.push(@truncate(i));
    }
    try testing.expectEqual(@as(u8, 44), queue.tail); // 200 + 100 = 300, 300 % 256 = 44

    // Pull them all
    for (0..100) |i| {
        try testing.expectEqual(@as(u8, @truncate(i)), queue.pull().?);
    }
}

test "Queue overflow overwrites oldest" {
    const testing = @import("std").testing;

    var queue = Queue(u8).init();

    // Push 256 items (fills queue)
    for (0..256) |i| {
        queue.push(@truncate(i));
    }

    // Push one more - this overwrites slot 0
    queue.push(255);

    // The first slot now contains 255, not 0
    // But head still points to slot 0, so pulling returns the overwritten value
    try testing.expectEqual(@as(u8, 255), queue.pull().?);

    // Next items are 1..255
    for (1..256) |i| {
        try testing.expectEqual(@as(u8, @truncate(i)), queue.pull().?);
    }
}
