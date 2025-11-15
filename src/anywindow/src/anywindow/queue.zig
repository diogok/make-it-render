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
            self.tail += 1;
        }

        pub fn pull(self: *@This()) ?Type {
            if (self.data[self.head]) |item| {
                self.data[self.head] = null;
                self.head += 1;
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
