// Property-based test for CommandPalette filter correctness
// **Validates: Requirements 10.2, 10.3, 10.6, 10.7**
//
// Property 16: CommandPalette Filter Correctness
// For any set of registered commands and any filter input string, the filtered
// results shall contain only commands whose labels fuzzy-match the input.
// When the input is empty, all commands (up to MAX_RESULTS) shall be included.
// The selected_index shall always be < filtered_count (or 0 when filtered_count is 0).
// After toggle(), visible is true, input is cleared, selected_index is 0, filter is updated.
// Filtered results are sorted by score descending.

const std = @import("std");
const command_palette = @import("command_palette");
const CommandPalette = command_palette.CommandPalette;
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

/// Generate a random label string of length [3, max_len] into buf.
/// Returns the slice of the generated string.
fn genRandomLabel(rng: *Lcg, buf: *[128]u8, max_len: usize) []const u8 {
    const len = rng.rangeUsize(3, max_len + 1);
    const actual_len = @min(len, 128);
    for (buf[0..actual_len]) |*c| {
        // Mix of lowercase, uppercase, spaces, underscores for realistic labels
        const kind = rng.bounded(10);
        if (kind < 5) {
            c.* = rng.rangeU8('a', 'z');
        } else if (kind < 8) {
            c.* = rng.rangeU8('A', 'Z');
        } else if (kind == 8) {
            c.* = ' ';
        } else {
            c.* = '_';
        }
    }
    return buf[0..actual_len];
}

/// Generate a short random query string of length [1, max_len] into buf.
fn genRandomQuery(rng: *Lcg, buf: *[32]u8, max_len: usize) []const u8 {
    const len = rng.rangeUsize(1, max_len + 1);
    const actual_len = @min(len, 32);
    for (buf[0..actual_len]) |*c| {
        c.* = rng.rangeU8('a', 'z');
    }
    return buf[0..actual_len];
}

/// Register a set of random commands into a CommandPalette.
fn registerRandomCommands(rng: *Lcg, cp: *CommandPalette, count: usize) void {
    var label_buf: [128]u8 = undefined;
    for (0..count) |i| {
        const label = genRandomLabel(rng, &label_buf, 30);
        _ = cp.registerCommand(@intCast(i), label, null, @intCast(i));
    }
}

// --- Property: Empty input shows all commands up to MAX_RESULTS (Req 10.2) ---

fn runEmptyInputProperty(rng: *Lcg) !void {
    var cp = CommandPalette{};
    const cmd_count = rng.rangeUsize(1, 80); // sometimes > MAX_RESULTS
    registerRandomCommands(rng, &cp, cmd_count);

    cp.input_len = 0;
    cp.updateFilter();

    const expected = @min(cmd_count, CommandPalette.MAX_RESULTS);
    try expect(cp.filtered_count == expected);

    // All filtered indices should be sequential 0..expected-1
    for (0..expected) |i| {
        try expect(cp.filtered_indices[i] == i);
    }
}

// --- Property: Non-empty input yields only fuzzy matches (Req 10.3) ---

fn runFuzzyMatchOnlyProperty(rng: *Lcg) !void {
    var cp = CommandPalette{};
    const cmd_count = rng.rangeUsize(5, 60);
    registerRandomCommands(rng, &cp, cmd_count);

    // Set a random query
    var query_buf: [32]u8 = undefined;
    const query = genRandomQuery(rng, &query_buf, 6);
    @memcpy(cp.input_buf[0..query.len], query);
    cp.input_len = query.len;

    cp.updateFilter();

    // Every filtered result must be a fuzzy match of the query
    for (0..cp.filtered_count) |i| {
        const cmd_idx = cp.filtered_indices[i];
        const cmd = &cp.commands[cmd_idx];
        const label = cmd.label[0..cmd.label_len];
        const score = fuzzyScore(query, label);
        try expect(score >= 0);
    }

    // Every command NOT in filtered results must NOT be a fuzzy match,
    // OR we hit MAX_RESULTS cap
    if (cp.filtered_count < CommandPalette.MAX_RESULTS) {
        for (0..cp.command_count) |ci| {
            var found = false;
            for (0..cp.filtered_count) |fi| {
                if (cp.filtered_indices[fi] == ci) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                const cmd = &cp.commands[ci];
                const label = cmd.label[0..cmd.label_len];
                const score = fuzzyScore(query, label);
                try expect(score < 0);
            }
        }
    }
}

// --- Property: toggle() sets visible=true, clears input, resets selected_index, updates filter (Req 10.6) ---

fn runToggleProperty(rng: *Lcg) !void {
    var cp = CommandPalette{};
    const cmd_count = rng.rangeUsize(1, 40);
    registerRandomCommands(rng, &cp, cmd_count);

    // Set some arbitrary state before toggle
    const q = "test";
    @memcpy(cp.input_buf[0..q.len], q);
    cp.input_len = q.len;
    cp.selected_index = rng.rangeUsize(0, 20);
    cp.visible = false;

    cp.toggle();

    try expect(cp.visible == true);
    try expect(cp.input_len == 0);
    try expect(cp.selected_index == 0);
    // Filter should have been updated with empty input → all commands up to MAX_RESULTS
    const expected = @min(cmd_count, CommandPalette.MAX_RESULTS);
    try expect(cp.filtered_count == expected);
}

// --- Property: selected_index clamped to filtered_count - 1 after updateFilter (Req 10.7) ---

fn runSelectedIndexClampProperty(rng: *Lcg) !void {
    var cp = CommandPalette{};
    const cmd_count = rng.rangeUsize(1, 60);
    registerRandomCommands(rng, &cp, cmd_count);

    // Set selected_index to a large value
    cp.selected_index = rng.rangeUsize(0, 200);

    // Set a random query (may produce few or zero results)
    var query_buf: [32]u8 = undefined;
    const query = genRandomQuery(rng, &query_buf, 8);
    @memcpy(cp.input_buf[0..query.len], query);
    cp.input_len = query.len;

    cp.updateFilter();

    if (cp.filtered_count == 0) {
        try expect(cp.selected_index == 0);
    } else {
        try expect(cp.selected_index < cp.filtered_count);
    }
}

// --- Property: filtered results sorted by score descending ---

fn runSortedByScoreProperty(rng: *Lcg) !void {
    var cp = CommandPalette{};
    const cmd_count = rng.rangeUsize(5, 60);
    registerRandomCommands(rng, &cp, cmd_count);

    // Set a random query
    var query_buf: [32]u8 = undefined;
    const query = genRandomQuery(rng, &query_buf, 5);
    @memcpy(cp.input_buf[0..query.len], query);
    cp.input_len = query.len;

    cp.updateFilter();

    // Scores must be in non-increasing order
    if (cp.filtered_count > 1) {
        for (0..cp.filtered_count - 1) |i| {
            try expect(cp.filtered_scores[i] >= cp.filtered_scores[i + 1]);
        }
    }
}

// --- Property tests across multiple seeds ---

test "Property 16: Empty input shows all commands up to MAX_RESULTS — seeds 0..99" {
    comptime var seed: u64 = 0;
    inline while (seed < 100) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runEmptyInputProperty(&rng);
    }
}

test "Property 16: Non-empty input yields only fuzzy matches — seeds 0..99" {
    comptime var seed: u64 = 0;
    inline while (seed < 100) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runFuzzyMatchOnlyProperty(&rng);
    }
}

test "Property 16: toggle() resets state correctly — seeds 0..99" {
    comptime var seed: u64 = 0;
    inline while (seed < 100) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runToggleProperty(&rng);
    }
}

test "Property 16: selected_index clamped after updateFilter — seeds 0..99" {
    comptime var seed: u64 = 0;
    inline while (seed < 100) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runSelectedIndexClampProperty(&rng);
    }
}

test "Property 16: filtered results sorted by score descending — seeds 0..99" {
    comptime var seed: u64 = 0;
    inline while (seed < 100) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runSortedByScoreProperty(&rng);
    }
}

test "Property 16: Empty input shows all — large seed range" {
    comptime var seed: u64 = 1000;
    inline while (seed < 1050) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runEmptyInputProperty(&rng);
    }
}

test "Property 16: Non-empty input fuzzy matches only — large seed range" {
    comptime var seed: u64 = 1000;
    inline while (seed < 1050) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runFuzzyMatchOnlyProperty(&rng);
    }
}

test "Property 16: selected_index clamped — large seed range" {
    comptime var seed: u64 = 1000;
    inline while (seed < 1050) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runSelectedIndexClampProperty(&rng);
    }
}

test "Property 16: sorted by score — large seed range" {
    comptime var seed: u64 = 1000;
    inline while (seed < 1050) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runSortedByScoreProperty(&rng);
    }
}
