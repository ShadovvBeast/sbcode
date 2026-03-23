// src/workbench/activity_bar.zig — Activity bar rendering (VS Code style)
//
// Draws 5 icon buttons vertically with text-based icon symbols,
// active indicator bar on the left, and proper VS Code dark theme colors.
// Zero allocators — all stack/comptime storage.

const gl = @import("gl");
const FontAtlas = @import("font_atlas").FontAtlas;
const Color = @import("color").Color;
const Rect = @import("rect").Rect;

// =============================================================================
// Constants
// =============================================================================

/// Activity bar background color (VS Code dark theme #333333).
const ACTIVITY_BAR_BG = Color.rgb(0x33, 0x33, 0x33);

/// Active indicator bar color (white).
const ACTIVE_INDICATOR = Color.rgb(0xFF, 0xFF, 0xFF);

/// Icon color when active.
const ICON_ACTIVE_COLOR = Color.rgb(0xFF, 0xFF, 0xFF);

/// Icon color when inactive (dimmed).
const ICON_INACTIVE_COLOR = Color.rgb(0x85, 0x85, 0x85);

/// Icon button height (each icon occupies this vertical space).
const ICON_BTN_H: i32 = 48;

/// Active indicator bar width (left edge).
const INDICATOR_W: i32 = 2;

/// Number of activity bar icons.
pub const ICON_COUNT: usize = 5;

/// Icon identifiers for the activity bar buttons.
pub const ActivityIcon = enum(u8) {
    explorer = 0,
    search = 1,
    git = 2,
    debug = 3,
    extensions = 4,
};

/// Text symbols for each icon (single chars that suggest the icon meaning).
/// Using ASCII art approximations since we only have monospace font.
const ICON_SYMBOLS = [ICON_COUNT][]const u8{
    "{}", // explorer (files)
    "?", // search (magnifying glass)
    "<>", // git (branch)
    "|>", // debug (play)
    "[]", // extensions (blocks)
};

// =============================================================================
// ActivityBar
// =============================================================================

pub const ActivityBar = struct {
    active_icon: u8 = 0,

    /// Render the activity bar into the given region.
    pub fn render(self: *const ActivityBar, region: Rect, font_atlas: *const FontAtlas) void {
        // Draw background
        renderQuad(region, ACTIVITY_BAR_BG);

        if (region.w <= 0 or region.h <= 0) return;

        // Derive icon button height from font size for DPI scaling
        const icon_btn_h: i32 = font_atlas.cell_h * 3; // ~3x cell height

        // Draw each icon button
        var i: usize = 0;
        while (i < ICON_COUNT) : (i += 1) {
            const btn_y = region.y + @as(i32, @intCast(i)) * icon_btn_h;
            const is_active = (i == self.active_icon);
            const color = if (is_active) ICON_ACTIVE_COLOR else ICON_INACTIVE_COLOR;

            // Active indicator bar on the left edge
            if (is_active) {
                renderQuad(Rect{
                    .x = region.x,
                    .y = btn_y,
                    .w = INDICATOR_W,
                    .h = icon_btn_h,
                }, ACTIVE_INDICATOR);
            }

            // Render icon symbol centered in the button area
            const symbol = ICON_SYMBOLS[i];
            const sym_w = @as(i32, @intCast(symbol.len)) * font_atlas.cell_w;
            const text_x = region.x + @divTrunc(region.w - sym_w, 2);
            const text_y = btn_y + @divTrunc(icon_btn_h - font_atlas.cell_h, 2);

            font_atlas.renderText(symbol, @floatFromInt(text_x), @floatFromInt(text_y), color);
        }

        // Draw right border (1px separator)
        renderQuad(Rect{
            .x = region.x + region.w - 1,
            .y = region.y,
            .w = 1,
            .h = region.h,
        }, Color.rgb(0x2B, 0x2B, 0x2B));
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

test "ActivityBar default initialization" {
    const bar = ActivityBar{};
    try testing.expectEqual(@as(u8, 0), bar.active_icon);
}

test "ICON_COUNT is 5" {
    try testing.expectEqual(@as(usize, 5), ICON_COUNT);
}

test "ActivityIcon enum values" {
    try testing.expectEqual(@as(u8, 0), @intFromEnum(ActivityIcon.explorer));
    try testing.expectEqual(@as(u8, 1), @intFromEnum(ActivityIcon.search));
    try testing.expectEqual(@as(u8, 2), @intFromEnum(ActivityIcon.git));
    try testing.expectEqual(@as(u8, 3), @intFromEnum(ActivityIcon.debug));
    try testing.expectEqual(@as(u8, 4), @intFromEnum(ActivityIcon.extensions));
}

test "Activity bar background color is #333333" {
    try testing.expectApproxEqAbs(@as(f32, 0x33) / 255.0, ACTIVITY_BAR_BG.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0x33) / 255.0, ACTIVITY_BAR_BG.g, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0x33) / 255.0, ACTIVITY_BAR_BG.b, 0.001);
}

test "ICON_SYMBOLS has correct count" {
    try testing.expectEqual(@as(usize, 5), ICON_SYMBOLS.len);
}
