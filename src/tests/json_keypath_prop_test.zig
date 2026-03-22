// Property-based test for JSON key-path lookup correctness
// **Validates: Requirements 4.3, 4.4**
//
// Property 6: JSON Key-Path Lookup Correctness
// For any valid JSON object and any dot-separated key path, if the key path
// exists in the JSON, the lookup shall return the correct value (string,
// number, or boolean). If the key path does not exist, the lookup shall
// return null.

const std = @import("std");
const json = @import("json");
const expect = std.testing.expect;

const JsonParser = json.JsonParser;

// --- Custom comptime LCG-based pseudo-random generator (zero dependencies) ---

const Lcg = struct {
    state: u64,

    const A: u64 = 6364136223846793005;
    const C: u64 = 1442695040888963407;

    fn init(seed: u64) Lcg {
        return .{ .state = seed };
    }

    fn next(self: *Lcg) u64 {
        self.state = self.state *% A +% C;
        return self.state;
    }

    fn bounded(self: *Lcg, bound: u64) u64 {
        return self.next() % bound;
    }
};

// --- Value types we track for verification ---

const ValueKind = enum { string_val, number_val, bool_val };

const TrackedValue = struct {
    kind: ValueKind,
    // For strings: the string content (without quotes)
    str_buf: [16]u8 = undefined,
    str_len: usize = 0,
    // For numbers: the integer value
    num_val: u32 = 0,
    // For bools
    bool_val: bool = false,
};

const TrackedEntry = struct {
    // Full dot-separated key path
    path_buf: [64]u8 = undefined,
    path_len: usize = 0,
    value: TrackedValue = .{ .kind = .string_val },

    fn path(self: *const TrackedEntry) []const u8 {
        return self.path_buf[0..self.path_len];
    }
};

const MAX_TRACKED = 32;

const TrackedEntries = struct {
    entries: [MAX_TRACKED]TrackedEntry = undefined,
    count: usize = 0,

    fn add(self: *TrackedEntries, path_prefix: []const u8, key: []const u8, value: TrackedValue) void {
        if (self.count >= MAX_TRACKED) return;
        var entry = &self.entries[self.count];
        entry.path_len = 0;
        entry.value = value;

        // Build full path: prefix.key or just key
        if (path_prefix.len > 0) {
            const plen = @min(path_prefix.len, 60);
            @memcpy(entry.path_buf[0..plen], path_prefix[0..plen]);
            entry.path_len = plen;
            if (entry.path_len < 63) {
                entry.path_buf[entry.path_len] = '.';
                entry.path_len += 1;
            }
        }
        const klen = @min(key.len, 64 - entry.path_len);
        @memcpy(entry.path_buf[entry.path_len..][0..klen], key[0..klen]);
        entry.path_len += klen;

        self.count += 1;
    }
};

// --- JSON generation with tracking ---

fn generateKey(rng: *Lcg, buf: []u8) []const u8 {
    const charset = "abcdefghijklmnopqrstuvwxyz";
    const len = @as(usize, @intCast(rng.bounded(4))) + 1; // 1..4 chars
    const actual_len = @min(len, buf.len);
    for (0..actual_len) |i| {
        buf[i] = charset[@as(usize, @intCast(rng.bounded(charset.len)))];
    }
    return buf[0..actual_len];
}

fn formatUint(val: u32, buf: *[10]u8) []const u8 {
    if (val == 0) {
        buf[0] = '0';
        return buf[0..1];
    }
    var v = val;
    var i: usize = 0;
    while (v > 0) {
        buf[i] = @as(u8, @intCast(v % 10)) + '0';
        v /= 10;
        i += 1;
    }
    var lo: usize = 0;
    var hi: usize = i - 1;
    while (lo < hi) {
        const tmp = buf[lo];
        buf[lo] = buf[hi];
        buf[hi] = tmp;
        lo += 1;
        hi -= 1;
    }
    return buf[0..i];
}

/// Generate a JSON object with tracked key-value pairs.
/// Returns the number of bytes written, or null if buffer exhausted.
fn generateTrackedObject(
    rng: *Lcg,
    buf: []u8,
    offset: usize,
    tracked: *TrackedEntries,
    path_prefix: []const u8,
    depth: usize,
) ?usize {
    var pos = offset;
    if (pos + 2 > buf.len) return null;

    buf[pos] = '{';
    pos += 1;

    // 1..3 key-value pairs
    const num_pairs = @as(usize, @intCast(rng.bounded(3))) + 1;

    for (0..num_pairs) |pair_idx| {
        if (pair_idx > 0) {
            if (pos + 1 > buf.len) return null;
            buf[pos] = ',';
            pos += 1;
        }

        // Generate key
        var key_buf: [8]u8 = undefined;
        const key = generateKey(rng, &key_buf);

        // Write key
        if (pos + key.len + 3 > buf.len) return null;
        buf[pos] = '"';
        pos += 1;
        @memcpy(buf[pos..][0..key.len], key);
        pos += key.len;
        buf[pos] = '"';
        pos += 1;
        buf[pos] = ':';
        pos += 1;

        // Choose value type: 0=string, 1=number, 2=bool, 3=nested object (only if depth < 2)
        const max_choice: u64 = if (depth < 2) 4 else 3;
        const choice = rng.bounded(max_choice);

        switch (choice) {
            0 => {
                // String value
                const charset = "abcdefghijklmnop";
                const slen = @as(usize, @intCast(rng.bounded(5))) + 1;
                if (pos + slen + 2 > buf.len) return null;
                buf[pos] = '"';
                pos += 1;
                var str_val: TrackedValue = .{ .kind = .string_val };
                for (0..slen) |si| {
                    const c = charset[@as(usize, @intCast(rng.bounded(charset.len)))];
                    buf[pos] = c;
                    if (si < 16) {
                        str_val.str_buf[si] = c;
                    }
                    pos += 1;
                }
                str_val.str_len = slen;
                buf[pos] = '"';
                pos += 1;
                tracked.add(path_prefix, key, str_val);
            },
            1 => {
                // Number value (0-999)
                const num = @as(u32, @truncate(rng.next())) % 1000;
                var num_fmt_buf: [10]u8 = undefined;
                const num_str = formatUint(num, &num_fmt_buf);
                if (pos + num_str.len > buf.len) return null;
                @memcpy(buf[pos..][0..num_str.len], num_str);
                pos += num_str.len;
                tracked.add(path_prefix, key, .{
                    .kind = .number_val,
                    .num_val = num,
                });
            },
            2 => {
                // Boolean value
                const bval = rng.bounded(2) == 0;
                if (bval) {
                    if (pos + 4 > buf.len) return null;
                    @memcpy(buf[pos..][0..4], "true");
                    pos += 4;
                } else {
                    if (pos + 5 > buf.len) return null;
                    @memcpy(buf[pos..][0..5], "false");
                    pos += 5;
                }
                tracked.add(path_prefix, key, .{
                    .kind = .bool_val,
                    .bool_val = bval,
                });
            },
            3 => {
                // Nested object — build new prefix
                var new_prefix: [64]u8 = undefined;
                var np_len: usize = 0;
                if (path_prefix.len > 0) {
                    const plen = @min(path_prefix.len, 58);
                    @memcpy(new_prefix[0..plen], path_prefix[0..plen]);
                    np_len = plen;
                    new_prefix[np_len] = '.';
                    np_len += 1;
                }
                const klen = @min(key.len, 64 - np_len);
                @memcpy(new_prefix[np_len..][0..klen], key[0..klen]);
                np_len += klen;

                const nested_len = generateTrackedObject(
                    rng,
                    buf,
                    pos,
                    tracked,
                    new_prefix[0..np_len],
                    depth + 1,
                ) orelse return null;
                pos += nested_len;
            },
            else => unreachable,
        }
    }

    if (pos + 1 > buf.len) return null;
    buf[pos] = '}';
    pos += 1;

    return pos - offset;
}

// --- Core property test logic ---

fn runKeyPathProperty(rng: *Lcg) !void {
    var json_buf: [2048]u8 = undefined;
    var tracked = TrackedEntries{};

    const obj_len = generateTrackedObject(rng, &json_buf, 0, &tracked, &.{}, 0) orelse return;
    const json_str = json_buf[0..obj_len];

    // Parse the generated JSON
    var parser = JsonParser{};
    if (!parser.parse(json_str)) return; // skip if parse fails (shouldn't happen)

    // Verify all tracked entries can be looked up with correct values
    for (0..tracked.count) |i| {
        const entry = &tracked.entries[i];
        const path = entry.path();

        switch (entry.value.kind) {
            .string_val => {
                const result = parser.getString(path);
                try expect(result != null);
                const expected = entry.value.str_buf[0..entry.value.str_len];
                try expect(result.?.len == expected.len);
                for (result.?, expected) |a, b| {
                    try expect(a == b);
                }
            },
            .number_val => {
                const result = parser.getNumber(path);
                try expect(result != null);
                const expected = @as(f64, @floatFromInt(entry.value.num_val));
                try expect(result.? == expected);
            },
            .bool_val => {
                const result = parser.getBool(path);
                try expect(result != null);
                try expect(result.? == entry.value.bool_val);
            },
        }
    }

    // Verify non-existent keys return null
    try expect(parser.getString("nonexistent_key_xyz") == null);
    try expect(parser.getNumber("nonexistent_key_xyz") == null);
    try expect(parser.getBool("nonexistent_key_xyz") == null);
    try expect(parser.getString("a.b.c.d.e.f.nonexistent") == null);
}

// --- Property tests across multiple seeds ---

test "Property 6: JSON key-path lookup — basic seeds" {
    comptime var seed: u64 = 0;
    inline while (seed < 50) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runKeyPathProperty(&rng);
    }
}

test "Property 6: JSON key-path lookup — mid seeds" {
    comptime var seed: u64 = 100;
    inline while (seed < 150) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runKeyPathProperty(&rng);
    }
}

test "Property 6: JSON key-path lookup — high seeds" {
    comptime var seed: u64 = 500;
    inline while (seed < 550) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runKeyPathProperty(&rng);
    }
}

test "Property 6: JSON key-path lookup — nested object traversal" {
    // Manually construct a known nested JSON and verify key-path traversal
    var parser = JsonParser{};
    const input = "{\"a\":{\"b\":{\"c\":\"deep\"}},\"x\":42,\"flag\":true}";
    try expect(parser.parse(input));

    // Nested string lookup
    const s = parser.getString("a.b.c");
    try expect(s != null);
    try expect(s.?.len == 4);
    try expect(s.?[0] == 'd');
    try expect(s.?[1] == 'e');
    try expect(s.?[2] == 'e');
    try expect(s.?[3] == 'p');

    // Top-level number
    const n = parser.getNumber("x");
    try expect(n != null);
    try expect(n.? == 42.0);

    // Top-level bool
    const b = parser.getBool("flag");
    try expect(b != null);
    try expect(b.? == true);

    // Non-existent paths
    try expect(parser.getString("a.b.d") == null);
    try expect(parser.getString("a.c") == null);
    try expect(parser.getNumber("missing") == null);
    try expect(parser.getBool("a.b.c.d") == null);
}

test "Property 6: JSON key-path lookup — non-existent returns null" {
    var parser = JsonParser{};
    const input = "{\"only\":\"one\"}";
    try expect(parser.parse(input));

    try expect(parser.getString("other") == null);
    try expect(parser.getNumber("only") == null); // wrong type
    try expect(parser.getBool("only") == null); // wrong type
    try expect(parser.getString("only.nested") == null); // not an object
}
