// src/base/ring_buffer.zig — Fixed-capacity ring buffer (no allocator)

pub fn RingBuffer(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        items: [capacity]T = undefined,
        head: usize = 0,
        tail: usize = 0,
        len: usize = 0,

        pub fn push(self: *Self, item: T) bool {
            if (self.len == capacity) return false;
            self.items[self.tail] = item;
            self.tail = (self.tail + 1) % capacity;
            self.len += 1;
            return true;
        }

        pub fn pop(self: *Self) ?T {
            if (self.len == 0) return null;
            const item = self.items[self.head];
            self.head = (self.head + 1) % capacity;
            self.len -= 1;
            return item;
        }

        pub fn peek(self: *const Self) ?T {
            if (self.len == 0) return null;
            return self.items[self.head];
        }

        pub fn isFull(self: *const Self) bool {
            return self.len == capacity;
        }

        pub fn clear(self: *Self) void {
            self.head = 0;
            self.tail = 0;
            self.len = 0;
        }
    };
}

// Unit tests
const std = @import("std");
const expect = std.testing.expect;

test "RingBuffer push and pop FIFO order" {
    var rb = RingBuffer(u32, 4){};
    try expect(rb.len == 0);

    try expect(rb.push(10));
    try expect(rb.push(20));
    try expect(rb.push(30));
    try expect(rb.len == 3);

    try expect(rb.pop().? == 10);
    try expect(rb.pop().? == 20);
    try expect(rb.pop().? == 30);
    try expect(rb.pop() == null);
}

test "RingBuffer push returns false when full" {
    var rb = RingBuffer(u8, 2){};
    try expect(rb.push(1));
    try expect(rb.push(2));
    try expect(!rb.push(3));
    try expect(rb.len == 2);
    // Buffer unchanged — head item is still 1
    try expect(rb.peek().? == 1);
}

test "RingBuffer pop returns null when empty" {
    var rb = RingBuffer(i32, 4){};
    try expect(rb.pop() == null);
}

test "RingBuffer peek returns head without removing" {
    var rb = RingBuffer(u32, 4){};
    try expect(rb.peek() == null);

    try expect(rb.push(42));
    try expect(rb.peek().? == 42);
    try expect(rb.len == 1); // not removed
    try expect(rb.peek().? == 42);
}

test "RingBuffer isFull" {
    var rb = RingBuffer(u8, 2){};
    try expect(!rb.isFull());
    try expect(rb.push(1));
    try expect(!rb.isFull());
    try expect(rb.push(2));
    try expect(rb.isFull());
    _ = rb.pop();
    try expect(!rb.isFull());
}

test "RingBuffer clear resets state" {
    var rb = RingBuffer(u32, 4){};
    try expect(rb.push(1));
    try expect(rb.push(2));
    try expect(rb.push(3));
    rb.clear();
    try expect(rb.len == 0);
    try expect(rb.head == 0);
    try expect(rb.tail == 0);
    try expect(rb.pop() == null);
}

test "RingBuffer wraps around correctly" {
    var rb = RingBuffer(u32, 3){};
    // Fill
    try expect(rb.push(1));
    try expect(rb.push(2));
    try expect(rb.push(3));
    // Pop two
    try expect(rb.pop().? == 1);
    try expect(rb.pop().? == 2);
    // Push two more (wraps tail around)
    try expect(rb.push(4));
    try expect(rb.push(5));
    // Should get 3, 4, 5 in FIFO order
    try expect(rb.pop().? == 3);
    try expect(rb.pop().? == 4);
    try expect(rb.pop().? == 5);
    try expect(rb.pop() == null);
}
