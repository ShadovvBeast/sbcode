// Property-based test for fuzzy scoring monotonicity
// **Validates: Requirements 11.3, 11.4, 11.5**
//
// Property 15: Fuzzy Scoring Monotonicity
// - Consecutive matches score higher than scattered matches
// - Word boundary matches get bonus
// - Exact case matches get bonus

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

const BOUNDARY_CHARS = [_]u8{ '.', '/', '_', '-', ' ' };

fn isBoundary(c: u8) bool {
    for (BOUNDARY_CHARS) |b| {
        if (c == b) return true;
    }
    return false;
}

/// Generate a random lowercase letter.
fn randomLower(rng: *Lcg) u8 {
    return rng.rangeU8('a', 'z');
}

/// Build a target string with word-boundary structure, e.g. "abc_def.ghi"
/// Returns the slice of the generated target.
fn genBoundaryTarget(rng: *Lcg, buf: *[64]u8) []const u8 {
    // Generate 2-4 "words" separated by boundary chars
    const word_count = rng.rangeUsize(2, 5);
    var pos: usize = 0;

    for (0..word_count) |wi| {
        if (wi > 0 and pos < 60) {
            // Insert a boundary separator
            const sep_idx = rng.bounded(BOUNDARY_CHARS.len);
            buf[pos] = BOUNDARY_CHARS[@intCast(sep_idx)];
            pos += 1;
        }
        // Generate a word of 2-6 lowercase letters
        const word_len = rng.rangeUsize(2, 7);
        for (0..word_len) |_| {
            if (pos >= 60) break;
            buf[pos] = randomLower(rng);
            pos += 1;
        }
    }
    return buf[0..pos];
}

// --- Property: Consecutive matches score >= scattered matches ---
// Requirement 11.3: consecutive character matches get higher score than scattered

fn runConsecutiveVsScatteredTest(rng: *Lcg) !void {
    var target_buf: [64]u8 = undefined;
    const target = genBoundaryTarget(rng, &target_buf);

    if (target.len < 6) return; // need enough chars to form meaningful queries

    // Pick a consecutive run of 2-3 chars from the target
    const consec_len = rng.rangeUsize(2, @min(4, target.len));
    const max_start = target.len - consec_len;
    const consec_start = rng.rangeUsize(0, max_start + 1);

    var consec_query: [4]u8 = undefined;
    for (0..consec_len) |i| {
        consec_query[i] = target[consec_start + i];
    }
    const consecutive_query = consec_query[0..consec_len];

    // Build a scattered query using the same chars but picked from distant positions
    // Find positions of those chars scattered throughout the target
    var scattered_query: [4]u8 = undefined;
    var scattered_len: usize = 0;

    // Pick chars from target that are spread apart (at least 2 positions gap)
    var last_pick: usize = 0;
    var ti: usize = 0;
    while (ti < target.len and scattered_len < consec_len) : (ti += 1) {
        if (scattered_len == 0 or ti >= last_pick + 3) {
            // Only pick non-boundary chars
            if (!isBoundary(target[ti])) {
                scattered_query[scattered_len] = target[ti];
                scattered_len += 1;
                last_pick = ti;
            }
        }
    }

    if (scattered_len < 2) return; // couldn't build a meaningful scattered query

    const consec_score = fuzzyScore(consecutive_query, target);
    const scattered_score = fuzzyScore(scattered_query[0..scattered_len], target);

    // Both must be valid matches
    if (consec_score < 0 or scattered_score < 0) return;

    // Consecutive matches should score >= scattered matches
    // (when query lengths are equal, consecutive bonus should dominate)
    if (scattered_len == consec_len) {
        try expect(consec_score >= scattered_score);
    }
}

// --- Property: Word boundary matches get bonus ---
// Requirement 11.4: match at word boundary awards boundary bonus

fn runWordBoundaryBonusTest(rng: *Lcg) !void {
    var target_buf: [64]u8 = undefined;
    const target = genBoundaryTarget(rng, &target_buf);

    // Find a char that appears at a word boundary position
    var boundary_char: u8 = 0;
    var boundary_found = false;
    for (target, 0..) |c, i| {
        if (isBoundary(c)) continue;
        if (i == 0 or isBoundary(target[i - 1])) {
            boundary_char = c;
            boundary_found = true;
            break;
        }
    }

    if (!boundary_found) return;

    // Find the same char at a non-boundary position (middle of a word)
    var mid_char: u8 = 0;
    var mid_found = false;
    for (target, 0..) |c, i| {
        if (isBoundary(c)) continue;
        if (i > 0 and !isBoundary(target[i - 1]) and c != boundary_char) {
            // This char is in the middle of a word — different char
            continue;
        }
        if (i > 0 and !isBoundary(target[i - 1])) {
            mid_char = c;
            mid_found = true;
            break;
        }
    }
    if (!mid_found) return;

    // Score single-char queries
    const boundary_query = [1]u8{boundary_char};
    const mid_query = [1]u8{mid_char};

    const boundary_score = fuzzyScore(&boundary_query, target);
    const mid_score = fuzzyScore(&mid_query, target);

    if (boundary_score < 0 or mid_score < 0) return;

    // Boundary match should score higher due to +5 boundary bonus
    try expect(boundary_score > mid_score);
}

// --- Property: Exact case matches get bonus ---
// Requirement 11.5: exact case match awards case bonus

fn runExactCaseBonusTest(rng: *Lcg) !void {
    // Generate a target with mixed case
    var target_buf: [64]u8 = undefined;
    const base_target = genBoundaryTarget(rng, &target_buf);

    if (base_target.len < 2) return;

    // Capitalize the first letter of each "word" to create a mixed-case target
    var mixed_buf: [64]u8 = undefined;
    for (base_target, 0..) |c, i| {
        if (i == 0 or (i > 0 and isBoundary(base_target[i - 1]))) {
            // Capitalize word start
            if (c >= 'a' and c <= 'z') {
                mixed_buf[i] = c - 32;
            } else {
                mixed_buf[i] = c;
            }
        } else {
            mixed_buf[i] = c;
        }
    }
    const mixed_target = mixed_buf[0..base_target.len];

    // Build exact-case query from first few non-boundary chars
    var exact_query: [8]u8 = undefined;
    var lower_query: [8]u8 = undefined;
    var qlen: usize = 0;

    for (mixed_target) |c| {
        if (qlen >= 4) break;
        if (isBoundary(c)) continue;
        exact_query[qlen] = c;
        lower_query[qlen] = if (c >= 'A' and c <= 'Z') c + 32 else c;
        qlen += 1;
    }

    if (qlen == 0) return;

    const exact_score = fuzzyScore(exact_query[0..qlen], mixed_target);
    const lower_score = fuzzyScore(lower_query[0..qlen], mixed_target);

    if (exact_score < 0 or lower_score < 0) return;

    // Exact case should score >= lowercase (case bonus of +1 per char)
    try expect(exact_score >= lower_score);
}

// --- Property tests across multiple seeds ---

test "Property 15: Consecutive matches score >= scattered — random seeds 0..99" {
    comptime var seed: u64 = 0;
    inline while (seed < 100) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runConsecutiveVsScatteredTest(&rng);
    }
}

test "Property 15: Consecutive matches score >= scattered — large seed range" {
    comptime var seed: u64 = 1000;
    inline while (seed < 1050) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runConsecutiveVsScatteredTest(&rng);
    }
}

test "Property 15: Word boundary matches get bonus — random seeds 0..99" {
    comptime var seed: u64 = 0;
    inline while (seed < 100) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runWordBoundaryBonusTest(&rng);
    }
}

test "Property 15: Word boundary matches get bonus — large seed range" {
    comptime var seed: u64 = 1000;
    inline while (seed < 1050) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runWordBoundaryBonusTest(&rng);
    }
}

test "Property 15: Exact case matches get bonus — random seeds 0..99" {
    comptime var seed: u64 = 0;
    inline while (seed < 100) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runExactCaseBonusTest(&rng);
    }
}

test "Property 15: Exact case matches get bonus — large seed range" {
    comptime var seed: u64 = 1000;
    inline while (seed < 1050) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runExactCaseBonusTest(&rng);
    }
}

// --- Deterministic edge case tests ---

test "Property 15: Exact case bonus — Open vs open on Open target" {
    const exact = fuzzyScore("Open", "Open");
    const lower = fuzzyScore("open", "Open");
    try expect(exact >= 0);
    try expect(lower >= 0);
    try expect(exact >= lower);
}

test "Property 15: Consecutive bonus — op in open vs o_p" {
    const consec = fuzzyScore("op", "open");
    const scattered = fuzzyScore("op", "o_x_p");
    try expect(consec >= 0);
    try expect(scattered >= 0);
    try expect(consec > scattered);
}

test "Property 15: Boundary bonus — f after _ in open_file" {
    const boundary = fuzzyScore("f", "open_file");
    const mid = fuzzyScore("i", "open_file");
    try expect(boundary >= 0);
    try expect(mid >= 0);
    try expect(boundary > mid);
}
