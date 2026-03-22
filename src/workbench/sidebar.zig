// src/workbench/sidebar.zig — Sidebar rendering stub
//
// Draws "EXPLORER" header text and placeholder file tree content
// in the sidebar region using GL immediate mode.
// Zero allocators — all stack/comptime storage.

const gl = @import("gl");
const FontAtlas = @import("font_atlas").FontAtlas;
const Color = @import("color").Color;
const Rect = @import("rect").Rect;

// =============================================================================
// Constants
// =============================================================================

/// Sidebar background color (VS Code dark theme #252525).
const SIDEBAR_BG = Color.rgb(0x25, 0x25, 0x25);

/// Header text color.
const HEADER_COLOR = Color.rgb(0xBB, 0xBB, 0xBB);

/// File entry text color.
const TEXT_COLOR = Color.rgb(0xD4, 0xD4, 0xD4);

/// Header height in pixels.
const HEADER_HEIGHT: i32 = 22;

/// Text padding.
const PAD_X: i32 = 12;
const PAD_Y: i32 = 4;

/// Placeholder file entries for the file tree stub.
const PLACEHOLDER_FILES = [_][]const u8{
    "src/",
    "  main.zig",
    "  app.zig",
    "  workbench/",
    "    layout.zig",
    "build.zig",
    "README.md",
};

// =============================================================================
// Sidebar
// =============================================================================

pub const Sidebar = struct {
    /// Render the sidebar into the given region.
    ///
    /// Preconditions:
    ///   - `region` is the sidebar layout rectangle
    ///   - `font_atlas` is initialized with a valid texture
    ///
    /// Postconditions:
    ///   - Background is drawn for the entire sidebar
    ///   - "EXPLORER" header text is rendered at the top
    ///   - Placeholder file tree entries are rendered below
    pub fn render(self: *const Sidebar, region: Rect, font_atlas: *const FontAtlas) void {
        _ = self;

        // Draw background
        renderQuad(region, SIDEBAR_BG);

        if (region.w <= 0 or region.h <= 0) return;

        const cell_h = font_atlas.cell_h;
        if (cell_h <= 0) return;

        // Draw "EXPLORER" header
        font_atlas.renderText(
            "EXPLORER",
            @floatFromInt(region.x + PAD_X),
            @floatFromInt(region.y + PAD_Y),
            HEADER_COLOR,
        );

        // Draw placeholder file tree entries
        const entries_y = region.y + HEADER_HEIGHT + PAD_Y;
        for (PLACEHOLDER_FILES, 0..) |entry, i| {
            const y = entries_y + @as(i32, @intCast(i)) * (cell_h + 2);
            if (y + cell_h > region.y + region.h) break;

            font_atlas.renderText(
                entry,
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

test "Sidebar struct can be default-initialized" {
    const sidebar = Sidebar{};
    _ = sidebar;
}

test "Sidebar background color is #252525" {
    try testing.expectApproxEqAbs(@as(f32, 0x25) / 255.0, SIDEBAR_BG.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0x25) / 255.0, SIDEBAR_BG.g, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0x25) / 255.0, SIDEBAR_BG.b, 0.001);
}

test "PLACEHOLDER_FILES has entries" {
    try testing.expect(PLACEHOLDER_FILES.len > 0);
}
