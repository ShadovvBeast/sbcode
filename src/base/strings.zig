// src/base/strings.zig — Stack-based string buffer (no allocator)

pub const MAX_STRING_LEN = 4096;

pub const FixedString = struct {
    buf: [MAX_STRING_LEN]u8 = undefined,
    len: usize = 0,

    pub fn fromSlice(s: []const u8) FixedString {
        var fs = FixedString{};
        const copy_len = @min(s.len, MAX_STRING_LEN);
        @memcpy(fs.buf[0..copy_len], s[0..copy_len]);
        fs.len = copy_len;
        return fs;
    }

    pub fn asSlice(self: *const FixedString) []const u8 {
        return self.buf[0..self.len];
    }

    pub fn append(self: *FixedString, s: []const u8) bool {
        const remaining = MAX_STRING_LEN - self.len;
        if (s.len > remaining) return false;
        @memcpy(self.buf[self.len..][0..s.len], s);
        self.len += s.len;
        return true;
    }

    pub fn clear(self: *FixedString) void {
        self.len = 0;
    }
};

// Unit tests
const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;

test "FixedString fromSlice and asSlice round-trip" {
    const fs = FixedString.fromSlice("hello world");
    try expect(fs.len == 11);
    try expect(mem.eql(u8, fs.asSlice(), "hello world"));
}

test "FixedString fromSlice empty string" {
    const fs = FixedString.fromSlice("");
    try expect(fs.len == 0);
    try expect(fs.asSlice().len == 0);
}

test "FixedString fromSlice truncates at MAX_STRING_LEN" {
    const big = [_]u8{'x'} ** (MAX_STRING_LEN + 100);
    const fs = FixedString.fromSlice(&big);
    try expect(fs.len == MAX_STRING_LEN);
    try expect(fs.asSlice().len == MAX_STRING_LEN);
}

test "FixedString append succeeds within capacity" {
    var fs = FixedString.fromSlice("hello");
    try expect(fs.append(" world"));
    try expect(fs.len == 11);
    try expect(mem.eql(u8, fs.asSlice(), "hello world"));
}

test "FixedString append returns false when exceeding capacity" {
    var fs = FixedString{};
    // Fill to exactly MAX_STRING_LEN
    const fill = [_]u8{'a'} ** MAX_STRING_LEN;
    try expect(fs.append(&fill));
    try expect(fs.len == MAX_STRING_LEN);

    // Any further append should fail and leave string unchanged
    try expect(!fs.append("x"));
    try expect(fs.len == MAX_STRING_LEN);
}

test "FixedString append leaves string unchanged on failure" {
    var fs = FixedString{};
    const fill = [_]u8{'b'} ** (MAX_STRING_LEN - 2);
    try expect(fs.append(&fill));
    try expect(fs.len == MAX_STRING_LEN - 2);

    // Trying to append 3 bytes when only 2 remain should fail
    try expect(!fs.append("abc"));
    try expect(fs.len == MAX_STRING_LEN - 2);
    // Original content preserved
    try expect(fs.buf[0] == 'b');
}

test "FixedString clear resets length to zero" {
    var fs = FixedString.fromSlice("some content");
    try expect(fs.len == 12);
    fs.clear();
    try expect(fs.len == 0);
    try expect(fs.asSlice().len == 0);
}

test "FixedString default initialization is empty" {
    const fs = FixedString{};
    try expect(fs.len == 0);
    try expect(fs.asSlice().len == 0);
}

test "FixedString multiple appends" {
    var fs = FixedString{};
    try expect(fs.append("foo"));
    try expect(fs.append("bar"));
    try expect(fs.append("baz"));
    try expect(fs.len == 9);
    try expect(mem.eql(u8, fs.asSlice(), "foobarbaz"));
}

test "FixedString fromSlice exactly MAX_STRING_LEN" {
    const exact = [_]u8{'z'} ** MAX_STRING_LEN;
    const fs = FixedString.fromSlice(&exact);
    try expect(fs.len == MAX_STRING_LEN);
    // No room to append
    try expect(!fs.append("a"));
}
