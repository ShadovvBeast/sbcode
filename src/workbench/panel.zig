// src/workbench/panel.zig — Panel rendering stub
//
// Draws "TERMINAL" header text and placeholder terminal content
// in the panel region using GL immediate mode.
// Zero allocators — all stack/comptime storage.

const gl = @import("gl");
const FontAtlas = @import("font_atlas").FontAtlas;
const Color = @import("color").Color;
const Rect = @import("rect").Rect;

// =============================================================================
// Constants
// =============================================================================

/// Panel background color (VS Code dark theme #1E1E1E).
const PANEL_BG = Color.rgb(0x1E, 0x1E, 0x1E);

/// Tab bar background at the top of the panel.
const PANEL_TAB_BG = Color.rgb(0x25, 0x25, 0x25);

/// Active tab indicator color.
const TAB_ACTIVE_COLOR = Color.rgb(0xD4, 0xD4, 0xD4);

/// Header/tab text color.
const HEADER_COLOR = Color.rgb(0xBB, 0xBB, 0xBB);

/// Terminal text color.
const TEXT_COLOR = Color.rgb(0xCC, 0xCC, 0xCC);

/// Tab bar height.
const TAB_HEIGHT: i32 = 28;

/// Text padding.
const PAD_X: i32 = 12;
const PAD_Y: i32 = 6;

/// Panel tab labels.
const TAB_LABELS = [_][]const u8{ "TERMINAL", "OUTPUT", "PROBLEMS" };

/// Placeholder terminal lines.
const PLACEHOLDER_LINES = [_][]const u8{
    "PS C:\\project> zig build test",
    "All 42 tests passed.",
    "PS C:\\project> _",
};

// =============================================================================
// Panel
// =============================================================================

pub const Panel = struct {
    active_tab: u8 = 0,

    /// Render the panel into the given region.
    ///
    /// Preconditions:
    ///   - `region` is the panel layout rectangle
    ///   - `font_atlas` is initialized with a valid texture
    ///
    /// Postconditions:
    ///   - Background is drawn for the entire panel
    ///   - Tab bar with TERMINAL/OUTPUT/PROBLEMS tabs is rendered
    ///   - Placeholder terminal content is rendered below
    pub fn render(self: *const Panel, region: Rect, font_atlas: *const FontAtlas) void {
        // Draw background
        renderQuad(region, PANEL_BG);

        if (region.w <= 0 or region.h <= 0) return;

        const cell_h = font_atlas.cell_h;
        const cell_w = font_atlas.cell_w;
        if (cell_h <= 0 or cell_w <= 0) return;

        // Draw tab bar background
        const tab_bar_rect = Rect{
            .x = region.x,
            .y = region.y,
            .w = region.w,
            .h = TAB_HEIGHT,
        };
        renderQuad(tab_bar_rect, PANEL_TAB_BG);

        // Draw tab labels
        var tab_x = region.x + PAD_X;
        for (TAB_LABELS, 0..) |label, i| {
            const color = if (i == self.active_tab) TAB_ACTIVE_COLOR else HEADER_COLOR;
            font_atlas.renderText(
                label,
                @floatFromInt(tab_x),
                @floatFromInt(region.y + PAD_Y),
                color,
            );
            tab_x += @as(i32, @intCast(label.len)) * cell_w + PAD_X;
        }

        // Draw placeholder terminal content
        const content_y = region.y + TAB_HEIGHT + PAD_Y;
        for (PLACEHOLDER_LINES, 0..) |line, i| {
            const y = content_y + @as(i32, @intCast(i)) * (cell_h + 2);
            if (y + cell_h > region.y + region.h) break;

            font_atlas.renderText(
                line,
                @floatFromInt(region.x + PAD_X),
                @floatFromInt(y),
                TEXT_COLOR,
            );
        }
    }
};

// =============================================================================
// GL rendering helper
// =============================================================================

fn renderQuad(region: Rect, color: Color) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(color.r, color.g, color.b, color.a);

    const x0: f32 = @floatFromInt(region.x);
    const y0: f32 = @floatFromInt(region.y);
    const x1: f32 = @floatFromInt(region.x + region.w);
    const y1: f32 = @floatFromInt(region.y + region.h);

    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(x0, y0);
    gl.glVertex2f(x1, y0);
    gl.glVertex2f(x1, y1);
    gl.glVertex2f(x0, y1);
    gl.glEnd();
}

// =============================================================================
// Tests
// =============================================================================

const testing = @import("std").testing;

test "Panel default initialization" {
    const panel = Panel{};
    try testing.expectEqual(@as(u8, 0), panel.active_tab);
}

test "Panel background color is #1E1E1E" {
    try testing.expectApproxEqAbs(@as(f32, 0x1E) / 255.0, PANEL_BG.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0x1E) / 255.0, PANEL_BG.g, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0x1E) / 255.0, PANEL_BG.b, 0.001);
}

test "TAB_LABELS has 3 entries" {
    try testing.expectEqual(@as(usize, 3), TAB_LABELS.len);
}

test "PLACEHOLDER_LINES has entries" {
    try testing.expect(PLACEHOLDER_LINES.len > 0);
}
