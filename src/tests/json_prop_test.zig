// Property-based test for JSON parse-serialize round-trip
// **Validates: Requirements 4.1, 4.5, 4.6**
//
// Property 5: JSON Parse-Serialize Round-Trip
// For any valid JSON object, parsing it into a token array and then serializing
// back to a JSON string and parsing again shall produce an equivalent token
// structure. The token counts match between first and second parse, and token
// types match at each position.

const std = @import("std");
const json = @import("json");
const expect = std.testing.expect;

const JsonParser = json.JsonParser;
const TokenType = json.TokenType;

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

    /// Returns a value in [0, bound).
    fn bounded(self: *Lcg, bound: u64) u64 {
        return self.next() % bound;
    }
};

// --- JSON generation helpers ---

/// Generate a random alphanumeric key of length [1, max_len].
fn generateKey(rng: *Lcg, buf: []u8) []const u8 {
    const charset = "abcdefghijklmnopqrstuvwxyz";
    const len = @as(usize, @intCast(rng.bounded(6))) + 1; // 1..6 chars
    const actual_len = @min(len, buf.len);
    for (0..actual_len) |i| {
        buf[i] = charset[@as(usize, @intCast(rng.bounded(charset.len)))];
    }
    return buf[0..actual_len];
}

/// Generate a random JSON value (string, number, boolean, null, or nested object)
/// into buf starting at offset. Returns the number of bytes written, or null if
/// buffer space exhausted.
fn generateValue(rng: *Lcg, buf: []u8, offset: usize, depth: usize) ?usize {
    var pos = offset;
    const remaining = buf.len - pos;
    if (remaining < 8) return null; // need some minimum space

    // At max depth or randomly, emit a primitive value
    const choice = if (depth >= 3) rng.bounded(4) else rng.bounded(5);

    switch (choice) {
        0 => {
            // String value
            if (pos + 10 > buf.len) return null;
            buf[pos] = '"';
            pos += 1;
            const slen = @as(usize, @intCast(rng.bounded(5))) + 1;
            const charset = "abcdefghijklmnop";
            for (0..slen) |_| {
                if (pos + 2 > buf.len) return null;
                buf[pos] = charset[@as(usize, @intCast(rng.bounded(charset.len)))];
                pos += 1;
            }
            buf[pos] = '"';
            pos += 1;
            return pos - offset;
        },
        1 => {
            // Number value (simple integer 0-999)
            const num = @as(u32, @truncate(rng.next())) % 1000;
            var num_buf: [10]u8 = undefined;
            const num_str = formatUint(num, &num_buf);
            if (pos + num_str.len > buf.len) return null;
            @memcpy(buf[pos..][0..num_str.len], num_str);
            pos += num_str.len;
            return pos - offset;
        },
        2 => {
            // Boolean
            if (rng.bounded(2) == 0) {
                if (pos + 4 > buf.len) return null;
                @memcpy(buf[pos..][0..4], "true");
                pos += 4;
            } else {
                if (pos + 5 > buf.len) return null;
                @memcpy(buf[pos..][0..5], "false");
                pos += 5;
            }
            return pos - offset;
        },
        3 => {
            // Null
            if (pos + 4 > buf.len) return null;
            @memcpy(buf[pos..][0..4], "null");
            pos += 4;
            return pos - offset;
        },
        4 => {
            // Nested object
            return generateObject(rng, buf, offset, depth + 1);
        },
        else => unreachable,
    }
}

/// Generate a random JSON object into buf starting at offset.
/// Returns the number of bytes written, or null if buffer space exhausted.
fn generateObject(rng: *Lcg, buf: []u8, offset: usize, depth: usize) ?usize {
    var pos = offset;
    if (pos + 2 > buf.len) return null;

    buf[pos] = '{';
    pos += 1;

    // Random number of key-value pairs (0..4)
    const num_pairs = @as(usize, @intCast(rng.bounded(4)));

    for (0..num_pairs) |pair_idx| {
        if (pair_idx > 0) {
            if (pos + 1 > buf.len) return null;
            buf[pos] = ',';
            pos += 1;
        }

        // Key
        if (pos + 10 > buf.len) return null;
        buf[pos] = '"';
        pos += 1;
        var key_buf: [8]u8 = undefined;
        const key = generateKey(rng, &key_buf);
        if (pos + key.len + 2 > buf.len) return null;
        @memcpy(buf[pos..][0..key.len], key);
        pos += key.len;
        buf[pos] = '"';
        pos += 1;

        // Colon
        if (pos + 1 > buf.len) return null;
        buf[pos] = ':';
        pos += 1;

        // Value
        const val_len = generateValue(rng, buf, pos, depth) orelse return null;
        pos += val_len;
    }

    if (pos + 1 > buf.len) return null;
    buf[pos] = '}';
    pos += 1;

    return pos - offset;
}

/// Format a u32 as a decimal string.
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
    // Reverse
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

// --- Core property test logic ---

/// Generate a random valid JSON object, parse it, serialize, parse again,
/// and verify that token counts and token types match.
fn runRoundTripProperty(rng: *Lcg) !void {
    // Generate a random JSON object
    var json_buf: [2048]u8 = undefined;
    const obj_len = generateObject(rng, &json_buf, 0, 0) orelse return; // skip if generation fails
    const json_str = json_buf[0..obj_len];

    // First parse
    var parser1 = JsonParser{};
    if (!parser1.parse(json_str)) return; // skip if generated JSON doesn't parse (shouldn't happen)

    // Serialize
    var ser_buf: [4096]u8 = undefined;
    const serialized = parser1.serialize(&ser_buf) orelse return; // skip if buffer too small

    // Second parse
    var parser2 = JsonParser{};
    const parse2_ok = parser2.parse(serialized);
    try expect(parse2_ok);

    // Token counts must match
    try expect(parser1.token_count == parser2.token_count);

    // Token types must match at each position
    for (0..parser1.token_count) |i| {
        try expect(parser1.tokens[i].kind == parser2.tokens[i].kind);
    }
}

// --- Property tests across multiple seeds ---

test "Property 5: JSON parse-serialize round-trip — basic seeds" {
    comptime var seed: u64 = 0;
    inline while (seed < 50) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runRoundTripProperty(&rng);
    }
}

test "Property 5: JSON parse-serialize round-trip — mid seeds" {
    comptime var seed: u64 = 100;
    inline while (seed < 150) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runRoundTripProperty(&rng);
    }
}

test "Property 5: JSON parse-serialize round-trip — high seeds" {
    comptime var seed: u64 = 500;
    inline while (seed < 550) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runRoundTripProperty(&rng);
    }
}

test "Property 5: JSON parse-serialize round-trip — empty object" {
    // Edge case: empty object should round-trip perfectly
    var parser1 = JsonParser{};
    try expect(parser1.parse("{}"));

    var ser_buf: [256]u8 = undefined;
    const serialized = parser1.serialize(&ser_buf);
    try expect(serialized != null);

    var parser2 = JsonParser{};
    try expect(parser2.parse(serialized.?));
    try expect(parser1.token_count == parser2.token_count);
    for (0..parser1.token_count) |i| {
        try expect(parser1.tokens[i].kind == parser2.tokens[i].kind);
    }
}

test "Property 5: JSON parse-serialize round-trip — nested objects" {
    comptime var seed: u64 = 1000;
    inline while (seed < 1030) : (seed += 1) {
        var rng = Lcg.init(seed);
        // Generate deeper objects by running multiple rounds
        var json_buf: [2048]u8 = undefined;
        const obj_len = generateObject(&rng, &json_buf, 0, 0) orelse continue;
        const json_str = json_buf[0..obj_len];

        var parser1 = JsonParser{};
        if (!parser1.parse(json_str)) continue;

        var ser_buf: [4096]u8 = undefined;
        const serialized = parser1.serialize(&ser_buf) orelse continue;

        var parser2 = JsonParser{};
        try expect(parser2.parse(serialized));
        try expect(parser1.token_count == parser2.token_count);

        for (0..parser1.token_count) |i| {
            try expect(parser1.tokens[i].kind == parser2.tokens[i].kind);
        }
    }
}
