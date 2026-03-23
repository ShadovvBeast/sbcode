// src/workbench/sidebar.zig — Sidebar rendering (VS Code style file explorer)
//
// Draws section header with "EXPLORER" title, file tree entries with
// indentation, and proper VS Code dark theme colors and separators.
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

/// Section header background (slightly lighter).
const SECTION_HEADER_BG = Color.rgb(0x38, 0x38, 0x38);

/// Section header text color (uppercase labels).
const SECTION_HEADER_COLOR = Color.rgb(0xBB, 0xBB, 0xBB);

/// File entry text color.
const TEXT_COLOR = Color.rgb(0xCC, 0xCC, 0xCC);

/// Dimmed text color for hints.
const DIM_COLOR = Color.rgb(0x6A, 0x6A, 0x6A);

/// Separator line color.
const SEPARATOR_COLOR = Color.rgb(0x2B, 0x2B, 0x2B);

/// Section header height.
const SECTION_H: i32 = 22;

/// File entry row height.
const ROW_H: i32 = 22;

/// Text padding.
const PAD_X: i32 = 20;
const PAD_Y: i32 = 3;

/// Maximum number of file entries in the sidebar.
pub const MAX_ENTRIES: usize = 64;

/// Maximum label length per entry.
pub const MAX_LABEL_LEN: usize = 64;

// =============================================================================
// Sidebar
// =============================================================================

pub const Sidebar = struct {
    entries: [MAX_ENTRIES][MAX_LABEL_LEN]u8 = undefined,
    entry_lens: [MAX_ENTRIES]u8 = [_]u8{0} ** MAX_ENTRIES,
    entry_count: u8 = 0,

    // Tree node properties for file explorer
    is_dir: [MAX_ENTRIES]bool = [_]bool{false} ** MAX_ENTRIES,
    indent_level: [MAX_ENTRIES]u8 = [_]u8{0} ** MAX_ENTRIES,
    expanded: [MAX_ENTRIES]bool = [_]bool{false} ** MAX_ENTRIES,

    // Search view state
    search_view: bool = false,
    search_query: [256]u8 = undefined,
    search_query_len: u16 = 0,

    /// Add a file entry to the sidebar list.
    pub fn addEntry(self: *Sidebar, label: []const u8) void {
        self.addTreeEntry(label, false, 0, false);
    }

    /// Add a tree entry with directory/indent/expanded properties.
    pub fn addTreeEntry(self: *Sidebar, label: []const u8, dir: bool, indent: u8, exp: bool) void {
        if (self.entry_count >= MAX_ENTRIES) return;
        const copy_len: u8 = @intCast(@min(label.len, MAX_LABEL_LEN));
        @memcpy(self.entries[self.entry_count][0..copy_len], label[0..copy_len]);
        self.entry_lens[self.entry_count] = copy_len;
        self.is_dir[self.entry_count] = dir;
        self.indent_level[self.entry_count] = indent;
        self.expanded[self.entry_count] = exp;
        self.entry_count += 1;
    }

    /// Clear all entries.
    pub fn clearEntries(self: *Sidebar) void {
        self.entry_count = 0;
    }

    /// Render the sidebar into the given region.
    pub fn render(self: *const Sidebar, region: Rect, font_atlas: *const FontAtlas) void {
        // Draw background
        renderQuad(region, SIDEBAR_BG);

        if (region.w <= 0 or region.h <= 0) return;

        const cell_h = font_atlas.cell_h;
        if (cell_h <= 0) return;

        // Top separator line
        renderQuad(Rect{ .x = region.x, .y = region.y, .w = region.w, .h = 1 }, SEPARATOR_COLOR);

        // Section header: "EXPLORER"
        const header_rect = Rect{
            .x = region.x,
            .y = region.y + 1,
            .w = region.w,
            .h = SECTION_H,
        };
        renderQuad(header_rect, SIDEBAR_BG);
        font_atlas.renderText(
            "EXPLORER",
            @floatFromInt(region.x + PAD_X),
            @floatFromInt(header_rect.y + PAD_Y),
            SECTION_HEADER_COLOR,
        );

        // Collapsible section: project name header
        const project_header_y = header_rect.y + SECTION_H;
        const project_rect = Rect{
            .x = region.x,
            .y = project_header_y,
            .w = region.w,
            .h = SECTION_H,
        };
        renderQuad(project_rect, SECTION_HEADER_BG);
        font_atlas.renderText(
            "> SBCODE",
            @floatFromInt(region.x + 8),
            @floatFromInt(project_header_y + PAD_Y),
            SECTION_HEADER_COLOR,
        );

        // Separator below project header
        renderQuad(Rect{
            .x = region.x,
            .y = project_header_y + SECTION_H,
            .w = region.w,
            .h = 1,
        }, SEPARATOR_COLOR);

        const entries_y = project_header_y + SECTION_H + 1;

        if (self.entry_count == 0) {
            // Show hint when no files are loaded
            font_atlas.renderText(
                "No folder opened",
                @floatFromInt(region.x + PAD_X),
                @floatFromInt(entries_y + 8),
                DIM_COLOR,
            );
            font_atlas.renderText(
                "Open a folder to",
                @floatFromInt(region.x + PAD_X),
                @floatFromInt(entries_y + 8 + cell_h + 4),
                DIM_COLOR,
            );
            font_atlas.renderText(
                "start working",
                @floatFromInt(region.x + PAD_X),
                @floatFromInt(entries_y + 8 + (cell_h + 4) * 2),
                DIM_COLOR,
            );
            return;
        }

        // Draw file entries from state
        var i: u8 = 0;
        while (i < self.entry_count) : (i += 1) {
            const y = entries_y + @as(i32, i) * ROW_H;
            if (y + ROW_H > region.y + region.h) break;

            const label = self.entries[i][0..self.entry_lens[i]];
            font_atlas.renderText(
                label,
                @floatFromInt(region.x + PAD_X + 8),
                @floatFromInt(y + PAD_Y),
                TEXT_COLOR,
            );
        }

        // Right border separator
        renderQuad(Rect{
            .x = region.x + region.w - 1,
            .y = region.y,
            .w = 1,
            .h = region.h,
        }, SEPARATOR_COLOR);
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
    try testing.expectEqual(@as(u8, 0), sidebar.entry_count);
}

test "Sidebar background color is #252525" {
    try testing.expectApproxEqAbs(@as(f32, 0x25) / 255.0, SIDEBAR_BG.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0x25) / 255.0, SIDEBAR_BG.g, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0x25) / 255.0, SIDEBAR_BG.b, 0.001);
}

test "Sidebar addEntry stores entries" {
    var sidebar = Sidebar{};
    sidebar.addEntry("main.zig");
    sidebar.addEntry("build.zig");
    try testing.expectEqual(@as(u8, 2), sidebar.entry_count);
    const mem = @import("std").mem;
    try testing.expect(mem.eql(u8, "main.zig", sidebar.entries[0][0..sidebar.entry_lens[0]]));
    try testing.expect(mem.eql(u8, "build.zig", sidebar.entries[1][0..sidebar.entry_lens[1]]));
}

test "Sidebar clearEntries resets count" {
    var sidebar = Sidebar{};
    sidebar.addEntry("file.zig");
    try testing.expectEqual(@as(u8, 1), sidebar.entry_count);
    sidebar.clearEntries();
    try testing.expectEqual(@as(u8, 0), sidebar.entry_count);
}

test "Sidebar addEntry respects MAX_ENTRIES" {
    var sidebar = Sidebar{};
    var i: u8 = 0;
    while (i < MAX_ENTRIES + 5) : (i += 1) {
        sidebar.addEntry("f");
    }
    try testing.expectEqual(@as(u8, MAX_ENTRIES), sidebar.entry_count);
}
