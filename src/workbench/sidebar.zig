// src/workbench/sidebar.zig — Sidebar with Explorer + Search views
//
// Explorer: file tree with icons, chevrons, indentation, hover/selection.
// Search: search input, replace input, regex/case/word toggles, match results.
// Uses shared rendering atoms from file_tree module.
// Zero allocators — all stack/comptime storage.

const gl = @import("gl");
const FontAtlas = @import("font_atlas").FontAtlas;
const Color = @import("color").Color;
const Rect = @import("rect").Rect;
const ft = @import("file_tree");
const file_icons = @import("file_icons");
const FileIconCache = file_icons.FileIconCache;
const manifest = @import("manifest");
const ext = @import("extension");

const SIDEBAR_BG = Color.rgb(0x25, 0x25, 0x25);
const SECTION_HEADER_BG = Color.rgb(0x38, 0x38, 0x38);
const SECTION_HEADER_COLOR = Color.rgb(0xBB, 0xBB, 0xBB);
const DIM_COLOR = Color.rgb(0x6A, 0x6A, 0x6A);
const HOVER_BG = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 0.06 };
const SELECTED_BG = Color{ .r = 0.02, .g = 0.22, .b = 0.37, .a = 1.0 };
const SELECTED_ACCENT = Color{ .r = 0.0, .g = 0.48, .b = 0.80, .a = 0.5 };
const INDENT_GUIDE_COLOR = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 0.06 };
const CHEVRON_COLOR = Color.rgb(0x96, 0x96, 0x96);
const SCROLLBAR_BG = Color{ .r = 0.20, .g = 0.20, .b = 0.20, .a = 0.5 };
const SCROLLBAR_FG = Color{ .r = 0.45, .g = 0.45, .b = 0.45, .a = 0.7 };
const INPUT_BG = Color.rgb(0x3C, 0x3C, 0x3C);
const INPUT_BORDER = Color{ .r = 0.0, .g = 0.48, .b = 0.80, .a = 0.6 };
const INPUT_BORDER_INACTIVE = Color.rgb(0x4A, 0x4A, 0x4A);
const TEXT_COLOR = Color.rgb(0xCC, 0xCC, 0xCC);
const ACCENT_COLOR = Color{ .r = 0.0, .g = 0.48, .b = 0.80, .a = 1.0 };
const TOGGLE_ON_BG = Color{ .r = 0.0, .g = 0.48, .b = 0.80, .a = 0.4 };
const TOGGLE_OFF_BG = Color{ .r = 0.30, .g = 0.30, .b = 0.30, .a = 1.0 };
const MATCH_FILE_COLOR = Color.rgb(0xCC, 0xCC, 0xCC);
const MATCH_LINE_COLOR = Color.rgb(0x80, 0x80, 0x80);
const MATCH_TEXT_COLOR = Color.rgb(0xAA, 0xAA, 0xAA);
const MATCH_HIGHLIGHT_BG = Color{ .r = 0.90, .g = 0.70, .b = 0.20, .a = 0.3 };

// Extensions view colors
const EXT_INSTALLED_BG = Color{ .r = 0.0, .g = 0.48, .b = 0.80, .a = 0.25 };
const EXT_ACTIVE_COLOR = Color{ .r = 0.30, .g = 0.85, .b = 0.40, .a = 1.0 };
const EXT_INACTIVE_COLOR = Color{ .r = 0.60, .g = 0.60, .b = 0.60, .a = 1.0 };
const EXT_BTN_BG = Color{ .r = 0.0, .g = 0.48, .b = 0.80, .a = 0.8 };
const EXT_BTN_HOVER_BG = Color{ .r = 0.0, .g = 0.55, .b = 0.90, .a = 0.9 };
const EXT_BTN_DANGER_BG = Color{ .r = 0.70, .g = 0.20, .b = 0.20, .a = 0.8 };
const EXT_VERSION_COLOR = Color.rgb(0x80, 0x80, 0x80);

/// Number of compiled-in extensions from the manifest.
pub const EXT_COUNT: usize = manifest.count;

pub const MAX_ENTRIES: usize = 64;
pub const MAX_LABEL_LEN: usize = 64;
pub const MAX_SEARCH_LEN: usize = 256;
pub const MAX_MATCHES: usize = 128;
pub const MAX_MATCH_TEXT: usize = 80;
pub const MAX_PATH_W: usize = 512;

pub const SearchMatch = struct {
    file_idx: u8 = 0,
    line_num: u32 = 0,
    col: u16 = 0,
    match_len: u16 = 0,
    text: [MAX_MATCH_TEXT]u8 = undefined,
    text_len: u8 = 0,
};

pub const SearchField = enum(u8) { search = 0, replace = 1 };

/// Explorer toolbar actions (icon buttons in header).
pub const ToolbarAction = enum(u8) {
    new_file = 0,
    new_folder = 1,
    refresh = 2,
    collapse_all = 3,
};

pub const TOOLBAR_BTN_COUNT: u8 = 4;

pub const Sidebar = struct {
    // Explorer state
    entries: [MAX_ENTRIES][MAX_LABEL_LEN]u8 = undefined,
    entry_lens: [MAX_ENTRIES]u8 = [_]u8{0} ** MAX_ENTRIES,
    entry_count: u8 = 0,
    is_dir: [MAX_ENTRIES]bool = [_]bool{false} ** MAX_ENTRIES,
    indent_level: [MAX_ENTRIES]u8 = [_]u8{0} ** MAX_ENTRIES,
    expanded: [MAX_ENTRIES]bool = [_]bool{false} ** MAX_ENTRIES,
    project_name: [MAX_LABEL_LEN]u8 = undefined,
    project_name_len: u8 = 0,
    hover_row: i16 = -1,
    selected_row: i16 = -1,
    scroll_top: u16 = 0,

    // Full UTF-16 paths for each entry (for file open / operations)
    entry_paths_w: [MAX_ENTRIES][MAX_PATH_W]u16 = undefined,
    entry_path_lens: [MAX_ENTRIES]u16 = [_]u16{0} ** MAX_ENTRIES,

    // Inline rename state
    rename_active: bool = false,
    rename_row: i16 = -1,
    rename_buf: [MAX_LABEL_LEN]u8 = undefined,
    rename_len: u8 = 0,

    // Search state
    search_query: [MAX_SEARCH_LEN]u8 = undefined,
    search_query_len: u16 = 0,
    replace_query: [MAX_SEARCH_LEN]u8 = undefined,
    replace_query_len: u16 = 0,
    search_active_field: SearchField = .search,
    search_regex: bool = false,
    search_case_sensitive: bool = false,
    search_whole_word: bool = false,
    search_replace_visible: bool = true,
    search_matches: [MAX_MATCHES]SearchMatch = undefined,
    search_match_count: u16 = 0,
    search_scroll_top: u16 = 0,
    search_hover_row: i16 = -1,
    search_selected_row: i16 = -1,

    // Toolbar hover state (-1 = none, 0..3 = button index)
    toolbar_hover: i8 = -1,

    // Extensions view state
    ext_installed: [EXT_COUNT]bool = [_]bool{true} ** EXT_COUNT,
    ext_active: [EXT_COUNT]bool = [_]bool{true} ** EXT_COUNT,
    ext_scroll_top: u16 = 0,
    ext_hover_row: i16 = -1,
    ext_selected_row: i16 = -1,
    ext_filter: [MAX_SEARCH_LEN]u8 = undefined,
    ext_filter_len: u16 = 0,
    ext_hover_btn: i8 = -1, // -1=none, 0=install/uninstall, 1=enable/disable

    // =========================================================================
    // Extensions view methods
    // =========================================================================

    /// Append a character to the extensions filter.
    pub fn appendExtFilterChar(self: *Sidebar, ch: u8) void {
        if (self.ext_filter_len < MAX_SEARCH_LEN) {
            self.ext_filter[self.ext_filter_len] = ch;
            self.ext_filter_len += 1;
        }
    }

    /// Delete last character from extensions filter.
    pub fn backspaceExtFilter(self: *Sidebar) void {
        if (self.ext_filter_len > 0) self.ext_filter_len -= 1;
    }

    /// Get extensions filter as slice.
    pub fn getExtFilter(self: *const Sidebar) []const u8 {
        return self.ext_filter[0..self.ext_filter_len];
    }

    /// Clear extensions filter.
    pub fn clearExtFilter(self: *Sidebar) void {
        self.ext_filter_len = 0;
        self.ext_scroll_top = 0;
    }

    /// Toggle install state for an extension by its manifest index.
    pub fn toggleExtInstalled(self: *Sidebar, idx: usize) void {
        if (idx >= EXT_COUNT) return;
        self.ext_installed[idx] = !self.ext_installed[idx];
        if (!self.ext_installed[idx]) self.ext_active[idx] = false;
    }

    /// Toggle active state for an extension by its manifest index.
    pub fn toggleExtActive(self: *Sidebar, idx: usize) void {
        if (idx >= EXT_COUNT) return;
        if (!self.ext_installed[idx]) return; // must be installed first
        self.ext_active[idx] = !self.ext_active[idx];
    }

    /// Count installed extensions.
    pub fn countInstalled(self: *const Sidebar) u16 {
        var c: u16 = 0;
        for (self.ext_installed) |inst| {
            if (inst) c += 1;
        }
        return c;
    }

    /// Count active extensions.
    pub fn countActive(self: *const Sidebar) u16 {
        var c: u16 = 0;
        for (self.ext_active) |act| {
            if (act) c += 1;
        }
        return c;
    }

    /// Check if extension name matches the current filter (case-insensitive substring).
    fn extMatchesFilter(self: *const Sidebar, name: []const u8) bool {
        if (self.ext_filter_len == 0) return true;
        const filter = self.ext_filter[0..self.ext_filter_len];
        if (filter.len > name.len) return false;
        var i: usize = 0;
        while (i + filter.len <= name.len) : (i += 1) {
            var match = true;
            for (0..filter.len) |j| {
                if (toLowerAscii(name[i + j]) != toLowerAscii(filter[j])) {
                    match = false;
                    break;
                }
            }
            if (match) return true;
        }
        return false;
    }

    /// Build a filtered index list of extensions matching the current filter.
    /// Returns the count of matching extensions and fills the provided buffer.
    fn getFilteredExtensions(self: *const Sidebar, buf: *[EXT_COUNT]u16) u16 {
        var count: u16 = 0;
        inline for (manifest.extensions, 0..) |e, i| {
            if (self.extMatchesFilter(e.name)) {
                buf[count] = @intCast(i);
                count += 1;
            }
        }
        return count;
    }

    /// Handle scroll wheel in extensions view.
    pub fn handleExtScroll(self: *Sidebar, lines: i16) void {
        if (lines < 0) {
            const add: u16 = @intCast(-lines);
            self.ext_scroll_top +|= add;
        } else {
            const sub: u16 = @intCast(lines);
            if (self.ext_scroll_top >= sub) {
                self.ext_scroll_top -= sub;
            } else {
                self.ext_scroll_top = 0;
            }
        }
    }

    /// Update hover state for extensions view.
    pub fn updateExtHover(self: *Sidebar, mx: i32, my: i32, region: Rect, cell_h: i32) void {
        const header_h = cell_h + @divTrunc(cell_h, 2);
        const input_h = cell_h + 8;
        const pad = 8;
        const content_y = region.y + header_h + pad + input_h + 4 + cell_h + 8;
        const row_h = cell_h * 3 + 8; // 3-line rows: name, description, version+buttons

        if (mx < region.x or mx >= region.x + region.w or my < content_y or my >= region.y + region.h) {
            self.ext_hover_row = -1;
            self.ext_hover_btn = -1;
            return;
        }

        const rel_y = my - content_y;
        const row: i16 = @intCast(@divTrunc(rel_y, row_h));
        self.ext_hover_row = row + @as(i16, @intCast(self.ext_scroll_top));

        // Check if hovering over buttons (right side, bottom line of row)
        const btn_w = cell_h * 5;
        const btn_area_x = region.x + region.w - pad - btn_w * 2 - 4;
        const row_bottom_y = content_y + @as(i32, @intCast(row)) * row_h + cell_h * 2 + 4;
        if (my >= row_bottom_y and my < row_bottom_y + cell_h + 2 and mx >= btn_area_x) {
            if (mx < btn_area_x + btn_w) {
                self.ext_hover_btn = 0; // install/uninstall
            } else if (mx >= btn_area_x + btn_w + 4) {
                self.ext_hover_btn = 1; // enable/disable
            } else {
                self.ext_hover_btn = -1;
            }
        } else {
            self.ext_hover_btn = -1;
        }
    }

    /// Handle click in extensions view. Returns true if a button was clicked.
    pub fn handleExtClick(self: *Sidebar, mx: i32, my: i32, region: Rect, cell_h: i32) bool {
        const header_h = cell_h + @divTrunc(cell_h, 2);
        const input_h = cell_h + 8;
        const pad = 8;
        const content_y = region.y + header_h + pad + input_h + 4 + cell_h + 8;
        const row_h = cell_h * 3 + 8;

        if (my < content_y or my >= region.y + region.h) return false;

        const rel_y = my - content_y;
        const row: i16 = @intCast(@divTrunc(rel_y, row_h));
        const actual_row = row + @as(i16, @intCast(self.ext_scroll_top));
        self.ext_selected_row = actual_row;

        // Get filtered list to map visual row to manifest index
        var filtered: [EXT_COUNT]u16 = undefined;
        const filtered_count = self.getFilteredExtensions(&filtered);
        if (actual_row < 0 or actual_row >= @as(i16, @intCast(filtered_count))) return false;
        const ext_idx = filtered[@intCast(actual_row)];

        // Check button clicks
        const btn_w = cell_h * 5;
        const btn_area_x = region.x + region.w - pad - btn_w * 2 - 4;
        const row_bottom_y = content_y + @as(i32, @intCast(row)) * row_h + cell_h * 2 + 4;
        if (my >= row_bottom_y and my < row_bottom_y + cell_h + 2 and mx >= btn_area_x) {
            if (mx < btn_area_x + btn_w) {
                self.toggleExtInstalled(ext_idx);
                return true;
            } else if (mx >= btn_area_x + btn_w + 4) {
                self.toggleExtActive(ext_idx);
                return true;
            }
        }
        return false;
    }

    // =========================================================================
    // Explorer methods
    // =========================================================================

    /// Add a flat entry (legacy compat).
    pub fn addEntry(self: *Sidebar, name: []const u8, is_directory: bool) void {
        self.addTreeEntry(name, is_directory, 0, false);
    }

    /// Add a tree entry with indentation and expansion state.
    pub fn addTreeEntry(self: *Sidebar, name: []const u8, is_directory: bool, depth: u8, is_expanded: bool) void {
        if (self.entry_count >= MAX_ENTRIES) return;
        const idx = self.entry_count;
        const copy_len: u8 = @intCast(@min(name.len, MAX_LABEL_LEN));
        @memcpy(self.entries[idx][0..copy_len], name[0..copy_len]);
        self.entry_lens[idx] = copy_len;
        self.is_dir[idx] = is_directory;
        self.indent_level[idx] = depth;
        self.expanded[idx] = is_expanded;
        self.entry_path_lens[idx] = 0; // no path by default
        self.entry_count += 1;
    }

    /// Add a tree entry with a full UTF-16 path for file operations.
    pub fn addTreeEntryWithPath(self: *Sidebar, name: []const u8, is_directory: bool, depth: u8, is_expanded: bool, path_w: [*]const u16, path_len: u16) void {
        if (self.entry_count >= MAX_ENTRIES) return;
        const idx = self.entry_count;
        const copy_len: u8 = @intCast(@min(name.len, MAX_LABEL_LEN));
        @memcpy(self.entries[idx][0..copy_len], name[0..copy_len]);
        self.entry_lens[idx] = copy_len;
        self.is_dir[idx] = is_directory;
        self.indent_level[idx] = depth;
        self.expanded[idx] = is_expanded;
        const plen: u16 = @intCast(@min(path_len, MAX_PATH_W - 1));
        @memcpy(self.entry_paths_w[idx][0..plen], path_w[0..plen]);
        self.entry_paths_w[idx][plen] = 0; // null-terminate
        self.entry_path_lens[idx] = plen;
        self.entry_count += 1;
    }

    /// Get the full UTF-16 path for an entry as a null-terminated pointer.
    /// Returns null if the entry has no path stored.
    pub fn getEntryPath(self: *Sidebar, idx: u8) ?[*:0]const u16 {
        if (idx >= self.entry_count) return null;
        if (self.entry_path_lens[idx] == 0) return null;
        return @ptrCast(&self.entry_paths_w[idx]);
    }

    /// Get the parent directory path (UTF-16) for an entry by walking up indent levels.
    /// For depth-0 entries, returns null (caller should use project root).
    /// For deeper entries, finds the parent directory entry and returns its path.
    pub fn getParentDirPath(self: *Sidebar, idx: u8) ?[*:0]const u16 {
        if (idx >= self.entry_count) return null;
        const depth = self.indent_level[idx];
        if (depth == 0) return null;
        // Walk backwards to find parent directory at depth-1
        var i: u8 = idx;
        while (i > 0) {
            i -= 1;
            if (self.is_dir[i] and self.indent_level[i] == depth - 1) {
                return self.getEntryPath(i);
            }
        }
        return null;
    }

    /// Set the project name displayed in the explorer header.
    pub fn setProjectName(self: *Sidebar, name: []const u8) void {
        const copy_len: u8 = @intCast(@min(name.len, MAX_LABEL_LEN));
        @memcpy(self.project_name[0..copy_len], name[0..copy_len]);
        self.project_name_len = copy_len;
    }

    /// Clear all explorer entries.
    pub fn clearEntries(self: *Sidebar) void {
        self.entry_count = 0;
        self.scroll_top = 0;
        self.selected_row = -1;
        self.hover_row = -1;
        self.cancelRename();
    }

    // =========================================================================
    // Inline rename methods
    // =========================================================================

    /// Start inline rename for the currently selected entry.
    pub fn startRename(self: *Sidebar) void {
        if (self.selected_row < 0 or self.selected_row >= self.entry_count) return;
        const idx: u8 = @intCast(self.selected_row);
        self.rename_active = true;
        self.rename_row = self.selected_row;
        const name_len = self.entry_lens[idx];
        @memcpy(self.rename_buf[0..name_len], self.entries[idx][0..name_len]);
        self.rename_len = name_len;
    }

    /// Cancel inline rename.
    pub fn cancelRename(self: *Sidebar) void {
        self.rename_active = false;
        self.rename_row = -1;
        self.rename_len = 0;
    }

    /// Append a character to the rename buffer.
    pub fn renameAppendChar(self: *Sidebar, ch: u8) void {
        if (!self.rename_active) return;
        if (self.rename_len < MAX_LABEL_LEN) {
            self.rename_buf[self.rename_len] = ch;
            self.rename_len += 1;
        }
    }

    /// Delete last character from rename buffer.
    pub fn renameBackspace(self: *Sidebar) void {
        if (!self.rename_active) return;
        if (self.rename_len > 0) self.rename_len -= 1;
    }

    /// Get the current rename text.
    pub fn getRenameText(self: *const Sidebar) []const u8 {
        return self.rename_buf[0..self.rename_len];
    }

    /// Commit rename: update the entry label with the rename buffer contents.
    /// Returns true if the rename was committed (caller should do the actual FS rename).
    pub fn commitRename(self: *Sidebar) bool {
        if (!self.rename_active or self.rename_row < 0) return false;
        if (self.rename_len == 0) {
            self.cancelRename();
            return false;
        }
        const idx: u8 = @intCast(self.rename_row);
        @memcpy(self.entries[idx][0..self.rename_len], self.rename_buf[0..self.rename_len]);
        self.entry_lens[idx] = self.rename_len;
        self.rename_active = false;
        self.rename_row = -1;
        return true;
    }

    // =========================================================================
    // Keyboard navigation
    // =========================================================================

    /// Move selection up by one row.
    pub fn moveUp(self: *Sidebar) void {
        if (self.entry_count == 0) return;
        if (self.selected_row <= 0) {
            self.selected_row = 0;
        } else {
            self.selected_row -= 1;
        }
        self.ensureSelectedVisible();
    }

    /// Move selection down by one row.
    pub fn moveDown(self: *Sidebar) void {
        if (self.entry_count == 0) return;
        if (self.selected_row < 0) {
            self.selected_row = 0;
        } else if (self.selected_row < @as(i16, @intCast(self.entry_count)) - 1) {
            self.selected_row += 1;
        }
        self.ensureSelectedVisible();
    }

    /// Collapse the selected directory, or move to parent if already collapsed / is a file.
    pub fn collapseOrParent(self: *Sidebar) void {
        if (self.selected_row < 0 or self.selected_row >= self.entry_count) return;
        const idx: u8 = @intCast(self.selected_row);
        if (self.is_dir[idx] and self.expanded[idx]) {
            self.expanded[idx] = false;
            return;
        }
        // Move to parent directory
        const depth = self.indent_level[idx];
        if (depth == 0) return;
        var i: u8 = idx;
        while (i > 0) {
            i -= 1;
            if (self.is_dir[i] and self.indent_level[i] == depth - 1) {
                self.selected_row = @intCast(i);
                self.ensureSelectedVisible();
                return;
            }
        }
    }

    /// Expand the selected directory, or move to first child if already expanded.
    pub fn expandOrFirstChild(self: *Sidebar) void {
        if (self.selected_row < 0 or self.selected_row >= self.entry_count) return;
        const idx: u8 = @intCast(self.selected_row);
        if (!self.is_dir[idx]) return;
        if (!self.expanded[idx]) {
            self.expanded[idx] = true;
            return;
        }
        // Move to first child
        if (idx + 1 < self.entry_count and self.indent_level[idx + 1] > self.indent_level[idx]) {
            self.selected_row += 1;
            self.ensureSelectedVisible();
        }
    }

    /// Ensure the selected row is visible by adjusting scroll_top.
    pub fn ensureSelectedVisible(self: *Sidebar) void {
        if (self.selected_row < 0) return;
        const row: u16 = @intCast(self.selected_row);
        if (row < self.scroll_top) {
            self.scroll_top = row;
        }
        // We don't know visible_rows here, so just ensure scroll_top <= row
        // The render pass will handle the rest
    }

    /// Update hover row from mouse position.
    pub fn updateHover(self: *Sidebar, mx: i32, my: i32, region: Rect, cell_h: i32) void {
        // Update toolbar hover
        self.updateToolbarHover(mx, my, region, cell_h);

        if (mx < region.x or mx >= region.x + region.w or my < region.y or my >= region.y + region.h) {
            self.hover_row = -1;
            return;
        }
        const header_h = cell_h + @divTrunc(cell_h, 2); // section header height
        const content_y = region.y + header_h;
        if (my < content_y) {
            self.hover_row = -1;
            return;
        }
        const row_h = cell_h + 4;
        const rel_y = my - content_y;
        const row: i16 = @intCast(@divTrunc(rel_y, row_h));
        const actual_row = row + @as(i16, @intCast(self.scroll_top));
        if (actual_row >= 0 and actual_row < self.entry_count) {
            self.hover_row = actual_row;
        } else {
            self.hover_row = -1;
        }
    }

    /// Handle click on sidebar, returns clicked row index or null.
    pub fn handleClick(self: *Sidebar, my: i32, region: Rect, cell_h: i32) ?u8 {
        const header_h = cell_h + @divTrunc(cell_h, 2);
        const content_y = region.y + header_h;
        if (my < content_y) return null;
        const row_h = cell_h + 4;
        const rel_y = my - content_y;
        const row: i16 = @intCast(@divTrunc(rel_y, row_h));
        const actual_row = row + @as(i16, @intCast(self.scroll_top));
        if (actual_row < 0 or actual_row >= self.entry_count) return null;
        const idx: u8 = @intCast(actual_row);
        self.selected_row = actual_row;
        // Toggle folder expansion
        if (self.is_dir[idx]) {
            self.expanded[idx] = !self.expanded[idx];
        }
        return idx;
    }

    /// Handle scroll wheel in sidebar.
    pub fn handleScroll(self: *Sidebar, lines: i16) void {
        if (lines < 0) {
            const add: u16 = @intCast(-lines);
            self.scroll_top +|= add;
            if (self.scroll_top >= self.entry_count) {
                self.scroll_top = if (self.entry_count > 0) self.entry_count - 1 else 0;
            }
        } else {
            const sub: u16 = @intCast(lines);
            if (self.scroll_top >= sub) {
                self.scroll_top -= sub;
            } else {
                self.scroll_top = 0;
            }
        }
    }

    // =========================================================================
    // Search methods
    // =========================================================================

    /// Append a character to the search query.
    pub fn appendSearchChar(self: *Sidebar, ch: u8) void {
        if (self.search_query_len < MAX_SEARCH_LEN) {
            self.search_query[self.search_query_len] = ch;
            self.search_query_len += 1;
        }
    }

    /// Delete last character from search query.
    pub fn backspaceSearch(self: *Sidebar) void {
        if (self.search_query_len > 0) self.search_query_len -= 1;
    }

    /// Append a character to the replace query.
    pub fn appendReplaceChar(self: *Sidebar, ch: u8) void {
        if (self.replace_query_len < MAX_SEARCH_LEN) {
            self.replace_query[self.replace_query_len] = ch;
            self.replace_query_len += 1;
        }
    }

    /// Delete last character from replace query.
    pub fn backspaceReplace(self: *Sidebar) void {
        if (self.replace_query_len > 0) self.replace_query_len -= 1;
    }

    /// Toggle regex mode.
    pub fn toggleRegex(self: *Sidebar) void {
        self.search_regex = !self.search_regex;
    }

    /// Toggle case sensitivity.
    pub fn toggleCaseSensitive(self: *Sidebar) void {
        self.search_case_sensitive = !self.search_case_sensitive;
    }

    /// Toggle whole word matching.
    pub fn toggleWholeWord(self: *Sidebar) void {
        self.search_whole_word = !self.search_whole_word;
    }

    /// Clear search state.
    pub fn clearSearch(self: *Sidebar) void {
        self.search_query_len = 0;
        self.replace_query_len = 0;
        self.search_match_count = 0;
        self.search_scroll_top = 0;
        self.search_hover_row = -1;
        self.search_selected_row = -1;
    }

    /// Add a search match result.
    pub fn addMatch(self: *Sidebar, file_idx: u8, line_num: u32, col: u16, match_len: u16, text: []const u8) void {
        if (self.search_match_count >= MAX_MATCHES) return;
        const idx = self.search_match_count;
        self.search_matches[idx].file_idx = file_idx;
        self.search_matches[idx].line_num = line_num;
        self.search_matches[idx].col = col;
        self.search_matches[idx].match_len = match_len;
        const tlen: u8 = @intCast(@min(text.len, MAX_MATCH_TEXT));
        @memcpy(self.search_matches[idx].text[0..tlen], text[0..tlen]);
        self.search_matches[idx].text_len = tlen;
        self.search_match_count += 1;
    }

    /// Get search query as slice.
    pub fn getSearchQuery(self: *const Sidebar) []const u8 {
        return self.search_query[0..self.search_query_len];
    }

    /// Get replace query as slice.
    pub fn getReplaceQuery(self: *const Sidebar) []const u8 {
        return self.replace_query[0..self.replace_query_len];
    }

    // =========================================================================
    // Render
    // =========================================================================
    // Toolbar methods
    // =========================================================================

    /// Compute toolbar button rect: returns (x, y, size) for button at index.
    /// Buttons are right-aligned in the header.
    fn toolbarBtnRect(region: Rect, header_h: i32, btn_idx: u8, btn_size: i32) struct { x: i32, y: i32 } {
        const pad = 4;
        const right_margin = 8;
        const x = region.x + region.w - right_margin - (@as(i32, @intCast(btn_idx)) + 1) * (btn_size + pad);
        const y = region.y + @divTrunc(header_h - btn_size, 2);
        return .{ .x = x, .y = y };
    }

    /// Hit-test toolbar buttons. Returns action if a button was clicked, null otherwise.
    /// Call this before handleClick — if it returns non-null, the click was on the toolbar.
    pub fn handleToolbarClick(self: *Sidebar, mx: i32, my: i32, region: Rect, cell_h: i32) ?ToolbarAction {
        _ = self;
        const header_h = cell_h + @divTrunc(cell_h, 2);
        if (my < region.y or my >= region.y + header_h) return null;
        const btn_size = cell_h;
        var i: u8 = 0;
        while (i < TOOLBAR_BTN_COUNT) : (i += 1) {
            const pos = toolbarBtnRect(region, header_h, i, btn_size);
            if (mx >= pos.x and mx < pos.x + btn_size and my >= pos.y and my < pos.y + btn_size) {
                // Buttons are ordered right-to-left: 0=collapse_all, 1=refresh, 2=new_folder, 3=new_file
                // But we want left-to-right logical order, so reverse:
                const action_idx: u8 = (TOOLBAR_BTN_COUNT - 1) - i;
                return @enumFromInt(action_idx);
            }
        }
        return null;
    }

    /// Update toolbar hover state from mouse position.
    pub fn updateToolbarHover(self: *Sidebar, mx: i32, my: i32, region: Rect, cell_h: i32) void {
        const header_h = cell_h + @divTrunc(cell_h, 2);
        if (my < region.y or my >= region.y + header_h) {
            self.toolbar_hover = -1;
            return;
        }
        const btn_size = cell_h;
        var i: u8 = 0;
        while (i < TOOLBAR_BTN_COUNT) : (i += 1) {
            const pos = toolbarBtnRect(region, header_h, i, btn_size);
            if (mx >= pos.x and mx < pos.x + btn_size and my >= pos.y and my < pos.y + btn_size) {
                self.toolbar_hover = @intCast(i);
                return;
            }
        }
        self.toolbar_hover = -1;
    }

    // =========================================================================
    // Rendering
    // =========================================================================

    /// Render sidebar. active_icon: 0=explorer, 1=search, 4=extensions.
    pub fn render(self: *const Sidebar, region: Rect, font_atlas: *const FontAtlas, active_icon: u8, icon_cache: *FileIconCache) void {
        // Background
        ft.renderAlphaRect(region.x, region.y, region.w, region.h, SIDEBAR_BG);
        if (region.w <= 0 or region.h <= 0) return;

        if (active_icon == 1) {
            self.renderSearchView(region, font_atlas, icon_cache);
        } else if (active_icon == 4) {
            self.renderExtensionsView(region, font_atlas);
        } else {
            self.renderExplorerView(region, font_atlas, icon_cache);
        }
    }

    // =========================================================================
    // Explorer view
    // =========================================================================

    fn renderExplorerView(self: *const Sidebar, region: Rect, font_atlas: *const FontAtlas, icon_cache: *FileIconCache) void {
        const cw = font_atlas.cell_w;
        const ch = font_atlas.cell_h;
        const header_h = ch + @divTrunc(ch, 2);
        const row_h = ch + 4;

        // Section header: "EXPLORER" or project name
        ft.renderAlphaRect(region.x, region.y, region.w, header_h, SECTION_HEADER_BG);
        const header_text = if (self.project_name_len > 0)
            self.project_name[0..self.project_name_len]
        else
            "EXPLORER";
        font_atlas.renderText(
            header_text,
            @as(f32, @floatFromInt(region.x + 12)),
            @as(f32, @floatFromInt(region.y + @divTrunc(header_h - ch, 2))),
            SECTION_HEADER_COLOR,
        );

        // Toolbar buttons (right-aligned): New File, New Folder, Refresh, Collapse All
        const btn_size = ch;
        var btn_i: u8 = 0;
        while (btn_i < TOOLBAR_BTN_COUNT) : (btn_i += 1) {
            const pos = toolbarBtnRect(region, header_h, btn_i, btn_size);
            const fx: f32 = @floatFromInt(pos.x);
            const fy: f32 = @floatFromInt(pos.y);
            const fs: f32 = @floatFromInt(btn_size);
            const is_hovered = (self.toolbar_hover >= 0 and @as(u8, @intCast(self.toolbar_hover)) == btn_i);

            // Hover background
            if (is_hovered) {
                ft.renderAlphaRect(pos.x - 1, pos.y - 1, btn_size + 2, btn_size + 2, HOVER_BG);
            }

            // Draw icon glyph — buttons right-to-left: 0=collapse_all, 1=refresh, 2=new_folder, 3=new_file
            const action_idx = (TOOLBAR_BTN_COUNT - 1) - btn_i;
            const icon_color = if (is_hovered) TEXT_COLOR else CHEVRON_COLOR;
            switch (action_idx) {
                0 => renderNewFileIcon(fx, fy, fs, icon_color),
                1 => renderNewFolderIcon(fx, fy, fs, icon_color),
                2 => renderRefreshIcon(fx, fy, fs, icon_color),
                3 => renderCollapseAllIcon(fx, fy, fs, icon_color),
                else => {},
            }
        }

        // File tree rows
        const content_y = region.y + header_h;
        const content_h = region.h - header_h;
        const visible_rows: u16 = @intCast(@max(1, @divTrunc(content_h, row_h)));

        var row: u16 = 0;
        while (row < visible_rows) : (row += 1) {
            const entry_idx = row + self.scroll_top;
            if (entry_idx >= self.entry_count) break;

            const ry = content_y + @as(i32, @intCast(row)) * row_h;
            if (ry + row_h < region.y or ry > region.y + region.h) continue;

            const idx: u8 = @intCast(entry_idx);
            const name = self.entries[idx][0..self.entry_lens[idx]];
            const depth = self.indent_level[idx];
            const is_selected = (self.selected_row >= 0 and @as(u16, @intCast(self.selected_row)) == entry_idx);
            const is_hovered = (self.hover_row >= 0 and @as(u16, @intCast(self.hover_row)) == entry_idx);

            // Row background
            if (is_selected) {
                ft.renderAlphaRect(region.x, ry, region.w, row_h, SELECTED_BG);
                // Left accent bar
                ft.renderAlphaRect(region.x, ry, 2, row_h, SELECTED_ACCENT);
            } else if (is_hovered) {
                ft.renderAlphaRect(region.x, ry, region.w, row_h, HOVER_BG);
            }

            // Indentation
            const indent_px = @as(i32, @intCast(depth)) * cw * 2;
            var d: u8 = 0;
            while (d < depth) : (d += 1) {
                const gx = region.x + 12 + @as(i32, @intCast(d)) * cw * 2;
                ft.renderIndentGuide(gx, ry, row_h, INDENT_GUIDE_COLOR);
            }

            const icon_x = region.x + 12 + indent_px;
            const text_x = icon_x + cw + 6;
            const text_y = ry + 2;
            const icon_size = ch - 2;

            if (self.is_dir[idx]) {
                // Chevron
                const chev_x: f32 = @as(f32, @floatFromInt(icon_x)) - @as(f32, @floatFromInt(cw)) * 0.3;
                const chev_y: f32 = @as(f32, @floatFromInt(ry)) + @as(f32, @floatFromInt(row_h)) * 0.5;
                ft.renderChevron(chev_x, chev_y, @as(f32, @floatFromInt(ch)) * 0.25, self.expanded[idx], CHEVRON_COLOR);
                // Folder icon (system icon)
                FileIconCache.renderIcon(icon_cache.getFolderIcon(), icon_x, ry + 2, icon_size);
            } else {
                // File icon (system icon by extension)
                FileIconCache.renderIcon(icon_cache.getIconForFile(name), icon_x, ry + 2, icon_size);
            }

            // Label — show rename input if active on this row
            const is_renaming = (self.rename_active and self.rename_row >= 0 and @as(u16, @intCast(self.rename_row)) == entry_idx);
            if (is_renaming) {
                // Render inline rename input box
                const rename_text = self.rename_buf[0..self.rename_len];
                const input_w = @max(region.w - text_x + region.x - 8, cw * 8);
                ft.renderAlphaRect(text_x - 2, ry, input_w, row_h, INPUT_BG);
                // Border
                ft.renderAlphaRect(text_x - 2, ry, input_w, 1, ACCENT_COLOR);
                ft.renderAlphaRect(text_x - 2, ry + row_h - 1, input_w, 1, ACCENT_COLOR);
                ft.renderAlphaRect(text_x - 2, ry, 1, row_h, ACCENT_COLOR);
                ft.renderAlphaRect(text_x - 2 + input_w - 1, ry, 1, row_h, ACCENT_COLOR);
                font_atlas.renderText(rename_text, @floatFromInt(text_x), @floatFromInt(text_y), TEXT_COLOR);
                // Cursor
                const cursor_x = text_x + @as(i32, @intCast(self.rename_len)) * cw;
                ft.renderAlphaRect(cursor_x, text_y, 1, ch, ACCENT_COLOR);
            } else {
                const label_color = ft.fileNameColor(name, 1.0, is_selected);
                font_atlas.renderText(name, @floatFromInt(text_x), @floatFromInt(text_y), label_color);
            }
        }

        // Scrollbar
        if (self.entry_count > visible_rows) {
            self.renderScrollbar(region, content_y, content_h, visible_rows, self.entry_count, self.scroll_top);
        }
    }

    // =========================================================================
    // Search view
    // =========================================================================

    fn renderSearchView(self: *const Sidebar, region: Rect, font_atlas: *const FontAtlas, icon_cache: *FileIconCache) void {
        const cw = font_atlas.cell_w;
        const ch = font_atlas.cell_h;
        const header_h = ch + @divTrunc(ch, 2);
        const pad = 8;
        const input_h = ch + 8;
        const toggle_size = ch;

        // Section header: "SEARCH"
        ft.renderAlphaRect(region.x, region.y, region.w, header_h, SECTION_HEADER_BG);
        font_atlas.renderText(
            "SEARCH",
            @as(f32, @floatFromInt(region.x + 12)),
            @as(f32, @floatFromInt(region.y + @divTrunc(header_h - ch, 2))),
            SECTION_HEADER_COLOR,
        );

        var cy = region.y + header_h + pad;

        // --- Search input field ---
        const input_w = region.w - pad * 2 - toggle_size * 3 - 12;
        const search_border = if (self.search_active_field == .search) INPUT_BORDER else INPUT_BORDER_INACTIVE;
        self.renderInputField(region.x + pad, cy, input_w, input_h, self.search_query[0..self.search_query_len], "Search", font_atlas, search_border);

        // Toggle buttons to the right of search input
        const toggle_x = region.x + pad + input_w + 4;
        const toggle_y = cy + @divTrunc(input_h - toggle_size, 2);
        self.renderToggleButton(toggle_x, toggle_y, toggle_size, ".*", self.search_regex, font_atlas);
        self.renderToggleButton(toggle_x + toggle_size + 2, toggle_y, toggle_size, "Aa", self.search_case_sensitive, font_atlas);
        self.renderToggleButton(toggle_x + (toggle_size + 2) * 2, toggle_y, toggle_size, "ab", self.search_whole_word, font_atlas);

        cy += input_h + 4;

        // --- Replace input field (collapsible) ---
        if (self.search_replace_visible) {
            const replace_border = if (self.search_active_field == .replace) INPUT_BORDER else INPUT_BORDER_INACTIVE;
            self.renderInputField(region.x + pad, cy, region.w - pad * 2, input_h, self.replace_query[0..self.replace_query_len], "Replace", font_atlas, replace_border);
            cy += input_h + 4;
        }

        // --- Match count summary ---
        cy += 2;
        if (self.search_query_len > 0) {
            var count_buf: [32]u8 = undefined;
            const count_str = formatMatchCount(self.search_match_count, &count_buf);
            font_atlas.renderText(count_str, @floatFromInt(region.x + pad), @floatFromInt(cy), DIM_COLOR);
        } else {
            font_atlas.renderText("Type to search", @floatFromInt(region.x + pad), @floatFromInt(cy), DIM_COLOR);
        }
        cy += ch + 6;

        // --- Separator ---
        ft.renderAlphaRect(region.x, cy, region.w, 1, Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 0.06 });
        cy += 1;

        // --- Match results list ---
        const results_y = cy;
        const results_h = region.y + region.h - cy;
        const row_h = ch + 4;
        if (results_h <= 0) return;
        const visible_rows: u16 = @intCast(@max(1, @divTrunc(results_h, row_h)));

        // Group matches by file — render file headers and match lines
        var prev_file_idx: u8 = 0xFF;
        var visual_row: u16 = 0;
        var match_i: u16 = 0;
        while (match_i < self.search_match_count) : (match_i += 1) {
            const m = self.search_matches[match_i];

            // File header row
            if (m.file_idx != prev_file_idx) {
                if (visual_row >= self.search_scroll_top and visual_row < self.search_scroll_top + visible_rows) {
                    const ry = results_y + @as(i32, @intCast(visual_row - self.search_scroll_top)) * row_h;
                    // File icon + name from entries
                    if (m.file_idx < self.entry_count) {
                        const fname = self.entries[m.file_idx][0..self.entry_lens[m.file_idx]];
                        FileIconCache.renderIcon(icon_cache.getIconForFile(fname), region.x + pad, ry + 2, ch - 2);
                        font_atlas.renderText(fname, @floatFromInt(region.x + pad + cw + 4), @floatFromInt(ry + 2), MATCH_FILE_COLOR);
                    }
                }
                prev_file_idx = m.file_idx;
                visual_row += 1;
            }

            // Match line row
            if (visual_row >= self.search_scroll_top and visual_row < self.search_scroll_top + visible_rows) {
                const ry = results_y + @as(i32, @intCast(visual_row - self.search_scroll_top)) * row_h;
                const is_hovered = (self.search_hover_row >= 0 and @as(u16, @intCast(self.search_hover_row)) == visual_row);
                const is_selected = (self.search_selected_row >= 0 and @as(u16, @intCast(self.search_selected_row)) == visual_row);

                if (is_selected) {
                    ft.renderAlphaRect(region.x, ry, region.w, row_h, SELECTED_BG);
                } else if (is_hovered) {
                    ft.renderAlphaRect(region.x, ry, region.w, row_h, HOVER_BG);
                }

                // Line number
                var line_buf: [32]u8 = undefined;
                const line_str = formatLineNum(m.line_num, &line_buf);
                const indent = pad + cw * 2;
                font_atlas.renderText(line_str, @floatFromInt(region.x + indent), @floatFromInt(ry + 2), MATCH_LINE_COLOR);

                // Match text
                const text_offset = indent + @as(i32, @intCast(line_str.len + 1)) * cw;
                const match_text = m.text[0..m.text_len];
                font_atlas.renderText(match_text, @floatFromInt(region.x + text_offset), @floatFromInt(ry + 2), MATCH_TEXT_COLOR);

                // Highlight the matched portion within the text
                if (m.col < m.text_len and m.match_len > 0) {
                    const hl_x = region.x + text_offset + @as(i32, @intCast(m.col)) * cw;
                    const hl_w = @as(i32, @intCast(@min(m.match_len, m.text_len - m.col))) * cw;
                    ft.renderAlphaRect(hl_x, ry, hl_w, row_h, MATCH_HIGHLIGHT_BG);
                }
            }
            visual_row += 1;
        }

        // Scrollbar for results
        if (visual_row > visible_rows) {
            self.renderScrollbar(region, results_y, results_h, visible_rows, visual_row, self.search_scroll_top);
        }
    }

    // =========================================================================
    // Extensions view
    // =========================================================================

    fn renderExtensionsView(self: *const Sidebar, region: Rect, font_atlas: *const FontAtlas) void {
        const cw = font_atlas.cell_w;
        const ch = font_atlas.cell_h;
        const header_h = ch + @divTrunc(ch, 2);
        const pad = 8;
        const input_h = ch + 8;
        const row_h = ch * 3 + 8; // name line + description line + version/buttons line + padding

        // Section header: "EXTENSIONS"
        ft.renderAlphaRect(region.x, region.y, region.w, header_h, SECTION_HEADER_BG);
        font_atlas.renderText(
            "EXTENSIONS",
            @as(f32, @floatFromInt(region.x + 12)),
            @as(f32, @floatFromInt(region.y + @divTrunc(header_h - ch, 2))),
            SECTION_HEADER_COLOR,
        );

        var cy = region.y + header_h + pad;

        // Filter input field
        const filter_border = if (self.ext_filter_len > 0) INPUT_BORDER else INPUT_BORDER_INACTIVE;
        self.renderInputField(region.x + pad, cy, region.w - pad * 2, input_h, self.ext_filter[0..self.ext_filter_len], "Filter extensions...", font_atlas, filter_border);
        cy += input_h + 4;

        // Summary line: "X installed, Y active of Z total"
        {
            var summary_buf: [64]u8 = undefined;
            var pos: usize = 0;
            pos = writeU16Buf(&summary_buf, pos, self.countInstalled());
            const s1 = " installed, ";
            @memcpy(summary_buf[pos..][0..s1.len], s1);
            pos += s1.len;
            pos = writeU16Buf(&summary_buf, pos, self.countActive());
            const s2 = " active of ";
            @memcpy(summary_buf[pos..][0..s2.len], s2);
            pos += s2.len;
            pos = writeU16Buf(&summary_buf, pos, @intCast(EXT_COUNT));
            @memcpy(summary_buf[pos..][0..6], " total");
            pos += 6;
            font_atlas.renderText(summary_buf[0..pos], @floatFromInt(region.x + pad), @floatFromInt(cy), DIM_COLOR);
        }
        cy += ch + 4;

        // Separator
        ft.renderAlphaRect(region.x, cy, region.w, 1, Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 0.06 });
        cy += 1;

        // Extension list
        const content_y = cy;
        const content_h = region.y + region.h - cy;
        if (content_h <= 0) return;
        const visible_rows: u16 = @intCast(@max(1, @divTrunc(content_h, row_h)));

        // Get filtered extensions
        var filtered: [EXT_COUNT]u16 = undefined;
        const filtered_count = self.getFilteredExtensions(&filtered);

        // Clamp scroll
        const max_scroll: u16 = if (filtered_count > visible_rows) filtered_count - visible_rows else 0;
        const scroll = @min(self.ext_scroll_top, max_scroll);

        var row: u16 = 0;
        while (row < visible_rows) : (row += 1) {
            const list_idx = row + scroll;
            if (list_idx >= filtered_count) break;

            const ext_idx = filtered[list_idx];
            const e = manifest.extensions[ext_idx];
            const ry = content_y + @as(i32, @intCast(row)) * row_h;
            if (ry + row_h < region.y or ry > region.y + region.h) continue;

            const is_selected = (self.ext_selected_row >= 0 and @as(u16, @intCast(self.ext_selected_row)) == list_idx);
            const is_hovered = (self.ext_hover_row >= 0 and @as(u16, @intCast(self.ext_hover_row)) == list_idx);
            const is_installed = self.ext_installed[ext_idx];
            const is_active = self.ext_active[ext_idx];

            // Row background
            if (is_selected) {
                ft.renderAlphaRect(region.x, ry, region.w, row_h, SELECTED_BG);
                ft.renderAlphaRect(region.x, ry, 2, row_h, SELECTED_ACCENT);
            } else if (is_hovered) {
                ft.renderAlphaRect(region.x, ry, region.w, row_h, HOVER_BG);
            }

            // Installed indicator (left bar)
            if (is_installed) {
                ft.renderAlphaRect(region.x + 3, ry + 2, 3, row_h - 4, EXT_INSTALLED_BG);
            }

            // Status dot (green=active, gray=inactive)
            const dot_x = region.x + pad;
            const dot_y = ry + 4;
            const dot_color = if (is_active) EXT_ACTIVE_COLOR else EXT_INACTIVE_COLOR;
            ft.renderAlphaRect(dot_x, dot_y, ch - 4, ch - 4, dot_color);

            // Line 1: Extension name
            const name_x = region.x + pad + ch;
            font_atlas.renderText(e.name, @floatFromInt(name_x), @floatFromInt(ry + 2), TEXT_COLOR);

            // Line 2: Description (truncated to fit)
            const desc = if (e.description.len > 0) e.description else "(no description)";
            const max_desc_chars: usize = @intCast(@max(1, @divTrunc(region.w - pad * 2 - ch, cw)));
            const desc_len = @min(desc.len, max_desc_chars);
            font_atlas.renderText(desc[0..desc_len], @floatFromInt(name_x), @floatFromInt(ry + ch + 4), DIM_COLOR);

            // Line 3: Version + buttons
            const line3_y = ry + ch * 2 + 6;
            font_atlas.renderText(e.version, @floatFromInt(name_x), @floatFromInt(line3_y), EXT_VERSION_COLOR);

            // Capability badges
            const badge_x = name_x + @as(i32, @intCast(e.version.len + 1)) * cw;
            var bx = badge_x;
            if (e.capabilities.syntax) {
                font_atlas.renderText("syn", @floatFromInt(bx), @floatFromInt(line3_y), ACCENT_COLOR);
                bx += cw * 4;
            }
            if (e.capabilities.theme) {
                font_atlas.renderText("thm", @floatFromInt(bx), @floatFromInt(line3_y), ACCENT_COLOR);
                bx += cw * 4;
            }
            if (e.capabilities.commands) {
                font_atlas.renderText("cmd", @floatFromInt(bx), @floatFromInt(line3_y), ACCENT_COLOR);
                bx += cw * 4;
            }
            if (e.capabilities.snippets) {
                font_atlas.renderText("snp", @floatFromInt(bx), @floatFromInt(line3_y), ACCENT_COLOR);
                bx += cw * 4;
            }

            // Buttons (right-aligned on line 3)
            const btn_h = ch + 2;
            const btn_w = ch * 5;
            const btn_y = line3_y - 1;

            // Install/Uninstall button
            const inst_btn_x = region.x + region.w - pad - btn_w * 2 - 4;
            const inst_bg = if (is_installed) EXT_BTN_DANGER_BG else (if (is_hovered and self.ext_hover_btn == 0) EXT_BTN_HOVER_BG else EXT_BTN_BG);
            ft.renderAlphaRect(inst_btn_x, btn_y, btn_w, btn_h, inst_bg);
            const inst_label = if (is_installed) "Remove" else "Install";
            const inst_lw = @as(i32, @intCast(inst_label.len)) * cw;
            font_atlas.renderText(inst_label, @floatFromInt(inst_btn_x + @divTrunc(btn_w - inst_lw, 2)), @floatFromInt(btn_y + 1), TEXT_COLOR);

            // Enable/Disable button
            const act_btn_x = inst_btn_x + btn_w + 4;
            const act_bg = if (!is_installed) TOGGLE_OFF_BG else (if (is_active) EXT_BTN_DANGER_BG else (if (is_hovered and self.ext_hover_btn == 1) EXT_BTN_HOVER_BG else EXT_BTN_BG));
            ft.renderAlphaRect(act_btn_x, btn_y, btn_w, btn_h, act_bg);
            const act_label = if (is_active) "Disable" else "Enable";
            const act_lw = @as(i32, @intCast(act_label.len)) * cw;
            const act_text_color = if (is_installed) TEXT_COLOR else DIM_COLOR;
            font_atlas.renderText(act_label, @floatFromInt(act_btn_x + @divTrunc(btn_w - act_lw, 2)), @floatFromInt(btn_y + 1), act_text_color);

            // Row separator
            ft.renderAlphaRect(region.x + pad, ry + row_h - 1, region.w - pad * 2, 1, Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 0.04 });
        }

        // Scrollbar
        if (filtered_count > visible_rows) {
            self.renderScrollbar(region, content_y, content_h, visible_rows, filtered_count, scroll);
        }
    }

    // =========================================================================
    // Rendering helpers
    // =========================================================================

    fn renderInputField(_: *const Sidebar, x: i32, y: i32, w: i32, h: i32, text: []const u8, placeholder: []const u8, font_atlas: *const FontAtlas, border_color: Color) void {
        const ch = font_atlas.cell_h;
        // Background
        ft.renderAlphaRect(x, y, w, h, INPUT_BG);
        // Border
        ft.renderAlphaRect(x, y, w, 1, border_color);
        ft.renderAlphaRect(x, y + h - 1, w, 1, border_color);
        ft.renderAlphaRect(x, y, 1, h, border_color);
        ft.renderAlphaRect(x + w - 1, y, 1, h, border_color);

        const text_y = y + @divTrunc(h - ch, 2);
        const text_x = x + 6;
        if (text.len > 0) {
            font_atlas.renderText(text, @floatFromInt(text_x), @floatFromInt(text_y), TEXT_COLOR);
            // Cursor
            const cursor_x = text_x + @as(i32, @intCast(text.len)) * font_atlas.cell_w;
            ft.renderAlphaRect(cursor_x, text_y, 1, ch, ACCENT_COLOR);
        } else {
            font_atlas.renderText(placeholder, @floatFromInt(text_x), @floatFromInt(text_y), DIM_COLOR);
        }
    }

    fn renderToggleButton(_: *const Sidebar, x: i32, y: i32, size: i32, label: []const u8, active: bool, font_atlas: *const FontAtlas) void {
        const bg = if (active) TOGGLE_ON_BG else TOGGLE_OFF_BG;
        ft.renderAlphaRect(x, y, size, size, bg);
        // Border when active
        if (active) {
            ft.renderAlphaRect(x, y + size - 1, size, 1, ACCENT_COLOR);
        }
        const ch = font_atlas.cell_h;
        const cw = font_atlas.cell_w;
        const lw = @as(i32, @intCast(label.len)) * cw;
        const tx = x + @divTrunc(size - lw, 2);
        const ty = y + @divTrunc(size - ch, 2);
        const color = if (active) TEXT_COLOR else DIM_COLOR;
        font_atlas.renderText(label, @floatFromInt(tx), @floatFromInt(ty), color);
    }

    fn renderScrollbar(_: *const Sidebar, region: Rect, content_y: i32, content_h: i32, visible_rows: u16, total_rows: u16, scroll_top: u16) void {
        const sb_w: i32 = 8;
        const sb_x = region.x + region.w - sb_w;
        // Track
        ft.renderAlphaRect(sb_x, content_y, sb_w, content_h, SCROLLBAR_BG);
        // Thumb
        if (total_rows > 0 and content_h > 0) {
            const ratio = @as(f32, @floatFromInt(visible_rows)) / @as(f32, @floatFromInt(total_rows));
            const thumb_h_f = @as(f32, @floatFromInt(content_h)) * @min(ratio, 1.0);
            const thumb_h: i32 = @max(16, @as(i32, @intFromFloat(thumb_h_f)));
            const scroll_ratio = if (total_rows > visible_rows)
                @as(f32, @floatFromInt(scroll_top)) / @as(f32, @floatFromInt(total_rows - visible_rows))
            else
                0.0;
            const thumb_y_f = @as(f32, @floatFromInt(content_y)) + scroll_ratio * @as(f32, @floatFromInt(content_h - thumb_h));
            const thumb_y: i32 = @intFromFloat(thumb_y_f);
            ft.renderAlphaRect(sb_x + 1, thumb_y, sb_w - 2, thumb_h, SCROLLBAR_FG);
        }
    }
};

// =============================================================================
// Standalone helpers
// =============================================================================

fn toLowerAscii(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

fn writeU16Buf(buf: *[64]u8, start: usize, val: u16) usize {
    if (val == 0) {
        buf[start] = '0';
        return start + 1;
    }
    var digits: [5]u8 = undefined;
    var dcount: usize = 0;
    var v = val;
    while (v > 0) {
        digits[dcount] = @intCast(v % 10 + '0');
        dcount += 1;
        v /= 10;
    }
    var pos = start;
    var i: usize = dcount;
    while (i > 0) {
        i -= 1;
        buf[pos] = digits[i];
        pos += 1;
    }
    return pos;
}

fn formatMatchCount(count: u16, buf: *[32]u8) []const u8 {
    var pos: usize = 0;
    pos = ft.writeU16(buf, pos, count);
    const suffix = " results";
    @memcpy(buf[pos..][0..suffix.len], suffix);
    pos += suffix.len;
    return buf[0..pos];
}

fn formatLineNum(line: u32, buf: *[32]u8) []const u8 {
    if (line == 0) {
        buf[0] = '1';
        buf[1] = ':';
        return buf[0..2];
    }
    var digits: [10]u8 = undefined;
    var dcount: usize = 0;
    var v = line;
    while (v > 0) {
        digits[dcount] = @intCast(v % 10 + '0');
        dcount += 1;
        v /= 10;
    }
    var pos: usize = 0;
    var i: usize = dcount;
    while (i > 0) {
        i -= 1;
        buf[pos] = digits[i];
        pos += 1;
    }
    buf[pos] = ':';
    pos += 1;
    return buf[0..pos];
}

// =============================================================================
// Toolbar icon rendering (GL vector shapes, VS Code codicon style)
// =============================================================================

/// New File icon: page outline with a "+" in the corner.
fn renderNewFileIcon(x: f32, y: f32, size: f32, color: Color) void {
    const s = size;
    const m = s * 0.15; // margin
    const lx = x + m;
    const rx = x + s - m;
    const ty = y + m;
    const by = y + s - m;
    const fold = s * 0.3; // corner fold size

    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(color.r, color.g, color.b, color.a);

    // Page outline (with folded corner)
    gl.glBegin(gl.GL_LINE_STRIP);
    gl.glVertex2f(lx, ty);
    gl.glVertex2f(rx - fold, ty);
    gl.glVertex2f(rx, ty + fold);
    gl.glVertex2f(rx, by);
    gl.glVertex2f(lx, by);
    gl.glVertex2f(lx, ty);
    gl.glEnd();

    // Corner fold line
    gl.glBegin(gl.GL_LINE_STRIP);
    gl.glVertex2f(rx - fold, ty);
    gl.glVertex2f(rx - fold, ty + fold);
    gl.glVertex2f(rx, ty + fold);
    gl.glEnd();

    // "+" sign (bottom-right area)
    const cx = rx - s * 0.15;
    const cy = by - s * 0.15;
    const ps = s * 0.18;
    gl.glBegin(gl.GL_LINES);
    gl.glVertex2f(cx - ps, cy);
    gl.glVertex2f(cx + ps, cy);
    gl.glVertex2f(cx, cy - ps);
    gl.glVertex2f(cx, cy + ps);
    gl.glEnd();
}

/// New Folder icon: folder shape with a "+" overlay.
fn renderNewFolderIcon(x: f32, y: f32, size: f32, color: Color) void {
    const s = size;
    const m = s * 0.12;
    const lx = x + m;
    const rx = x + s - m;
    const ty = y + s * 0.25;
    const by = y + s - m;
    const tab_w = s * 0.35;
    const tab_h = s * 0.15;

    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(color.r, color.g, color.b, color.a);

    // Folder body outline
    gl.glBegin(gl.GL_LINE_STRIP);
    gl.glVertex2f(lx, ty);
    gl.glVertex2f(lx + tab_w, ty);
    gl.glVertex2f(lx + tab_w + tab_h, ty - tab_h);
    gl.glVertex2f(lx, ty - tab_h);
    gl.glVertex2f(lx, ty);
    gl.glEnd();

    gl.glBegin(gl.GL_LINE_STRIP);
    gl.glVertex2f(lx, ty);
    gl.glVertex2f(lx, by);
    gl.glVertex2f(rx, by);
    gl.glVertex2f(rx, ty);
    gl.glVertex2f(lx + tab_w + tab_h, ty);
    gl.glEnd();

    // "+" sign (center)
    const cx = (lx + rx) * 0.5;
    const cy = (ty + by) * 0.5 + s * 0.05;
    const ps = s * 0.16;
    gl.glBegin(gl.GL_LINES);
    gl.glVertex2f(cx - ps, cy);
    gl.glVertex2f(cx + ps, cy);
    gl.glVertex2f(cx, cy - ps);
    gl.glVertex2f(cx, cy + ps);
    gl.glEnd();
}

/// Refresh icon: circular arrow.
fn renderRefreshIcon(x: f32, y: f32, size: f32, color: Color) void {
    const cx = x + size * 0.5;
    const cy = y + size * 0.5;
    const r = size * 0.32;

    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(color.r, color.g, color.b, color.a);

    // Arc (3/4 circle)
    gl.glBegin(gl.GL_LINE_STRIP);
    const segments: u8 = 12;
    var i: u8 = 0;
    while (i <= segments) : (i += 1) {
        const angle = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(segments)) * 4.712; // 3/4 * 2π
        const ax = cx + @cos(angle) * r;
        const ay = cy + @sin(angle) * r;
        gl.glVertex2f(ax, ay);
    }
    gl.glEnd();

    // Arrowhead at the end of the arc
    const end_angle: f32 = 4.712;
    const ex = cx + @cos(end_angle) * r;
    const ey = cy + @sin(end_angle) * r;
    const arrow_s = size * 0.12;
    gl.glBegin(gl.GL_TRIANGLES);
    gl.glVertex2f(ex, ey);
    gl.glVertex2f(ex - arrow_s, ey + arrow_s);
    gl.glVertex2f(ex + arrow_s, ey + arrow_s);
    gl.glEnd();
}

/// Collapse All icon: two downward chevrons stacked.
fn renderCollapseAllIcon(x: f32, y: f32, size: f32, color: Color) void {
    const cx = x + size * 0.5;
    const m = size * 0.2;
    const w = size * 0.28;

    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(color.r, color.g, color.b, color.a);

    // Top chevron (pointing down = collapsed)
    const y1 = y + m + size * 0.05;
    gl.glBegin(gl.GL_LINE_STRIP);
    gl.glVertex2f(cx - w, y1);
    gl.glVertex2f(cx, y1 + w * 0.7);
    gl.glVertex2f(cx + w, y1);
    gl.glEnd();

    // Bottom chevron
    const y2 = y1 + size * 0.28;
    gl.glBegin(gl.GL_LINE_STRIP);
    gl.glVertex2f(cx - w, y2);
    gl.glVertex2f(cx, y2 + w * 0.7);
    gl.glVertex2f(cx + w, y2);
    gl.glEnd();

    // Vertical line on left (tree indicator)
    gl.glBegin(gl.GL_LINES);
    gl.glVertex2f(x + m, y + m);
    gl.glVertex2f(x + m, y + size - m);
    gl.glEnd();
}

// =============================================================================
// Tests
// =============================================================================

const testing = @import("std").testing;

test "Sidebar default initialization" {
    const s = Sidebar{};
    try testing.expectEqual(@as(u8, 0), s.entry_count);
    try testing.expectEqual(@as(i16, -1), s.hover_row);
    try testing.expectEqual(@as(i16, -1), s.selected_row);
    try testing.expectEqual(@as(u16, 0), s.scroll_top);
    try testing.expectEqual(@as(u16, 0), s.search_query_len);
    try testing.expectEqual(@as(u16, 0), s.replace_query_len);
    try testing.expect(!s.search_regex);
    try testing.expect(!s.search_case_sensitive);
    try testing.expect(!s.search_whole_word);
}

test "addTreeEntry adds entries" {
    var s = Sidebar{};
    s.addTreeEntry("src", true, 0, true);
    s.addTreeEntry("main.zig", false, 1, false);
    try testing.expectEqual(@as(u8, 2), s.entry_count);
    try testing.expect(s.is_dir[0]);
    try testing.expect(!s.is_dir[1]);
    try testing.expect(s.expanded[0]);
    try testing.expect(!s.expanded[1]);
    try testing.expectEqual(@as(u8, 0), s.indent_level[0]);
    try testing.expectEqual(@as(u8, 1), s.indent_level[1]);
    try testing.expectEqualSlices(u8, "src", s.entries[0][0..s.entry_lens[0]]);
    try testing.expectEqualSlices(u8, "main.zig", s.entries[1][0..s.entry_lens[1]]);
}

test "addEntry is flat addTreeEntry" {
    var s = Sidebar{};
    s.addEntry("file.txt", false);
    try testing.expectEqual(@as(u8, 1), s.entry_count);
    try testing.expectEqual(@as(u8, 0), s.indent_level[0]);
}

test "clearEntries resets state" {
    var s = Sidebar{};
    s.addTreeEntry("a", false, 0, false);
    s.addTreeEntry("b", true, 0, true);
    s.selected_row = 1;
    s.clearEntries();
    try testing.expectEqual(@as(u8, 0), s.entry_count);
    try testing.expectEqual(@as(i16, -1), s.selected_row);
    try testing.expectEqual(@as(u16, 0), s.scroll_top);
}

test "setProjectName stores name" {
    var s = Sidebar{};
    s.setProjectName("my-project");
    try testing.expectEqualSlices(u8, "my-project", s.project_name[0..s.project_name_len]);
}

test "handleScroll clamps correctly" {
    var s = Sidebar{};
    s.addTreeEntry("a", false, 0, false);
    s.addTreeEntry("b", false, 0, false);
    s.handleScroll(-1); // scroll down
    try testing.expectEqual(@as(u16, 1), s.scroll_top);
    s.handleScroll(-100); // scroll way down — clamp
    try testing.expectEqual(@as(u16, 1), s.scroll_top); // clamped to entry_count-1
    s.handleScroll(100); // scroll way up — clamp to 0
    try testing.expectEqual(@as(u16, 0), s.scroll_top);
}

test "addTreeEntry respects MAX_ENTRIES" {
    var s = Sidebar{};
    var i: u8 = 0;
    while (i < MAX_ENTRIES + 5) : (i += 1) {
        s.addTreeEntry("x", false, 0, false);
    }
    try testing.expectEqual(@as(u8, @intCast(MAX_ENTRIES)), s.entry_count);
}

test "search char append and backspace" {
    var s = Sidebar{};
    s.appendSearchChar('h');
    s.appendSearchChar('i');
    try testing.expectEqual(@as(u16, 2), s.search_query_len);
    try testing.expectEqualSlices(u8, "hi", s.getSearchQuery());
    s.backspaceSearch();
    try testing.expectEqual(@as(u16, 1), s.search_query_len);
    try testing.expectEqualSlices(u8, "h", s.getSearchQuery());
    s.backspaceSearch();
    s.backspaceSearch(); // extra backspace on empty — no crash
    try testing.expectEqual(@as(u16, 0), s.search_query_len);
}

test "replace char append and backspace" {
    var s = Sidebar{};
    s.appendReplaceChar('a');
    s.appendReplaceChar('b');
    try testing.expectEqualSlices(u8, "ab", s.getReplaceQuery());
    s.backspaceReplace();
    try testing.expectEqualSlices(u8, "a", s.getReplaceQuery());
}

test "toggle search options" {
    var s = Sidebar{};
    try testing.expect(!s.search_regex);
    s.toggleRegex();
    try testing.expect(s.search_regex);
    s.toggleRegex();
    try testing.expect(!s.search_regex);

    try testing.expect(!s.search_case_sensitive);
    s.toggleCaseSensitive();
    try testing.expect(s.search_case_sensitive);

    try testing.expect(!s.search_whole_word);
    s.toggleWholeWord();
    try testing.expect(s.search_whole_word);
}

test "clearSearch resets search state" {
    var s = Sidebar{};
    s.appendSearchChar('x');
    s.appendReplaceChar('y');
    s.search_match_count = 5;
    s.clearSearch();
    try testing.expectEqual(@as(u16, 0), s.search_query_len);
    try testing.expectEqual(@as(u16, 0), s.replace_query_len);
    try testing.expectEqual(@as(u16, 0), s.search_match_count);
}

test "addMatch stores match data" {
    var s = Sidebar{};
    s.addMatch(0, 42, 5, 3, "hello world");
    try testing.expectEqual(@as(u16, 1), s.search_match_count);
    try testing.expectEqual(@as(u32, 42), s.search_matches[0].line_num);
    try testing.expectEqual(@as(u16, 5), s.search_matches[0].col);
    try testing.expectEqual(@as(u16, 3), s.search_matches[0].match_len);
    try testing.expectEqualSlices(u8, "hello world", s.search_matches[0].text[0..s.search_matches[0].text_len]);
}

test "addMatch respects MAX_MATCHES" {
    var s = Sidebar{};
    var i: u16 = 0;
    while (i < MAX_MATCHES + 10) : (i += 1) {
        s.addMatch(0, i, 0, 1, "x");
    }
    try testing.expectEqual(@as(u16, MAX_MATCHES), s.search_match_count);
}

test "formatMatchCount formats correctly" {
    var buf: [32]u8 = undefined;
    const result = formatMatchCount(42, &buf);
    try testing.expectEqualSlices(u8, "42 results", result);
}

test "formatMatchCount zero" {
    var buf: [32]u8 = undefined;
    const result = formatMatchCount(0, &buf);
    try testing.expectEqualSlices(u8, "0 results", result);
}

test "formatLineNum formats correctly" {
    var buf: [32]u8 = undefined;
    const result = formatLineNum(123, &buf);
    try testing.expectEqualSlices(u8, "123:", result);
}

test "formatLineNum zero gives 1:" {
    var buf: [32]u8 = undefined;
    const result = formatLineNum(0, &buf);
    try testing.expectEqualSlices(u8, "1:", result);
}

test "SearchMatch default initialization" {
    const m = SearchMatch{};
    try testing.expectEqual(@as(u8, 0), m.file_idx);
    try testing.expectEqual(@as(u32, 0), m.line_num);
    try testing.expectEqual(@as(u16, 0), m.col);
    try testing.expectEqual(@as(u16, 0), m.match_len);
    try testing.expectEqual(@as(u8, 0), m.text_len);
}

test "SearchField enum values" {
    try testing.expectEqual(@as(u8, 0), @intFromEnum(SearchField.search));
    try testing.expectEqual(@as(u8, 1), @intFromEnum(SearchField.replace));
}

test "addTreeEntryWithPath stores path" {
    var s = Sidebar{};
    const path = [_]u16{ 'C', ':', '\\', 'f', 'o', 'o', 0 };
    s.addTreeEntryWithPath("foo", false, 0, false, &path, 6);
    try testing.expectEqual(@as(u8, 1), s.entry_count);
    try testing.expectEqual(@as(u16, 6), s.entry_path_lens[0]);
    try testing.expectEqualSlices(u8, "foo", s.entries[0][0..s.entry_lens[0]]);
}

test "getEntryPath returns null for no path" {
    var s = Sidebar{};
    s.addTreeEntry("test", false, 0, false);
    try testing.expect(s.getEntryPath(0) == null);
}

test "getEntryPath returns path when stored" {
    var s = Sidebar{};
    const path = [_]u16{ 'a', 'b', 'c', 0 };
    s.addTreeEntryWithPath("abc", false, 0, false, &path, 3);
    const p = s.getEntryPath(0);
    try testing.expect(p != null);
}

test "moveUp and moveDown navigation" {
    var s = Sidebar{};
    s.addTreeEntry("a", false, 0, false);
    s.addTreeEntry("b", false, 0, false);
    s.addTreeEntry("c", false, 0, false);
    s.moveDown();
    try testing.expectEqual(@as(i16, 0), s.selected_row);
    s.moveDown();
    try testing.expectEqual(@as(i16, 1), s.selected_row);
    s.moveDown();
    try testing.expectEqual(@as(i16, 2), s.selected_row);
    s.moveDown(); // clamp at end
    try testing.expectEqual(@as(i16, 2), s.selected_row);
    s.moveUp();
    try testing.expectEqual(@as(i16, 1), s.selected_row);
    s.moveUp();
    try testing.expectEqual(@as(i16, 0), s.selected_row);
    s.moveUp(); // clamp at start
    try testing.expectEqual(@as(i16, 0), s.selected_row);
}

test "collapseOrParent collapses expanded dir" {
    var s = Sidebar{};
    s.addTreeEntry("src", true, 0, true);
    s.addTreeEntry("main.zig", false, 1, false);
    s.selected_row = 0;
    try testing.expect(s.expanded[0]);
    s.collapseOrParent();
    try testing.expect(!s.expanded[0]);
}

test "collapseOrParent moves to parent for file" {
    var s = Sidebar{};
    s.addTreeEntry("src", true, 0, true);
    s.addTreeEntry("main.zig", false, 1, false);
    s.selected_row = 1;
    s.collapseOrParent();
    try testing.expectEqual(@as(i16, 0), s.selected_row);
}

test "expandOrFirstChild expands collapsed dir" {
    var s = Sidebar{};
    s.addTreeEntry("src", true, 0, false);
    s.addTreeEntry("main.zig", false, 1, false);
    s.selected_row = 0;
    try testing.expect(!s.expanded[0]);
    s.expandOrFirstChild();
    try testing.expect(s.expanded[0]);
}

test "expandOrFirstChild moves to child when expanded" {
    var s = Sidebar{};
    s.addTreeEntry("src", true, 0, true);
    s.addTreeEntry("main.zig", false, 1, false);
    s.selected_row = 0;
    s.expandOrFirstChild();
    try testing.expectEqual(@as(i16, 1), s.selected_row);
}

test "inline rename start and commit" {
    var s = Sidebar{};
    s.addTreeEntry("old.zig", false, 0, false);
    s.selected_row = 0;
    s.startRename();
    try testing.expect(s.rename_active);
    try testing.expectEqualSlices(u8, "old.zig", s.getRenameText());
    // Clear and type new name
    s.rename_len = 0;
    s.renameAppendChar('n');
    s.renameAppendChar('e');
    s.renameAppendChar('w');
    try testing.expectEqualSlices(u8, "new", s.getRenameText());
    const committed = s.commitRename();
    try testing.expect(committed);
    try testing.expect(!s.rename_active);
    try testing.expectEqualSlices(u8, "new", s.entries[0][0..s.entry_lens[0]]);
}

test "inline rename cancel" {
    var s = Sidebar{};
    s.addTreeEntry("file.txt", false, 0, false);
    s.selected_row = 0;
    s.startRename();
    try testing.expect(s.rename_active);
    s.cancelRename();
    try testing.expect(!s.rename_active);
    try testing.expectEqualSlices(u8, "file.txt", s.entries[0][0..s.entry_lens[0]]);
}

test "rename backspace" {
    var s = Sidebar{};
    s.addTreeEntry("ab", false, 0, false);
    s.selected_row = 0;
    s.startRename();
    try testing.expectEqual(@as(u8, 2), s.rename_len);
    s.renameBackspace();
    try testing.expectEqual(@as(u8, 1), s.rename_len);
    s.renameBackspace();
    try testing.expectEqual(@as(u8, 0), s.rename_len);
    s.renameBackspace(); // no crash on empty
    try testing.expectEqual(@as(u8, 0), s.rename_len);
}

test "getParentDirPath returns null for depth 0" {
    var s = Sidebar{};
    s.addTreeEntry("root.zig", false, 0, false);
    try testing.expect(s.getParentDirPath(0) == null);
}

test "MAX_PATH_W constant" {
    try testing.expectEqual(@as(usize, 512), MAX_PATH_W);
}

test "ToolbarAction enum values" {
    try testing.expectEqual(@as(u8, 0), @intFromEnum(ToolbarAction.new_file));
    try testing.expectEqual(@as(u8, 1), @intFromEnum(ToolbarAction.new_folder));
    try testing.expectEqual(@as(u8, 2), @intFromEnum(ToolbarAction.refresh));
    try testing.expectEqual(@as(u8, 3), @intFromEnum(ToolbarAction.collapse_all));
}

test "TOOLBAR_BTN_COUNT is 4" {
    try testing.expectEqual(@as(u8, 4), TOOLBAR_BTN_COUNT);
}

test "toolbar_hover default is -1" {
    const s = Sidebar{};
    try testing.expectEqual(@as(i8, -1), s.toolbar_hover);
}

// =============================================================================
// Extensions view tests
// =============================================================================

test "EXT_COUNT matches manifest" {
    try testing.expectEqual(manifest.count, EXT_COUNT);
}

test "extensions default all installed and active" {
    const s = Sidebar{};
    for (s.ext_installed) |inst| {
        try testing.expect(inst);
    }
    for (s.ext_active) |act| {
        try testing.expect(act);
    }
}

test "toggleExtInstalled toggles and deactivates" {
    var s = Sidebar{};
    try testing.expect(s.ext_installed[0]);
    try testing.expect(s.ext_active[0]);
    s.toggleExtInstalled(0);
    try testing.expect(!s.ext_installed[0]);
    try testing.expect(!s.ext_active[0]); // uninstall deactivates
    s.toggleExtInstalled(0);
    try testing.expect(s.ext_installed[0]);
}

test "toggleExtActive requires installed" {
    var s = Sidebar{};
    s.ext_installed[0] = false;
    s.ext_active[0] = false;
    s.toggleExtActive(0); // should be no-op
    try testing.expect(!s.ext_active[0]);
    s.ext_installed[0] = true;
    s.toggleExtActive(0);
    try testing.expect(s.ext_active[0]);
}

test "countInstalled and countActive" {
    var s = Sidebar{};
    try testing.expectEqual(@as(u16, EXT_COUNT), s.countInstalled());
    try testing.expectEqual(@as(u16, EXT_COUNT), s.countActive());
    s.toggleExtInstalled(0);
    try testing.expectEqual(@as(u16, EXT_COUNT - 1), s.countInstalled());
    try testing.expectEqual(@as(u16, EXT_COUNT - 1), s.countActive());
}

test "ext filter append and backspace" {
    var s = Sidebar{};
    s.appendExtFilterChar('z');
    s.appendExtFilterChar('i');
    s.appendExtFilterChar('g');
    try testing.expectEqualSlices(u8, "zig", s.getExtFilter());
    s.backspaceExtFilter();
    try testing.expectEqualSlices(u8, "zi", s.getExtFilter());
    s.clearExtFilter();
    try testing.expectEqual(@as(u16, 0), s.ext_filter_len);
}

test "extMatchesFilter case insensitive" {
    var s = Sidebar{};
    s.appendExtFilterChar('Z');
    s.appendExtFilterChar('I');
    try testing.expect(s.extMatchesFilter("Zig Language"));
    try testing.expect(!s.extMatchesFilter("Python"));
}

test "extMatchesFilter empty matches all" {
    const s = Sidebar{};
    try testing.expect(s.extMatchesFilter("anything"));
    try testing.expect(s.extMatchesFilter(""));
}

test "getFilteredExtensions returns all when no filter" {
    const s = Sidebar{};
    var buf: [EXT_COUNT]u16 = undefined;
    const count = s.getFilteredExtensions(&buf);
    try testing.expectEqual(@as(u16, EXT_COUNT), count);
}

test "handleExtScroll clamps" {
    var s = Sidebar{};
    s.handleExtScroll(-3);
    try testing.expectEqual(@as(u16, 3), s.ext_scroll_top);
    s.handleExtScroll(2);
    try testing.expectEqual(@as(u16, 1), s.ext_scroll_top);
    s.handleExtScroll(100);
    try testing.expectEqual(@as(u16, 0), s.ext_scroll_top);
}

test "ext_hover_row default is -1" {
    const s = Sidebar{};
    try testing.expectEqual(@as(i16, -1), s.ext_hover_row);
    try testing.expectEqual(@as(i16, -1), s.ext_selected_row);
    try testing.expectEqual(@as(i8, -1), s.ext_hover_btn);
}

test "writeU16Buf formats numbers" {
    var buf: [64]u8 = undefined;
    const end = writeU16Buf(&buf, 0, 42);
    try testing.expectEqualSlices(u8, "42", buf[0..end]);
}

test "writeU16Buf formats zero" {
    var buf: [64]u8 = undefined;
    const end = writeU16Buf(&buf, 0, 0);
    try testing.expectEqualSlices(u8, "0", buf[0..end]);
}

test "toLowerAscii converts uppercase" {
    try testing.expectEqual(@as(u8, 'a'), toLowerAscii('A'));
    try testing.expectEqual(@as(u8, 'z'), toLowerAscii('Z'));
    try testing.expectEqual(@as(u8, 'a'), toLowerAscii('a'));
    try testing.expectEqual(@as(u8, '1'), toLowerAscii('1'));
}
