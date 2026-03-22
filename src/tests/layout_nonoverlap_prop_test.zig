// Property-based test for layout non-overlap and full coverage
// **Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5**
//
// Property 12: Layout Non-Overlap and Full Coverage
// For any valid window dimensions (w > 0, h > 0) and any combination of
// sidebar_visible and panel_visible flags, after recompute: (a) all visible
// regions (area > 0) shall be pairwise non-overlapping, and (b) the union of
// all regions shall cover the full window rectangle. Hidden regions shall have
// zero area.

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

// --- Helper: check pairwise non-overlap of all visible regions ---

fn checkNonOverlap(state: *const LayoutState) !void {
    var i: usize = 0;
    while (i < REGION_COUNT) : (i += 1) {
        const ri = state.regions[i];
        if (ri.w <= 0 or ri.h <= 0) continue;
        var j: usize = i + 1;
        while (j < REGION_COUNT) : (j += 1) {
            const rj = state.regions[j];
            if (rj.w <= 0 or rj.h <= 0) continue;
            if (ri.intersects(rj)) {
                return error.TestUnexpectedResult;
            }
        }
    }
}

// --- Helper: check full window coverage via area sum ---
// The sum of all region areas must equal window_w * window_h.

fn checkFullCoverageByArea(state: *const LayoutState) !void {
    var area_sum: i64 = 0;
    for (state.regions[0..REGION_COUNT]) |r| {
        if (r.w > 0 and r.h > 0) {
            area_sum += @as(i64, r.w) * @as(i64, r.h);
        }
    }
    const window_area: i64 = @as(i64, state.window_w) * @as(i64, state.window_h);
    if (area_sum != window_area) {
        return error.TestUnexpectedResult;
    }
}

// --- Helper: check full window coverage via grid sampling ---
// Every sampled point within the window must be covered by hitTest.

fn checkFullCoverageByGrid(state: *const LayoutState, step: i32) !void {
    var y: i32 = 0;
    while (y < state.window_h) : (y += step) {
        var x: i32 = 0;
        while (x < state.window_w) : (x += step) {
            if (state.hitTest(x, y) == null) {
                return error.TestUnexpectedResult;
            }
        }
    }
}

// --- Helper: check hidden regions have zero area ---

fn checkHiddenRegionsZeroArea(state: *const LayoutState) !void {
    if (!state.sidebar_visible) {
        const sidebar = state.regions[@intFromEnum(LayoutRegion.sidebar)];
        try expect(sidebar.w == 0 or sidebar.h == 0);
    }
    if (!state.panel_visible) {
        const panel = state.regions[@intFromEnum(LayoutRegion.panel)];
        try expect(panel.w == 0 or panel.h == 0);
    }
}

// --- Core property test logic ---

fn runLayoutPropertyTest(rng: *Lcg) !void {
    var state = LayoutState{};

    // Generate random window dimensions in reasonable range
    const width = rng.rangeI32(200, 3841);
    const height = rng.rangeI32(200, 2161);

    // Generate random visibility flags
    state.sidebar_visible = rng.nextBool();
    state.panel_visible = rng.nextBool();

    state.recompute(width, height);

    // Property (a): all visible regions are pairwise non-overlapping
    try checkNonOverlap(&state);

    // Property (b): union of all regions covers the full window area
    try checkFullCoverageByArea(&state);

    // Additional grid-based coverage check (coarse step for speed)
    try checkFullCoverageByGrid(&state, 50);

    // Hidden regions must have zero area
    try checkHiddenRegionsZeroArea(&state);
}

// --- Property tests across multiple seeds ---

test "Property 12: Layout non-overlap and full coverage — random seeds 0..99" {
    comptime var seed: u64 = 0;
    inline while (seed < 100) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runLayoutPropertyTest(&rng);
    }
}

test "Property 12: Layout non-overlap and full coverage — large seed range" {
    comptime var seed: u64 = 1000;
    inline while (seed < 1050) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runLayoutPropertyTest(&rng);
    }
}

test "Property 12: Layout non-overlap and full coverage — all visibility combos" {
    // Exhaustively test all 4 visibility combinations across multiple sizes
    const widths = [_]i32{ 200, 800, 1280, 1920, 3840 };
    const heights = [_]i32{ 200, 600, 720, 1080, 2160 };

    inline for (widths) |w| {
        inline for (heights) |h| {
            // Both visible
            {
                var state = LayoutState{};
                state.sidebar_visible = true;
                state.panel_visible = true;
                state.recompute(w, h);
                try checkNonOverlap(&state);
                try checkFullCoverageByArea(&state);
                try checkHiddenRegionsZeroArea(&state);
            }
            // Sidebar hidden
            {
                var state = LayoutState{};
                state.sidebar_visible = false;
                state.panel_visible = true;
                state.recompute(w, h);
                try checkNonOverlap(&state);
                try checkFullCoverageByArea(&state);
                try checkHiddenRegionsZeroArea(&state);
            }
            // Panel hidden
            {
                var state = LayoutState{};
                state.sidebar_visible = true;
                state.panel_visible = false;
                state.recompute(w, h);
                try checkNonOverlap(&state);
                try checkFullCoverageByArea(&state);
                try checkHiddenRegionsZeroArea(&state);
            }
            // Both hidden
            {
                var state = LayoutState{};
                state.sidebar_visible = false;
                state.panel_visible = false;
                state.recompute(w, h);
                try checkNonOverlap(&state);
                try checkFullCoverageByArea(&state);
                try checkHiddenRegionsZeroArea(&state);
            }
        }
    }
}
