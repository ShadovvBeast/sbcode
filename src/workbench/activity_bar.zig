// src/workbench/activity_bar.zig — Activity bar rendering stub
//
// Draws 5 icon placeholder squares (explorer, search, git, debug, extensions)
// in the activity bar region using GL immediate mode.
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

/// Icon placeholder size in pixels.
const ICON_SIZE: i32 = 28;

/// Vertical padding between icons.
const ICON_PAD_Y: i32 = 8;

/// Horizontal centering offset (computed from activity bar width 48).
const ICON_PAD_X: i32 = 10;

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

/// Colors for each icon placeholder (distinct for visual identification).
const ICON_COLORS = [ICON_COUNT]Color{
    Color.rgb(0xDC, 0xDC, 0xAA), // explorer — warm yellow
    Color.rgb(0x56, 0x9C, 0xD6), // search — blue
    Color.rgb(0xE2, 0x8A, 0x4D), // git — orange
    Color.rgb(0xD1, 0x6B, 0x6B), // debug — red
    Color.rgb(0x6A, 0x9F, 0x55), // extensions — green
};

// =============================================================================
// ActivityBar
// =============================================================================

pub const ActivityBar = struct {
    active_icon: u8 = 0,

    /// Render the activity bar into the given region.
    ///
    /// Preconditions:
    ///   - `region` is the activity_bar layout rectangle
    ///   - `font_atlas` is initialized (unused for icon placeholders)
    ///
    /// Postconditions:
    ///   - Background is drawn for the entire activity bar
    ///   - 5 colored icon placeholder squares are drawn vertically
    pub fn render(self: *const ActivityBar, region: Rect, font_atlas: *const FontAtlas) void {
        _ = font_atlas;

        // Draw background
        renderQuad(region, ACTIVITY_BAR_BG);

        // Draw icon placeholders vertically centered
        const start_y = region.y + ICON_PAD_Y;
        const icon_x = region.x + ICON_PAD_X;

        var i: usize = 0;
        while (i < ICON_COUNT) : (i += 1) {
            const icon_y = start_y + @as(i32, @intCast(i)) * (ICON_SIZE + ICON_PAD_Y);
            const icon_rect = Rect{
                .x = icon_x,
                .y = icon_y,
                .w = ICON_SIZE,
                .h = ICON_SIZE,
            };

            // Highlight active icon with full opacity, others slightly dimmed
            var color = ICON_COLORS[i];
            if (i != self.active_icon) {
                color.a = 0.5;
            }

            renderQuad(icon_rect, color);
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

test "ICON_COLORS has correct count" {
    try testing.expectEqual(@as(usize, 5), ICON_COLORS.len);
}

test "Activity bar background color is #333333" {
    try testing.expectApproxEqAbs(@as(f32, 0x33) / 255.0, ACTIVITY_BAR_BG.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0x33) / 255.0, ACTIVITY_BAR_BG.g, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0x33) / 255.0, ACTIVITY_BAR_BG.b, 0.001);
}
