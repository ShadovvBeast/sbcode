// Property-based test for FixedString construction round-trip
// **Validates: Requirement 3.6**
//
// Property 3: FixedString Construction Round-Trip
// For any byte slice of length <= MAX_STRING_LEN, constructing a FixedString
// via fromSlice and then calling asSlice shall return a slice equal to the
// original input. For slices longer than MAX_STRING_LEN, the result shall be
// truncated to MAX_STRING_LEN bytes. For any sequence of successful appends,
// asSlice equals the concatenation of all appended slices. append returns
// false and leaves the string unchanged when it would exceed MAX_STRING_LEN.

const std = @import("std");
const strings = @import("strings");
const FixedString = strings.FixedString;
const MAX_STRING_LEN = strings.MAX_STRING_LEN;
const expect = std.testing.expect;
const mem = std.mem;

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

// --- Helpers ---

/// Generate a random byte slice of a given length into a buffer.
fn generateBytes(buf: []u8, rng: *Lcg) void {
    for (buf) |*b| {
        b.* = @as(u8, @truncate(rng.next()));
    }
}

// --- Core property test: fromSlice/asSlice round-trip ---

fn runFromSliceRoundTrip(rng: *Lcg) !void {
    // Generate a random length in [0, MAX_STRING_LEN]
    const len = @as(usize, @intCast(rng.bounded(MAX_STRING_LEN + 1)));
    var input_buf: [MAX_STRING_LEN]u8 = undefined;
    generateBytes(input_buf[0..len], rng);
    const input = input_buf[0..len];

    const fs = FixedString.fromSlice(input);
    const output = fs.asSlice();

    // Round-trip: asSlice must equal the original input
    try expect(output.len == input.len);
    try expect(mem.eql(u8, output, input));
}

// --- Core property test: fromSlice truncation for oversized slices ---

fn runFromSliceTruncation(rng: *Lcg) !void {
    // Generate a length in (MAX_STRING_LEN, MAX_STRING_LEN + 512]
    const extra = @as(usize, @intCast(rng.bounded(512))) + 1;
    const total_len = MAX_STRING_LEN + extra;
    // Use a comptime-sized buffer large enough
    var input_buf: [MAX_STRING_LEN + 512]u8 = undefined;
    generateBytes(input_buf[0..total_len], rng);
    const input = input_buf[0..total_len];

    const fs = FixedString.fromSlice(input);
    const output = fs.asSlice();

    // Must be truncated to MAX_STRING_LEN
    try expect(output.len == MAX_STRING_LEN);
    try expect(mem.eql(u8, output, input[0..MAX_STRING_LEN]));
}

// --- Core property test: append sequence round-trip ---

fn runAppendSequenceRoundTrip(comptime max_appends: usize, rng: *Lcg) !void {
    var fs = FixedString{};

    // Shadow buffer to track expected concatenation
    var shadow: [MAX_STRING_LEN]u8 = undefined;
    var shadow_len: usize = 0;

    const num_appends = @as(usize, @intCast(rng.bounded(max_appends))) + 1;

    for (0..num_appends) |_| {
        // Generate a random chunk of [0, 128) bytes
        const chunk_len = @as(usize, @intCast(rng.bounded(128)));
        var chunk_buf: [128]u8 = undefined;
        generateBytes(chunk_buf[0..chunk_len], rng);
        const chunk = chunk_buf[0..chunk_len];

        const remaining = MAX_STRING_LEN - shadow_len;
        const result = fs.append(chunk);

        if (chunk_len > remaining) {
            // Should fail — string unchanged
            try expect(!result);
            try expect(fs.asSlice().len == shadow_len);
            try expect(mem.eql(u8, fs.asSlice(), shadow[0..shadow_len]));
        } else {
            // Should succeed — shadow tracks concatenation
            try expect(result);
            @memcpy(shadow[shadow_len..][0..chunk_len], chunk);
            shadow_len += chunk_len;
            try expect(fs.asSlice().len == shadow_len);
            try expect(mem.eql(u8, fs.asSlice(), shadow[0..shadow_len]));
        }
    }
}

// --- Core property test: append failure leaves string unchanged ---

fn runAppendFailureUnchanged(rng: *Lcg) !void {
    // Fill to a random level, then attempt an append that would overflow
    const fill_len = @as(usize, @intCast(rng.bounded(MAX_STRING_LEN + 1)));
    var fill_buf: [MAX_STRING_LEN]u8 = undefined;
    generateBytes(fill_buf[0..fill_len], rng);

    var fs = FixedString.fromSlice(fill_buf[0..fill_len]);
    const remaining = MAX_STRING_LEN - fs.asSlice().len;

    // Generate a chunk that is strictly larger than remaining
    if (remaining < MAX_STRING_LEN) {
        const overflow_len = remaining + 1 + @as(usize, @intCast(rng.bounded(64)));
        const capped_len = @min(overflow_len, MAX_STRING_LEN);
        var overflow_buf: [MAX_STRING_LEN]u8 = undefined;
        generateBytes(overflow_buf[0..capped_len], rng);

        // Snapshot before failed append
        const len_before = fs.asSlice().len;
        var snapshot: [MAX_STRING_LEN]u8 = undefined;
        @memcpy(snapshot[0..len_before], fs.asSlice());

        const result = fs.append(overflow_buf[0..capped_len]);
        try expect(!result);
        // String must be unchanged
        try expect(fs.asSlice().len == len_before);
        try expect(mem.eql(u8, fs.asSlice(), snapshot[0..len_before]));
    }
}

// --- Property tests across multiple seeds ---

test "Property 3: FixedString fromSlice/asSlice round-trip" {
    comptime var seed: u64 = 0;
    inline while (seed < 50) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runFromSliceRoundTrip(&rng);
    }
}

test "Property 3: FixedString fromSlice truncation for oversized slices" {
    comptime var seed: u64 = 100;
    inline while (seed < 150) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runFromSliceTruncation(&rng);
    }
}

test "Property 3: FixedString append sequence round-trip" {
    comptime var seed: u64 = 200;
    inline while (seed < 250) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runAppendSequenceRoundTrip(32, &rng);
    }
}

test "Property 3: FixedString append failure leaves string unchanged" {
    comptime var seed: u64 = 300;
    inline while (seed < 350) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runAppendFailureUnchanged(&rng);
    }
}

test "Property 3: FixedString fromSlice empty and exact MAX_STRING_LEN" {
    // Empty slice round-trip
    const empty_fs = FixedString.fromSlice("");
    try expect(empty_fs.asSlice().len == 0);

    // Exact MAX_STRING_LEN round-trip
    var exact_buf: [MAX_STRING_LEN]u8 = undefined;
    var rng = Lcg.init(999);
    generateBytes(&exact_buf, &rng);
    const exact_fs = FixedString.fromSlice(&exact_buf);
    try expect(exact_fs.asSlice().len == MAX_STRING_LEN);
    try expect(mem.eql(u8, exact_fs.asSlice(), &exact_buf));

    // Append to full string must fail
    var full_fs = FixedString.fromSlice(&exact_buf);
    try expect(!full_fs.append("a"));
    try expect(full_fs.asSlice().len == MAX_STRING_LEN);
}
