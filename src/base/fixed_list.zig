// src/base/fixed_list.zig — Fixed-capacity list (no allocator)

pub fn FixedList(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        items: [capacity]T = undefined,
        len: usize = 0,

        pub fn append(self: *Self, item: T) bool {
            if (self.len >= capacity) return false;
            self.items[self.len] = item;
            self.len += 1;
            return true;
        }

        pub fn remove(self: *Self, index: usize) ?T {
            if (index >= self.len) return null;
            const item = self.items[index];
            var i = index;
            while (i < self.len - 1) : (i += 1) {
                self.items[i] = self.items[i + 1];
            }
            self.len -= 1;
            return item;
        }

        pub fn get(self: *const Self, index: usize) ?T {
            if (index >= self.len) return null;
            return self.items[index];
        }

        pub fn slice(self: *const Self) []const T {
            return self.items[0..self.len];
        }
    };
}

// Unit tests
const std = @import("std");
const expect = std.testing.expect;

test "FixedList append and get" {
    var list = FixedList(u32, 4){};
    try expect(list.len == 0);

    try expect(list.append(10));
    try expect(list.append(20));
    try expect(list.append(30));
    try expect(list.len == 3);

    try expect(list.get(0).? == 10);
    try expect(list.get(1).? == 20);
    try expect(list.get(2).? == 30);
    try expect(list.get(3) == null);
}

test "FixedList append returns false when full" {
    var list = FixedList(u8, 2){};
    try expect(list.append(1));
    try expect(list.append(2));
    try expect(!list.append(3));
    try expect(list.len == 2);
    // List unchanged — items still 1, 2
    try expect(list.get(0).? == 1);
    try expect(list.get(1).? == 2);
}

test "FixedList get returns null for out-of-bounds" {
    var list = FixedList(i32, 4){};
    try expect(list.get(0) == null);

    try expect(list.append(42));
    try expect(list.get(0).? == 42);
    try expect(list.get(1) == null);
    try expect(list.get(100) == null);
}

test "FixedList remove shifts items left" {
    var list = FixedList(u32, 8){};
    try expect(list.append(10));
    try expect(list.append(20));
    try expect(list.append(30));
    try expect(list.append(40));

    // Remove index 1 (value 20)
    try expect(list.remove(1).? == 20);
    try expect(list.len == 3);
    try expect(list.get(0).? == 10);
    try expect(list.get(1).? == 30);
    try expect(list.get(2).? == 40);
}

test "FixedList remove returns null for out-of-bounds" {
    var list = FixedList(u32, 4){};
    try expect(list.remove(0) == null);

    try expect(list.append(1));
    try expect(list.remove(1) == null);
    try expect(list.remove(100) == null);
    try expect(list.len == 1);
}

test "FixedList remove first and last elements" {
    var list = FixedList(u32, 4){};
    try expect(list.append(10));
    try expect(list.append(20));
    try expect(list.append(30));

    // Remove first
    try expect(list.remove(0).? == 10);
    try expect(list.len == 2);
    try expect(list.get(0).? == 20);
    try expect(list.get(1).? == 30);

    // Remove last
    try expect(list.remove(1).? == 30);
    try expect(list.len == 1);
    try expect(list.get(0).? == 20);
}

test "FixedList slice returns items[0..len]" {
    var list = FixedList(u32, 8){};
    try expect(list.slice().len == 0);

    try expect(list.append(5));
    try expect(list.append(10));
    try expect(list.append(15));

    const s = list.slice();
    try expect(s.len == 3);
    try expect(s[0] == 5);
    try expect(s[1] == 10);
    try expect(s[2] == 15);
}
