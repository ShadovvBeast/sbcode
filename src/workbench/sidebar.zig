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

pub const MAX_ENTRIES: usize = 64;
pub const MAX_LABEL_LEN: usize = 64;
pub const MAX_SEARCH_LEN: usize = 256;
pub const MAX_MATCHES: usize = 128;
pub const MAX_MATCH_TEXT: usize = 80;

pub const SearchMatch = struct {
    file_idx: u8 = 0,
    line_num: u32 = 0,
    col: u16 = 0,
    match_len: u16 = 0,
    text: [MAX_MATCH_TEXT]u8 = undefined,
    text_len: u8 = 0,
};

pub const SearchField = enum(u8) { search = 0, replace = 1 };

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
        self.entry_count += 1;
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
    }

    /// Update hover row from mouse position.
    pub fn updateHover(self: *Sidebar, mx: i32, my: i32, region: Rect, cell_h: i32) void {
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

    /// Render sidebar. active_icon: 0=explorer, 1=search.
    pub fn render(self: *const Sidebar, region: Rect, font_atlas: *const FontAtlas, active_icon: u8) void {
        // Background
        ft.renderAlphaRect(region.x, region.y, region.w, region.h, SIDEBAR_BG);
        if (region.w <= 0 or region.h <= 0) return;

        if (active_icon == 1) {
            self.renderSearchView(region, font_atlas);
        } else {
            self.renderExplorerView(region, font_atlas);
        }
    }

    // =========================================================================
    // Explorer view
    // =========================================================================

    fn renderExplorerView(self: *const Sidebar, region: Rect, font_atlas: *const FontAtlas) void {
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
                // Folder icon
                ft.renderFolderIcon(icon_x, ry + 2, icon_size, ft.DIR_ICON_COLOR);
            } else {
                // File icon with extension color
                const file_color = ft.fileNameColor(name, 1.0, false);
                ft.renderFileIcon(icon_x, ry + 2, icon_size, file_color);
            }

            // Label
            const label_color = ft.fileNameColor(name, 1.0, is_selected);
            font_atlas.renderText(name, @floatFromInt(text_x), @floatFromInt(text_y), label_color);
        }

        // Scrollbar
        if (self.entry_count > visible_rows) {
            self.renderScrollbar(region, content_y, content_h, visible_rows, self.entry_count, self.scroll_top);
        }
    }

    // =========================================================================
    // Search view
    // =========================================================================

    fn renderSearchView(self: *const Sidebar, region: Rect, font_atlas: *const FontAtlas) void {
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
                        const fcolor = ft.fileNameColor(fname, 1.0, false);
                        ft.renderFileIcon(region.x + pad, ry + 2, ch - 2, fcolor);
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
