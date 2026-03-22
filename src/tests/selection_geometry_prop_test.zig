// Property-based test for Selection geometry correctness
// **Validates: Requirement 6.5**
//
// Property 10: Selection Geometry Correctness
// For any pair of Position values (anchor, active), the Selection shall
// correctly report: isEmpty is true iff anchor equals active, isForward is
// true iff anchor is before or equal to active, startPos returns the lesser
// position, and endPos returns the greater position.

const std = @import("std");
const cursor = @import("cursor");
const expect = std.testing.expect;

const Position = cursor.Position;
const Selection = cursor.Selection;

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

// --- Position generation helpers ---

/// Generate a random Position with line in [0, max_line) and col in [0, max_col).
fn generatePosition(rng: *Lcg, max_line: u32, max_col: u32) Position {
    return .{
        .line = @as(u32, @intCast(rng.bounded(max_line))),
        .col = @as(u32, @intCast(rng.bounded(max_col))),
    };
}

/// Generate a random Selection from two random positions.
fn generateSelection(rng: *Lcg, max_line: u32, max_col: u32) Selection {
    return .{
        .anchor = generatePosition(rng, max_line, max_col),
        .active = generatePosition(rng, max_line, max_col),
    };
}

// --- Comparison helpers ---

/// Lexicographic comparison: returns true if a <= b (line first, then col).
fn posLessOrEqual(a: Position, b: Position) bool {
    if (a.line < b.line) return true;
    if (a.line == b.line) return a.col <= b.col;
    return false;
}

/// Strict equality of two positions.
fn posEqual(a: Position, b: Position) bool {
    return a.line == b.line and a.col == b.col;
}

// --- Core property test logic ---

/// Verify all five selection geometry properties for a given Selection.
fn checkSelectionGeometry(sel: Selection) !void {
    const s = sel.startPos();
    const e = sel.endPos();

    // Property 1: startPos() <= endPos() (lexicographic order)
    try expect(posLessOrEqual(s, e));

    // Property 2: if isEmpty(), then startPos == endPos == anchor == active
    if (sel.isEmpty()) {
        try expect(posEqual(s, e));
        try expect(posEqual(s, sel.anchor));
        try expect(posEqual(s, sel.active));
    }

    // Property 3: isForward() is true iff anchor <= active (lexicographic)
    const anchor_leq_active = posLessOrEqual(sel.anchor, sel.active);
    try expect(sel.isForward() == anchor_leq_active);

    // Property 4: startPos() is always either anchor or active
    try expect(posEqual(s, sel.anchor) or posEqual(s, sel.active));

    // Property 5: endPos() is always either anchor or active
    try expect(posEqual(e, sel.anchor) or posEqual(e, sel.active));
}

// --- Property tests across multiple seeds ---

test "Property 10: Selection geometry — small positions" {
    comptime var seed: u64 = 0;
    inline while (seed < 50) : (seed += 1) {
        var rng = Lcg.init(seed);
        const sel = generateSelection(&rng, 10, 20);
        try checkSelectionGeometry(sel);
    }
}

test "Property 10: Selection geometry — large positions" {
    comptime var seed: u64 = 100;
    inline while (seed < 150) : (seed += 1) {
        var rng = Lcg.init(seed);
        const sel = generateSelection(&rng, 10000, 50000);
        try checkSelectionGeometry(sel);
    }
}

test "Property 10: Selection geometry — same line selections" {
    comptime var seed: u64 = 200;
    inline while (seed < 250) : (seed += 1) {
        var rng = Lcg.init(seed);
        const line = @as(u32, @intCast(rng.bounded(100)));
        const sel = Selection{
            .anchor = .{ .line = line, .col = @as(u32, @intCast(rng.bounded(200))) },
            .active = .{ .line = line, .col = @as(u32, @intCast(rng.bounded(200))) },
        };
        try checkSelectionGeometry(sel);
    }
}

test "Property 10: Selection geometry — empty selections" {
    comptime var seed: u64 = 300;
    inline while (seed < 350) : (seed += 1) {
        var rng = Lcg.init(seed);
        const pos = generatePosition(&rng, 5000, 5000);
        const sel = Selection{ .anchor = pos, .active = pos };
        try checkSelectionGeometry(sel);
    }
}

test "Property 10: Selection geometry — boundary values" {
    // Test with extreme u32 values
    const cases = [_]Selection{
        .{ .anchor = .{ .line = 0, .col = 0 }, .active = .{ .line = 0, .col = 0 } },
        .{ .anchor = .{ .line = 0, .col = 0 }, .active = .{ .line = 0xFFFFFFFF, .col = 0xFFFFFFFF } },
        .{ .anchor = .{ .line = 0xFFFFFFFF, .col = 0xFFFFFFFF }, .active = .{ .line = 0, .col = 0 } },
        .{ .anchor = .{ .line = 0xFFFFFFFF, .col = 0xFFFFFFFF }, .active = .{ .line = 0xFFFFFFFF, .col = 0xFFFFFFFF } },
        .{ .anchor = .{ .line = 0, .col = 0xFFFFFFFF }, .active = .{ .line = 0xFFFFFFFF, .col = 0 } },
        .{ .anchor = .{ .line = 0xFFFFFFFF, .col = 0 }, .active = .{ .line = 0, .col = 0xFFFFFFFF } },
    };
    for (cases) |sel| {
        try checkSelectionGeometry(sel);
    }
}
