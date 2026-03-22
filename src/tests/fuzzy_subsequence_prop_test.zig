// Property-based test for fuzzy match subsequence correctness
// **Validates: Requirements 10.4, 10.5, 11.1, 11.2**
//
// Property 14: Fuzzy Match Subsequence Correctness
// For any query and target string pair, fuzzyScore shall return a score >= 0
// if and only if the query is a case-insensitive subsequence of the target,
// and shall return -1 otherwise.

const std = @import("std");
const command_palette = @import("command_palette");
const fuzzyScore = command_palette.fuzzyScore;
const expect = std.testing.expect;

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

    /// Generate a random u8 in [min, max] inclusive range.
    fn rangeU8(self: *Lcg, min: u8, max: u8) u8 {
        const span: u64 = @as(u64, max - min) + 1;
        return min + @as(u8, @intCast(self.bounded(span)));
    }

    /// Generate a random usize in [min, max) range.
    fn rangeUsize(self: *Lcg, min: usize, max: usize) usize {
        const span: u64 = @intCast(max - min);
        return min + @as(usize, @intCast(self.bounded(span)));
    }
};

// --- Helpers ---

fn toLower(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

/// Check if query is a case-insensitive subsequence of target (oracle).
fn isSubsequence(query: []const u8, target: []const u8) bool {
    if (query.len == 0) return true;
    var qi: usize = 0;
    for (target) |tc| {
        if (toLower(query[qi]) == toLower(tc)) {
            qi += 1;
            if (qi == query.len) return true;
        }
    }
    return false;
}

/// Generate a random printable ASCII string of length [1, max_len] into buf.
/// Returns the slice of the generated string.
fn genRandomString(rng: *Lcg, buf: *[64]u8, max_len: usize) []const u8 {
    const len = rng.rangeUsize(1, max_len + 1);
    for (buf[0..len]) |*c| {
        c.* = rng.rangeU8(32, 126); // printable ASCII
    }
    return buf[0..len];
}

/// Generate a query that IS a subsequence of target by picking random indices.
/// Returns the slice of the generated query.
fn genSubsequenceQuery(rng: *Lcg, target: []const u8, buf: *[64]u8) []const u8 {
    if (target.len == 0) return buf[0..0];

    // Pick a random number of characters to include (1..target.len, capped at 64)
    const max_pick = @min(target.len, 64);
    const pick_count = rng.rangeUsize(1, max_pick + 1);

    // Use a simple selection: walk through target, randomly decide to pick each char
    // We need exactly pick_count chars. Use reservoir-like approach:
    // Generate pick_count unique sorted indices from [0, target.len).
    var indices: [64]usize = undefined;
    var idx_count: usize = 0;

    // Simple approach: for each position, decide with probability pick_count/remaining
    var remaining = target.len;
    var needed = pick_count;
    for (0..target.len) |i| {
        if (needed == 0) break;
        // Pick this index with probability needed/remaining
        const roll = rng.bounded(remaining);
        if (roll < needed) {
            indices[idx_count] = i;
            idx_count += 1;
            needed -= 1;
        }
        remaining -= 1;
    }

    // Copy selected characters into buf
    for (indices[0..idx_count], 0..) |idx, i| {
        buf[i] = target[idx];
    }
    return buf[0..idx_count];
}

/// Generate a query that is NOT a subsequence of target.
/// Strategy: include a character that doesn't appear in target (case-insensitive).
fn genNonSubsequenceQuery(rng: *Lcg, target: []const u8, buf: *[64]u8) []const u8 {
    // Find a printable ASCII char not in target (case-insensitive)
    var present = [_]bool{false} ** 128;
    for (target) |c| {
        const lc = toLower(c);
        if (lc < 128) present[lc] = true;
    }

    // Find a char not present
    var absent_char: u8 = 0;
    var found = false;
    // Start from a random offset to vary the absent char
    const start = rng.rangeU8('a', 'z');
    var i: u8 = 0;
    while (i < 26) : (i += 1) {
        const candidate = 'a' + ((start - 'a' + i) % 26);
        if (!present[candidate]) {
            absent_char = candidate;
            found = true;
            break;
        }
    }

    if (!found) {
        // All lowercase letters present in target — use a digit
        var d: u8 = 0;
        while (d < 10) : (d += 1) {
            const candidate = '0' + d;
            if (!present[candidate]) {
                absent_char = candidate;
                found = true;
                break;
            }
        }
    }

    if (!found) {
        // Extremely unlikely: target contains all alphanumeric chars.
        // Use a punctuation char not in target.
        const puncts = "!@#$%^&*()~`";
        for (puncts) |p| {
            if (!present[p]) {
                absent_char = p;
                found = true;
                break;
            }
        }
    }

    if (!found) {
        // Target contains virtually all printable ASCII — skip this iteration
        buf[0] = 0; // null won't match printable
        return buf[0..0];
    }

    // Build a query: take a few chars from target + insert the absent char
    const query_len = rng.rangeUsize(1, @min(target.len + 1, 16) + 1);
    const insert_pos = rng.bounded(query_len);

    var qi: usize = 0;
    var ti: usize = 0;
    for (0..query_len) |pos| {
        if (pos == insert_pos) {
            buf[qi] = absent_char;
            qi += 1;
        } else {
            if (ti < target.len) {
                buf[qi] = target[ti];
                ti += 1;
                qi += 1;
            } else {
                buf[qi] = absent_char;
                qi += 1;
            }
        }
    }
    return buf[0..qi];
}

// --- Core property test logic ---

fn runSubsequencePropertyTest(rng: *Lcg) !void {
    var target_buf: [64]u8 = undefined;
    var query_buf: [64]u8 = undefined;

    // Generate random target string
    const target = genRandomString(rng, &target_buf, 64);

    // --- Property: empty query always returns 0 ---
    {
        const score = fuzzyScore("", target);
        try expect(score == 0);
    }

    // --- Property: valid subsequence query returns score >= 0 ---
    {
        const query = genSubsequenceQuery(rng, target, &query_buf);
        if (query.len > 0) {
            // Verify our oracle agrees it's a subsequence
            try expect(isSubsequence(query, target));

            const score = fuzzyScore(query, target);
            // fuzzyScore must return >= 0 for a valid subsequence
            try expect(score >= 0);
        }
    }

    // --- Property: non-subsequence query returns -1 ---
    {
        var non_sub_buf: [64]u8 = undefined;
        const query = genNonSubsequenceQuery(rng, target, &non_sub_buf);
        if (query.len > 0) {
            // Verify our oracle agrees it's NOT a subsequence
            if (!isSubsequence(query, target)) {
                const score = fuzzyScore(query, target);
                try expect(score == -1);
            }
        }
    }
}

// --- Property tests across multiple seeds ---

test "Property 14: Fuzzy subsequence correctness — random seeds 0..99" {
    comptime var seed: u64 = 0;
    inline while (seed < 100) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runSubsequencePropertyTest(&rng);
    }
}

test "Property 14: Fuzzy subsequence correctness — large seed range" {
    comptime var seed: u64 = 1000;
    inline while (seed < 1050) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runSubsequencePropertyTest(&rng);
    }
}

test "Property 14: Empty query always returns 0" {
    const targets = [_][]const u8{ "hello", "world", "", "a", "Open File", "src/main.zig" };
    inline for (targets) |t| {
        try expect(fuzzyScore("", t) == 0);
    }
}

test "Property 14: Full string is always a subsequence of itself" {
    const cases = [_][]const u8{ "open", "File", "command_palette", "src/main.zig", "A" };
    inline for (cases) |s| {
        const score = fuzzyScore(s, s);
        try expect(score >= 0);
    }
}
