// Property-based test for layout hit-test consistency
// **Validates: Requirement 9.6**
//
// Property 13: Layout Hit-Test Consistency
// For any point (x, y) within the window bounds, hitTest returns a LayoutRegion R
// such that getRegion(R).contains(x, y) is true. For any point outside the window
// bounds, hitTest returns null. hitTest is deterministic — calling it twice with
// the same point returns the same result.

const std = @import("std");
const layout = @import("layout");
const LayoutState = layout.LayoutState;
const LayoutRegion = layout.LayoutRegion;
const REGION_COUNT = layout.REGION_COUNT;
const Rect = @import("rect").Rect;
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

    fn nextBool(self: *Lcg) bool {
        return self.bounded(2) == 0;
    }

    /// Generate a random i32 in [min, max) range.
    fn rangeI32(self: *Lcg, min: i32, max: i32) i32 {
        const span: u64 = @intCast(max - min);
        return min + @as(i32, @intCast(self.bounded(span)));
    }
};

// --- Helper: create a LayoutState with random dimensions and visibility ---

fn makeRandomLayout(rng: *Lcg) LayoutState {
    var state = LayoutState{};
    state.sidebar_visible = rng.nextBool();
    state.panel_visible = rng.nextBool();
    const width = rng.rangeI32(200, 3841);
    const height = rng.rangeI32(200, 2161);
    state.recompute(width, height);
    return state;
}

// --- Property: hitTest returns a region whose rect contains the queried point ---

fn checkHitTestContainment(state: *const LayoutState, rng: *Lcg, num_points: usize) !void {
    for (0..num_points) |_| {
        const x = rng.rangeI32(0, state.window_w);
        const y = rng.rangeI32(0, state.window_h);

        const maybe_region = state.hitTest(x, y);
        // Within window bounds, hitTest must return a region
        try expect(maybe_region != null);

        const region = maybe_region.?;
        const rect = state.getRegion(region);
        // The returned region's rect must contain the queried point
        try expect(rect.contains(x, y));
    }
}

// --- Property: hitTest returns null for points outside window bounds ---

fn checkHitTestOutOfBounds(state: *const LayoutState, rng: *Lcg) !void {
    // Points to the left of the window
    {
        const y = rng.rangeI32(0, state.window_h);
        try expect(state.hitTest(-1, y) == null);
        const far_left = rng.rangeI32(-1000, 0);
        try expect(state.hitTest(far_left, y) == null);
    }
    // Points above the window
    {
        const x = rng.rangeI32(0, state.window_w);
        try expect(state.hitTest(x, -1) == null);
        const far_above = rng.rangeI32(-1000, 0);
        try expect(state.hitTest(x, far_above) == null);
    }
    // Points to the right of the window (at or beyond window_w)
    {
        const y = rng.rangeI32(0, state.window_h);
        try expect(state.hitTest(state.window_w, y) == null);
        const far_right = rng.rangeI32(state.window_w, state.window_w + 1000);
        try expect(state.hitTest(far_right, y) == null);
    }
    // Points below the window (at or beyond window_h)
    {
        const x = rng.rangeI32(0, state.window_w);
        try expect(state.hitTest(x, state.window_h) == null);
        const far_below = rng.rangeI32(state.window_h, state.window_h + 1000);
        try expect(state.hitTest(x, far_below) == null);
    }
    // Corner cases: all four out-of-bounds corners
    try expect(state.hitTest(-1, -1) == null);
    try expect(state.hitTest(state.window_w, -1) == null);
    try expect(state.hitTest(-1, state.window_h) == null);
    try expect(state.hitTest(state.window_w, state.window_h) == null);
}

// --- Property: hitTest is deterministic (same input → same output) ---

fn checkHitTestDeterminism(state: *const LayoutState, rng: *Lcg, num_points: usize) !void {
    for (0..num_points) |_| {
        // Generate points both inside and outside window bounds
        const x = rng.rangeI32(-100, state.window_w + 100);
        const y = rng.rangeI32(-100, state.window_h + 100);

        const result1 = state.hitTest(x, y);
        const result2 = state.hitTest(x, y);

        // Both calls must return the same result
        if (result1) |r1| {
            try expect(result2 != null);
            try expect(r1 == result2.?);
        } else {
            try expect(result2 == null);
        }
    }
}

// --- Core property test logic ---

fn runHitTestPropertyTest(rng: *Lcg) !void {
    const state = makeRandomLayout(rng);

    // Property: hitTest returns region containing the queried point
    try checkHitTestContainment(&state, rng, 50);

    // Property: hitTest returns null for out-of-bounds points
    try checkHitTestOutOfBounds(&state, rng);

    // Property: hitTest is deterministic
    try checkHitTestDeterminism(&state, rng, 50);
}

// --- Property tests across multiple seeds ---

test "Property 13: Layout hit-test consistency — random seeds 0..99" {
    comptime var seed: u64 = 0;
    inline while (seed < 100) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runHitTestPropertyTest(&rng);
    }
}

test "Property 13: Layout hit-test consistency — large seed range" {
    comptime var seed: u64 = 1000;
    inline while (seed < 1050) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runHitTestPropertyTest(&rng);
    }
}

test "Property 13: Layout hit-test consistency — boundary points" {
    // Test all four window corners and edge midpoints for all visibility combos
    const widths = [_]i32{ 200, 800, 1280, 1920, 3840 };
    const heights = [_]i32{ 200, 600, 720, 1080, 2160 };

    inline for (widths) |w| {
        inline for (heights) |h| {
            const combos = [_][2]bool{
                .{ true, true },
                .{ true, false },
                .{ false, true },
                .{ false, false },
            };
            inline for (combos) |combo| {
                var state = LayoutState{};
                state.sidebar_visible = combo[0];
                state.panel_visible = combo[1];
                state.recompute(w, h);

                // All four corners inside window must hit a region
                const corners = [_][2]i32{
                    .{ 0, 0 },
                    .{ w - 1, 0 },
                    .{ 0, h - 1 },
                    .{ w - 1, h - 1 },
                };
                inline for (corners) |pt| {
                    const result = state.hitTest(pt[0], pt[1]);
                    try expect(result != null);
                    const rect = state.getRegion(result.?);
                    try expect(rect.contains(pt[0], pt[1]));
                }

                // Edge midpoints must also hit a region
                const mid_x = @divTrunc(w, 2);
                const mid_y = @divTrunc(h, 2);
                const edges = [_][2]i32{
                    .{ mid_x, 0 },
                    .{ mid_x, h - 1 },
                    .{ 0, mid_y },
                    .{ w - 1, mid_y },
                };
                inline for (edges) |pt| {
                    const result = state.hitTest(pt[0], pt[1]);
                    try expect(result != null);
                    const rect = state.getRegion(result.?);
                    try expect(rect.contains(pt[0], pt[1]));
                }

                // Just outside must return null
                try expect(state.hitTest(-1, 0) == null);
                try expect(state.hitTest(0, -1) == null);
                try expect(state.hitTest(w, 0) == null);
                try expect(state.hitTest(0, h) == null);
            }
        }
    }
}
