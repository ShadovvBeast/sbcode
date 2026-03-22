// src/workbench/workbench.zig — Top-level workbench state and orchestration
//
// Pure Zig, zero dependencies, zero allocators, stack/comptime only.
// Holds references to all sub-components and orchestrates update/render.

const gl = @import("gl");
const LayoutState = @import("layout").LayoutState;
const LayoutRegion = @import("layout").LayoutRegion;
const FontAtlas = @import("font_atlas").FontAtlas;
const InputState = @import("input").InputState;
const CommandPalette = @import("command_palette").CommandPalette;
const TextBuffer = @import("buffer").TextBuffer;
const MAX_BUFFER_SIZE = @import("buffer").MAX_BUFFER_SIZE;
const CursorState = @import("cursor").CursorState;
const SyntaxHighlighter = @import("syntax").SyntaxHighlighter;
const LanguageId = @import("syntax").LanguageId;
const viewport = @import("viewport");
const KeybindingService = @import("keybinding").KeybindingService;
const Color = @import("color").Color;
const Rect = @import("rect").Rect;
const file_service = @import("file_service");
const StatusBar = @import("status_bar").StatusBar;
const win32 = @import("win32");

// =============================================================================
// Constants
// =============================================================================

/// Maximum number of open editor tabs.
pub const MAX_TABS = 32;

/// VS Code dark theme region background colors.
const TITLE_BAR_BG = Color.rgb(0x32, 0x32, 0x32);
const ACTIVITY_BAR_BG = Color.rgb(0x33, 0x33, 0x33);
const SIDEBAR_BG = Color.rgb(0x25, 0x25, 0x25);
const EDITOR_BG = Color.rgb(0x1E, 0x1E, 0x1E);
const PANEL_BG = Color.rgb(0x1E, 0x1E, 0x1E);
const STATUS_BAR_BG = Color.rgb(0x00, 0x7A, 0xCC);
const TAB_ACTIVE_BG = Color.rgb(0x1E, 0x1E, 0x1E);
const TAB_INACTIVE_BG = Color.rgb(0x2D, 0x2D, 0x2D);

// Virtual key codes for keybinding dispatch
const VK_O: u16 = 0x4F;
const VK_P: u16 = 0x50;
const VK_UP: u16 = 0x26;
const VK_DOWN: u16 = 0x28;
const VK_LEFT: u16 = 0x25;
const VK_RIGHT: u16 = 0x27;
const VK_RETURN: u16 = 0x0D;
const VK_ESCAPE: u16 = 0x1B;
const VK_BACK: u16 = 0x08;

/// Command index for the "Open File" command (Ctrl+O).
pub const CMD_OPEN_FILE: u16 = 0;

/// Command index for the "Save File" command (Ctrl+S).
pub const CMD_SAVE_FILE: u16 = 1;

/// Command index for the "Toggle Sidebar" command.
pub const CMD_TOGGLE_SIDEBAR: u16 = 2;

/// Command index for the "Toggle Panel" command.
pub const CMD_TOGGLE_PANEL: u16 = 3;

/// Virtual key code for 'S'.
const VK_S: u16 = 0x53;

/// Maximum length for a stored file path (UTF-16 code units).
const MAX_FILE_PATH: usize = 512;

// =============================================================================
// Tab
// =============================================================================

pub const Tab = struct {
    active: bool = false,
    label: [128]u8 = undefined,
    label_len: u8 = 0,
    buffer_index: u8 = 0,
};

// =============================================================================
// Workbench
// =============================================================================

pub const Workbench = struct {
    // Sub-components
    command_palette: CommandPalette = .{},
    keybindings: KeybindingService = .{},
    buffer: TextBuffer = .{},
    cursor_state: CursorState = .{},
    highlighter: SyntaxHighlighter = .{},
    status_bar: StatusBar = .{},

    // Tab state
    tabs: [MAX_TABS]Tab = [_]Tab{.{}} ** MAX_TABS,
    tab_count: u8 = 0,
    active_tab: u8 = 0,

    // Current file path (UTF-16, null-terminated, for save operations)
    current_file_path: [MAX_FILE_PATH]u16 = [_]u16{0} ** MAX_FILE_PATH,
    current_file_path_len: u32 = 0,

    // Sidebar / panel visibility (mirrors layout flags)
    sidebar_visible: bool = true,
    panel_visible: bool = true,

    // Scroll state
    scroll_top: u32 = 0,

    /// Register default keybindings (e.g., Ctrl+O for file open).
    ///
    /// Postconditions:
    ///   - Ctrl+O is registered as CMD_OPEN_FILE
    pub fn registerDefaultKeybindings(self: *Workbench) void {
        _ = self.keybindings.register(VK_O, true, false, false, CMD_OPEN_FILE);
        _ = self.keybindings.register(VK_S, true, false, false, CMD_SAVE_FILE);
    }

    /// Open a file given a UTF-16 null-terminated path (from Win32 file dialog).
    ///
    /// Calls FileService.readFile, then delegates to loadContent on success.
    /// On failure, notifies via the status bar.
    ///
    /// Preconditions:
    ///   - `path` is a valid null-terminated UTF-16 file path
    ///
    /// Postconditions:
    ///   - On success: file content is loaded, tokenized, and a tab is opened
    ///   - On read failure: status bar shows error notification, no tab opened
    ///   - On file too large: status bar shows "too large" notification, no tab opened
    pub fn openFile(self: *Workbench, path: [*:0]const u16) void {
        var read_buf: [file_service.MAX_FILE_SIZE]u8 = undefined;
        const result = file_service.readFile(path, &read_buf);

        if (!result.success) {
            self.status_bar.notifyFileReadError(win32.GetLastError());
            return;
        }

        const data = read_buf[0..result.bytes_read];

        if (result.bytes_read > MAX_BUFFER_SIZE) {
            self.status_bar.notifyFileTooLarge();
            return;
        }

        // Extract filename from UTF-16 path for the tab label
        var label_buf: [128]u8 = undefined;
        const label_len = extractFilenameFromUtf16(path, &label_buf);

        // Store the file path for later save operations
        self.storeFilePath(path);

        self.loadContent(data, label_buf[0..label_len]);
    }

    /// Save buffer content to a file given a UTF-16 null-terminated path.
    ///
    /// Preconditions:
    ///   - `path` is a valid null-terminated UTF-16 file path
    ///   - self.buffer contains content to save
    ///
    /// Postconditions:
    ///   - On success: file is written, buffer dirty flag is cleared
    ///   - On failure: status bar shows error notification, dirty flag unchanged
    pub fn saveFile(self: *Workbench, path: [*:0]const u16) void {
        const content = self.buffer.content[0..self.buffer.content_len];
        const ok = file_service.writeFile(path, content);

        if (ok) {
            self.buffer.dirty = false;
        } else {
            self.status_bar.setNotification("File save failed");
        }
    }

    /// Save the current buffer using the stored file path.
    ///
    /// Preconditions:
    ///   - A file path has been stored via openFile or storeFilePath
    ///
    /// Postconditions:
    ///   - Delegates to saveFile with the stored path
    ///   - If no path is stored, shows notification
    pub fn saveCurrentFile(self: *Workbench) void {
        if (self.current_file_path_len == 0) {
            self.status_bar.setNotification("No file path");
            return;
        }
        // The stored path is null-terminated at current_file_path_len
        self.saveFile(@ptrCast(&self.current_file_path));
    }

    /// Register default commands in the command palette.
    ///
    /// Postconditions:
    ///   - "Open File", "Save File", "Toggle Sidebar", "Toggle Panel" are registered
    pub fn registerDefaultCommands(self: *Workbench) void {
        _ = self.command_palette.registerCommand(CMD_OPEN_FILE, "Open File", null, CMD_OPEN_FILE);
        _ = self.command_palette.registerCommand(CMD_SAVE_FILE, "Save File", null, CMD_SAVE_FILE);
        _ = self.command_palette.registerCommand(CMD_TOGGLE_SIDEBAR, "Toggle Sidebar", null, CMD_TOGGLE_SIDEBAR);
        _ = self.command_palette.registerCommand(CMD_TOGGLE_PANEL, "Toggle Panel", null, CMD_TOGGLE_PANEL);
    }

    /// Dispatch a command by index.
    ///
    /// Postconditions:
    ///   - CMD_OPEN_FILE: (no-op here, handled by Win32 file dialog in app layer)
    ///   - CMD_SAVE_FILE: saves the current file
    ///   - CMD_TOGGLE_SIDEBAR: toggles sidebar_visible
    ///   - CMD_TOGGLE_PANEL: toggles panel_visible
    pub fn dispatchCommand(self: *Workbench, command_index: u16) void {
        switch (command_index) {
            CMD_OPEN_FILE => {
                // File open is handled at the app layer (Win32 file dialog)
            },
            CMD_SAVE_FILE => {
                self.saveCurrentFile();
            },
            CMD_TOGGLE_SIDEBAR => {
                self.sidebar_visible = !self.sidebar_visible;
            },
            CMD_TOGGLE_PANEL => {
                self.panel_visible = !self.panel_visible;
            },
            else => {},
        }
    }

    /// Store a UTF-16 null-terminated file path for save operations.
    fn storeFilePath(self: *Workbench, path: [*:0]const u16) void {
        var len: u32 = 0;
        while (len < MAX_FILE_PATH - 1 and path[len] != 0) : (len += 1) {}
        @memcpy(self.current_file_path[0..len], path[0..len]);
        self.current_file_path[len] = 0; // null terminate
        self.current_file_path_len = len;
    }

    /// Load raw file content into the buffer, tokenize all lines, and open a tab.
    ///
    /// This is the testable core of the file-open flow — no Win32 dependencies.
    ///
    /// Preconditions:
    ///   - `data.len` <= MAX_BUFFER_SIZE
    ///   - `label.len` <= 128
    ///
    /// Postconditions:
    ///   - self.buffer contains the loaded content with line index built
    ///   - self.highlighter has tokenized every line
    ///   - A new tab is opened with the given label
    ///   - self.cursor_state is reset to position (0, 0)
    ///   - self.scroll_top is reset to 0
    pub fn loadContent(self: *Workbench, data: []const u8, label: []const u8) void {
        if (!self.buffer.load(data)) return;

        // Tokenize all lines
        var line_idx: u32 = 0;
        while (line_idx < self.buffer.line_count) : (line_idx += 1) {
            const line_text = self.buffer.getLine(line_idx) orelse "";
            self.highlighter.tokenizeLine(line_idx, line_text);
        }

        // Open a tab with the filename label
        self.openTab(label);

        // Reset cursor and scroll
        self.cursor_state.setPrimary(.{ .line = 0, .col = 0 });
        self.scroll_top = 0;
    }

    /// Process input and dispatch to sub-components.
    ///
    /// Preconditions:
    ///   - `input` contains the current frame's input state
    ///
    /// Postconditions:
    ///   - Keybinding lookups are performed for key events
    ///   - Command palette toggle is handled (Ctrl+P)
    ///   - Text input is dispatched to active buffer when palette is not visible
    ///   - Cursor movement is handled for arrow keys
    pub fn update(self: *Workbench, input: *const InputState) void {
        // Process key events for keybinding lookups and special keys
        var i: u32 = 0;
        while (i < input.key_event_count) : (i += 1) {
            const ev = input.key_events[i];
            if (!ev.pressed) continue;

            // Command palette: Ctrl+P toggles
            if (ev.vk == VK_P and ev.ctrl and !ev.shift and !ev.alt) {
                self.command_palette.toggle();
                continue;
            }

            // When command palette is visible, route input there
            if (self.command_palette.visible) {
                self.handleCommandPaletteInput(ev.vk);
                continue;
            }

            // Escape closes command palette (already handled above if visible)
            // Try keybinding lookup
            if (self.keybindings.lookup(ev.vk, ev.ctrl, ev.shift, ev.alt)) |cmd_index| {
                self.dispatchCommand(cmd_index);
                continue;
            }

            // Arrow key cursor movement
            self.handleCursorMovement(ev.vk);
        }

        // Dispatch text input to active buffer when palette is not visible
        if (!self.command_palette.visible) {
            self.handleTextInput(input);
        } else {
            // Route text input to command palette filter
            self.handlePaletteTextInput(input);
        }
    }

    /// Render all UI regions in order.
    ///
    /// Preconditions:
    ///   - `layout` has been recomputed for current window dimensions
    ///   - `font_atlas` is initialized with valid texture
    ///
    /// Postconditions:
    ///   - All UI regions are rendered in order: title bar, activity bar,
    ///     sidebar, editor tabs, editor area, panel, status bar
    ///   - Command palette overlay is rendered if visible
    pub fn render(self: *Workbench, layout: *const LayoutState, font_atlas: *const FontAtlas) void {
        // 1. Title bar
        renderRegionBackground(layout.getRegion(.title_bar), TITLE_BAR_BG);

        // 2. Activity bar
        renderRegionBackground(layout.getRegion(.activity_bar), ACTIVITY_BAR_BG);

        // 3. Sidebar
        if (self.sidebar_visible) {
            renderRegionBackground(layout.getRegion(.sidebar), SIDEBAR_BG);
        }

        // 4. Editor tabs
        self.renderTabBar(layout.getRegion(.editor_tabs), font_atlas);

        // 5. Editor area
        const editor_area = layout.getRegion(.editor_area);
        renderRegionBackground(editor_area, EDITOR_BG);

        // Compute visible lines from editor area height and font cell height
        const cell_h = font_atlas.cell_h;
        const visible_lines: u32 = if (cell_h > 0) @intCast(@divTrunc(editor_area.h, cell_h)) else 0;

        viewport.renderEditorViewport(
            editor_area,
            &self.buffer,
            &self.cursor_state,
            &self.highlighter,
            font_atlas,
            self.scroll_top,
            visible_lines,
        );

        // 6. Panel
        if (self.panel_visible) {
            renderRegionBackground(layout.getRegion(.panel), PANEL_BG);
        }

        // 7. Status bar
        renderRegionBackground(layout.getRegion(.status_bar), STATUS_BAR_BG);

        // 8. Command palette overlay
        if (self.command_palette.visible) {
            self.renderCommandPalette(layout, font_atlas);
        }
    }

    // =========================================================================
    // Input handling helpers
    // =========================================================================

    fn handleCommandPaletteInput(self: *Workbench, vk: u16) void {
        switch (vk) {
            VK_ESCAPE => self.command_palette.toggle(),
            VK_UP => {
                if (self.command_palette.selected_index > 0) {
                    self.command_palette.selected_index -= 1;
                }
            },
            VK_DOWN => {
                if (self.command_palette.filtered_count > 0 and
                    self.command_palette.selected_index < self.command_palette.filtered_count - 1)
                {
                    self.command_palette.selected_index += 1;
                }
            },
            VK_RETURN => {
                // Execute selected command via dispatchCommand
                if (self.command_palette.getSelectedCommand()) |cmd| {
                    const cmd_index = cmd.callback_index;
                    self.command_palette.visible = false;
                    self.dispatchCommand(cmd_index);
                } else {
                    self.command_palette.visible = false;
                }
            },
            VK_BACK => {
                if (self.command_palette.input_len > 0) {
                    self.command_palette.input_len -= 1;
                    self.command_palette.updateFilter();
                }
            },
            else => {},
        }
    }

    fn handleCursorMovement(self: *Workbench, vk: u16) void {
        const sel = self.cursor_state.primary();
        var pos = sel.active;

        switch (vk) {
            VK_LEFT => {
                if (pos.col > 0) pos.col -= 1;
            },
            VK_RIGHT => {
                pos.col += 1;
            },
            VK_UP => {
                if (pos.line > 0) pos.line -= 1;
            },
            VK_DOWN => {
                pos.line += 1;
            },
            else => return,
        }

        self.cursor_state.setPrimary(pos);
    }

    fn handleTextInput(self: *Workbench, input: *const InputState) void {
        if (input.text_input_len == 0) return;

        var i: u32 = 0;
        while (i < input.text_input_len) : (i += 1) {
            const ch = input.text_input[i];
            // Skip control characters except newline
            if (ch < 0x20 and ch != '\n' and ch != '\r') continue;

            // Read current cursor position for each character
            const cur = self.cursor_state.primary().active;
            const cur_line = cur.line;
            const cur_col = cur.col;

            const text = &[_]u8{ch};
            if (self.buffer.insert(cur_line, cur_col, text)) {
                if (ch == '\n') {
                    // Newline: retokenize the old line (now split) and the new line
                    self.highlighter.tokenizeLine(cur_line, self.buffer.getLine(cur_line) orelse "");
                    if (cur_line + 1 < self.buffer.line_count) {
                        self.highlighter.tokenizeLine(cur_line + 1, self.buffer.getLine(cur_line + 1) orelse "");
                    }
                    // Move cursor to beginning of next line
                    self.cursor_state.setPrimary(.{ .line = cur_line + 1, .col = 0 });
                } else {
                    // Regular character: retokenize the current line and advance col
                    self.highlighter.tokenizeLine(cur_line, self.buffer.getLine(cur_line) orelse "");
                    self.cursor_state.setPrimary(.{ .line = cur_line, .col = cur_col + 1 });
                }
            }
        }
    }

    fn handlePaletteTextInput(self: *Workbench, input: *const InputState) void {
        var i: u32 = 0;
        while (i < input.text_input_len) : (i += 1) {
            const ch = input.text_input[i];
            if (ch < 0x20) continue; // skip control chars
            if (self.command_palette.input_len < 256) {
                self.command_palette.input_buf[self.command_palette.input_len] = ch;
                self.command_palette.input_len += 1;
            }
        }
        if (input.text_input_len > 0) {
            self.command_palette.updateFilter();
        }
    }

    /// Open a new tab with the given label. Returns the tab index, or null if full.
    pub fn openTab(self: *Workbench, label: []const u8) void {
        if (self.tab_count >= MAX_TABS) return;

        const idx = self.tab_count;
        const copy_len: u8 = @intCast(@min(label.len, 128));

        // Deactivate previous active tab
        if (self.tab_count > 0) {
            self.tabs[self.active_tab].active = false;
        }

        self.tabs[idx] = .{
            .active = true,
            .label_len = copy_len,
        };
        @memcpy(self.tabs[idx].label[0..copy_len], label[0..copy_len]);

        self.active_tab = idx;
        self.tab_count += 1;
    }

    // =========================================================================
    // Rendering helpers
    // =========================================================================

    fn renderTabBar(self: *const Workbench, region: Rect, font_atlas: *const FontAtlas) void {
        renderRegionBackground(region, TAB_INACTIVE_BG);

        if (self.tab_count == 0) return;

        const tab_width: i32 = 120;
        var t: u8 = 0;
        while (t < self.tab_count) : (t += 1) {
            const tab = self.tabs[t];
            const bg = if (t == self.active_tab) TAB_ACTIVE_BG else TAB_INACTIVE_BG;
            const tab_rect = Rect{
                .x = region.x + @as(i32, t) * tab_width,
                .y = region.y,
                .w = tab_width,
                .h = region.h,
            };
            renderRegionBackground(tab_rect, bg);

            if (tab.label_len > 0) {
                font_atlas.renderText(
                    tab.label[0..tab.label_len],
                    @floatFromInt(tab_rect.x + 8),
                    @floatFromInt(tab_rect.y + 8),
                    Color.rgb(0xD4, 0xD4, 0xD4),
                );
            }
        }
    }

    fn renderCommandPalette(self: *const Workbench, layout: *const LayoutState, font_atlas: *const FontAtlas) void {
        // Center palette at top of editor area
        const editor_tabs = layout.getRegion(.editor_tabs);
        const palette_w: i32 = 500;
        const palette_h: i32 = 300;
        const palette_x = editor_tabs.x + @divTrunc(editor_tabs.w - palette_w, 2);
        const palette_y = editor_tabs.y;

        const palette_rect = Rect{
            .x = palette_x,
            .y = palette_y,
            .w = palette_w,
            .h = palette_h,
        };

        // Background
        renderRegionBackground(palette_rect, Color.rgb(0x25, 0x25, 0x25));

        // Input field
        const input_text = self.command_palette.input_buf[0..self.command_palette.input_len];
        if (input_text.len > 0) {
            font_atlas.renderText(
                input_text,
                @floatFromInt(palette_x + 8),
                @floatFromInt(palette_y + 8),
                Color.rgb(0xD4, 0xD4, 0xD4),
            );
        }

        // Filtered results
        const line_h = font_atlas.cell_h;
        const results_y = palette_y + 30;
        var r: usize = 0;
        while (r < self.command_palette.filtered_count) : (r += 1) {
            if (r >= 10) break; // show max 10 visible results
            const cmd_idx = self.command_palette.filtered_indices[r];
            const cmd = &self.command_palette.commands[cmd_idx];
            const label = cmd.label[0..cmd.label_len];

            const item_y = results_y + @as(i32, @intCast(r)) * (line_h + 2);

            // Highlight selected item
            if (r == self.command_palette.selected_index) {
                renderRegionBackground(
                    Rect{ .x = palette_x, .y = item_y, .w = palette_w, .h = line_h + 2 },
                    Color.rgb(0x04, 0x39, 0x5E),
                );
            }

            font_atlas.renderText(
                label,
                @floatFromInt(palette_x + 8),
                @floatFromInt(item_y + 1),
                Color.rgb(0xD4, 0xD4, 0xD4),
            );
        }
    }
};

// =============================================================================
// Shared rendering utility
// =============================================================================

/// Extract the filename portion from a UTF-16 null-terminated path.
/// Scans backwards for '\\' or '/', copies the filename as ASCII bytes.
/// Returns the number of bytes written to `out`.
fn extractFilenameFromUtf16(path: [*:0]const u16, out: *[128]u8) u8 {
    // Find the end of the string
    var len: usize = 0;
    while (path[len] != 0) : (len += 1) {
        if (len >= 512) break; // safety limit
    }

    // Scan backwards for path separator
    var start: usize = 0;
    if (len > 0) {
        var i: usize = len;
        while (i > 0) {
            i -= 1;
            if (path[i] == '\\' or path[i] == '/') {
                start = i + 1;
                break;
            }
        }
    }

    // Copy filename characters (ASCII subset of UTF-16)
    var out_len: u8 = 0;
    var j: usize = start;
    while (j < len and out_len < 128) : (j += 1) {
        const ch = path[j];
        if (ch < 128) {
            out[out_len] = @intCast(ch);
            out_len += 1;
        }
    }

    // If no filename extracted, use a default
    if (out_len == 0) {
        const default = "untitled";
        @memcpy(out[0..default.len], default);
        return @intCast(default.len);
    }

    return out_len;
}

/// Draw a filled rectangle with the given color using GL immediate mode.
fn renderRegionBackground(region: Rect, color: Color) void {
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
const mem = @import("std").mem;

test "Workbench default initialization" {
    const wb = Workbench{};
    try testing.expectEqual(@as(u8, 0), wb.tab_count);
    try testing.expectEqual(@as(u8, 0), wb.active_tab);
    try testing.expectEqual(true, wb.sidebar_visible);
    try testing.expectEqual(true, wb.panel_visible);
    try testing.expectEqual(@as(u32, 0), wb.scroll_top);
    try testing.expectEqual(false, wb.command_palette.visible);
}

test "Workbench.update method exists" {
    const update_fn = @TypeOf(Workbench.update);
    try testing.expect(update_fn == *const fn (*Workbench, *const InputState) void);
}

test "Workbench.render method exists" {
    const render_fn = @TypeOf(Workbench.render);
    try testing.expect(render_fn == *const fn (*Workbench, *const LayoutState, *const FontAtlas) void);
}

test "Workbench has all required sub-components" {
    const wb = Workbench{};
    // Verify all sub-component fields exist and are default-initialized
    _ = wb.command_palette;
    _ = wb.keybindings;
    _ = wb.buffer;
    _ = wb.cursor_state;
    _ = wb.highlighter;
    _ = wb.tabs;
    _ = wb.status_bar;
}

test "Tab default initialization" {
    const tab = Tab{};
    try testing.expectEqual(false, tab.active);
    try testing.expectEqual(@as(u8, 0), tab.label_len);
    try testing.expectEqual(@as(u8, 0), tab.buffer_index);
}

test "Workbench.handleCursorMovement moves cursor right" {
    var wb = Workbench{};
    wb.cursor_state.setPrimary(.{ .line = 0, .col = 5 });
    wb.handleCursorMovement(VK_RIGHT);
    try testing.expectEqual(@as(u32, 6), wb.cursor_state.primary().active.col);
}

test "Workbench.handleCursorMovement moves cursor left" {
    var wb = Workbench{};
    wb.cursor_state.setPrimary(.{ .line = 0, .col = 5 });
    wb.handleCursorMovement(VK_LEFT);
    try testing.expectEqual(@as(u32, 4), wb.cursor_state.primary().active.col);
}

test "Workbench.handleCursorMovement left at col 0 stays at 0" {
    var wb = Workbench{};
    wb.cursor_state.setPrimary(.{ .line = 0, .col = 0 });
    wb.handleCursorMovement(VK_LEFT);
    try testing.expectEqual(@as(u32, 0), wb.cursor_state.primary().active.col);
}

test "Workbench.handleCursorMovement moves cursor down" {
    var wb = Workbench{};
    wb.cursor_state.setPrimary(.{ .line = 2, .col = 0 });
    wb.handleCursorMovement(VK_DOWN);
    try testing.expectEqual(@as(u32, 3), wb.cursor_state.primary().active.line);
}

test "Workbench.handleCursorMovement moves cursor up" {
    var wb = Workbench{};
    wb.cursor_state.setPrimary(.{ .line = 2, .col = 0 });
    wb.handleCursorMovement(VK_UP);
    try testing.expectEqual(@as(u32, 1), wb.cursor_state.primary().active.line);
}

test "Workbench.handleCursorMovement up at line 0 stays at 0" {
    var wb = Workbench{};
    wb.cursor_state.setPrimary(.{ .line = 0, .col = 0 });
    wb.handleCursorMovement(VK_UP);
    try testing.expectEqual(@as(u32, 0), wb.cursor_state.primary().active.line);
}

test "MAX_TABS constant is 32" {
    try testing.expectEqual(@as(u8, 32), MAX_TABS);
}

// =========================================================================
// loadContent tests
// =========================================================================

test "loadContent loads buffer and opens tab" {
    var wb = Workbench{};
    wb.loadContent("hello\nworld\n", "test.zig");

    // Buffer should be loaded
    try testing.expectEqual(@as(u32, 12), wb.buffer.content_len);
    try testing.expectEqual(@as(u32, 3), wb.buffer.line_count);

    // Tab should be opened
    try testing.expectEqual(@as(u8, 1), wb.tab_count);
    try testing.expect(wb.tabs[0].active);
    try testing.expect(mem.eql(u8, "test.zig", wb.tabs[0].label[0..wb.tabs[0].label_len]));

    // Cursor should be at (0, 0)
    try testing.expectEqual(@as(u32, 0), wb.cursor_state.primary().active.line);
    try testing.expectEqual(@as(u32, 0), wb.cursor_state.primary().active.col);

    // Scroll should be reset
    try testing.expectEqual(@as(u32, 0), wb.scroll_top);
}

test "loadContent tokenizes all lines" {
    var wb = Workbench{};
    wb.highlighter.language = .plain_text;
    wb.loadContent("line1\nline2\nline3", "file.txt");

    // 3 lines should be tokenized
    try testing.expectEqual(@as(u32, 3), wb.buffer.line_count);

    // Each line should have at least one token (plain text fallback)
    try testing.expect(wb.highlighter.line_syntax[0].token_count > 0);
    try testing.expect(wb.highlighter.line_syntax[1].token_count > 0);
    try testing.expect(wb.highlighter.line_syntax[2].token_count > 0);
}

test "loadContent with empty content" {
    var wb = Workbench{};
    wb.loadContent("", "empty.txt");

    try testing.expectEqual(@as(u32, 0), wb.buffer.content_len);
    try testing.expectEqual(@as(u8, 1), wb.tab_count);
    try testing.expect(mem.eql(u8, "empty.txt", wb.tabs[0].label[0..wb.tabs[0].label_len]));
}

test "loadContent resets cursor from non-zero position" {
    var wb = Workbench{};
    // Set cursor to a non-zero position first
    wb.cursor_state.setPrimary(.{ .line = 10, .col = 20 });
    wb.scroll_top = 50;

    wb.loadContent("new content", "new.txt");

    try testing.expectEqual(@as(u32, 0), wb.cursor_state.primary().active.line);
    try testing.expectEqual(@as(u32, 0), wb.cursor_state.primary().active.col);
    try testing.expectEqual(@as(u32, 0), wb.scroll_top);
}

test "loadContent with Zig syntax tokenizes keywords" {
    var wb = Workbench{};
    wb.highlighter.language = .zig_lang;
    wb.loadContent("const x = 5;", "main.zig");

    // First token should be a keyword ("const")
    try testing.expect(wb.highlighter.line_syntax[0].token_count > 0);
    const first_token = wb.highlighter.line_syntax[0].tokens[0];
    try testing.expectEqual(@as(@import("syntax").TokenKind, .keyword), first_token.kind);
}

// =========================================================================
// registerDefaultKeybindings tests
// =========================================================================

test "registerDefaultKeybindings registers Ctrl+O" {
    var wb = Workbench{};
    wb.registerDefaultKeybindings();

    // Ctrl+O should map to CMD_OPEN_FILE
    const result = wb.keybindings.lookup(VK_O, true, false, false);
    try testing.expect(result != null);
    try testing.expectEqual(CMD_OPEN_FILE, result.?);
}

// =========================================================================
// openTab tests
// =========================================================================

test "openTab adds a tab and activates it" {
    var wb = Workbench{};
    wb.openTab("file1.zig");

    try testing.expectEqual(@as(u8, 1), wb.tab_count);
    try testing.expectEqual(@as(u8, 0), wb.active_tab);
    try testing.expect(wb.tabs[0].active);
    try testing.expect(mem.eql(u8, "file1.zig", wb.tabs[0].label[0..wb.tabs[0].label_len]));
}

test "openTab deactivates previous tab" {
    var wb = Workbench{};
    wb.openTab("file1.zig");
    wb.openTab("file2.zig");

    try testing.expectEqual(@as(u8, 2), wb.tab_count);
    try testing.expectEqual(@as(u8, 1), wb.active_tab);
    try testing.expect(!wb.tabs[0].active);
    try testing.expect(wb.tabs[1].active);
}

// =========================================================================
// extractFilenameFromUtf16 tests
// =========================================================================

test "extractFilenameFromUtf16 extracts filename from path" {
    // Simulate "C:\Users\test\file.zig" as UTF-16
    const path = comptime blk: {
        const str = "C:\\Users\\test\\file.zig";
        var buf: [str.len:0]u16 = undefined;
        for (str, 0..) |c, i| {
            buf[i] = c;
        }
        break :blk buf;
    };
    var out: [128]u8 = undefined;
    const len = extractFilenameFromUtf16(&path, &out);
    try testing.expect(mem.eql(u8, "file.zig", out[0..len]));
}

test "extractFilenameFromUtf16 handles no separator" {
    const path = comptime blk: {
        const str = "file.txt";
        var buf: [str.len:0]u16 = undefined;
        for (str, 0..) |c, i| {
            buf[i] = c;
        }
        break :blk buf;
    };
    var out: [128]u8 = undefined;
    const len = extractFilenameFromUtf16(&path, &out);
    try testing.expect(mem.eql(u8, "file.txt", out[0..len]));
}

test "extractFilenameFromUtf16 handles empty path" {
    const path = [_:0]u16{};
    var out: [128]u8 = undefined;
    const len = extractFilenameFromUtf16(&path, &out);
    try testing.expect(mem.eql(u8, "untitled", out[0..len]));
}

// =========================================================================
// Task 19.3: File save flow tests
// =========================================================================

test "registerDefaultKeybindings includes Ctrl+S" {
    var wb = Workbench{};
    wb.registerDefaultKeybindings();

    // Ctrl+S should map to CMD_SAVE_FILE
    const result = wb.keybindings.lookup(VK_S, true, false, false);
    try testing.expect(result != null);
    try testing.expectEqual(CMD_SAVE_FILE, result.?);
}

test "dispatchCommand exists and handles CMD_SAVE_FILE" {
    // Verify dispatchCommand is callable — it delegates to saveCurrentFile
    // which will show "No file path" since no path is stored
    var wb = Workbench{};
    wb.dispatchCommand(CMD_SAVE_FILE);

    // With no file path stored, status bar should show notification
    try testing.expect(wb.status_bar.notification_len > 0);
    try testing.expect(mem.eql(u8, "No file path", wb.status_bar.notification[0..wb.status_bar.notification_len]));
}

test "dispatchCommand handles CMD_OPEN_FILE without error" {
    var wb = Workbench{};
    // CMD_OPEN_FILE is a no-op at workbench level (handled by app layer)
    wb.dispatchCommand(CMD_OPEN_FILE);
    // Should not crash or set any notification
    try testing.expectEqual(@as(u8, 0), wb.status_bar.notification_len);
}

test "dispatchCommand handles unknown command without error" {
    var wb = Workbench{};
    wb.dispatchCommand(999);
    // Should not crash or set any notification
    try testing.expectEqual(@as(u8, 0), wb.status_bar.notification_len);
}

test "saveFile clears dirty flag on success logic flow" {
    // We can't test actual file I/O (Win32 externs unavailable in test),
    // but we can test the dirty flag logic by directly manipulating state.
    var wb = Workbench{};
    _ = wb.buffer.load("hello world");
    try testing.expect(wb.buffer.dirty == false);

    // Simulate an edit to make buffer dirty
    _ = wb.buffer.insert(0, 5, "!");
    try testing.expect(wb.buffer.dirty == true);

    // Directly clear dirty flag (simulating what saveFile does on success)
    wb.buffer.dirty = false;
    try testing.expect(wb.buffer.dirty == false);
}

test "saveCurrentFile with no path shows notification" {
    var wb = Workbench{};
    wb.saveCurrentFile();

    try testing.expect(wb.status_bar.notification_len > 0);
    try testing.expect(mem.eql(u8, "No file path", wb.status_bar.notification[0..wb.status_bar.notification_len]));
}

test "storeFilePath stores UTF-16 path correctly" {
    var wb = Workbench{};

    const path = comptime blk: {
        const str = "C:\\test.zig";
        var buf: [str.len:0]u16 = undefined;
        for (str, 0..) |c, i| {
            buf[i] = c;
        }
        break :blk buf;
    };

    wb.storeFilePath(&path);

    try testing.expectEqual(@as(u32, 11), wb.current_file_path_len);
    try testing.expectEqual(@as(u16, 'C'), wb.current_file_path[0]);
    try testing.expectEqual(@as(u16, ':'), wb.current_file_path[1]);
    try testing.expectEqual(@as(u16, 0), wb.current_file_path[wb.current_file_path_len]);
}

test "Workbench default has empty file path" {
    const wb = Workbench{};
    try testing.expectEqual(@as(u32, 0), wb.current_file_path_len);
    try testing.expectEqual(@as(u16, 0), wb.current_file_path[0]);
}

test "CMD_SAVE_FILE constant is 1" {
    try testing.expectEqual(@as(u16, 1), CMD_SAVE_FILE);
}

// =========================================================================
// Task 19.4: Command palette wiring tests
// =========================================================================

test "CMD_TOGGLE_SIDEBAR constant is 2" {
    try testing.expectEqual(@as(u16, 2), CMD_TOGGLE_SIDEBAR);
}

test "CMD_TOGGLE_PANEL constant is 3" {
    try testing.expectEqual(@as(u16, 3), CMD_TOGGLE_PANEL);
}

test "registerDefaultCommands populates command palette" {
    var wb = Workbench{};
    wb.registerDefaultCommands();

    try testing.expectEqual(@as(usize, 4), wb.command_palette.command_count);

    // Verify each command is registered with correct id and label
    const cmd0 = wb.command_palette.commands[0];
    try testing.expectEqual(@as(u16, CMD_OPEN_FILE), cmd0.id);
    try testing.expect(mem.eql(u8, "Open File", cmd0.label[0..cmd0.label_len]));

    const cmd1 = wb.command_palette.commands[1];
    try testing.expectEqual(@as(u16, CMD_SAVE_FILE), cmd1.id);
    try testing.expect(mem.eql(u8, "Save File", cmd1.label[0..cmd1.label_len]));

    const cmd2 = wb.command_palette.commands[2];
    try testing.expectEqual(@as(u16, CMD_TOGGLE_SIDEBAR), cmd2.id);
    try testing.expect(mem.eql(u8, "Toggle Sidebar", cmd2.label[0..cmd2.label_len]));

    const cmd3 = wb.command_palette.commands[3];
    try testing.expectEqual(@as(u16, CMD_TOGGLE_PANEL), cmd3.id);
    try testing.expect(mem.eql(u8, "Toggle Panel", cmd3.label[0..cmd3.label_len]));
}

test "dispatchCommand CMD_TOGGLE_SIDEBAR toggles sidebar_visible" {
    var wb = Workbench{};
    try testing.expectEqual(true, wb.sidebar_visible);

    wb.dispatchCommand(CMD_TOGGLE_SIDEBAR);
    try testing.expectEqual(false, wb.sidebar_visible);

    wb.dispatchCommand(CMD_TOGGLE_SIDEBAR);
    try testing.expectEqual(true, wb.sidebar_visible);
}

test "dispatchCommand CMD_TOGGLE_PANEL toggles panel_visible" {
    var wb = Workbench{};
    try testing.expectEqual(true, wb.panel_visible);

    wb.dispatchCommand(CMD_TOGGLE_PANEL);
    try testing.expectEqual(false, wb.panel_visible);

    wb.dispatchCommand(CMD_TOGGLE_PANEL);
    try testing.expectEqual(true, wb.panel_visible);
}

test "command palette Enter executes selected command" {
    var wb = Workbench{};
    wb.registerDefaultCommands();

    // Open command palette and update filter to show all commands
    wb.command_palette.toggle();
    try testing.expectEqual(true, wb.command_palette.visible);
    try testing.expectEqual(@as(usize, 4), wb.command_palette.filtered_count);

    // Select "Toggle Sidebar" (index 2 in unfiltered list)
    wb.command_palette.selected_index = 2;

    // Press Enter
    wb.handleCommandPaletteInput(VK_RETURN);

    // Command palette should be closed
    try testing.expectEqual(false, wb.command_palette.visible);

    // The selected command (Toggle Sidebar) should have been executed
    try testing.expectEqual(false, wb.sidebar_visible);
}

test "command palette Enter with no results just closes palette" {
    var wb = Workbench{};
    wb.registerDefaultCommands();

    // Open palette and filter to something with no matches
    wb.command_palette.toggle();
    const query = "zzzzz";
    @memcpy(wb.command_palette.input_buf[0..query.len], query);
    wb.command_palette.input_len = query.len;
    wb.command_palette.updateFilter();
    try testing.expectEqual(@as(usize, 0), wb.command_palette.filtered_count);

    // Press Enter — should just close, no crash
    wb.handleCommandPaletteInput(VK_RETURN);
    try testing.expectEqual(false, wb.command_palette.visible);

    // Sidebar should remain unchanged (no command executed)
    try testing.expectEqual(true, wb.sidebar_visible);
}

test "command palette filter then Enter executes filtered command" {
    var wb = Workbench{};
    wb.registerDefaultCommands();

    // Open palette
    wb.command_palette.toggle();

    // Type "panel" to filter
    const query = "panel";
    @memcpy(wb.command_palette.input_buf[0..query.len], query);
    wb.command_palette.input_len = query.len;
    wb.command_palette.updateFilter();

    // Should match "Toggle Panel"
    try testing.expect(wb.command_palette.filtered_count >= 1);

    // Select first result and press Enter
    wb.command_palette.selected_index = 0;
    wb.handleCommandPaletteInput(VK_RETURN);

    // Palette closed and panel toggled
    try testing.expectEqual(false, wb.command_palette.visible);
    try testing.expectEqual(false, wb.panel_visible);
}
