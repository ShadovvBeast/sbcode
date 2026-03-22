// src/workbench/layout.zig — Workbench layout manager
//
// Pure Zig, zero dependencies, zero allocators, stack/comptime only.
// Computes non-overlapping rectangular regions for all UI areas from
// window dimensions and visibility flags.

const Rect = @import("rect").Rect;

pub const LayoutRegion = enum {
    title_bar,
    activity_bar,
    sidebar,
    editor_tabs,
    editor_breadcrumbs,
    editor_area,
    minimap,
    panel,
    status_bar,
};

pub const REGION_COUNT = @typeInfo(LayoutRegion).@"enum".fields.len;

pub const LayoutState = struct {
    regions: [REGION_COUNT]Rect = [_]Rect{.{ .x = 0, .y = 0, .w = 0, .h = 0 }} ** REGION_COUNT,
    window_w: i32 = 0,
    window_h: i32 = 0,

    // Visibility flags
    sidebar_visible: bool = true,
    panel_visible: bool = true,

    // Fixed dimensions
    title_bar_height: i32 = 30,
    activity_bar_width: i32 = 48,
    sidebar_width: i32 = 250,
    status_bar_height: i32 = 22,
    panel_height: i32 = 200,
    editor_tabs_height: i32 = 35,
    breadcrumbs_height: i32 = 22,
    minimap_width: i32 = 60,

    /// Recompute all region rectangles from window dimensions and visibility state.
    ///
    /// Preconditions:
    ///   - self.window_w > 0 and self.window_h > 0
    ///
    /// Postconditions:
    ///   - All regions in self.regions are non-overlapping
    ///   - Union of all regions covers the full window area
    ///   - Hidden regions (sidebar_visible=false, panel_visible=false) have zero area
    pub fn recompute(self: *LayoutState, width: i32, height: i32) void {
        self.window_w = width;
        self.window_h = height;

        const sb_w: i32 = if (self.sidebar_visible) self.sidebar_width else 0;
        const pn_h: i32 = if (self.panel_visible) self.panel_height else 0;

        // Title bar: full width across the top
        self.regions[@intFromEnum(LayoutRegion.title_bar)] = .{
            .x = 0,
            .y = 0,
            .w = width,
            .h = self.title_bar_height,
        };

        // Content area sits between title bar and status bar (minus panel)
        const content_y = self.title_bar_height;
        const content_h = height - self.title_bar_height - self.status_bar_height - pn_h;

        // Activity bar: left column spanning content height
        self.regions[@intFromEnum(LayoutRegion.activity_bar)] = .{
            .x = 0,
            .y = content_y,
            .w = self.activity_bar_width,
            .h = content_h,
        };

        // Sidebar: next to activity bar (zero width when hidden)
        self.regions[@intFromEnum(LayoutRegion.sidebar)] = .{
            .x = self.activity_bar_width,
            .y = content_y,
            .w = sb_w,
            .h = content_h,
        };

        // Editor zone starts after activity bar + sidebar
        const editor_x = self.activity_bar_width + sb_w;
        const editor_total_w = width - editor_x;
        const editor_w = editor_total_w - self.minimap_width;

        // Editor tabs: spans editor + minimap width
        self.regions[@intFromEnum(LayoutRegion.editor_tabs)] = .{
            .x = editor_x,
            .y = content_y,
            .w = editor_total_w,
            .h = self.editor_tabs_height,
        };

        // Breadcrumbs: below tabs, editor width only (not minimap)
        const breadcrumbs_y = content_y + self.editor_tabs_height;
        self.regions[@intFromEnum(LayoutRegion.editor_breadcrumbs)] = .{
            .x = editor_x,
            .y = breadcrumbs_y,
            .w = editor_w,
            .h = self.breadcrumbs_height,
        };

        // Editor area: main editing surface
        const ed_y = breadcrumbs_y + self.breadcrumbs_height;
        const ed_h = content_h - self.editor_tabs_height - self.breadcrumbs_height;
        self.regions[@intFromEnum(LayoutRegion.editor_area)] = .{
            .x = editor_x,
            .y = ed_y,
            .w = editor_w,
            .h = ed_h,
        };

        // Minimap: right of editor area, same vertical span
        self.regions[@intFromEnum(LayoutRegion.minimap)] = .{
            .x = editor_x + editor_w,
            .y = ed_y,
            .w = self.minimap_width,
            .h = ed_h,
        };

        // Panel: below content area, spans from activity bar to right edge
        self.regions[@intFromEnum(LayoutRegion.panel)] = .{
            .x = self.activity_bar_width,
            .y = content_y + content_h,
            .w = width - self.activity_bar_width,
            .h = pn_h,
        };

        // Status bar: full width at the bottom
        self.regions[@intFromEnum(LayoutRegion.status_bar)] = .{
            .x = 0,
            .y = height - self.status_bar_height,
            .w = width,
            .h = self.status_bar_height,
        };
    }

    /// Returns the Rect for the given region.
    pub fn getRegion(self: *const LayoutState, region: LayoutRegion) Rect {
        return self.regions[@intFromEnum(region)];
    }

    /// Hit-test: returns the LayoutRegion containing the given point, or null.
    /// Checks regions in enum order; first match wins.
    pub fn hitTest(self: *const LayoutState, x: i32, y: i32) ?LayoutRegion {
        inline for (0..REGION_COUNT) |i| {
            if (self.regions[i].contains(x, y)) {
                return @enumFromInt(i);
            }
        }
        return null;
    }
};

// --- Unit Tests ---

const testing = @import("std").testing;

test "recompute - default layout with all regions visible" {
    var layout = LayoutState{};
    layout.recompute(1280, 720);

    // Title bar spans full width
    const tb = layout.getRegion(.title_bar);
    try testing.expectEqual(@as(i32, 0), tb.x);
    try testing.expectEqual(@as(i32, 0), tb.y);
    try testing.expectEqual(@as(i32, 1280), tb.w);
    try testing.expectEqual(@as(i32, 30), tb.h);

    // Status bar at bottom
    const sb = layout.getRegion(.status_bar);
    try testing.expectEqual(@as(i32, 0), sb.x);
    try testing.expectEqual(@as(i32, 698), sb.y);
    try testing.expectEqual(@as(i32, 1280), sb.w);
    try testing.expectEqual(@as(i32, 22), sb.h);

    // Activity bar left column
    const ab = layout.getRegion(.activity_bar);
    try testing.expectEqual(@as(i32, 0), ab.x);
    try testing.expectEqual(@as(i32, 30), ab.y);
    try testing.expectEqual(@as(i32, 48), ab.w);

    // Sidebar next to activity bar
    const side = layout.getRegion(.sidebar);
    try testing.expectEqual(@as(i32, 48), side.x);
    try testing.expectEqual(@as(i32, 250), side.w);

    // Editor area should have positive dimensions
    const ea = layout.getRegion(.editor_area);
    try testing.expect(ea.w > 0);
    try testing.expect(ea.h > 0);
}

test "recompute - sidebar hidden expands editor area" {
    var with_sidebar = LayoutState{};
    with_sidebar.recompute(1280, 720);
    const ea_with = with_sidebar.getRegion(.editor_area);

    var without_sidebar = LayoutState{};
    without_sidebar.sidebar_visible = false;
    without_sidebar.recompute(1280, 720);
    const ea_without = without_sidebar.getRegion(.editor_area);

    // Editor area should be wider when sidebar is hidden
    try testing.expect(ea_without.w > ea_with.w);
    // Sidebar region should have zero width
    const side = without_sidebar.getRegion(.sidebar);
    try testing.expectEqual(@as(i32, 0), side.w);
    // Editor area should start further left
    try testing.expect(ea_without.x < ea_with.x);
}

test "recompute - panel hidden expands editor area" {
    var with_panel = LayoutState{};
    with_panel.recompute(1280, 720);
    const ea_with = with_panel.getRegion(.editor_area);

    var without_panel = LayoutState{};
    without_panel.panel_visible = false;
    without_panel.recompute(1280, 720);
    const ea_without = without_panel.getRegion(.editor_area);

    // Editor area should be taller when panel is hidden
    try testing.expect(ea_without.h > ea_with.h);
    // Panel region should have zero height
    const pn = without_panel.getRegion(.panel);
    try testing.expectEqual(@as(i32, 0), pn.h);
}

test "recompute - both sidebar and panel hidden" {
    var layout = LayoutState{};
    layout.sidebar_visible = false;
    layout.panel_visible = false;
    layout.recompute(1280, 720);

    const side = layout.getRegion(.sidebar);
    try testing.expectEqual(@as(i32, 0), side.w);

    const pn = layout.getRegion(.panel);
    try testing.expectEqual(@as(i32, 0), pn.h);

    // Editor area should be maximized
    const ea = layout.getRegion(.editor_area);
    try testing.expect(ea.w > 0);
    try testing.expect(ea.h > 0);
}

test "recompute - regions are non-overlapping" {
    var layout = LayoutState{};
    layout.recompute(1280, 720);

    // Check that no two visible regions overlap
    var i: usize = 0;
    while (i < REGION_COUNT) : (i += 1) {
        const ri = layout.regions[i];
        if (ri.w == 0 or ri.h == 0) continue;
        var j: usize = i + 1;
        while (j < REGION_COUNT) : (j += 1) {
            const rj = layout.regions[j];
            if (rj.w == 0 or rj.h == 0) continue;
            if (ri.intersects(rj)) {
                // Provide info about which regions overlap
                const region_i: LayoutRegion = @enumFromInt(i);
                const region_j: LayoutRegion = @enumFromInt(j);
                _ = region_i;
                _ = region_j;
                return error.TestUnexpectedResult;
            }
        }
    }
}

test "recompute - full window coverage" {
    var layout = LayoutState{};
    layout.recompute(1280, 720);

    // Every pixel in the window should be covered by some region
    // Test a grid of sample points
    var covered: usize = 0;
    var total: usize = 0;
    var y: i32 = 0;
    while (y < 720) : (y += 10) {
        var x: i32 = 0;
        while (x < 1280) : (x += 10) {
            total += 1;
            if (layout.hitTest(x, y) != null) {
                covered += 1;
            }
        }
    }
    try testing.expectEqual(total, covered);
}

test "hitTest - returns correct region for known points" {
    var layout = LayoutState{};
    layout.recompute(1280, 720);

    // Title bar area
    try testing.expectEqual(LayoutRegion.title_bar, layout.hitTest(640, 15).?);

    // Activity bar
    try testing.expectEqual(LayoutRegion.activity_bar, layout.hitTest(24, 300).?);

    // Status bar
    try testing.expectEqual(LayoutRegion.status_bar, layout.hitTest(640, 705).?);
}

test "hitTest - returns null for out-of-bounds point" {
    var layout = LayoutState{};
    layout.recompute(1280, 720);

    try testing.expectEqual(@as(?LayoutRegion, null), layout.hitTest(-1, 0));
    try testing.expectEqual(@as(?LayoutRegion, null), layout.hitTest(0, -1));
    try testing.expectEqual(@as(?LayoutRegion, null), layout.hitTest(1280, 0));
    try testing.expectEqual(@as(?LayoutRegion, null), layout.hitTest(0, 720));
}

test "hitTest - visibility toggling changes hit results" {
    var layout = LayoutState{};
    layout.recompute(1280, 720);

    // Point in sidebar area
    const sidebar_x = 48 + 125; // middle of sidebar
    const sidebar_y = 300;
    try testing.expectEqual(LayoutRegion.sidebar, layout.hitTest(sidebar_x, sidebar_y).?);

    // Hide sidebar and recompute
    layout.sidebar_visible = false;
    layout.recompute(1280, 720);

    // Same point should now be in a different region (editor area or tabs)
    const result = layout.hitTest(sidebar_x, sidebar_y);
    try testing.expect(result != null);
    try testing.expect(result.? != .sidebar);
}

test "getRegion - returns stored rect" {
    var layout = LayoutState{};
    layout.recompute(1280, 720);

    const tb = layout.getRegion(.title_bar);
    try testing.expectEqual(@as(i32, 0), tb.x);
    try testing.expectEqual(@as(i32, 0), tb.y);
    try testing.expectEqual(@as(i32, 1280), tb.w);
    try testing.expectEqual(@as(i32, 30), tb.h);
}
