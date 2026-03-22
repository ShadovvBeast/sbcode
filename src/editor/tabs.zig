// src/editor/tabs.zig — Reusable tab bar for the editor area
//
// Manages a fixed list of open tabs with open/close/switch operations.
// Renders the tab strip in the editor_tabs layout region using GL immediate mode.
// Zero allocators — all stack/comptime storage.

const gl = @import("gl");
const FontAtlas = @import("font_atlas").FontAtlas;
const Color = @import("color").Color;
const Rect = @import("rect").Rect;

// =============================================================================
// Constants
// =============================================================================

/// Maximum number of open tabs.
pub const MAX_TABS: u8 = 32;

/// Maximum label length per tab (bytes).
const MAX_LABEL_LEN: usize = 128;

/// Tab width in pixels for rendering.
const TAB_WIDTH: i32 = 120;

/// Horizontal text padding inside a tab.
const TAB_TEXT_PAD_X: i32 = 8;

/// Vertical text padding inside a tab.
const TAB_TEXT_PAD_Y: i32 = 8;

// VS Code dark theme tab colors
const TAB_ACTIVE_BG = Color.rgb(0x1E, 0x1E, 0x1E);
const TAB_INACTIVE_BG = Color.rgb(0x2D, 0x2D, 0x2D);
const TAB_TEXT_COLOR = Color.rgb(0xD4, 0xD4, 0xD4);

// =============================================================================
// Tab
// =============================================================================

pub const Tab = struct {
    label: [MAX_LABEL_LEN]u8 = undefined,
    label_len: u8 = 0,
    active: bool = false,
    dirty: bool = false,
};

// =============================================================================
// TabBar
// =============================================================================

pub const TabBar = struct {
    tabs: [MAX_TABS]Tab = [_]Tab{.{}} ** MAX_TABS,
    tab_count: u8 = 0,
    active_tab: u8 = 0,

    /// Open a new tab with the given label. Returns the tab index, or null if full.
    ///
    /// Preconditions:
    ///   - `label.len` <= MAX_LABEL_LEN
    ///
    /// Postconditions:
    ///   - A new tab is appended with the given label
    ///   - The new tab becomes the active tab
    ///   - Returns the index of the new tab, or null if MAX_TABS reached
    pub fn open(self: *TabBar, label: []const u8) ?u8 {
        if (self.tab_count >= MAX_TABS) return null;

        const idx = self.tab_count;
        const copy_len = @min(label.len, MAX_LABEL_LEN);

        self.tabs[idx] = .{
            .label_len = @intCast(copy_len),
            .active = true,
            .dirty = false,
        };
        @memcpy(self.tabs[idx].label[0..copy_len], label[0..copy_len]);

        // Deactivate previous active tab
        if (self.tab_count > 0) {
            self.tabs[self.active_tab].active = false;
        }

        self.active_tab = idx;
        self.tab_count += 1;
        return idx;
    }

    /// Close the tab at the given index. Returns false if index is out of bounds.
    ///
    /// Postconditions:
    ///   - Tab at `index` is removed, subsequent tabs shift left
    ///   - active_tab is adjusted if needed
    ///   - tab_count is decremented
    pub fn close(self: *TabBar, index: u8) bool {
        if (index >= self.tab_count) return false;

        // Shift tabs left
        var i: u8 = index;
        while (i + 1 < self.tab_count) : (i += 1) {
            self.tabs[i] = self.tabs[i + 1];
        }
        self.tab_count -= 1;

        // Clear the now-unused slot
        self.tabs[self.tab_count] = .{};

        // Adjust active tab
        if (self.tab_count == 0) {
            self.active_tab = 0;
        } else if (self.active_tab >= self.tab_count) {
            self.active_tab = self.tab_count - 1;
            self.tabs[self.active_tab].active = true;
        } else if (index == self.active_tab or (index < self.active_tab)) {
            // If we closed the active tab or one before it, adjust
            if (index < self.active_tab) {
                self.active_tab -= 1;
            } else {
                // Closed the active tab — activate the one now at this index
                if (self.active_tab < self.tab_count) {
                    self.tabs[self.active_tab].active = true;
                }
            }
        }

        return true;
    }

    /// Switch to the tab at the given index. Returns false if index is out of bounds.
    ///
    /// Postconditions:
    ///   - Previous active tab is deactivated
    ///   - Tab at `index` becomes active
    pub fn switchTo(self: *TabBar, index: u8) bool {
        if (index >= self.tab_count) return false;
        if (self.tab_count == 0) return false;

        self.tabs[self.active_tab].active = false;
        self.active_tab = index;
        self.tabs[index].active = true;
        return true;
    }

    /// Render the tab strip into the given region.
    ///
    /// Preconditions:
    ///   - `region` is the editor_tabs layout rectangle
    ///   - `font_atlas` is initialized with a valid texture
    ///
    /// Postconditions:
    ///   - Background is drawn for the entire tab strip
    ///   - Each tab is drawn with active/inactive background color
    ///   - Tab labels are rendered with the font atlas
    pub fn render(self: *const TabBar, region: Rect, font_atlas: *const FontAtlas) void {
        // Draw strip background
        renderQuad(region, TAB_INACTIVE_BG);

        if (self.tab_count == 0) return;

        var t: u8 = 0;
        while (t < self.tab_count) : (t += 1) {
            const tab = &self.tabs[t];
            const bg = if (t == self.active_tab) TAB_ACTIVE_BG else TAB_INACTIVE_BG;

            const tab_rect = Rect{
                .x = region.x + @as(i32, t) * TAB_WIDTH,
                .y = region.y,
                .w = TAB_WIDTH,
                .h = region.h,
            };
            renderQuad(tab_rect, bg);

            if (tab.label_len > 0) {
                font_atlas.renderText(
                    tab.label[0..tab.label_len],
                    @floatFromInt(tab_rect.x + TAB_TEXT_PAD_X),
                    @floatFromInt(tab_rect.y + TAB_TEXT_PAD_Y),
                    TAB_TEXT_COLOR,
                );
            }
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

test "TabBar default initialization" {
    const bar = TabBar{};
    try testing.expectEqual(@as(u8, 0), bar.tab_count);
    try testing.expectEqual(@as(u8, 0), bar.active_tab);
}

test "TabBar.open adds a tab and activates it" {
    var bar = TabBar{};
    const idx = bar.open("main.zig");
    try testing.expect(idx != null);
    try testing.expectEqual(@as(u8, 0), idx.?);
    try testing.expectEqual(@as(u8, 1), bar.tab_count);
    try testing.expectEqual(@as(u8, 0), bar.active_tab);
    try testing.expect(bar.tabs[0].active);
    try testing.expect(testing.mem.eql(u8, "main.zig", bar.tabs[0].label[0..bar.tabs[0].label_len]));
}

test "TabBar.open multiple tabs activates the latest" {
    var bar = TabBar{};
    _ = bar.open("file1.zig");
    const idx2 = bar.open("file2.zig");
    try testing.expectEqual(@as(u8, 1), idx2.?);
    try testing.expectEqual(@as(u8, 2), bar.tab_count);
    try testing.expectEqual(@as(u8, 1), bar.active_tab);
    try testing.expect(!bar.tabs[0].active);
    try testing.expect(bar.tabs[1].active);
}

test "TabBar.open returns null when full" {
    var bar = TabBar{};
    var i: u8 = 0;
    while (i < MAX_TABS) : (i += 1) {
        try testing.expect(bar.open("tab") != null);
    }
    try testing.expectEqual(@as(u8, MAX_TABS), bar.tab_count);
    try testing.expect(bar.open("overflow") == null);
    try testing.expectEqual(@as(u8, MAX_TABS), bar.tab_count);
}

test "TabBar.close removes a tab" {
    var bar = TabBar{};
    _ = bar.open("a.zig");
    _ = bar.open("b.zig");
    _ = bar.open("c.zig");
    try testing.expectEqual(@as(u8, 3), bar.tab_count);

    try testing.expect(bar.close(1)); // close "b.zig"
    try testing.expectEqual(@as(u8, 2), bar.tab_count);
    // "c.zig" should have shifted to index 1
    try testing.expect(testing.mem.eql(u8, "c.zig", bar.tabs[1].label[0..bar.tabs[1].label_len]));
}

test "TabBar.close returns false for out-of-bounds" {
    var bar = TabBar{};
    try testing.expect(!bar.close(0));
    _ = bar.open("x.zig");
    try testing.expect(!bar.close(1));
    try testing.expect(!bar.close(5));
}

test "TabBar.close adjusts active_tab when closing before active" {
    var bar = TabBar{};
    _ = bar.open("a.zig");
    _ = bar.open("b.zig");
    _ = bar.open("c.zig");
    // active_tab is 2 (c.zig)
    try testing.expectEqual(@as(u8, 2), bar.active_tab);

    try testing.expect(bar.close(0)); // close "a.zig"
    // active_tab should shift from 2 to 1
    try testing.expectEqual(@as(u8, 1), bar.active_tab);
    try testing.expectEqual(@as(u8, 2), bar.tab_count);
}

test "TabBar.close last tab results in empty bar" {
    var bar = TabBar{};
    _ = bar.open("only.zig");
    try testing.expect(bar.close(0));
    try testing.expectEqual(@as(u8, 0), bar.tab_count);
    try testing.expectEqual(@as(u8, 0), bar.active_tab);
}

test "TabBar.switchTo changes active tab" {
    var bar = TabBar{};
    _ = bar.open("a.zig");
    _ = bar.open("b.zig");
    _ = bar.open("c.zig");
    try testing.expectEqual(@as(u8, 2), bar.active_tab);

    try testing.expect(bar.switchTo(0));
    try testing.expectEqual(@as(u8, 0), bar.active_tab);
    try testing.expect(bar.tabs[0].active);
    try testing.expect(!bar.tabs[2].active);
}

test "TabBar.switchTo returns false for out-of-bounds" {
    var bar = TabBar{};
    try testing.expect(!bar.switchTo(0)); // empty bar
    _ = bar.open("a.zig");
    try testing.expect(!bar.switchTo(1));
    try testing.expect(!bar.switchTo(5));
}

test "TabBar.open sets dirty to false" {
    var bar = TabBar{};
    _ = bar.open("test.zig");
    try testing.expect(!bar.tabs[0].dirty);
}

test "Tab default initialization" {
    const tab = Tab{};
    try testing.expectEqual(@as(u8, 0), tab.label_len);
    try testing.expect(!tab.active);
    try testing.expect(!tab.dirty);
}

test "MAX_TABS constant is 32" {
    try testing.expectEqual(@as(u8, 32), MAX_TABS);
}
