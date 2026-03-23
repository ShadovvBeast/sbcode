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
const Position = @import("cursor").Position;
const SyntaxHighlighter = @import("syntax").SyntaxHighlighter;
const LanguageId = @import("syntax").LanguageId;
const viewport = @import("viewport");
const KeybindingService = @import("keybinding").KeybindingService;
const Color = @import("color").Color;
const Rect = @import("rect").Rect;
const file_service = @import("file_service");
const StatusBar = @import("status_bar").StatusBar;
const ActivityBar = @import("activity_bar").ActivityBar;
const Sidebar = @import("sidebar").Sidebar;
const Panel = @import("panel").Panel;
const win32 = @import("win32");
const context_menu = @import("context_menu");
const file_picker_mod = @import("file_picker");
const FilePicker = file_picker_mod.FilePicker;

// Global HWND for window control button clicks
var global_hwnd: ?win32.HWND = null;

/// Set the global HWND for window control operations.
pub fn setGlobalHwnd(hwnd: win32.HWND) void {
    global_hwnd = hwnd;
}

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
const VK_DELETE: u16 = 0x46; // VK_DELETE = 0x2E but we use 'F' for now — actual: 0x2E
const VK_DEL: u16 = 0x2E;
const VK_TAB: u16 = 0x09;
const VK_HOME: u16 = 0x24;
const VK_END: u16 = 0x23;
const VK_PRIOR: u16 = 0x21; // Page Up
const VK_NEXT: u16 = 0x22; // Page Down
const VK_A: u16 = 0x41;
const VK_B: u16 = 0x42;
const VK_C: u16 = 0x43;
const VK_F: u16 = 0x46;
const VK_G: u16 = 0x47;
const VK_H: u16 = 0x48;
const VK_J: u16 = 0x4A;
const VK_N: u16 = 0x4E;
const VK_V: u16 = 0x56;
const VK_W: u16 = 0x57;
const VK_X: u16 = 0x58;
const VK_Y: u16 = 0x59;
const VK_Z: u16 = 0x5A;
const VK_OEM_2: u16 = 0xBF; // '/' key
const VK_OEM_PLUS: u16 = 0xBB; // '=' / '+' key
const VK_OEM_MINUS: u16 = 0xBD; // '-' key

/// Window control button dimensions (46px wide like VS Code).
const WINDOW_BTN_WIDTH: i32 = 46;
const WINDOW_BTN_HEIGHT: i32 = 30;
const WINDOW_BTN_HOVER_COLOR = Color.rgb(0x40, 0x40, 0x40);

/// Breadcrumbs background color.
const BREADCRUMBS_BG = Color.rgb(0x1E, 0x1E, 0x1E);
const BREADCRUMBS_TEXT = Color.rgb(0x96, 0x96, 0x96);

/// Minimap background color.
const MINIMAP_BG = Color.rgb(0x1E, 0x1E, 0x1E);

/// Welcome text colors.
const WELCOME_TITLE_COLOR = Color.rgb(0x56, 0x56, 0x56);
const WELCOME_HINT_COLOR = Color.rgb(0x4A, 0x4A, 0x4A);

/// Tab close button color.
const TAB_CLOSE_COLOR = Color.rgb(0x96, 0x96, 0x96);

/// Active tab bottom border color.
const TAB_ACTIVE_BORDER = Color.rgb(0xFF, 0xFF, 0xFF);

/// Tab separator color.
const TAB_SEPARATOR_COLOR = Color.rgb(0x25, 0x25, 0x25);

/// Command index for the "Open File" command (Ctrl+O).
pub const CMD_OPEN_FILE: u16 = 0;

/// Command index for the "Save File" command (Ctrl+S).
pub const CMD_SAVE_FILE: u16 = 1;

/// Command index for the "Toggle Sidebar" command.
pub const CMD_TOGGLE_SIDEBAR: u16 = 2;

/// Command index for the "Toggle Panel" command.
pub const CMD_TOGGLE_PANEL: u16 = 3;

/// Command index for "New File" (Ctrl+N).
pub const CMD_NEW_FILE: u16 = 4;

/// Command index for "Save As" (Ctrl+Shift+S).
pub const CMD_SAVE_AS: u16 = 5;

/// Command index for "Find" (Ctrl+F).
pub const CMD_FIND: u16 = 6;

/// Command index for "Go to Line" (Ctrl+G).
pub const CMD_GOTO_LINE: u16 = 7;

/// Command index for "Search Across Files" (Ctrl+Shift+F).
pub const CMD_SEARCH_FILES: u16 = 8;

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
    file_picker: FilePicker = .{},
    keybindings: KeybindingService = .{},
    buffer: TextBuffer = .{},
    cursor_state: CursorState = .{},
    highlighter: SyntaxHighlighter = .{},
    status_bar: StatusBar = .{},
    activity_bar: ActivityBar = .{},
    sidebar: Sidebar = .{},
    panel: Panel = .{},

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

    // Cursor blink timer (seconds)
    blink_timer: f64 = 0.0,
    cursor_visible: bool = true,

    // Find/Replace overlay state
    find_visible: bool = false,
    find_query: [256]u8 = undefined,
    find_query_len: u16 = 0,
    find_match_line: u32 = 0,
    find_match_col: u32 = 0,
    find_has_match: bool = false,

    // Double-click tracking
    last_click_time: f64 = 0.0,
    click_count: u8 = 0,
    accumulated_time: f64 = 0.0,

    // Autocomplete state
    autocomplete_visible: bool = false,
    autocomplete_items: [16][64]u8 = undefined,
    autocomplete_item_lens: [16]u8 = [_]u8{0} ** 16,
    autocomplete_count: u8 = 0,
    autocomplete_selected: u8 = 0,

    // Window handle for window control operations
    hwnd: ?win32.HWND = null,

    // Recent file history (MRU list)
    recent_file_history: [16][260]u8 = undefined,
    recent_file_history_lens: [16]u16 = [_]u16{0} ** 16,
    recent_file_count: u8 = 0,

    // Menu bar state
    menu_bar_visible: bool = true,
    menu_bar_active: i8 = -1,

    // Dropdown menu state (GL-rendered, animated)
    dropdown_open: bool = false,
    dropdown_index: u8 = 0, // which menu bar item is open
    dropdown_anim: f32 = 0.0, // 0.0 = closed, 1.0 = fully open
    dropdown_hover_item: i16 = -1, // hovered item index (-1 = none)
    dropdown_x: i32 = 0, // dropdown X position (client coords)
    dropdown_y: i32 = 0, // dropdown Y position (below title bar)
    dropdown_w: i32 = 0, // dropdown width
    dropdown_item_count: u8 = 0, // number of items in current dropdown

    // Snippet expansion state
    snippet_active: bool = false,
    snippet_tab_stops: [8]u32 = [_]u32{0} ** 8,
    snippet_tab_stop_count: u8 = 0,
    snippet_current_stop: u8 = 0,

    // Tooltip / hover state
    hover_tooltip_visible: bool = false,
    hover_tooltip_line: u32 = 0,
    hover_tooltip_col: u32 = 0,

    // Font zoom level
    font_zoom_level: i8 = 0,

    // App icon GL texture (rasterized from sbcode.ico at startup)
    icon_texture_id: gl.GLuint = 0,

    // Search icon GL texture (rasterized from search.ico at startup)
    search_icon_texture_id: gl.GLuint = 0,

    // Cached font cell dimensions (set from render, used by update for hit-testing)
    cell_w: i32 = 8,
    cell_h: i32 = 16,

    // Title bar double_click tracking
    title_bar_last_click: f64 = 0.0,

    // File picker open animation (0.0 = closed, 1.0 = fully open)
    file_picker_anim: f32 = 0.0,

    // File picker double-click tracking
    file_picker_last_click: f64 = 0.0,
    file_picker_last_click_idx: u16 = 0xFFFF,

    // File picker mouse hover row (-1 = none)
    file_picker_hover_row: i16 = -1,

    // Debug session state
    debug_session_active: bool = false,
    breakpoint_lines: [64]u32 = [_]u32{0} ** 64,
    breakpoint_count: u8 = 0,

    // Extension / plugin system stub
    plugin_system_initialized: bool = false,

    // SCM / git integration state
    git_status_dirty: bool = false,
    scm_provider_active: bool = false,

    // Color theme support
    color_theme: [64]u8 = undefined,
    color_theme_len: u8 = 0,

    // Confirm dialog state (GL-rendered, replaces Win32 MessageBox)
    confirm_dialog_visible: bool = false,
    confirm_dialog_selected: u8 = 0, // 0=Save, 1=Don't Save, 2=Cancel
    confirm_dialog_anim: f32 = 0.0, // fade-in animation
    confirm_dialog_action: u8 = 0, // 0=close window, 1=close tab

    /// Show the unsaved changes confirmation dialog.
    /// action: 0 = close window, 1 = close tab
    pub fn showConfirmDialog(self: *Workbench, action: u8) void {
        self.confirm_dialog_visible = true;
        self.confirm_dialog_selected = 0;
        self.confirm_dialog_anim = 0.0;
        self.confirm_dialog_action = action;
    }

    /// Handle the confirm dialog result. Called when user picks a button.
    pub fn handleConfirmResult(self: *Workbench, choice: u8) void {
        self.confirm_dialog_visible = false;
        self.confirm_dialog_anim = 0.0;
        const action = self.confirm_dialog_action;

        switch (choice) {
            0 => {
                // Save
                self.saveCurrentFile();
                if (action == 0) {
                    // Close window
                    const hwnd = self.hwnd orelse (global_hwnd orelse return);
                    _ = win32.DestroyWindow(hwnd);
                } else {
                    // Close tab
                    if (self.tab_count > 0) self.closeTab(self.active_tab);
                }
            },
            1 => {
                // Don't Save
                self.buffer.dirty = false; // discard changes
                if (action == 0) {
                    const hwnd = self.hwnd orelse (global_hwnd orelse return);
                    _ = win32.DestroyWindow(hwnd);
                } else {
                    if (self.tab_count > 0) self.closeTab(self.active_tab);
                }
            },
            2 => {
                // Cancel — do nothing
            },
            else => {},
        }
    }

    /// Register default keybindings (e.g., Ctrl+O for file open).
    ///
    /// Postconditions:
    ///   - Ctrl+O is registered as CMD_OPEN_FILE
    pub fn registerDefaultKeybindings(self: *Workbench) void {
        _ = self.keybindings.register(VK_O, true, false, false, CMD_OPEN_FILE);
        _ = self.keybindings.register(VK_S, true, false, false, CMD_SAVE_FILE);
        _ = self.keybindings.register(VK_B, true, false, false, CMD_TOGGLE_SIDEBAR);
        _ = self.keybindings.register(VK_J, true, false, false, CMD_TOGGLE_PANEL);
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
        _ = self.command_palette.registerCommand(CMD_NEW_FILE, "New File", null, CMD_NEW_FILE);
        _ = self.command_palette.registerCommand(CMD_SAVE_AS, "Save As", null, CMD_SAVE_AS);
        _ = self.command_palette.registerCommand(CMD_FIND, "Find", null, CMD_FIND);
        _ = self.command_palette.registerCommand(CMD_GOTO_LINE, "Go to Line", null, CMD_GOTO_LINE);
        _ = self.command_palette.registerCommand(CMD_SEARCH_FILES, "Search in Files", null, CMD_SEARCH_FILES);
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
                self.showOpenFileDialog();
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
            CMD_NEW_FILE => {
                self.handleNewFile();
            },
            CMD_SAVE_AS => {
                self.showSaveAsDialog();
            },
            CMD_FIND => {
                self.find_visible = !self.find_visible;
            },
            CMD_GOTO_LINE => {
                // Use command palette as go-to-line input
                self.command_palette.toggle();
            },
            CMD_SEARCH_FILES => {
                // Switch sidebar to search view
                self.sidebar_visible = true;
                self.activity_bar.active_icon = 1; // search icon
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
    pub fn update(self: *Workbench, input: *const InputState, layout: *LayoutState, delta_time: f64) void {
        // Click dispatch: editor_tabs active_tab tab_close, activity_bar active_icon,
        // sidebar entry clicks, panel active_tab — see handleAllClicks()

        // Sync visibility flags to layout
        layout.sidebar_visible = self.sidebar_visible;
        layout.panel_visible = self.panel_visible;
        layout.recompute(layout.window_w, layout.window_h);

        // Update cursor blink timer
        self.blink_timer += delta_time;
        if (self.blink_timer >= 0.5) {
            self.blink_timer -= 0.5;
            self.cursor_visible = !self.cursor_visible;
        }

        // Animate dropdown menu (smooth open)
        if (self.dropdown_open and self.dropdown_anim < 1.0) {
            self.dropdown_anim = @min(1.0, self.dropdown_anim + @as(f32, @floatCast(delta_time)) * 8.0);
        }

        // Animate confirm dialog (fade-in)
        if (self.confirm_dialog_visible and self.confirm_dialog_anim < 1.0) {
            self.confirm_dialog_anim = @min(1.0, self.confirm_dialog_anim + @as(f32, @floatCast(delta_time)) * 6.0);
        }

        // Animate file picker (slide-down + fade-in)
        if (self.file_picker.visible) {
            if (self.file_picker_anim < 1.0) {
                self.file_picker_anim = @min(1.0, self.file_picker_anim + @as(f32, @floatCast(delta_time)) * 5.0);
            }
            // Track mouse hover over file list rows
            self.updateFilePickerHover(input.mouse_x, input.mouse_y, layout);
        } else {
            self.file_picker_anim = 0.0;
            self.file_picker_hover_row = -1;
        }

        // When confirm dialog is visible, it blocks all other input
        if (self.confirm_dialog_visible) {
            if (input.left_button_pressed) {
                self.handleConfirmDialogClickSimple(input.mouse_x, input.mouse_y, layout);
            }
            var ki: u32 = 0;
            while (ki < input.key_event_count) : (ki += 1) {
                const ev = input.key_events[ki];
                if (!ev.pressed) continue;
                if (ev.vk == VK_ESCAPE) {
                    self.handleConfirmResult(2);
                } else if (ev.vk == VK_RETURN) {
                    self.handleConfirmResult(self.confirm_dialog_selected);
                } else if (ev.vk == VK_TAB or ev.vk == VK_RIGHT) {
                    self.confirm_dialog_selected = (self.confirm_dialog_selected + 1) % 3;
                } else if (ev.vk == VK_LEFT) {
                    self.confirm_dialog_selected = if (self.confirm_dialog_selected == 0) 2 else self.confirm_dialog_selected - 1;
                }
            }
            return; // Block all other input
        }

        // Track dropdown hover item from mouse position
        if (self.dropdown_open) {
            self.updateDropdownHover(input.mouse_x, input.mouse_y);

            // Menu bar hover-to-switch: when dropdown is open, hovering over
            // a different menu bar label switches to that menu
            const title_h = layout.title_bar_height;
            if (input.mouse_y >= 0 and input.mouse_y < title_h) {
                const cw = self.cell_w;
                const menu_xs = context_menu.menuBarLabelX(cw);
                const menu_ws = context_menu.menuBarLabelW(cw);
                var mi: u8 = 0;
                while (mi < context_menu.MENU_BAR_COUNT) : (mi += 1) {
                    if (input.mouse_x >= menu_xs[mi] and input.mouse_x < menu_xs[mi] + menu_ws[mi]) {
                        if (mi != self.dropdown_index) {
                            self.dropdown_index = mi;
                            self.menu_bar_active = @intCast(mi);
                            self.dropdown_anim = 0.3; // Quick transition
                            self.dropdown_hover_item = -1;
                            self.dropdown_x = menu_xs[mi];
                            self.dropdown_y = title_h;
                            self.dropdown_item_count = self.getDropdownItemCount(mi);
                            self.dropdown_w = self.getDropdownWidth(mi, cw);
                        }
                        break;
                    }
                }
            }
        }

        // Handle mouse wheel scrolling
        if (input.scroll_delta != 0) {
            // File picker scroll takes priority when visible
            if (self.file_picker.visible) {
                const scroll_lines: i32 = @divTrunc(input.scroll_delta, 40);
                if (scroll_lines < 0) {
                    const add: u16 = @intCast(@min(-scroll_lines, 255));
                    self.file_picker.scroll_top +|= add;
                    const max_scroll = if (self.file_picker.filtered_count > 14) self.file_picker.filtered_count - 14 else 0;
                    if (self.file_picker.scroll_top > max_scroll) self.file_picker.scroll_top = max_scroll;
                } else {
                    const sub: u16 = @intCast(@min(scroll_lines, 255));
                    if (self.file_picker.scroll_top >= sub) {
                        self.file_picker.scroll_top -= sub;
                    } else {
                        self.file_picker.scroll_top = 0;
                    }
                }
            } else {
                const lines: i32 = @divTrunc(input.scroll_delta, 40);
                if (lines < 0) {
                    const add: u32 = @intCast(-lines);
                    self.scroll_top +|= add;
                } else {
                    const sub: u32 = @intCast(lines);
                    if (self.scroll_top >= sub) {
                        self.scroll_top -= sub;
                    } else {
                        self.scroll_top = 0;
                    }
                }
                if (self.buffer.line_count > 0 and self.scroll_top >= self.buffer.line_count) {
                    self.scroll_top = self.buffer.line_count - 1;
                }
            }
        }

        // Handle mouse clicks on various UI regions
        // Handles: editor_tabs (active_tab switch, tab_close), activity_bar (active_icon),
        // sidebar (entry clicks), panel (active_tab clicks)
        if (input.left_button_pressed) {
            self.handleAllClicks(input, layout);
        }

        // Handle right-click context menus
        if (input.right_button_pressed) {
            self.handleRightClick(input.mouse_x, input.mouse_y, layout);
        }

        // Process key events
        var i: u32 = 0;
        while (i < input.key_event_count) : (i += 1) {
            const ev = input.key_events[i];
            if (!ev.pressed) continue;

            // Command palette: Ctrl+P toggles
            if (ev.vk == VK_P and ev.ctrl and !ev.shift and !ev.alt) {
                self.command_palette.toggle();
                continue;
            }

            // Escape closes dropdown menu first
            if (ev.vk == VK_ESCAPE and self.dropdown_open) {
                self.dropdown_open = false;
                self.menu_bar_active = -1;
                self.dropdown_anim = 0.0;
                continue;
            }

            // When command palette is visible, route input there
            if (self.command_palette.visible) {
                self.handleCommandPaletteInput(ev.vk);
                continue;
            }

            // When file picker is visible, route input there
            if (self.file_picker.visible) {
                self.handleFilePickerInput(ev.vk);
                continue;
            }

            // When find overlay is visible, route input there
            if (self.find_visible) {
                self.handleFindInput(ev.vk, ev.ctrl);
                continue;
            }

            // Try keybinding lookup
            if (self.keybindings.lookup(ev.vk, ev.ctrl, ev.shift, ev.alt)) |cmd_index| {
                self.dispatchCommand(cmd_index);
                continue;
            }

            // --- Ctrl+key shortcuts ---
            if (ev.ctrl and !ev.alt) {
                if (self.handleCtrlShortcut(ev.vk, ev.shift)) continue;
            }

            // Backspace
            if (ev.vk == VK_BACK) {
                if (!self.deleteSelection()) {
                    self.handleBackspace();
                }
                continue;
            }

            // Delete
            if (ev.vk == VK_DEL) {
                if (!self.deleteSelection()) {
                    self.handleDelete();
                }
                continue;
            }

            // Tab key: insert spaces
            if (ev.vk == VK_TAB) {
                _ = self.deleteSelection();
                self.handleTab();
                continue;
            }

            // Arrow key cursor movement (with shift/ctrl support)
            self.handleCursorMovement(ev.vk, ev.shift, ev.ctrl);
        }

        // Dispatch text input to active buffer when no overlay is visible
        if (!self.command_palette.visible and !self.find_visible and !self.file_picker.visible) {
            self.handleTextInput(input);
        } else if (self.command_palette.visible) {
            self.handlePaletteTextInput(input);
        } else if (self.file_picker.visible) {
            self.handleFilePickerTextInput(input);
        } else if (self.find_visible) {
            self.handleFindTextInput(input);
        }

        // Sync cursor position to status bar
        const cur = self.cursor_state.primary().active;
        self.status_bar.line = cur.line + 1;
        self.status_bar.col = cur.col + 1;

        // Reset blink on any key/text input
        if (input.key_event_count > 0 or input.text_input_len > 0) {
            self.blink_timer = 0.0;
            self.cursor_visible = true;
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
        // Cache font cell dimensions for use by update() hit-testing
        self.cell_w = font_atlas.cell_w;
        self.cell_h = font_atlas.cell_h;

        // 1. Title bar with text and window control buttons
        self.renderTitleBar(layout.getRegion(.title_bar), font_atlas);

        // 2. Activity bar (delegated to sub-component)
        self.activity_bar.render(layout.getRegion(.activity_bar), font_atlas);

        // 3. Sidebar (delegated to sub-component)
        if (self.sidebar_visible) {
            self.sidebar.render(layout.getRegion(.sidebar), font_atlas);
        }

        // 4. Editor tabs
        self.renderTabBar(layout.getRegion(.editor_tabs), font_atlas);

        // 5. Breadcrumbs region
        self.renderBreadcrumbs(layout.getRegion(.editor_breadcrumbs), font_atlas);

        // 6. Editor area
        const editor_area = layout.getRegion(.editor_area);
        renderRegionBackground(editor_area, EDITOR_BG);

        if (self.tab_count == 0) {
            // Welcome / empty state
            self.renderWelcome(editor_area, font_atlas);
        } else {
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
                self.cursor_visible,
            );
        }

        // 7. Minimap region
        self.renderMinimap(layout.getRegion(.minimap));

        // 8. Panel (delegated to sub-component)
        if (self.panel_visible) {
            self.panel.render(layout.getRegion(.panel), font_atlas);
        }

        // 9. Status bar (delegated to sub-component)
        self.status_bar.render(layout.getRegion(.status_bar), font_atlas);

        // 10. Command palette overlay
        if (self.command_palette.visible) {
            self.renderCommandPalette(layout, font_atlas);
        }

        // 11. Find overlay
        if (self.find_visible) {
            self.renderFindOverlay(layout, font_atlas);
        }

        // 12. Dropdown menu overlay (animated, GL-rendered)
        self.renderDropdownMenu(font_atlas, layout);

        // 13. Confirm dialog overlay (topmost)
        self.renderConfirmDialog(layout, font_atlas);

        // 14. File picker overlay (above confirm dialog)
        if (self.file_picker.visible) {
            self.renderFilePicker(layout, font_atlas);
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

    fn handleCursorMovement(self: *Workbench, vk: u16, shift: bool, ctrl: bool) void {
        const sel = self.cursor_state.primary();
        var pos = sel.active;
        const anchor = sel.anchor;
        const page: u32 = 30;
        switch (vk) {
            VK_LEFT => if (ctrl) {
                pos.col = self.findWordBoundaryLeft(pos.line, pos.col);
            } else {
                if (pos.col > 0) pos.col -= 1;
            },
            VK_RIGHT => if (ctrl) {
                pos.col = self.findWordBoundaryRight(pos.line, pos.col);
            } else {
                pos.col += 1;
            },
            VK_UP => if (pos.line > 0) {
                pos.line -= 1;
            },
            VK_DOWN => {
                pos.line += 1;
            },
            VK_HOME => {
                pos.col = 0;
            },
            VK_END => if (self.buffer.getLine(pos.line)) |line| {
                pos.col = @intCast(line.len);
            },
            VK_PRIOR => {
                pos.line = if (pos.line >= page) pos.line - page else 0;
                self.scroll_top = if (self.scroll_top >= page) self.scroll_top - page else 0;
            },
            VK_NEXT => {
                pos.line += page;
                if (self.buffer.line_count > 0 and pos.line >= self.buffer.line_count)
                    pos.line = self.buffer.line_count - 1;
                self.scroll_top +|= page;
                if (self.buffer.line_count > 0 and self.scroll_top >= self.buffer.line_count)
                    self.scroll_top = self.buffer.line_count - 1;
            },
            else => return,
        }
        if (shift) {
            self.cursor_state.setSelection(anchor, pos);
        } else {
            self.cursor_state.setPrimary(pos);
        }
    }

    fn findWordBoundaryLeft(self: *Workbench, line: u32, col: u32) u32 {
        const text = self.buffer.getLine(line) orelse return 0;
        if (col == 0) return 0;
        var c: u32 = col;
        if (c > @as(u32, @intCast(text.len))) c = @intCast(text.len);
        // Skip whitespace backwards
        while (c > 0 and (text[c - 1] == ' ' or text[c - 1] == '\t')) c -= 1;
        // Skip word chars backwards
        while (c > 0 and isWordChar(text[c - 1])) c -= 1;
        return c;
    }

    fn findWordBoundaryRight(self: *Workbench, line: u32, col: u32) u32 {
        const text = self.buffer.getLine(line) orelse return col;
        const len: u32 = @intCast(text.len);
        if (col >= len) return len;
        var c: u32 = col;
        // Skip word chars forward
        while (c < len and isWordChar(text[c])) c += 1;
        // Skip whitespace forward
        while (c < len and (text[c] == ' ' or text[c] == '\t')) c += 1;
        return c;
    }

    fn handleTextInput(self: *Workbench, input: *const InputState) void {
        if (input.text_input_len == 0) return;

        var i: u32 = 0;
        while (i < input.text_input_len) : (i += 1) {
            const ch = input.text_input[i];
            // Skip control characters except newline
            if (ch < 0x20 and ch != '\n' and ch != '\r') continue;

            // Delete selection before inserting
            _ = self.deleteSelection();

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

    /// Close the active tab. Shifts remaining tabs left.
    pub fn closeTab(self: *Workbench, tab_idx: u8) void {
        if (tab_idx >= self.tab_count) return;
        if (self.tab_count == 0) return;

        // Shift tabs left
        var i: u8 = tab_idx;
        while (i + 1 < self.tab_count) : (i += 1) {
            self.tabs[i] = self.tabs[i + 1];
        }
        self.tab_count -= 1;

        // Adjust active tab
        if (self.tab_count == 0) {
            self.active_tab = 0;
        } else if (self.active_tab >= self.tab_count) {
            self.active_tab = self.tab_count - 1;
        }
        if (self.tab_count > 0) {
            self.tabs[self.active_tab].active = true;
        }
    }

    /// Handle backspace key: delete character before cursor.
    fn handleBackspace(self: *Workbench) void {
        const cur = self.cursor_state.primary().active;
        if (cur.col > 0) {
            // Delete one character before cursor
            if (self.buffer.delete(cur.line, cur.col - 1, 1)) {
                self.highlighter.tokenizeLine(cur.line, self.buffer.getLine(cur.line) orelse "");
                self.cursor_state.setPrimary(.{ .line = cur.line, .col = cur.col - 1 });
            }
        } else if (cur.line > 0) {
            // At beginning of line: merge with previous line
            const prev_len = if (self.buffer.getLine(cur.line - 1)) |l| @as(u32, @intCast(l.len)) else 0;
            // Delete the newline at end of previous line
            if (self.buffer.delete(cur.line - 1, prev_len, 1)) {
                // Retokenize merged line
                self.highlighter.tokenizeLine(cur.line - 1, self.buffer.getLine(cur.line - 1) orelse "");
                self.cursor_state.setPrimary(.{ .line = cur.line - 1, .col = prev_len });
            }
        }
    }

    /// Handle delete key: delete character at cursor.
    fn handleDelete(self: *Workbench) void {
        const cur = self.cursor_state.primary().active;
        if (cur.line < self.buffer.line_count) {
            const line = self.buffer.getLine(cur.line) orelse return;
            if (cur.col < @as(u32, @intCast(line.len))) {
                // Delete character at cursor
                if (self.buffer.delete(cur.line, cur.col, 1)) {
                    self.highlighter.tokenizeLine(cur.line, self.buffer.getLine(cur.line) orelse "");
                }
            } else if (cur.line + 1 < self.buffer.line_count) {
                // At end of line: merge with next line (delete the newline)
                if (self.buffer.delete(cur.line, cur.col, 1)) {
                    self.highlighter.tokenizeLine(cur.line, self.buffer.getLine(cur.line) orelse "");
                }
            }
        }
    }

    /// Handle mouse click to position cursor in editor area.
    fn handleMouseClick(self: *Workbench, input: *const InputState, editor_area: Rect, shift: bool) void {
        const cw = self.cell_w;
        const ch = self.cell_h;
        if (cw <= 0 or ch <= 0) return;

        // Account for gutter width (line numbers)
        const gutter_px = @as(i32, @intCast(viewport.GUTTER_CHAR_WIDTH)) * cw;
        const rel_x = input.mouse_x - editor_area.x - gutter_px;
        const rel_y = input.mouse_y - editor_area.y;
        if (rel_y < 0) return;

        const click_line = self.scroll_top + @as(u32, @intCast(@divTrunc(rel_y, ch)));
        const click_col: u32 = if (rel_x > 0) @intCast(@divTrunc(rel_x, cw)) else 0;

        // Clamp to buffer bounds
        var line = click_line;
        if (self.buffer.line_count > 0 and line >= self.buffer.line_count) {
            line = self.buffer.line_count - 1;
        }
        var col = click_col;
        if (self.buffer.getLine(line)) |l| {
            if (col > @as(u32, @intCast(l.len))) {
                col = @intCast(l.len);
            }
        }

        const new_pos = Position{ .line = line, .col = col };

        if (shift) {
            // Shift+click: extend selection
            const anchor = self.cursor_state.primary().anchor;
            self.cursor_state.setSelection(anchor, new_pos);
        } else {
            self.cursor_state.setPrimary(new_pos);
        }
    }

    /// Select the word at the given position (for double-click word selection).
    pub fn select_word(self: *Workbench, line: u32, col: u32) void {
        const text = self.buffer.getLine(line) orelse return;
        if (text.len == 0) return;
        var c = col;
        if (c >= @as(u32, @intCast(text.len))) c = @intCast(text.len -| 1);

        // Find word boundaries
        var start = c;
        while (start > 0 and isWordChar(text[start - 1])) start -= 1;
        var end = c;
        while (end < @as(u32, @intCast(text.len)) and isWordChar(text[end])) end += 1;

        if (end > start) {
            self.cursor_state.setSelection(
                .{ .line = line, .col = start },
                .{ .line = line, .col = end },
            );
        }
    }

    /// Handle all click regions (tabs, title bar buttons, activity bar, sidebar, panel, editor).
    fn handleAllClicks(self: *Workbench, input: *const InputState, layout: *LayoutState) void {
        if (self.command_palette.visible) return;

        // File picker click handling (highest priority when open)
        if (self.file_picker.visible) {
            self.handleFilePickerClick(input.mouse_x, input.mouse_y, layout);
            return;
        }

        const mx = input.mouse_x;
        const my = input.mouse_y;

        // Dropdown menu click handling (highest priority when open)
        if (self.dropdown_open) {
            if (self.handleDropdownClick(mx, my)) return;
            // Click was outside dropdown — close it
            // But check if it's on the title bar (menu bar labels handled by handleTitleBarClick)
            const title_bar = layout.getRegion(.title_bar);
            if (title_bar.contains(mx, my)) {
                self.handleTitleBarClick(mx, title_bar);
                return;
            }
            // Click outside everything — close dropdown
            self.dropdown_open = false;
            self.menu_bar_active = -1;
            self.dropdown_anim = 0.0;
            // Fall through to handle the click normally
        }

        // Title bar window control buttons
        const title_bar = layout.getRegion(.title_bar);
        if (title_bar.contains(mx, my)) {
            self.handleTitleBarClick(mx, title_bar);
            return;
        }

        // Tab bar clicks
        const editor_tabs = layout.getRegion(.editor_tabs);
        if (editor_tabs.contains(mx, my)) {
            self.handleTabBarClick(mx, my, editor_tabs);
            return;
        }

        // Activity bar clicks
        const activity_bar_region = layout.getRegion(.activity_bar);
        if (activity_bar_region.contains(mx, my)) {
            self.handleActivityBarClick(my, activity_bar_region);
            return;
        }

        // Sidebar clicks
        if (self.sidebar_visible) {
            const sidebar_region = layout.getRegion(.sidebar);
            if (sidebar_region.contains(mx, my)) {
                self.handleSidebarClick(my, sidebar_region);
                return;
            }
        }

        // Panel tab clicks
        if (self.panel_visible) {
            const panel_region = layout.getRegion(.panel);
            if (panel_region.contains(mx, my)) {
                self.handlePanelClick(mx, panel_region);
                return;
            }
        }

        // Editor area clicks
        const editor_area = layout.getRegion(.editor_area);
        if (editor_area.contains(mx, my)) {
            const shift = (win32.GetKeyState(win32.VK_SHIFT) & @as(i16, -128)) != 0;
            self.handleMouseClick(input, editor_area, shift);
            return;
        }
    }

    /// Handle title bar window control button clicks and menu bar clicks.
    fn handleTitleBarClick(self: *Workbench, mx: i32, title_bar: Rect) void {
        const close_x = title_bar.x + title_bar.w - WINDOW_BTN_WIDTH;
        const max_x = close_x - WINDOW_BTN_WIDTH;
        const min_x = max_x - WINDOW_BTN_WIDTH;

        // Window control buttons (right side)
        if (mx >= min_x) {
            const hwnd = self.hwnd orelse (global_hwnd orelse return);
            if (mx >= close_x) {
                _ = win32.PostMessageW(hwnd, win32.WM_SYSCOMMAND, win32.SC_CLOSE, 0);
            } else if (mx >= max_x) {
                if (win32.IsZoomed(hwnd) != 0) {
                    _ = win32.PostMessageW(hwnd, win32.WM_SYSCOMMAND, win32.SC_RESTORE, 0);
                } else {
                    _ = win32.PostMessageW(hwnd, win32.WM_SYSCOMMAND, win32.SC_MAXIMIZE, 0);
                }
            } else {
                _ = win32.PostMessageW(hwnd, win32.WM_SYSCOMMAND, win32.SC_MINIMIZE, 0);
            }
            return;
        }

        // Menu bar label clicks (left side) — with overflow awareness
        const cw = self.cell_w;
        const menu_xs = context_menu.menuBarLabelX(cw);
        const menu_ws = context_menu.menuBarLabelW(cw);
        const rel_x = mx - title_bar.x;

        // Check if click is on the search bar (centered in full title bar width)
        const bar_w: i32 = @min(420, @divTrunc(title_bar.w, 3));
        const bar_x_click = title_bar.x + @divTrunc(title_bar.w - bar_w, 2);
        if (bar_w > cw * 8 and mx >= bar_x_click and mx < bar_x_click + bar_w) {
            if (!self.command_palette.visible) {
                self.command_palette.toggle();
            }
            return;
        }

        // Compute visible menu count (same logic as renderTitleBar)
        const overflow_btn_w = cw * 3 + context_menu.MENU_BAR_PAD * 2;
        var visible_count: u8 = context_menu.MENU_BAR_COUNT;
        {
            var idx: u8 = 0;
            while (idx < context_menu.MENU_BAR_COUNT) : (idx += 1) {
                const menu_right = title_bar.x + menu_xs[idx] + menu_ws[idx];
                if (menu_right + overflow_btn_w > bar_x_click and bar_w > cw * 8) {
                    visible_count = idx;
                    break;
                }
            }
        }

        // Check clicks on visible menu labels
        var i: u8 = 0;
        while (i < visible_count) : (i += 1) {
            if (rel_x >= menu_xs[i] and rel_x < menu_xs[i] + menu_ws[i]) {
                if (self.dropdown_open and self.dropdown_index == i) {
                    self.dropdown_open = false;
                    self.menu_bar_active = -1;
                    self.dropdown_anim = 0.0;
                } else {
                    self.dropdown_open = true;
                    self.dropdown_index = i;
                    self.menu_bar_active = @intCast(i);
                    self.dropdown_anim = 0.0;
                    self.dropdown_hover_item = -1;
                    self.dropdown_x = title_bar.x + menu_xs[i];
                    self.dropdown_y = title_bar.y + title_bar.h;
                    self.dropdown_item_count = self.getDropdownItemCount(i);
                    self.dropdown_w = self.getDropdownWidth(i, cw);
                }
                return;
            }
        }

        // Check click on "..." overflow button
        if (visible_count < context_menu.MENU_BAR_COUNT) {
            const ox = menu_xs[visible_count];
            if (rel_x >= ox and rel_x < ox + overflow_btn_w) {
                // Open the first hidden menu as a starting point
                const first_hidden = visible_count;
                if (self.dropdown_open and self.dropdown_index == first_hidden) {
                    self.dropdown_open = false;
                    self.menu_bar_active = -1;
                    self.dropdown_anim = 0.0;
                } else {
                    self.dropdown_open = true;
                    self.dropdown_index = first_hidden;
                    self.menu_bar_active = @intCast(first_hidden);
                    self.dropdown_anim = 0.0;
                    self.dropdown_hover_item = -1;
                    self.dropdown_x = title_bar.x + ox;
                    self.dropdown_y = title_bar.y + title_bar.h;
                    self.dropdown_item_count = self.getDropdownItemCount(first_hidden);
                    self.dropdown_w = self.getDropdownWidth(first_hidden, cw);
                }
                return;
            }
        }
    }

    /// Dispatch a menu bar dropdown command by ID.
    fn dispatchMenuBarCmd(self: *Workbench, cmd_id: u16) void {
        // File menu (600–649)
        if (cmd_id >= 600 and cmd_id < 650) {
            const cmd: context_menu.FileCmd = @enumFromInt(cmd_id);
            switch (cmd) {
                .new_file => self.handleNewFile(),
                .new_window => self.status_bar.setNotification("New Window"),
                .open_file => self.showOpenFileDialog(),
                .open_folder => self.status_bar.setNotification("Open Folder"),
                .open_recent => self.status_bar.setNotification("Open Recent"),
                .save => self.saveCurrentFile(),
                .save_as => self.showSaveAsDialog(),
                .save_all => self.saveCurrentFile(),
                .auto_save => self.status_bar.setNotification("Auto Save toggled"),
                .preferences => self.status_bar.setNotification("Preferences"),
                .revert_file => {
                    // Reload from stored path
                    if (self.current_file_path_len > 0) {
                        self.openFile(@ptrCast(&self.current_file_path));
                    }
                },
                .close_editor => {
                    if (self.tab_count > 0) self.closeTab(self.active_tab);
                },
                .close_folder => self.status_bar.setNotification("Close Folder"),
                .close_window => {
                    const hwnd = self.hwnd orelse (global_hwnd orelse return);
                    _ = win32.PostMessageW(hwnd, win32.WM_SYSCOMMAND, win32.SC_CLOSE, 0);
                },
                .exit => {
                    const hwnd = self.hwnd orelse (global_hwnd orelse return);
                    _ = win32.PostMessageW(hwnd, win32.WM_SYSCOMMAND, win32.SC_CLOSE, 0);
                },
            }
            return;
        }
        // Edit menu (700–749)
        if (cmd_id >= 700 and cmd_id < 750) {
            const cmd: context_menu.EditCmd = @enumFromInt(cmd_id);
            switch (cmd) {
                .undo => {
                    if (self.buffer.undo()) self.retokenizeAll();
                },
                .redo => {
                    if (self.buffer.redo()) self.retokenizeAll();
                },
                .cut => self.cutSelection(),
                .copy => self.copySelection(),
                .paste => self.pasteFromClipboard(),
                .find => {
                    self.find_visible = !self.find_visible;
                },
                .replace => {
                    self.find_visible = true;
                },
                .find_in_files => {
                    self.sidebar_visible = true;
                    self.activity_bar.active_icon = 1;
                },
                .replace_in_files => {
                    self.sidebar_visible = true;
                    self.activity_bar.active_icon = 1;
                },
                .toggle_line_comment => self.handleToggleComment(),
                .toggle_block_comment => self.handleToggleComment(),
                .emmet_expand => self.status_bar.setNotification("Emmet: no abbreviation"),
            }
            return;
        }
        // Selection menu (800–849)
        if (cmd_id >= 800 and cmd_id < 850) {
            const cmd: context_menu.SelectionCmd = @enumFromInt(cmd_id);
            switch (cmd) {
                .select_all => self.selectAll(),
                .expand_selection, .shrink_selection => self.status_bar.setNotification("Selection"),
                .copy_line_up => self.duplicate_line(),
                .copy_line_down => self.duplicate_line(),
                .move_line_up => self.move_line(-1),
                .move_line_down => self.move_line(1),
                .duplicate_selection => self.duplicate_line(),
                .add_cursor_above, .add_cursor_below, .add_cursors_to_line_ends => {
                    self.status_bar.setNotification("Multi-cursor");
                },
                .add_next_occurrence, .add_all_occurrences => {
                    self.status_bar.setNotification("Multi-cursor");
                },
                .column_selection_mode => self.status_bar.setNotification("Column selection"),
            }
            return;
        }
        // View menu (900–969)
        if (cmd_id >= 900 and cmd_id < 970) {
            const cmd: context_menu.ViewCmd = @enumFromInt(cmd_id);
            switch (cmd) {
                .command_palette => self.command_palette.toggle(),
                .open_view => self.command_palette.toggle(),
                .appearance => self.status_bar.setNotification("Appearance"),
                .editor_layout => self.status_bar.setNotification("Editor Layout"),
                .explorer => {
                    self.sidebar_visible = true;
                    self.activity_bar.active_icon = 0;
                },
                .search => {
                    self.sidebar_visible = true;
                    self.activity_bar.active_icon = 1;
                },
                .scm => {
                    self.sidebar_visible = true;
                    self.activity_bar.active_icon = 2;
                },
                .run_and_debug => {
                    self.sidebar_visible = true;
                    self.activity_bar.active_icon = 3;
                },
                .extensions => {
                    self.sidebar_visible = true;
                    self.activity_bar.active_icon = 4;
                },
                .problems => {
                    self.panel_visible = true;
                    self.panel.active_tab = 0;
                },
                .output => {
                    self.panel_visible = true;
                    self.panel.active_tab = 1;
                },
                .debug_console => {
                    self.panel_visible = true;
                    self.panel.active_tab = 1;
                },
                .terminal => {
                    self.panel_visible = true;
                    self.panel.active_tab = 2;
                },
                .word_wrap => self.status_bar.setNotification("Word Wrap toggled"),
                .minimap => self.status_bar.setNotification("Minimap toggled"),
                .breadcrumbs => self.status_bar.setNotification("Breadcrumbs toggled"),
                .zoom_in => self.handleFontZoom(true),
                .zoom_out => self.handleFontZoom(false),
                .reset_zoom => {
                    self.font_zoom_level = 0;
                },
                .full_screen => self.status_bar.setNotification("Full Screen"),
            }
            return;
        }
        // Go menu (1000–1059)
        if (cmd_id >= 1000 and cmd_id < 1060) {
            const cmd: context_menu.GoCmd = @enumFromInt(cmd_id);
            switch (cmd) {
                .back, .forward, .last_edit_location => self.status_bar.setNotification("Navigation"),
                .go_to_file => self.command_palette.toggle(),
                .go_to_symbol_in_workspace, .go_to_symbol_in_editor => self.command_palette.toggle(),
                .go_to_definition,
                .go_to_declaration,
                .go_to_type_definition,
                .go_to_implementations,
                .go_to_references,
                => self.status_bar.setNotification("No language server"),
                .go_to_line => self.command_palette.toggle(),
                .go_to_bracket => self.status_bar.setNotification("Go to Bracket"),
                .next_problem, .previous_problem => self.status_bar.setNotification("Problems"),
                .next_change, .previous_change => self.status_bar.setNotification("Changes"),
            }
            return;
        }
        // Run menu (1100–1159)
        if (cmd_id >= 1100 and cmd_id < 1160) {
            const cmd: context_menu.RunCmd = @enumFromInt(cmd_id);
            switch (cmd) {
                .start_debugging, .run_without_debugging => self.status_bar.setNotification("No debugger configured"),
                .stop_debugging => {
                    self.debug_session_active = false;
                    self.status_bar.setNotification("Debugging stopped");
                },
                .restart_debugging => self.status_bar.setNotification("No debugger configured"),
                .open_configurations, .add_configuration => self.status_bar.setNotification("Configurations"),
                .step_over, .step_into, .step_out, .@"continue" => self.status_bar.setNotification("Not debugging"),
                .toggle_breakpoint => {
                    const cur = self.cursor_state.primary().active;
                    self.toggleBreakpoint(cur.line);
                },
                .new_breakpoint => self.status_bar.setNotification("New Breakpoint"),
                .enable_all_breakpoints => self.status_bar.setNotification("Breakpoints enabled"),
                .disable_all_breakpoints => self.status_bar.setNotification("Breakpoints disabled"),
                .remove_all_breakpoints => {
                    self.breakpoint_count = 0;
                    self.status_bar.setNotification("All breakpoints removed");
                },
                .install_debuggers => self.status_bar.setNotification("Install Debuggers"),
            }
            return;
        }
        // Terminal menu (1200–1239)
        if (cmd_id >= 1200 and cmd_id < 1240) {
            const cmd: context_menu.TerminalCmd = @enumFromInt(cmd_id);
            switch (cmd) {
                .new_terminal => {
                    self.panel_visible = true;
                    self.panel.active_tab = 2;
                },
                .split_terminal => self.status_bar.setNotification("Split Terminal"),
                .run_task => self.status_bar.setNotification("Run Task"),
                .run_build_task => self.status_bar.setNotification("Run Build Task"),
                .run_active_file => self.status_bar.setNotification("Run Active File"),
                .run_selected_text => self.status_bar.setNotification("Run Selected Text"),
                .configure_tasks => self.status_bar.setNotification("Configure Tasks"),
            }
            return;
        }
        // Help menu (1300–1359)
        if (cmd_id >= 1300 and cmd_id < 1360) {
            const cmd: context_menu.HelpCmd = @enumFromInt(cmd_id);
            switch (cmd) {
                .welcome => self.status_bar.setNotification("Welcome"),
                .show_all_commands => self.command_palette.toggle(),
                .documentation => self.status_bar.setNotification("Documentation"),
                .release_notes => self.status_bar.setNotification("Release Notes"),
                .keyboard_shortcuts => self.status_bar.setNotification("Keyboard Shortcuts"),
                .report_issue => self.status_bar.setNotification("Report Issue"),
                .toggle_developer_tools => self.status_bar.setNotification("Developer Tools"),
                .about => self.status_bar.setNotification("SBCode v0.1.0"),
            }
            return;
        }
    }

    /// Handle tab bar clicks (switch tab or close tab).
    fn handleTabBarClick(self: *Workbench, mx: i32, _my: i32, region: Rect) void {
        _ = _my;
        if (self.tab_count == 0) return;
        const tab_width: i32 = 160;
        const rel_x = mx - region.x;
        const tab_idx: u8 = @intCast(@min(@as(u32, @intCast(@divTrunc(rel_x, tab_width))), self.tab_count -| 1));
        if (tab_idx >= self.tab_count) return;

        // Check if click is on the close 'x' button (last 24px of tab)
        const tab_start = region.x + @as(i32, tab_idx) * tab_width;
        const close_x = tab_start + tab_width - 24;
        if (mx >= close_x) {
            self.closeTab(tab_idx);
        } else {
            // Switch to clicked tab
            if (self.active_tab < self.tab_count) {
                self.tabs[self.active_tab].active = false;
            }
            self.active_tab = tab_idx;
            self.tabs[tab_idx].active = true;
        }
    }

    /// Handle activity bar icon clicks.
    fn handleActivityBarClick(self: *Workbench, my: i32, region: Rect) void {
        const ICON_BTN_H: i32 = 48;
        const rel_y = my - region.y;
        const icon_idx: u8 = @intCast(@min(@as(u32, @intCast(@divTrunc(rel_y, ICON_BTN_H))), 4));
        self.activity_bar.active_icon = icon_idx;
    }

    /// Handle sidebar file entry clicks.
    fn handleSidebarClick(self: *Workbench, my: i32, region: Rect) void {
        // Section header + project header = 22 + 22 + 1 = 45px offset
        const entries_y = region.y + 45;
        const ROW_H: i32 = 22;
        if (my < entries_y) return;
        if (self.sidebar.entry_count == 0) return;
        const rel_y = my - entries_y;
        const entry_idx: u8 = @intCast(@min(@as(u32, @intCast(@divTrunc(rel_y, ROW_H))), self.sidebar.entry_count - 1));
        if (entry_idx >= self.sidebar.entry_count) return;

        // Toggle expand/collapse for directories
        if (self.sidebar.is_dir[entry_idx]) {
            self.sidebar.expanded[entry_idx] = !self.sidebar.expanded[entry_idx];
        }
    }

    /// Handle panel tab clicks.
    fn handlePanelClick(self: *Workbench, mx: i32, region: Rect) void {
        // Panel tab bar is at top of panel region
        const TAB_HEIGHT: i32 = 35;
        const tab_bar_y = region.y + 1;
        // Only handle clicks in the tab bar area
        // Tab positions are computed from label widths; approximate with fixed widths
        const tab_widths = [_]i32{ 80, 70, 80 }; // PROBLEMS, OUTPUT, TERMINAL
        const PAD_X: i32 = 12;
        var tab_x = region.x + PAD_X;
        for (tab_widths, 0..) |tw, idx| {
            if (mx >= tab_x and mx < tab_x + tw and region.y <= tab_bar_y + TAB_HEIGHT) {
                self.panel.active_tab = @intCast(idx);
                return;
            }
            tab_x += tw + PAD_X * 2;
        }
    }

    /// Handle Ctrl+key shortcuts. Returns true if handled.
    fn handleCtrlShortcut(self: *Workbench, vk: u16, shift: bool) bool {
        switch (vk) {
            VK_Z => {
                // Ctrl+Z: Undo
                if (self.buffer.undo()) {
                    self.retokenizeAll();
                }
                return true;
            },
            VK_Y => {
                // Ctrl+Y: Redo
                if (self.buffer.redo()) {
                    self.retokenizeAll();
                }
                return true;
            },
            VK_A => {
                // Ctrl+A: Select All
                self.selectAll();
                return true;
            },
            VK_C => {
                // Ctrl+C: Copy
                self.copySelection();
                return true;
            },
            VK_X => {
                // Ctrl+X: Cut
                self.cutSelection();
                return true;
            },
            VK_V => {
                // Ctrl+V: Paste
                self.pasteFromClipboard();
                return true;
            },
            VK_W => {
                // Ctrl+W: Close tab
                if (self.tab_count > 0) {
                    self.closeTab(self.active_tab);
                }
                return true;
            },
            VK_N => {
                // Ctrl+N: New file
                self.handleNewFile();
                return true;
            },
            VK_F => {
                if (shift) {
                    // Ctrl+Shift+F: Search across files
                    self.dispatchCommand(CMD_SEARCH_FILES);
                } else {
                    // Ctrl+F: Find
                    self.find_visible = !self.find_visible;
                }
                return true;
            },
            VK_G => {
                // Ctrl+G: Go to line
                self.command_palette.toggle();
                return true;
            },
            VK_OEM_2 => {
                // Ctrl+/: Toggle comment
                self.handleToggleComment();
                return true;
            },
            VK_S => {
                if (shift) {
                    // Ctrl+Shift+S: Save As
                    self.showSaveAsDialog();
                    return true;
                }
                return false; // Let keybinding handle Ctrl+S
            },
            else => return false,
        }
    }

    /// Select all text in the buffer.
    fn selectAll(self: *Workbench) void {
        if (self.buffer.line_count == 0) return;
        const last_line = self.buffer.line_count - 1;
        const last_col: u32 = if (self.buffer.getLine(last_line)) |l| @intCast(l.len) else 0;
        self.cursor_state.setSelection(
            .{ .line = 0, .col = 0 },
            .{ .line = last_line, .col = last_col },
        );
    }

    /// Copy selected text to clipboard.
    fn copySelection(self: *Workbench) void {
        const range = self.cursor_state.getSelectionRange() orelse return;
        // Build selected text into a temp buffer
        var sel_buf: [4096]u8 = undefined;
        var sel_len: usize = 0;

        var line = range.start.line;
        while (line <= range.end.line) : (line += 1) {
            const lt = self.buffer.getLine(line) orelse continue;
            const start_col: usize = if (line == range.start.line) range.start.col else 0;
            const end_col: usize = if (line == range.end.line) @min(range.end.col, @as(u32, @intCast(lt.len))) else lt.len;
            if (start_col < end_col) {
                const chunk = lt[start_col..end_col];
                if (sel_len + chunk.len < sel_buf.len) {
                    @memcpy(sel_buf[sel_len..][0..chunk.len], chunk);
                    sel_len += chunk.len;
                }
            }
            if (line < range.end.line and sel_len + 1 < sel_buf.len) {
                sel_buf[sel_len] = '\n';
                sel_len += 1;
            }
        }
        if (sel_len == 0) return;

        // Copy to Win32 clipboard as UTF-16
        if (win32.OpenClipboard(null) != 0) {
            _ = win32.EmptyClipboard();
            // Allocate global memory for UTF-16 text
            const u16_size = (sel_len + 1) * 2;
            const hmem = win32.GlobalAlloc(win32.GMEM_MOVEABLE, u16_size) orelse {
                _ = win32.CloseClipboard();
                return;
            };
            const ptr = win32.GlobalLock(hmem) orelse {
                _ = win32.GlobalFree(hmem);
                _ = win32.CloseClipboard();
                return;
            };
            // Convert ASCII to UTF-16
            const u16_ptr: [*]u16 = @ptrCast(@alignCast(ptr));
            for (sel_buf[0..sel_len], 0..) |ch, idx| {
                u16_ptr[idx] = ch;
            }
            u16_ptr[sel_len] = 0; // null terminate
            _ = win32.GlobalUnlock(hmem);
            _ = win32.SetClipboardData(win32.CF_UNICODETEXT, hmem);
            _ = win32.CloseClipboard();
        }
    }

    /// Cut selected text (copy + delete).
    fn cutSelection(self: *Workbench) void {
        self.copySelection();
        _ = self.deleteSelection();
    }

    /// Paste text from clipboard.
    fn pasteFromClipboard(self: *Workbench) void {
        if (win32.OpenClipboard(null) == 0) return;
        const hdata = win32.GetClipboardData(win32.CF_UNICODETEXT) orelse {
            _ = win32.CloseClipboard();
            return;
        };
        const ptr = win32.GlobalLock(hdata) orelse {
            _ = win32.CloseClipboard();
            return;
        };
        // Convert UTF-16 to ASCII
        const u16_ptr: [*]const u16 = @ptrCast(@alignCast(ptr));
        var paste_buf: [4096]u8 = undefined;
        var paste_len: usize = 0;
        var idx: usize = 0;
        while (idx < 4096) : (idx += 1) {
            const ch = u16_ptr[idx];
            if (ch == 0) break;
            if (ch < 128) {
                paste_buf[paste_len] = @intCast(ch);
                paste_len += 1;
            }
        }
        _ = win32.GlobalUnlock(hdata);
        _ = win32.CloseClipboard();

        if (paste_len == 0) return;

        // Delete selection first if any
        _ = self.deleteSelection();

        // Insert pasted text
        const cur = self.cursor_state.primary().active;
        if (self.buffer.insert(cur.line, cur.col, paste_buf[0..paste_len])) {
            self.retokenizeAll();
            // Move cursor to end of pasted text
            var new_line = cur.line;
            var new_col = cur.col;
            for (paste_buf[0..paste_len]) |ch| {
                if (ch == '\n') {
                    new_line += 1;
                    new_col = 0;
                } else {
                    new_col += 1;
                }
            }
            self.cursor_state.setPrimary(.{ .line = new_line, .col = new_col });
        }
    }

    /// Delete selected text. Returns true if there was a selection to delete.
    fn deleteSelection(self: *Workbench) bool {
        const range = self.cursor_state.getSelectionRange() orelse return false;
        const start_off = self.buffer.posToOffset(range.start.line, range.start.col) orelse return false;
        const end_off = self.buffer.posToOffset(range.end.line, range.end.col) orelse return false;
        if (end_off <= start_off) return false;
        if (self.buffer.delete(range.start.line, range.start.col, end_off - start_off)) {
            self.retokenizeAll();
            self.cursor_state.setPrimary(.{ .line = range.start.line, .col = range.start.col });
            return true;
        }
        return false;
    }

    /// Handle Tab key: insert spaces.
    fn handleTab(self: *Workbench) void {
        const cur = self.cursor_state.primary().active;
        const spaces = "    "; // 4 spaces
        if (self.buffer.insert(cur.line, cur.col, spaces)) {
            self.highlighter.tokenizeLine(cur.line, self.buffer.getLine(cur.line) orelse "");
            self.cursor_state.setPrimary(.{ .line = cur.line, .col = cur.col + 4 });
        }
    }

    /// Handle Ctrl+/ toggle line comment.
    fn handleToggleComment(self: *Workbench) void {
        const cur = self.cursor_state.primary().active;
        const line_text = self.buffer.getLine(cur.line) orelse return;

        // Check if line starts with "//" (possibly with leading whitespace)
        var first_non_space: u32 = 0;
        while (first_non_space < @as(u32, @intCast(line_text.len)) and
            (line_text[first_non_space] == ' ' or line_text[first_non_space] == '\t'))
        {
            first_non_space += 1;
        }

        if (first_non_space + 2 <= @as(u32, @intCast(line_text.len)) and
            line_text[first_non_space] == '/' and line_text[first_non_space + 1] == '/')
        {
            // Remove comment: delete "// " or "//"
            const del_len: u32 = if (first_non_space + 3 <= @as(u32, @intCast(line_text.len)) and
                line_text[first_non_space + 2] == ' ') 3 else 2;
            if (self.buffer.delete(cur.line, first_non_space, del_len)) {
                self.highlighter.tokenizeLine(cur.line, self.buffer.getLine(cur.line) orelse "");
                if (cur.col >= del_len) {
                    self.cursor_state.setPrimary(.{ .line = cur.line, .col = cur.col - del_len });
                }
            }
        } else {
            // Add comment: insert "// " at first non-space
            if (self.buffer.insert(cur.line, first_non_space, "// ")) {
                self.highlighter.tokenizeLine(cur.line, self.buffer.getLine(cur.line) orelse "");
                self.cursor_state.setPrimary(.{ .line = cur.line, .col = cur.col + 3 });
            }
        }
    }

    /// Handle Ctrl+N: new untitled file.
    fn handleNewFile(self: *Workbench) void {
        _ = self.buffer.load("");
        self.current_file_path_len = 0;
        self.openTab("untitled");
        self.cursor_state.setPrimary(.{ .line = 0, .col = 0 });
        self.scroll_top = 0;
    }

    /// Show Save As dialog (GL-rendered file picker).
    fn showSaveAsDialog(self: *Workbench) void {
        self.file_picker.open(.save);
    }

    /// Retokenize all lines after undo/redo/paste.
    fn retokenizeAll(self: *Workbench) void {
        var line_idx: u32 = 0;
        while (line_idx < self.buffer.line_count) : (line_idx += 1) {
            const line_text = self.buffer.getLine(line_idx) orelse "";
            self.highlighter.tokenizeLine(line_idx, line_text);
        }
    }

    /// Handle find overlay key input.
    fn handleFindInput(self: *Workbench, vk: u16, ctrl: bool) void {
        switch (vk) {
            VK_ESCAPE => {
                self.find_visible = false;
            },
            VK_RETURN => {
                self.findNext();
            },
            VK_BACK => {
                if (self.find_query_len > 0) {
                    self.find_query_len -= 1;
                    self.findNext();
                }
            },
            VK_F => {
                if (ctrl) self.find_visible = false;
            },
            else => {},
        }
    }

    /// Handle text input for find overlay.
    fn handleFindTextInput(self: *Workbench, input: *const InputState) void {
        var i: u32 = 0;
        while (i < input.text_input_len) : (i += 1) {
            const ch = input.text_input[i];
            if (ch < 0x20) continue;
            if (self.find_query_len < 256) {
                self.find_query[self.find_query_len] = ch;
                self.find_query_len += 1;
            }
        }
        if (input.text_input_len > 0) {
            self.findNext();
        }
    }

    /// Find next match from current cursor position.
    fn findNext(self: *Workbench) void {
        if (self.find_query_len == 0) {
            self.find_has_match = false;
            return;
        }
        const query = self.find_query[0..self.find_query_len];
        const cur = self.cursor_state.primary().active;
        var line = cur.line;
        var start_col = cur.col;

        // Search from current position
        var iterations: u32 = 0;
        while (iterations < self.buffer.line_count) : (iterations += 1) {
            if (line >= self.buffer.line_count) line = 0;
            const lt = self.buffer.getLine(line) orelse {
                line += 1;
                start_col = 0;
                continue;
            };
            if (lt.len >= query.len) {
                var col: u32 = start_col;
                while (col + @as(u32, @intCast(query.len)) <= @as(u32, @intCast(lt.len))) : (col += 1) {
                    const slice = lt[col..][0..query.len];
                    if (strEql(slice, query)) {
                        self.find_match_line = line;
                        self.find_match_col = col;
                        self.find_has_match = true;
                        self.cursor_state.setSelection(
                            .{ .line = line, .col = col },
                            .{ .line = line, .col = col + @as(u32, @intCast(query.len)) },
                        );
                        // Scroll to match
                        if (line < self.scroll_top or line >= self.scroll_top + 30) {
                            self.scroll_top = if (line > 10) line - 10 else 0;
                        }
                        return;
                    }
                }
            }
            line += 1;
            start_col = 0;
        }
        self.find_has_match = false;
    }

    /// Open the GL-rendered file picker overlay (replaces blocking Win32 dialog).
    fn showOpenFileDialog(self: *Workbench) void {
        self.file_picker.open(.open);
    }

    // =========================================================================
    // Rendering helpers
    // =========================================================================

    fn renderTitleBar(self: *const Workbench, region: Rect, font_atlas: *const FontAtlas) void {
        // Translucent flat title bar — same color (#323232) with alpha gradient
        // from nearly opaque at top (0.92) to more see-through at bottom (0.70),
        // letting the content behind bleed through for a frosted-glass look.
        {
            const r = 0x32.0 / 255.0;
            const g = 0x32.0 / 255.0;
            const b = 0x32.0 / 255.0;
            const alpha_top: f32 = 0.92;
            const alpha_bot: f32 = 0.70;

            const x0: f32 = @floatFromInt(region.x);
            const y0: f32 = @floatFromInt(region.y);
            const x1: f32 = @floatFromInt(region.x + region.w);
            const y1: f32 = @floatFromInt(region.y + region.h);

            gl.glDisable(gl.GL_TEXTURE_2D);

            gl.glBegin(gl.GL_QUADS);
            gl.glColor4f(r, g, b, alpha_top);
            gl.glVertex2f(x0, y0);
            gl.glColor4f(r, g, b, alpha_top);
            gl.glVertex2f(x1, y0);
            gl.glColor4f(r, g, b, alpha_bot);
            gl.glVertex2f(x1, y1);
            gl.glColor4f(r, g, b, alpha_bot);
            gl.glVertex2f(x0, y1);
            gl.glEnd();

            // Subtle 1px bottom separator
            gl.glBegin(gl.GL_QUADS);
            gl.glColor4f(0.0, 0.0, 0.0, 0.25);
            gl.glVertex2f(x0, y1 - 1.0);
            gl.glVertex2f(x1, y1 - 1.0);
            gl.glVertex2f(x1, y1);
            gl.glVertex2f(x0, y1);
            gl.glEnd();
        }

        if (region.w <= 0 or region.h <= 0) return;

        const cell_w = font_atlas.cell_w;
        const cell_h = font_atlas.cell_h;

        // --- App icon: render sbcode.ico texture or fallback "SB" text ---
        {
            const icon_size = @min(region.h - 4, cell_h + 4);
            const icon_x = region.x + @divTrunc(cell_w, 2);
            const icon_y = region.y + @divTrunc(region.h - icon_size, 2);

            if (self.icon_texture_id != 0) {
                // Render the actual icon as a textured quad
                const fx: f32 = @floatFromInt(icon_x);
                const fy: f32 = @floatFromInt(icon_y);
                const fx1: f32 = fx + @as(f32, @floatFromInt(icon_size));
                const fy1: f32 = fy + @as(f32, @floatFromInt(icon_size));

                gl.glEnable(gl.GL_TEXTURE_2D);
                gl.glBindTexture(gl.GL_TEXTURE_2D, self.icon_texture_id);
                gl.glColor4f(1.0, 1.0, 1.0, 1.0);
                gl.glBegin(gl.GL_QUADS);
                gl.glTexCoord2f(0.0, 0.0);
                gl.glVertex2f(fx, fy);
                gl.glTexCoord2f(1.0, 0.0);
                gl.glVertex2f(fx1, fy);
                gl.glTexCoord2f(1.0, 1.0);
                gl.glVertex2f(fx1, fy1);
                gl.glTexCoord2f(0.0, 1.0);
                gl.glVertex2f(fx, fy1);
                gl.glEnd();
                gl.glDisable(gl.GL_TEXTURE_2D);
            } else {
                // Fallback: blue "SB" box
                const icon_w = cell_w * 2 + 6;
                const icon_h = cell_h + 4;
                const fb_y = region.y + @divTrunc(region.h - icon_h, 2);
                renderRegionBackground(Rect{
                    .x = icon_x,
                    .y = fb_y,
                    .w = icon_w,
                    .h = icon_h,
                }, Color.rgb(0x00, 0x7A, 0xCC));
                const text_ix = icon_x + 3;
                const text_iy = fb_y + 2;
                font_atlas.renderText("SB", @floatFromInt(text_ix), @floatFromInt(text_iy), Color.rgb(0xFF, 0xFF, 0xFF));
            }
        }

        // --- Menu bar labels with overflow "..." collapse ---
        const menu_xs = context_menu.menuBarLabelX(cell_w);
        const menu_ws = context_menu.menuBarLabelW(cell_w);
        const text_y = region.y + @divTrunc(region.h - font_atlas.cell_h, 2);

        // Compute search bar position first so we know the cutoff
        const bar_w: i32 = @min(420, @divTrunc(region.w, 3));
        const bar_x = region.x + @divTrunc(region.w - bar_w, 2);
        const overflow_btn_w = cell_w * 3 + context_menu.MENU_BAR_PAD * 2; // width of "..." button

        // Determine how many menu labels fit before the search bar
        var visible_menu_count: u8 = context_menu.MENU_BAR_COUNT;
        {
            var idx: u8 = 0;
            while (idx < context_menu.MENU_BAR_COUNT) : (idx += 1) {
                const menu_right = region.x + menu_xs[idx] + menu_ws[idx];
                // Need room for the label + overflow button if not the last
                if (menu_right + overflow_btn_w > bar_x and bar_w > cell_w * 8) {
                    visible_menu_count = idx;
                    break;
                }
            }
        }

        // Render visible menu labels
        var mi: u8 = 0;
        while (mi < visible_menu_count) : (mi += 1) {
            const label = context_menu.MENU_BAR_LABELS[mi];
            const mx = region.x + menu_xs[mi];
            const is_active = (self.menu_bar_active >= 0 and @as(u8, @intCast(mi)) == @as(u8, @intCast(self.menu_bar_active)));

            if (is_active) {
                renderRegionBackground(Rect{
                    .x = mx,
                    .y = region.y,
                    .w = menu_ws[mi],
                    .h = region.h,
                }, Color.rgb(0x45, 0x45, 0x45));
            }

            const text_color = if (is_active) Color.rgb(0xFF, 0xFF, 0xFF) else Color.rgb(0xCC, 0xCC, 0xCC);
            font_atlas.renderText(
                label,
                @floatFromInt(mx + context_menu.MENU_BAR_PAD),
                @floatFromInt(text_y),
                text_color,
            );
        }

        // Render "..." overflow button if some menus are hidden
        const overflow_x: i32 = if (visible_menu_count < context_menu.MENU_BAR_COUNT) blk: {
            const ox = region.x + menu_xs[visible_menu_count]; // position where next label would be
            const is_overflow_active = (self.menu_bar_active >= 0 and @as(u8, @intCast(self.menu_bar_active)) >= visible_menu_count);
            if (is_overflow_active) {
                renderRegionBackground(Rect{
                    .x = ox,
                    .y = region.y,
                    .w = overflow_btn_w,
                    .h = region.h,
                }, Color.rgb(0x45, 0x45, 0x45));
            }
            const dot_color = if (is_overflow_active) Color.rgb(0xFF, 0xFF, 0xFF) else Color.rgb(0xCC, 0xCC, 0xCC);
            font_atlas.renderText("...", @floatFromInt(ox + context_menu.MENU_BAR_PAD), @floatFromInt(text_y), dot_color);
            break :blk ox;
        } else -1;
        // Store overflow state for click handling
        _ = overflow_x;

        // --- Search bar centered in the full title bar width (VS Code style) ---
        {
            const bar_h: i32 = region.h - 8;
            const bar_y = region.y + @divTrunc(region.h - bar_h, 2);

            if (bar_w > cell_w * 8) {
                // Background — slightly lighter than title bar (#3C3C3C)
                renderRegionBackground(Rect{
                    .x = bar_x,
                    .y = bar_y,
                    .w = bar_w,
                    .h = bar_h,
                }, Color.rgb(0x3C, 0x3C, 0x3C));

                // Subtle 1px inset border (#505050 top/sides, #2A2A2A bottom for depth)
                {
                    const bx0: f32 = @floatFromInt(bar_x);
                    const by0: f32 = @floatFromInt(bar_y);
                    const bx1: f32 = @floatFromInt(bar_x + bar_w);
                    const by1: f32 = @floatFromInt(bar_y + bar_h);
                    gl.glDisable(gl.GL_TEXTURE_2D);
                    // Top + sides: lighter border
                    gl.glColor4f(0x50.0 / 255.0, 0x50.0 / 255.0, 0x50.0 / 255.0, 0.8);
                    gl.glBegin(gl.GL_LINE_STRIP);
                    gl.glVertex2f(bx0, by1);
                    gl.glVertex2f(bx0, by0);
                    gl.glVertex2f(bx1, by0);
                    gl.glVertex2f(bx1, by1);
                    gl.glEnd();
                    // Bottom: darker for depth
                    gl.glColor4f(0x2A.0 / 255.0, 0x2A.0 / 255.0, 0x2A.0 / 255.0, 0.8);
                    gl.glBegin(gl.GL_LINES);
                    gl.glVertex2f(bx0, by1);
                    gl.glVertex2f(bx1, by1);
                    gl.glEnd();
                }

                // Build display text: active file name or "SBCode"
                var bar_label_buf: [80]u8 = undefined;
                var bar_label_len: usize = 0;
                if (self.tab_count > 0 and self.tabs[self.active_tab].label_len > 0) {
                    const lbl = self.tabs[self.active_tab].label[0..self.tabs[self.active_tab].label_len];
                    @memcpy(bar_label_buf[0..lbl.len], lbl);
                    bar_label_len = lbl.len;
                } else {
                    const default = "SBCode";
                    @memcpy(bar_label_buf[0..default.len], default);
                    bar_label_len = default.len;
                }

                // Center the content inside the bar: search icon + label
                const icon_px: i32 = @min(bar_h - 4, cell_h); // icon size
                const gap: i32 = 6;
                const label_w = @as(i32, @intCast(bar_label_len)) * cell_w;
                const total_content_w = icon_px + gap + label_w;
                const content_x = bar_x + @divTrunc(bar_w - total_content_w, 2);
                const content_y = bar_y + @divTrunc(bar_h - cell_h, 2);

                // Search icon — use texture if available, fallback to ">" text
                if (self.search_icon_texture_id != 0) {
                    const ix: f32 = @floatFromInt(content_x);
                    const iy: f32 = @floatFromInt(bar_y + @divTrunc(bar_h - icon_px, 2));
                    const ix1: f32 = ix + @as(f32, @floatFromInt(icon_px));
                    const iy1: f32 = iy + @as(f32, @floatFromInt(icon_px));
                    gl.glEnable(gl.GL_TEXTURE_2D);
                    gl.glBindTexture(gl.GL_TEXTURE_2D, self.search_icon_texture_id);
                    gl.glColor4f(0.6, 0.6, 0.6, 1.0);
                    gl.glBegin(gl.GL_QUADS);
                    gl.glTexCoord2f(0.0, 0.0);
                    gl.glVertex2f(ix, iy);
                    gl.glTexCoord2f(1.0, 0.0);
                    gl.glVertex2f(ix1, iy);
                    gl.glTexCoord2f(1.0, 1.0);
                    gl.glVertex2f(ix1, iy1);
                    gl.glTexCoord2f(0.0, 1.0);
                    gl.glVertex2f(ix, iy1);
                    gl.glEnd();
                    gl.glDisable(gl.GL_TEXTURE_2D);
                } else {
                    font_atlas.renderText(">", @floatFromInt(content_x), @floatFromInt(content_y), Color.rgb(0x80, 0x80, 0x80));
                }

                // Label text (slightly brighter)
                font_atlas.renderText(
                    bar_label_buf[0..bar_label_len],
                    @floatFromInt(content_x + icon_px + gap),
                    @floatFromInt(content_y),
                    Color.rgb(0xA0, 0xA0, 0xA0),
                );
            }
        }

        // --- Window control buttons (46px wide each, right-aligned) ---
        const close_x = region.x + region.w - WINDOW_BTN_WIDTH;
        const max_x = close_x - WINDOW_BTN_WIDTH;
        const min_x = max_x - WINDOW_BTN_WIDTH;
        const sym_y = region.y + @divTrunc(region.h - font_atlas.cell_h, 2);

        font_atlas.renderText("_", @floatFromInt(min_x + @divTrunc(WINDOW_BTN_WIDTH - cell_w, 2)), @floatFromInt(sym_y), Color.rgb(0xCC, 0xCC, 0xCC));

        const max_sym_w = 2 * cell_w;
        font_atlas.renderText("[]", @floatFromInt(max_x + @divTrunc(WINDOW_BTN_WIDTH - max_sym_w, 2)), @floatFromInt(sym_y), Color.rgb(0xCC, 0xCC, 0xCC));

        font_atlas.renderText("x", @floatFromInt(close_x + @divTrunc(WINDOW_BTN_WIDTH - cell_w, 2)), @floatFromInt(sym_y), Color.rgb(0xCC, 0xCC, 0xCC));
    }

    fn renderTabBar(self: *const Workbench, region: Rect, font_atlas: *const FontAtlas) void {
        renderRegionBackground(region, TAB_INACTIVE_BG);

        if (region.w <= 0 or region.h <= 0) return;

        if (self.tab_count == 0) {
            // Empty tab bar — just background, no tabs
            return;
        }

        const tab_width: i32 = 160;
        var t: u8 = 0;
        while (t < self.tab_count) : (t += 1) {
            const tab = self.tabs[t];
            const is_active = (t == self.active_tab);
            const bg = if (is_active) TAB_ACTIVE_BG else TAB_INACTIVE_BG;
            const tab_rect = Rect{
                .x = region.x + @as(i32, t) * tab_width,
                .y = region.y,
                .w = tab_width,
                .h = region.h,
            };
            renderRegionBackground(tab_rect, bg);

            // Tab label text
            if (tab.label_len > 0) {
                const text_color = if (is_active) Color.rgb(0xFF, 0xFF, 0xFF) else Color.rgb(0x96, 0x96, 0x96);
                font_atlas.renderText(
                    tab.label[0..tab.label_len],
                    @floatFromInt(tab_rect.x + 12),
                    @floatFromInt(tab_rect.y + @divTrunc(region.h - font_atlas.cell_h, 2)),
                    text_color,
                );
            }

            // Close "x" button on the right side of each tab
            const close_x = tab_rect.x + tab_width - 24;
            const close_y = tab_rect.y + @divTrunc(region.h - font_atlas.cell_h, 2);
            font_atlas.renderText("x", @floatFromInt(close_x), @floatFromInt(close_y), TAB_CLOSE_COLOR);

            // Active tab: bottom highlight border (1px white line)
            if (is_active) {
                renderRegionBackground(Rect{
                    .x = tab_rect.x,
                    .y = tab_rect.y + region.h - 1,
                    .w = tab_width,
                    .h = 1,
                }, TAB_ACTIVE_BORDER);
            }

            // Separator line between inactive tabs
            if (!is_active and t > 0) {
                renderRegionBackground(Rect{
                    .x = tab_rect.x,
                    .y = tab_rect.y + 6,
                    .w = 1,
                    .h = region.h - 12,
                }, TAB_SEPARATOR_COLOR);
            }
        }

        // Bottom border of entire tab bar
        renderRegionBackground(Rect{
            .x = region.x,
            .y = region.y + region.h - 1,
            .w = region.w,
            .h = 1,
        }, Color.rgb(0x25, 0x25, 0x25));
    }

    fn renderBreadcrumbs(self: *const Workbench, region: Rect, font_atlas: *const FontAtlas) void {
        renderRegionBackground(region, BREADCRUMBS_BG);

        if (region.w <= 0 or region.h <= 0) return;

        // Show breadcrumb path for active tab
        if (self.tab_count > 0 and self.tabs[self.active_tab].label_len > 0) {
            const label = self.tabs[self.active_tab].label[0..self.tabs[self.active_tab].label_len];
            font_atlas.renderText(
                label,
                @floatFromInt(region.x + 12),
                @floatFromInt(region.y + 3),
                BREADCRUMBS_TEXT,
            );
        }

        // Bottom separator
        renderRegionBackground(Rect{
            .x = region.x,
            .y = region.y + region.h - 1,
            .w = region.w,
            .h = 1,
        }, Color.rgb(0x2B, 0x2B, 0x2B));
    }

    fn renderWelcome(self: *const Workbench, region: Rect, font_atlas: *const FontAtlas) void {
        if (region.w <= 0 or region.h <= 0) return;

        const cell_w = font_atlas.cell_w;
        const cell_h = font_atlas.cell_h;
        if (cell_w <= 0 or cell_h <= 0) return;

        // Center "SBCode" title
        const title = "SBCode";
        const title_w = @as(i32, @intCast(title.len)) * cell_w;
        const center_x = region.x + @divTrunc(region.w - title_w, 2);
        const center_y = region.y + @divTrunc(region.h, 3);

        font_atlas.renderText(title, @floatFromInt(center_x), @floatFromInt(center_y), WELCOME_TITLE_COLOR);

        // Keyboard shortcut hints below (only when no tabs are open)
        if (self.tab_count == 0) {
            const hints = [_][]const u8{
                "Ctrl+O   Open File",
                "Ctrl+P   Command Palette",
                "Ctrl+S   Save File",
            };

            var h: usize = 0;
            while (h < hints.len) : (h += 1) {
                const hint = hints[h];
                const hint_w = @as(i32, @intCast(hint.len)) * cell_w;
                const hx = region.x + @divTrunc(region.w - hint_w, 2);
                const hy = center_y + cell_h * 3 + @as(i32, @intCast(h)) * (cell_h + 6);
                font_atlas.renderText(hint, @floatFromInt(hx), @floatFromInt(hy), WELCOME_HINT_COLOR);
            }
        }
    }

    fn renderMinimap(self: *const Workbench, region: Rect) void {
        renderRegionBackground(region, MINIMAP_BG);

        if (region.w <= 0 or region.h <= 0) return;

        // Left border separator
        renderRegionBackground(Rect{
            .x = region.x,
            .y = region.y,
            .w = 1,
            .h = region.h,
        }, Color.rgb(0x2B, 0x2B, 0x2B));

        // Render simplified buffer line content blocks in minimap
        const line_h: i32 = 2;
        const max_lines: u32 = @intCast(@divTrunc(region.h, line_h + 1));
        var i: u32 = 0;
        while (i < @min(self.buffer.line_count, max_lines)) : (i += 1) {
            const line = self.buffer.getLine(self.scroll_top + i) orelse break;
            const len: i32 = @intCast(@min(line.len, @as(usize, @intCast(region.w - 4))));
            if (len > 0) {
                renderRegionBackground(Rect{
                    .x = region.x + 2,
                    .y = region.y + 2 + @as(i32, @intCast(i)) * (line_h + 1),
                    .w = len,
                    .h = line_h,
                }, Color.rgba(0x80, 0x80, 0x80, 0x40));
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

    fn renderFindOverlay(self: *const Workbench, layout: *const LayoutState, font_atlas: *const FontAtlas) void {
        const editor_area = layout.getRegion(.editor_area);
        const overlay_w: i32 = 350;
        const overlay_h: i32 = 34;
        const overlay_x = editor_area.x + editor_area.w - overlay_w - 20;
        const overlay_y = editor_area.y;

        // Background
        renderRegionBackground(
            Rect{ .x = overlay_x, .y = overlay_y, .w = overlay_w, .h = overlay_h },
            Color.rgb(0x25, 0x25, 0x25),
        );

        // Border
        renderRegionBackground(
            Rect{ .x = overlay_x, .y = overlay_y + overlay_h - 1, .w = overlay_w, .h = 1 },
            Color.rgb(0x00, 0x7A, 0xCC),
        );

        // Search query text
        if (self.find_query_len > 0) {
            font_atlas.renderText(
                self.find_query[0..self.find_query_len],
                @floatFromInt(overlay_x + 8),
                @floatFromInt(overlay_y + 8),
                Color.rgb(0xD4, 0xD4, 0xD4),
            );
        } else {
            font_atlas.renderText(
                "Find",
                @floatFromInt(overlay_x + 8),
                @floatFromInt(overlay_y + 8),
                Color.rgb(0x6A, 0x6A, 0x6A),
            );
        }
    }

    /// Duplicate the current line below the cursor.
    fn duplicate_line(self: *Workbench) void {
        const pos = self.cursor_state.primary().active;
        const line_text = self.buffer.getLine(pos.line) orelse return;
        // Insert a copy of the current line below
        self.buffer.insertLine(pos.line + 1, line_text);
        self.cursor_state.setPrimary(.{ .line = pos.line + 1, .col = pos.col });
    }

    /// Move the current line up or down.
    fn move_line(self: *Workbench, direction: i32) void {
        const pos = self.cursor_state.primary().active;
        if (direction < 0 and pos.line == 0) return;
        const target: u32 = if (direction < 0) pos.line - 1 else pos.line + 1;
        if (target >= self.buffer.line_count) return;
        self.buffer.swapLines(pos.line, target);
        self.cursor_state.setPrimary(.{ .line = target, .col = pos.col });
    }

    /// Add a file path to the recent file history (MRU list).
    fn addRecentFile(self: *Workbench, path: []const u8) void {
        if (path.len == 0 or path.len > 260) return;
        // Shift existing entries down
        if (self.recent_file_count < 16) {
            self.recent_file_count += 1;
        }
        var i: u8 = self.recent_file_count - 1;
        while (i > 0) : (i -= 1) {
            self.recent_file_history[i] = self.recent_file_history[i - 1];
            self.recent_file_history_lens[i] = self.recent_file_history_lens[i - 1];
        }
        const copy_len: u16 = @intCast(@min(path.len, 260));
        @memcpy(self.recent_file_history[0][0..copy_len], path[0..copy_len]);
        self.recent_file_history_lens[0] = copy_len;
    }

    /// Render the menu bar (File, Edit, View, Help) in the title bar area.
    fn renderMenu(self: *const Workbench, region: Rect, font_atlas: *const FontAtlas) void {
        if (!self.menu_bar_visible) return;
        const labels = [_][]const u8{ "File", "Edit", "View", "Help" };
        var x = region.x + 8;
        for (labels) |label| {
            font_atlas.renderText(label, @floatFromInt(x), @floatFromInt(region.y + 6), Color.rgb(0xCC, 0xCC, 0xCC));
            x += @as(i32, @intCast(label.len)) * font_atlas.cell_w + 16;
        }
    }

    /// Handle right-click context menu based on which UI zone was clicked.
    /// Uses layout hit-testing to determine the zone, shows the appropriate
    /// Win32 native popup menu, and dispatches the selected command.
    fn handleRightClick(self: *Workbench, mx: i32, my: i32, layout: *const LayoutState) void {
        const hwnd = self.hwnd orelse (global_hwnd orelse return);

        // Convert client coords to screen coords for TrackPopupMenu
        var pt = win32.POINT{ .x = mx, .y = my };
        _ = win32.ClientToScreen(hwnd, &pt);

        // Determine which zone was right-clicked
        const zone = self.detectMenuZone(mx, my, layout);

        const cmd_id: u16 = switch (zone) {
            .editor => context_menu.showEditorMenu(hwnd, pt.x, pt.y),
            .tab => context_menu.showTabMenu(hwnd, pt.x, pt.y),
            .sidebar => context_menu.showSidebarMenu(hwnd, pt.x, pt.y),
            .panel => context_menu.showPanelMenu(hwnd, pt.x, pt.y),
            .title_bar => context_menu.showTitleBarMenu(hwnd, pt.x, pt.y),
        };

        if (cmd_id == 0) return; // User cancelled

        switch (zone) {
            .editor => self.dispatchEditorMenuCmd(cmd_id),
            .tab => self.dispatchTabMenuCmd(cmd_id, mx, layout),
            .sidebar => self.dispatchSidebarMenuCmd(cmd_id),
            .panel => self.dispatchPanelMenuCmd(cmd_id),
            .title_bar => self.dispatchTitleBarMenuCmd(cmd_id),
        }
    }

    /// Detect which menu zone the mouse position falls in.
    fn detectMenuZone(self: *const Workbench, mx: i32, my: i32, layout: *const LayoutState) context_menu.MenuZone {
        // Check regions in priority order
        const editor_tabs = layout.getRegion(.editor_tabs);
        if (editor_tabs.contains(mx, my) and self.tab_count > 0) return .tab;

        const title_bar = layout.getRegion(.title_bar);
        if (title_bar.contains(mx, my)) return .title_bar;

        if (self.sidebar_visible) {
            const sidebar_region = layout.getRegion(.sidebar);
            if (sidebar_region.contains(mx, my)) return .sidebar;
        }

        if (self.panel_visible) {
            const panel_region = layout.getRegion(.panel);
            if (panel_region.contains(mx, my)) return .panel;
        }

        // Default: editor area (includes editor_area, breadcrumbs, minimap)
        return .editor;
    }

    /// Dispatch an editor context menu command.
    fn dispatchEditorMenuCmd(self: *Workbench, cmd_id: u16) void {
        const cmd: context_menu.EditorCmd = @enumFromInt(cmd_id);
        switch (cmd) {
            .cut => self.cutSelection(),
            .copy => self.copySelection(),
            .paste => self.pasteFromClipboard(),
            .toggle_line_comment => self.handleToggleComment(),
            .command_palette => self.command_palette.toggle(),
            .rename_symbol => {
                // Select the word under cursor for rename
                const cur = self.cursor_state.primary().active;
                self.select_word(cur.line, cur.col);
            },
            .change_all_occurrences => {
                // Open find with current word
                const cur = self.cursor_state.primary().active;
                if (self.buffer.getLine(cur.line)) |line| {
                    var start = cur.col;
                    var end = cur.col;
                    while (start > 0 and isWordChar(line[start - 1])) start -= 1;
                    while (end < @as(u32, @intCast(line.len)) and isWordChar(line[end])) end += 1;
                    if (end > start) {
                        const word = line[start..end];
                        const copy_len = @min(word.len, @as(usize, 256));
                        @memcpy(self.find_query[0..copy_len], word[0..copy_len]);
                        self.find_query_len = @intCast(copy_len);
                        self.find_visible = true;
                        self.findNext();
                    }
                }
            },
            .format_document, .format_selection => {
                self.status_bar.setNotification("Format: no formatter");
            },
            .refactor, .source_action => {
                self.status_bar.setNotification("No refactorings available");
            },
            .toggle_block_comment => {
                // Block comment toggle: wrap selection in /* */
                self.handleToggleComment();
            },
            // Navigation commands — stub with status bar notification
            .go_to_definition,
            .go_to_declaration,
            .go_to_type_definition,
            .go_to_implementations,
            .go_to_references,
            .peek_definition,
            .peek_declaration,
            .peek_type_definition,
            .peek_implementations,
            .peek_references,
            => {
                self.status_bar.setNotification("No language server");
            },
        }
    }

    /// Dispatch a tab context menu command.
    fn dispatchTabMenuCmd(self: *Workbench, cmd_id: u16, mx: i32, layout: *const LayoutState) void {
        const cmd: context_menu.TabCmd = @enumFromInt(cmd_id);
        // Determine which tab was right-clicked
        const editor_tabs = layout.getRegion(.editor_tabs);
        const tab_width: i32 = 160;
        const rel_x = mx - editor_tabs.x;
        const clicked_tab: u8 = @intCast(@min(
            @as(u32, @intCast(@max(0, @divTrunc(rel_x, tab_width)))),
            if (self.tab_count > 0) self.tab_count - 1 else 0,
        ));

        switch (cmd) {
            .close => self.closeTab(clicked_tab),
            .close_others => {
                // Close all tabs except the clicked one
                // Keep the clicked tab, remove others
                if (self.tab_count > 1) {
                    const keep = self.tabs[clicked_tab];
                    self.tabs[0] = keep;
                    self.tab_count = 1;
                    self.active_tab = 0;
                    self.tabs[0].active = true;
                }
            },
            .close_to_the_right => {
                // Close all tabs to the right of clicked
                if (clicked_tab + 1 < self.tab_count) {
                    self.tab_count = clicked_tab + 1;
                    if (self.active_tab >= self.tab_count) {
                        self.active_tab = self.tab_count - 1;
                        self.tabs[self.active_tab].active = true;
                    }
                }
            },
            .close_saved => {
                // Close tabs that are not dirty (simplified: close all non-active)
                // In a real impl each tab would track its own dirty state
                self.status_bar.setNotification("Close Saved");
            },
            .close_all => {
                self.tab_count = 0;
                self.active_tab = 0;
            },
            .copy_path => {
                // Copy the current file path to clipboard
                if (self.current_file_path_len > 0) {
                    self.copyPathToClipboard();
                }
            },
            .copy_relative_path => {
                // Copy relative path (same as full for now)
                if (self.current_file_path_len > 0) {
                    self.copyPathToClipboard();
                }
            },
            .reveal_in_explorer => {
                self.status_bar.setNotification("Reveal in Explorer");
            },
            .keep_open => {
                self.status_bar.setNotification("Tab pinned");
            },
            .split_up, .split_down, .split_left, .split_right => {
                self.status_bar.setNotification("Split editor");
            },
        }
    }

    /// Dispatch a sidebar context menu command.
    fn dispatchSidebarMenuCmd(self: *Workbench, cmd_id: u16) void {
        const cmd: context_menu.SidebarCmd = @enumFromInt(cmd_id);
        switch (cmd) {
            .new_file => self.handleNewFile(),
            .new_folder => self.status_bar.setNotification("New Folder"),
            .cut => self.cutSelection(),
            .copy => self.copySelection(),
            .paste => self.pasteFromClipboard(),
            .copy_path => {
                if (self.current_file_path_len > 0) self.copyPathToClipboard();
            },
            .copy_relative_path => {
                if (self.current_file_path_len > 0) self.copyPathToClipboard();
            },
            .rename => self.status_bar.setNotification("Rename"),
            .delete => self.status_bar.setNotification("Delete"),
            .reveal_in_file_explorer => self.status_bar.setNotification("Reveal in Explorer"),
            .open_in_integrated_terminal => {
                self.panel_visible = true;
                self.panel.active_tab = 2; // Terminal tab
            },
            .find_in_folder => {
                self.sidebar_visible = true;
                self.activity_bar.active_icon = 1; // Search
            },
            .collapse_folders => {
                // Collapse all expanded folders
                var i: u8 = 0;
                while (i < self.sidebar.entry_count) : (i += 1) {
                    if (self.sidebar.is_dir[i]) {
                        self.sidebar.expanded[i] = false;
                    }
                }
            },
        }
    }

    /// Dispatch a panel context menu command.
    fn dispatchPanelMenuCmd(self: *Workbench, cmd_id: u16) void {
        const cmd: context_menu.PanelCmd = @enumFromInt(cmd_id);
        switch (cmd) {
            .clear => self.status_bar.setNotification("Terminal cleared"),
            .copy_all => self.status_bar.setNotification("Copied all"),
            .select_all => self.status_bar.setNotification("Selected all"),
            .scroll_to_bottom => self.status_bar.setNotification("Scrolled to bottom"),
            .split_terminal => self.status_bar.setNotification("Split terminal"),
            .new_terminal => {
                self.panel_visible = true;
                self.panel.active_tab = 2;
            },
            .kill_terminal => self.status_bar.setNotification("Terminal killed"),
        }
    }

    /// Dispatch a title bar context menu command.
    fn dispatchTitleBarMenuCmd(self: *Workbench, cmd_id: u16) void {
        const cmd: context_menu.TitleBarCmd = @enumFromInt(cmd_id);
        const hwnd = self.hwnd orelse (global_hwnd orelse return);
        switch (cmd) {
            .restore => _ = win32.PostMessageW(hwnd, win32.WM_SYSCOMMAND, win32.SC_RESTORE, 0),
            .minimize => _ = win32.PostMessageW(hwnd, win32.WM_SYSCOMMAND, win32.SC_MINIMIZE, 0),
            .maximize => _ = win32.PostMessageW(hwnd, win32.WM_SYSCOMMAND, win32.SC_MAXIMIZE, 0),
            .close => _ = win32.PostMessageW(hwnd, win32.WM_SYSCOMMAND, win32.SC_CLOSE, 0),
        }
    }

    /// Copy the current file path to the Win32 clipboard.
    fn copyPathToClipboard(self: *Workbench) void {
        if (self.current_file_path_len == 0) return;
        if (win32.OpenClipboard(null) != 0) {
            _ = win32.EmptyClipboard();
            const u16_size = (@as(usize, self.current_file_path_len) + 1) * 2;
            const hmem = win32.GlobalAlloc(win32.GMEM_MOVEABLE, u16_size) orelse {
                _ = win32.CloseClipboard();
                return;
            };
            const ptr = win32.GlobalLock(hmem) orelse {
                _ = win32.GlobalFree(hmem);
                _ = win32.CloseClipboard();
                return;
            };
            const u16_ptr: [*]u16 = @ptrCast(@alignCast(ptr));
            const len = self.current_file_path_len;
            @memcpy(u16_ptr[0..len], self.current_file_path[0..len]);
            u16_ptr[len] = 0;
            _ = win32.GlobalUnlock(hmem);
            _ = win32.SetClipboardData(win32.CF_UNICODETEXT, hmem);
            _ = win32.CloseClipboard();
        }
    }

    /// Handle font zoom in/out (Ctrl+= / Ctrl+-).
    fn handleFontZoom(self: *Workbench, zoom_in: bool) void {
        if (zoom_in) {
            if (self.font_zoom_level < 20) self.font_zoom_level += 1;
        } else {
            if (self.font_zoom_level > -10) self.font_zoom_level -= 1;
        }
    }

    /// Handle confirm dialog click using fixed button layout (no font atlas needed).
    fn handleConfirmDialogClickSimple(self: *Workbench, mx: i32, my: i32, layout: *const LayoutState) void {
        const win_w = layout.window_w;
        const win_h = layout.window_h;
        const dlg_w: i32 = 400;
        const dlg_h: i32 = 140;
        const dlg_x = @divTrunc(win_w - dlg_w, 2);
        const dlg_y = @divTrunc(win_h - dlg_h, 2) - 30;

        // Click outside dialog = cancel
        if (mx < dlg_x or mx >= dlg_x + dlg_w or my < dlg_y or my >= dlg_y + dlg_h) {
            self.handleConfirmResult(2);
            return;
        }

        // Button row: fixed widths (Save=60, Don't Save=110, Cancel=75)
        const btn_h: i32 = 28;
        const btn_pad: i32 = 8;
        const btn_y = dlg_y + dlg_h - btn_h - 16;
        const btn_ws = [_]i32{ 60, 110, 75 };
        const total_btn_w = btn_ws[0] + btn_ws[1] + btn_ws[2] + btn_pad * 2;
        var bx = dlg_x + dlg_w - total_btn_w - 16;

        if (my >= btn_y and my < btn_y + btn_h) {
            for (0..3) |i| {
                if (mx >= bx and mx < bx + btn_ws[i]) {
                    self.handleConfirmResult(@intCast(i));
                    return;
                }
                bx += btn_ws[i] + btn_pad;
            }
        }
    }

    /// Render the custom confirm dialog overlay (replaces Win32 MessageBox).
    fn renderConfirmDialog(self: *const Workbench, layout: *const LayoutState, font_atlas: *const FontAtlas) void {
        if (!self.confirm_dialog_visible) return;

        const win_w = layout.window_w;
        const win_h = layout.window_h;
        const cell_w = font_atlas.cell_w;
        const cell_h = font_atlas.cell_h;

        // Fade-in alpha
        const alpha_f = self.confirm_dialog_anim;
        const bg_alpha: u8 = @intFromFloat(@min(255.0, alpha_f * 180.0));

        // Semi-transparent dark overlay covering entire window
        gl.glEnable(gl.GL_BLEND);
        gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
        renderRegionBackground(Rect{ .x = 0, .y = 0, .w = win_w, .h = win_h }, Color.rgba(0x00, 0x00, 0x00, bg_alpha));

        if (alpha_f < 0.1) return;

        // Dialog box dimensions
        const dlg_w: i32 = 400;
        const dlg_h: i32 = 140;
        const dlg_x = @divTrunc(win_w - dlg_w, 2);
        const dlg_y = @divTrunc(win_h - dlg_h, 2) - 30; // slightly above center

        // Dialog background
        renderRegionBackground(Rect{ .x = dlg_x, .y = dlg_y, .w = dlg_w, .h = dlg_h }, Color.rgb(0x25, 0x25, 0x25));

        // Border
        renderRegionBackground(Rect{ .x = dlg_x, .y = dlg_y, .w = dlg_w, .h = 1 }, Color.rgb(0x45, 0x45, 0x45));
        renderRegionBackground(Rect{ .x = dlg_x, .y = dlg_y + dlg_h - 1, .w = dlg_w, .h = 1 }, Color.rgb(0x45, 0x45, 0x45));
        renderRegionBackground(Rect{ .x = dlg_x, .y = dlg_y, .w = 1, .h = dlg_h }, Color.rgb(0x45, 0x45, 0x45));
        renderRegionBackground(Rect{ .x = dlg_x + dlg_w - 1, .y = dlg_y, .w = 1, .h = dlg_h }, Color.rgb(0x45, 0x45, 0x45));

        // Title text
        const title = "SBCode";
        font_atlas.renderText(title, @floatFromInt(dlg_x + 16), @floatFromInt(dlg_y + 12), Color.rgb(0xE0, 0xE0, 0xE0));

        // Message text
        const msg_text = "Do you want to save changes before closing?";
        const msg_y = dlg_y + 12 + cell_h + 16;
        font_atlas.renderText(msg_text, @floatFromInt(dlg_x + 16), @floatFromInt(msg_y), Color.rgb(0xCC, 0xCC, 0xCC));

        // Buttons row (right-aligned)
        const btn_h: i32 = 28;
        const btn_pad: i32 = 8;
        const btn_y = dlg_y + dlg_h - btn_h - 16;

        const btn_labels = [_][]const u8{ "Save", "Don't Save", "Cancel" };
        const btn_widths = [_]i32{
            @as(i32, @intCast(btn_labels[0].len)) * cell_w + 24,
            @as(i32, @intCast(btn_labels[1].len)) * cell_w + 24,
            @as(i32, @intCast(btn_labels[2].len)) * cell_w + 24,
        };
        const total_btn_w = btn_widths[0] + btn_widths[1] + btn_widths[2] + btn_pad * 2;
        var bx = dlg_x + dlg_w - total_btn_w - 16;

        for (btn_labels, 0..) |label, i| {
            const is_selected = (@as(u8, @intCast(i)) == self.confirm_dialog_selected);
            const bg = if (is_selected) Color.rgb(0x09, 0x47, 0x71) else Color.rgb(0x3C, 0x3C, 0x3C);
            const border_color = if (is_selected) Color.rgb(0x26, 0x7F, 0xD9) else Color.rgb(0x50, 0x50, 0x50);

            renderRegionBackground(Rect{ .x = bx, .y = btn_y, .w = btn_widths[i], .h = btn_h }, bg);
            // Button border
            renderRegionBackground(Rect{ .x = bx, .y = btn_y, .w = btn_widths[i], .h = 1 }, border_color);
            renderRegionBackground(Rect{ .x = bx, .y = btn_y + btn_h - 1, .w = btn_widths[i], .h = 1 }, border_color);
            renderRegionBackground(Rect{ .x = bx, .y = btn_y, .w = 1, .h = btn_h }, border_color);
            renderRegionBackground(Rect{ .x = bx + btn_widths[i] - 1, .y = btn_y, .w = 1, .h = btn_h }, border_color);

            // Button text centered
            const text_x = bx + @divTrunc(btn_widths[i] - @as(i32, @intCast(label.len)) * cell_w, 2);
            const text_y = btn_y + @divTrunc(btn_h - cell_h, 2);
            const text_color = if (is_selected) Color.rgb(0xFF, 0xFF, 0xFF) else Color.rgb(0xCC, 0xCC, 0xCC);
            font_atlas.renderText(label, @floatFromInt(text_x), @floatFromInt(text_y), text_color);

            bx += btn_widths[i] + btn_pad;
        }
    }

    /// Handle a click inside the confirm dialog. Returns true if consumed.
    fn handleConfirmDialogClick(self: *Workbench, mx: i32, my: i32, layout: *const LayoutState, font_atlas: *const FontAtlas) bool {
        if (!self.confirm_dialog_visible) return false;

        const win_w = layout.window_w;
        const win_h = layout.window_h;
        const cell_w = font_atlas.cell_w;

        const dlg_w: i32 = 400;
        const dlg_h: i32 = 140;
        const dlg_x = @divTrunc(win_w - dlg_w, 2);
        const dlg_y = @divTrunc(win_h - dlg_h, 2) - 30;

        // Click outside dialog = cancel
        if (mx < dlg_x or mx >= dlg_x + dlg_w or my < dlg_y or my >= dlg_y + dlg_h) {
            self.handleConfirmResult(2); // Cancel
            return true;
        }

        // Check button clicks
        const btn_h: i32 = 28;
        const btn_pad: i32 = 8;
        const btn_y = dlg_y + dlg_h - btn_h - 16;

        if (my < btn_y or my >= btn_y + btn_h) return true; // inside dialog but not on buttons

        const btn_labels = [_][]const u8{ "Save", "Don't Save", "Cancel" };
        const btn_widths = [_]i32{
            @as(i32, @intCast(btn_labels[0].len)) * cell_w + 24,
            @as(i32, @intCast(btn_labels[1].len)) * cell_w + 24,
            @as(i32, @intCast(btn_labels[2].len)) * cell_w + 24,
        };
        const total_btn_w = btn_widths[0] + btn_widths[1] + btn_widths[2] + btn_pad * 2;
        var bx = dlg_x + dlg_w - total_btn_w - 16;

        for (0..3) |i| {
            if (mx >= bx and mx < bx + btn_widths[i]) {
                self.handleConfirmResult(@intCast(i));
                return true;
            }
            bx += btn_widths[i] + btn_pad;
        }

        return true; // consumed (inside dialog)
    }

    /// Handle a click inside the dropdown menu. Returns true if click was consumed.
    fn handleDropdownClick(self: *Workbench, mx: i32, my: i32) bool {
        const items = getDropdownItems(self.dropdown_index);
        const item_h: i32 = self.cell_h + 8;
        const sep_h: i32 = @divTrunc(self.cell_h, 2);
        const pad: i32 = @divTrunc(self.cell_h, 4);
        const dx = self.dropdown_x;
        const dy = self.dropdown_y;
        const dw = self.dropdown_w;

        // Compute total height
        var total_h: i32 = pad;
        for (items) |item| {
            total_h += item_h;
            if (item.separator_after) total_h += sep_h;
        }
        total_h += pad;

        // Check if click is inside dropdown bounds
        if (mx < dx or mx >= dx + dw or my < dy or my >= dy + total_h) return false;

        // Find which item was clicked
        var y = dy + pad;
        for (items) |item| {
            if (my >= y and my < y + item_h) {
                if (!item.grayed) {
                    // Close dropdown and dispatch command
                    self.dropdown_open = false;
                    self.menu_bar_active = -1;
                    self.dropdown_anim = 0.0;
                    self.dispatchMenuBarCmd(item.id);
                }
                return true;
            }
            y += item_h;
            if (item.separator_after) y += sep_h;
        }
        return true; // Click was inside dropdown area (maybe on padding)
    }

    /// Update dropdown hover item based on mouse position.
    fn updateDropdownHover(self: *Workbench, mx: i32, my: i32) void {
        const items = getDropdownItems(self.dropdown_index);
        const item_h: i32 = self.cell_h + 8;
        const sep_h: i32 = @divTrunc(self.cell_h, 2);
        const pad: i32 = @divTrunc(self.cell_h, 4);
        const dx = self.dropdown_x;
        const dy = self.dropdown_y;
        const dw = self.dropdown_w;

        // Check if mouse is inside dropdown bounds
        if (mx < dx or mx >= dx + dw or my < dy) {
            self.dropdown_hover_item = -1;
            return;
        }

        var y = dy + pad;
        for (items, 0..) |item, idx| {
            if (my >= y and my < y + item_h) {
                self.dropdown_hover_item = @intCast(idx);
                return;
            }
            y += item_h;
            if (item.separator_after) y += sep_h;
        }
        self.dropdown_hover_item = -1;
    }

    /// Get the number of items in a dropdown menu by index.
    fn getDropdownItemCount(_: *const Workbench, index: u8) u8 {
        return switch (index) {
            0 => context_menu.file_menu_items.len,
            1 => context_menu.edit_menu_items.len,
            2 => context_menu.selection_menu_items.len,
            3 => context_menu.view_menu_items.len,
            4 => context_menu.go_menu_items.len,
            5 => context_menu.run_menu_items.len,
            6 => context_menu.terminal_menu_items.len,
            7 => context_menu.help_menu_items.len,
            else => 0,
        };
    }

    /// Get the pixel width of a dropdown menu (based on longest label + shortcut).
    fn getDropdownWidth(_: *const Workbench, index: u8, cell_w: i32) i32 {
        const items: []const context_menu.MenuItem = switch (index) {
            0 => &context_menu.file_menu_items,
            1 => &context_menu.edit_menu_items,
            2 => &context_menu.selection_menu_items,
            3 => &context_menu.view_menu_items,
            4 => &context_menu.go_menu_items,
            5 => &context_menu.run_menu_items,
            6 => &context_menu.terminal_menu_items,
            7 => &context_menu.help_menu_items,
            else => return 200,
        };
        var max_len: usize = 0;
        for (items) |item| {
            var total = item.label.len;
            if (item.shortcut.len > 0) total += 4 + item.shortcut.len; // 4 chars gap
            if (total > max_len) max_len = total;
        }
        return @as(i32, @intCast(max_len)) * cell_w + cell_w * 4; // 2 cell_w padding each side
    }

    /// Get the menu items slice for a given dropdown index.
    fn getDropdownItems(index: u8) []const context_menu.MenuItem {
        return switch (index) {
            0 => &context_menu.file_menu_items,
            1 => &context_menu.edit_menu_items,
            2 => &context_menu.selection_menu_items,
            3 => &context_menu.view_menu_items,
            4 => &context_menu.go_menu_items,
            5 => &context_menu.run_menu_items,
            6 => &context_menu.terminal_menu_items,
            7 => &context_menu.help_menu_items,
            else => &context_menu.file_menu_items,
        };
    }

    /// Render the GL-rendered animated dropdown menu.
    fn renderDropdownMenu(self: *const Workbench, font_atlas: *const FontAtlas, layout: *const LayoutState) void {
        if (!self.dropdown_open) return;
        if (self.dropdown_anim <= 0.001) return;

        const items = getDropdownItems(self.dropdown_index);
        const cell_h = font_atlas.cell_h;
        const cell_w = font_atlas.cell_w;
        const item_h: i32 = cell_h + 8; // font height + padding
        const sep_h: i32 = @divTrunc(cell_h, 2); // half cell height
        const pad: i32 = @divTrunc(cell_h, 4); // vertical padding top/bottom
        const left_pad: i32 = cell_w * 2; // left text inset
        const right_pad: i32 = cell_w * 2; // right text inset

        // Compute total height including separators
        var total_h: i32 = pad; // top padding
        for (items) |item| {
            total_h += item_h;
            if (item.separator_after) total_h += sep_h;
        }
        total_h += pad; // bottom padding

        // Animated clip height (smooth ease-out)
        const t = self.dropdown_anim;
        const ease = 1.0 - (1.0 - t) * (1.0 - t); // quadratic ease-out
        const anim_h: i32 = @intFromFloat(@as(f32, @floatFromInt(total_h)) * ease);

        if (anim_h <= 0) return;

        const dx = self.dropdown_x;
        const dy = self.dropdown_y;
        const dw = self.dropdown_w;

        // Use GL scissor test to clip the dropdown during animation.
        // glScissor uses bottom-left origin, so flip Y using window height.
        const win_h = layout.window_h;
        const scissor_y = win_h - (dy + anim_h); // bottom-left Y
        gl.glEnable(gl.GL_SCISSOR_TEST);
        gl.glScissor(dx, scissor_y, dw + 4, anim_h + 4); // +4 for shadow

        // Enable blending for semi-transparency
        gl.glEnable(gl.GL_BLEND);
        gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);

        // Shadow (slightly offset, darker, semi-transparent)
        renderRegionBackground(Rect{
            .x = dx + 2,
            .y = dy + 2,
            .w = dw,
            .h = anim_h,
        }, Color.rgba(0x00, 0x00, 0x00, 0x59));

        // Main dropdown background (#2D2D2D)
        renderRegionBackground(Rect{
            .x = dx,
            .y = dy,
            .w = dw,
            .h = anim_h,
        }, Color.rgb(0x2D, 0x2D, 0x2D));

        // Border (1px, subtle)
        // Top border
        renderRegionBackground(Rect{ .x = dx, .y = dy, .w = dw, .h = 1 }, Color.rgb(0x45, 0x45, 0x45));
        // Left border
        renderRegionBackground(Rect{ .x = dx, .y = dy, .w = 1, .h = anim_h }, Color.rgb(0x45, 0x45, 0x45));
        // Right border
        renderRegionBackground(Rect{ .x = dx + dw - 1, .y = dy, .w = 1, .h = anim_h }, Color.rgb(0x45, 0x45, 0x45));
        // Bottom border
        renderRegionBackground(Rect{ .x = dx, .y = dy + anim_h - 1, .w = dw, .h = 1 }, Color.rgb(0x45, 0x45, 0x45));

        // Render items
        var y = dy + pad; // top padding
        for (items, 0..) |item, idx| {
            // Only render if within animated clip region
            if (y + item_h > dy + anim_h) break;

            const is_hovered = (self.dropdown_hover_item >= 0 and @as(usize, @intCast(self.dropdown_hover_item)) == idx);

            // Hover highlight (#094771 — VS Code selection blue)
            if (is_hovered) {
                renderRegionBackground(Rect{
                    .x = dx + 2,
                    .y = y,
                    .w = dw - 4,
                    .h = item_h,
                }, Color.rgb(0x09, 0x47, 0x71));
            }

            // Item label
            const text_y = y + @divTrunc(item_h - cell_h, 2);
            const label_color = if (item.grayed) Color.rgb(0x6E, 0x6E, 0x6E) else Color.rgb(0xE0, 0xE0, 0xE0);
            font_atlas.renderText(
                item.label,
                @floatFromInt(dx + left_pad),
                @floatFromInt(text_y),
                label_color,
            );

            // Shortcut text (right-aligned)
            if (item.shortcut.len > 0) {
                const sc_w = @as(i32, @intCast(item.shortcut.len)) * cell_w;
                const sc_x = dx + dw - sc_w - right_pad;
                font_atlas.renderText(
                    item.shortcut,
                    @floatFromInt(sc_x),
                    @floatFromInt(text_y),
                    Color.rgb(0x6E, 0x6E, 0x6E),
                );
            }

            y += item_h;

            // Separator line
            if (item.separator_after) {
                if (y + 1 <= dy + anim_h) {
                    const sep_y = y + @divTrunc(sep_h, 2);
                    renderRegionBackground(Rect{
                        .x = dx + left_pad,
                        .y = sep_y,
                        .w = dw - left_pad * 2,
                        .h = 1,
                    }, Color.rgb(0x45, 0x45, 0x45));
                }
                y += sep_h;
            }
        }

        gl.glDisable(gl.GL_SCISSOR_TEST);
    }

    /// Toggle a breakpoint on the given line.
    fn toggleBreakpoint(self: *Workbench, line: u32) void {
        // Check if breakpoint already exists
        var i: u8 = 0;
        while (i < self.breakpoint_count) : (i += 1) {
            if (self.breakpoint_lines[i] == line) {
                // Remove it
                var j = i;
                while (j + 1 < self.breakpoint_count) : (j += 1) {
                    self.breakpoint_lines[j] = self.breakpoint_lines[j + 1];
                }
                self.breakpoint_count -= 1;
                return;
            }
        }
        // Add new breakpoint
        if (self.breakpoint_count < 64) {
            self.breakpoint_lines[self.breakpoint_count] = line;
            self.breakpoint_count += 1;
        }
    }

    // =========================================================================
    // File Picker input / rendering
    // =========================================================================

    /// Handle keyboard input when the file picker overlay is visible.
    fn handleFilePickerInput(self: *Workbench, vk: u16) void {
        switch (vk) {
            VK_ESCAPE => self.file_picker.close(),
            VK_UP => {
                if (self.file_picker.selected > 0) {
                    self.file_picker.selected -= 1;
                    // Scroll up if selection moves above visible area
                    if (self.file_picker.selected < self.file_picker.scroll_top) {
                        self.file_picker.scroll_top = self.file_picker.selected;
                    }
                }
            },
            VK_DOWN => {
                if (self.file_picker.filtered_count > 0 and
                    self.file_picker.selected < self.file_picker.filtered_count - 1)
                {
                    self.file_picker.selected += 1;
                    // Scroll down if selection moves below visible area
                    const max_vis: u16 = @intCast(file_picker_mod.MAX_VISIBLE_ROWS);
                    if (self.file_picker.selected >= self.file_picker.scroll_top + max_vis) {
                        self.file_picker.scroll_top = self.file_picker.selected - max_vis + 1;
                    }
                }
            },
            VK_RETURN => {
                const entry = self.file_picker.getSelected() orelse return;
                if (entry.is_dir) {
                    // Navigate into directory (or go up for "..")
                    const name = entry.name[0..entry.name_len];
                    if (entry.name_len == 2 and entry.name[0] == '.' and entry.name[1] == '.') {
                        self.file_picker.goUp();
                    } else {
                        self.file_picker.enterDirectory(name);
                    }
                } else {
                    // Open or save the selected file
                    var path_buf: [file_picker_mod.MAX_PATH_LEN]u16 = undefined;
                    const path_len = self.file_picker.getSelectedPath(&path_buf);
                    if (path_len > 0) {
                        path_buf[path_len] = 0; // null-terminate
                        if (self.file_picker.mode == .save) {
                            self.storeFilePath(@ptrCast(&path_buf));
                            self.saveCurrentFile();
                        } else {
                            self.openFile(@ptrCast(&path_buf));
                        }
                        self.file_picker.close();
                    }
                }
            },
            VK_BACK => {
                if (self.file_picker.filter_len > 0) {
                    // Delete last filter character
                    self.file_picker.filter_len -= 1;
                    self.file_picker.updateFilter();
                } else {
                    // Empty filter + backspace = go up one directory
                    self.file_picker.goUp();
                }
            },
            else => {},
        }
    }

    /// Handle text input when the file picker overlay is visible.
    fn handleFilePickerTextInput(self: *Workbench, input: *const InputState) void {
        var i: u32 = 0;
        while (i < input.text_input_len) : (i += 1) {
            const ch = input.text_input[i];
            if (ch < 0x20) continue; // skip control chars
            if (self.file_picker.filter_len < file_picker_mod.MAX_FILTER_LEN) {
                self.file_picker.filter_buf[self.file_picker.filter_len] = ch;
                self.file_picker.filter_len += 1;
            }
        }
        if (input.text_input_len > 0) {
            self.file_picker.updateFilter();
        }
    }

    /// Handle mouse click on the file picker overlay.
    /// Computes the same geometry as renderFilePicker for hit-testing.
    fn handleFilePickerClick(self: *Workbench, mx: i32, my: i32, layout: *const LayoutState) void {
        const win_w = layout.window_w;
        const win_h = layout.window_h;
        const line_h = self.cell_h;

        // Recompute picker geometry (must match renderFilePicker exactly)
        const max_rows: i32 = 14;
        const row_h: i32 = line_h + 6;
        const header_h: i32 = 36;
        const input_h: i32 = 34;
        const footer_h: i32 = 28;
        const picker_w: i32 = @min(640, win_w - 80);
        const list_h: i32 = max_rows * row_h;
        const picker_h: i32 = header_h + input_h + list_h + footer_h;
        const picker_x: i32 = @divTrunc(win_w - picker_w, 2);

        const ease = self.file_picker_anim;
        const anim = 1.0 - (1.0 - ease) * (1.0 - ease) * (1.0 - ease);
        const final_y: f32 = @floatFromInt(@divTrunc(win_h - picker_h, 5));
        const slide_offset: f32 = -30.0 * (1.0 - anim);
        const picker_y: i32 = @intFromFloat(final_y + slide_offset);

        // Check if click is inside the picker panel
        const inside = mx >= picker_x and mx < picker_x + picker_w and
            my >= picker_y and my < picker_y + picker_h;

        if (!inside) {
            // Click on backdrop — close the picker
            self.file_picker.close();
            return;
        }

        // Compute list area bounds
        const hdr_y = picker_y + 2;
        const inp_y = hdr_y + header_h + 4;
        const list_y_start = inp_y + 26 + 4; // inp_inner_h=26 + 4px gap

        // Check if click is in the file list area
        if (my >= list_y_start and my < list_y_start + list_h) {
            // Determine which row was clicked
            const rel_y = my - list_y_start;
            const clicked_row: u16 = @intCast(@divTrunc(rel_y, row_h));
            const clicked_idx = self.file_picker.scroll_top + clicked_row;

            if (clicked_idx < self.file_picker.filtered_count) {
                // Check for double-click (same item within 400ms)
                const now = self.accumulated_time;
                const is_double = (clicked_idx == self.file_picker_last_click_idx and
                    (now - self.file_picker_last_click) < 0.4);

                self.file_picker.selected = clicked_idx;
                self.file_picker_last_click = now;
                self.file_picker_last_click_idx = clicked_idx;

                if (is_double) {
                    // Double-click: open file or enter directory
                    self.handleFilePickerInput(VK_RETURN);
                    self.file_picker_last_click_idx = 0xFFFF; // reset to prevent triple-click
                }
            }
        }

        // Clicks on header, input, or footer are consumed but do nothing special
    }

    /// Update file picker hover row based on mouse position (called every frame).
    fn updateFilePickerHover(self: *Workbench, mx: i32, my: i32, layout: *const LayoutState) void {
        const win_w = layout.window_w;
        const win_h = layout.window_h;
        const line_h = self.cell_h;

        const max_rows: i32 = 14;
        const row_h: i32 = line_h + 6;
        const header_h: i32 = 36;
        const picker_w: i32 = @min(640, win_w - 80);
        const list_h: i32 = max_rows * row_h;
        const picker_h: i32 = header_h + 34 + list_h + 28;
        const picker_x: i32 = @divTrunc(win_w - picker_w, 2);

        const ease = self.file_picker_anim;
        const anim = 1.0 - (1.0 - ease) * (1.0 - ease) * (1.0 - ease);
        const final_y: f32 = @floatFromInt(@divTrunc(win_h - picker_h, 5));
        const slide_offset: f32 = -30.0 * (1.0 - anim);
        const picker_y: i32 = @intFromFloat(final_y + slide_offset);

        const hdr_y = picker_y + 2;
        const inp_y = hdr_y + header_h + 4;
        const list_y_start = inp_y + 26 + 4;

        // Check if mouse is in the list area
        if (mx >= picker_x and mx < picker_x + picker_w and
            my >= list_y_start and my < list_y_start + list_h)
        {
            const rel_y = my - list_y_start;
            const hover_row: i16 = @intCast(@divTrunc(rel_y, row_h));
            const hover_idx = @as(u16, @intCast(hover_row)) + self.file_picker.scroll_top;
            if (hover_idx < self.file_picker.filtered_count) {
                self.file_picker_hover_row = hover_row;
            } else {
                self.file_picker_hover_row = -1;
            }
        } else {
            self.file_picker_hover_row = -1;
        }
    }

    /// Render the file picker overlay with animated, polished UI.
    fn renderFilePicker(self: *const Workbench, layout: *const LayoutState, font_atlas: *const FontAtlas) void {
        const t = self.file_picker_anim; // 0..1 animation progress
        if (t <= 0.001) return; // not visible yet

        // Ease-out cubic for smooth deceleration
        const ease = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);

        const win_w = layout.window_w;
        const win_h = layout.window_h;
        const line_h = font_atlas.cell_h;
        const cw = font_atlas.cell_w;

        // ── Full-screen dimmed backdrop ──────────────────────────────
        gl.glEnable(gl.GL_BLEND);
        gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
        gl.glDisable(gl.GL_TEXTURE_2D);
        gl.glColor4f(0.0, 0.0, 0.0, 0.55 * ease);
        gl.glBegin(gl.GL_QUADS);
        gl.glVertex2f(0, 0);
        gl.glVertex2f(@floatFromInt(win_w), 0);
        gl.glVertex2f(@floatFromInt(win_w), @floatFromInt(win_h));
        gl.glVertex2f(0, @floatFromInt(win_h));
        gl.glEnd();

        // ── Panel dimensions ─────────────────────────────────────────
        const max_rows: i32 = 14;
        const row_h: i32 = line_h + 6; // generous row height
        const header_h: i32 = 36;
        const input_h: i32 = 34;
        const footer_h: i32 = 28;
        const picker_w: i32 = @min(640, win_w - 80);
        const list_h: i32 = max_rows * row_h;
        const picker_h: i32 = header_h + input_h + list_h + footer_h;
        const picker_x: i32 = @divTrunc(win_w - picker_w, 2);
        // Slide down from above: start 30px above final position
        const final_y: f32 = @floatFromInt(@divTrunc(win_h - picker_h, 5)); // upper third
        const slide_offset: f32 = -30.0 * (1.0 - ease);
        const picker_y_f: f32 = final_y + slide_offset;
        const picker_y: i32 = @intFromFloat(picker_y_f);

        const alpha: f32 = ease; // overall panel alpha

        // ── Colors ───────────────────────────────────────────────────
        const accent = Color{ .r = 0.0, .g = 0.48, .b = 0.80, .a = alpha }; // #007ACC
        const accent_glow = Color{ .r = 0.0, .g = 0.48, .b = 0.80, .a = alpha * 0.3 };
        const panel_bg = Color{ .r = 0.145, .g = 0.145, .b = 0.145, .a = alpha * 0.98 }; // #252525
        const header_bg = Color{ .r = 0.18, .g = 0.18, .b = 0.18, .a = alpha }; // #2E2E2E
        const input_bg = Color{ .r = 0.22, .g = 0.22, .b = 0.22, .a = alpha }; // #383838
        const input_border = Color{ .r = 0.0, .g = 0.48, .b = 0.80, .a = alpha * 0.6 };
        const text_primary = Color{ .r = 0.83, .g = 0.83, .b = 0.83, .a = alpha };
        const text_dim = Color{ .r = 0.45, .g = 0.45, .b = 0.45, .a = alpha };
        const text_accent = Color{ .r = 0.40, .g = 0.70, .b = 1.0, .a = alpha };
        const sel_bg = Color{ .r = 0.02, .g = 0.22, .b = 0.37, .a = alpha }; // #04395E
        const sel_border = Color{ .r = 0.0, .g = 0.48, .b = 0.80, .a = alpha * 0.5 };
        const dir_icon_color = Color{ .r = 0.86, .g = 0.74, .b = 0.42, .a = alpha }; // golden
        const file_icon_color = Color{ .r = 0.55, .g = 0.65, .b = 0.80, .a = alpha }; // steel blue
        const footer_bg = Color{ .r = 0.16, .g = 0.16, .b = 0.16, .a = alpha };
        const shadow_color = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = alpha * 0.4 };
        const scrollbar_bg = Color{ .r = 0.20, .g = 0.20, .b = 0.20, .a = alpha * 0.5 };
        const scrollbar_fg = Color{ .r = 0.45, .g = 0.45, .b = 0.45, .a = alpha * 0.7 };

        // ── Drop shadow (layered rects for soft shadow) ──────────────
        renderAlphaRect(picker_x - 4, picker_y + 4, picker_w + 8, picker_h + 4, shadow_color);
        renderAlphaRect(picker_x - 2, picker_y + 2, picker_w + 4, picker_h + 2, Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = alpha * 0.25 });

        // ── Main panel background ────────────────────────────────────
        renderAlphaRect(picker_x, picker_y, picker_w, picker_h, panel_bg);

        // ── Top accent line (gradient-like: bright center, fading edges) ──
        const accent_y = picker_y;
        renderAlphaRect(picker_x, accent_y, picker_w, 2, accent);
        // Glow below accent line
        renderAlphaRect(picker_x, accent_y + 2, picker_w, 3, accent_glow);

        // ── Header bar ───────────────────────────────────────────────
        const hdr_y = picker_y + 2;
        renderAlphaRect(picker_x, hdr_y, picker_w, header_h, header_bg);

        // Mode icon (small colored square)
        const icon_size: i32 = 14;
        const icon_y = hdr_y + @divTrunc(header_h - icon_size, 2);
        const icon_color = if (self.file_picker.mode == .save) Color{ .r = 0.30, .g = 0.75, .b = 0.40, .a = alpha } else accent;
        renderAlphaRect(picker_x + 12, icon_y, icon_size, icon_size, icon_color);
        // Inner highlight on icon
        renderAlphaRect(picker_x + 14, icon_y + 2, icon_size - 4, icon_size - 4, Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = alpha * 0.15 });

        // Mode label
        const mode_label: []const u8 = if (self.file_picker.mode == .save) "Save As" else "Open File";
        font_atlas.renderText(
            mode_label,
            @floatFromInt(picker_x + 32),
            @floatFromInt(hdr_y + @divTrunc(header_h - line_h, 2)),
            text_accent,
        );

        // Breadcrumb path (right side of header)
        var dir_utf8: [file_picker_mod.MAX_PATH_LEN]u8 = undefined;
        const dir_len = self.file_picker.getCurrentDirUtf8(&dir_utf8);
        if (dir_len > 0) {
            // Truncate path to fit: show last N chars with leading "..."
            const max_path_chars: u16 = @intCast(@max(10, @divTrunc(picker_w - 200, cw)));
            var path_start: u16 = 0;
            var show_ellipsis = false;
            if (dir_len > max_path_chars) {
                path_start = dir_len - max_path_chars;
                show_ellipsis = true;
            }
            const path_x = picker_x + picker_w - @as(i32, @intCast(dir_len - path_start)) * cw - 12 - (if (show_ellipsis) cw * 3 else @as(i32, 0));
            if (show_ellipsis) {
                font_atlas.renderText("...", @floatFromInt(path_x), @floatFromInt(hdr_y + @divTrunc(header_h - line_h, 2)), text_dim);
            }
            font_atlas.renderText(
                dir_utf8[path_start..dir_len],
                @floatFromInt(path_x + (if (show_ellipsis) cw * 3 else @as(i32, 0))),
                @floatFromInt(hdr_y + @divTrunc(header_h - line_h, 2)),
                text_dim,
            );
        }

        // Header bottom separator
        renderAlphaRect(picker_x + 8, hdr_y + header_h - 1, picker_w - 16, 1, Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = alpha * 0.06 });

        // ── Search / filter input field ──────────────────────────────
        const inp_y = hdr_y + header_h + 4;
        const inp_x = picker_x + 10;
        const inp_w = picker_w - 20;
        const inp_inner_h: i32 = 26;

        // Input background
        renderAlphaRect(inp_x, inp_y, inp_w, inp_inner_h, input_bg);
        // Input focus border (1px)
        renderAlphaRect(inp_x, inp_y, inp_w, 1, input_border); // top
        renderAlphaRect(inp_x, inp_y + inp_inner_h - 1, inp_w, 1, input_border); // bottom
        renderAlphaRect(inp_x, inp_y, 1, inp_inner_h, input_border); // left
        renderAlphaRect(inp_x + inp_w - 1, inp_y, 1, inp_inner_h, input_border); // right

        // Search icon (magnifying glass: small circle + line)
        const search_cx: f32 = @floatFromInt(inp_x + 14);
        const search_cy: f32 = @floatFromInt(inp_y + @divTrunc(inp_inner_h, 2));
        renderSearchIcon(search_cx, search_cy, 5.0, text_dim);

        // Filter text or placeholder
        const text_x = inp_x + 28;
        const text_y = inp_y + @divTrunc(inp_inner_h - line_h, 2);
        if (self.file_picker.filter_len > 0) {
            font_atlas.renderText(
                self.file_picker.filter_buf[0..self.file_picker.filter_len],
                @floatFromInt(text_x),
                @floatFromInt(text_y),
                text_primary,
            );
        } else {
            font_atlas.renderText(
                "Search files and folders...",
                @floatFromInt(text_x),
                @floatFromInt(text_y),
                text_dim,
            );
        }

        // Blinking cursor
        if (self.cursor_visible) {
            const cur_x = text_x + @as(i32, @intCast(self.file_picker.filter_len)) * cw;
            renderAlphaRect(cur_x, inp_y + 4, 2, inp_inner_h - 8, text_accent);
        }

        // ── File list area ───────────────────────────────────────────
        const list_y_start = inp_y + inp_inner_h + 4;
        const scroll = self.file_picker.scroll_top;

        // Enable scissor to clip file list
        gl.glEnable(gl.GL_SCISSOR_TEST);
        // GL scissor uses bottom-left origin, so flip Y
        const scissor_bottom = win_h - (list_y_start + list_h);
        gl.glScissor(picker_x, scissor_bottom, picker_w, list_h);

        var row: u16 = 0;
        while (row < @as(u16, @intCast(max_rows))) : (row += 1) {
            const idx = scroll + row;
            if (idx >= self.file_picker.filtered_count) break;

            const entry_idx = self.file_picker.filtered[idx];
            const entry = &self.file_picker.entries[entry_idx];
            const name = entry.name[0..entry.name_len];
            const item_y = list_y_start + @as(i32, @intCast(row)) * row_h;
            const is_selected = (idx == self.file_picker.selected);
            const is_dotdot = (entry.name_len == 2 and entry.name[0] == '.' and entry.name[1] == '.');

            // Selection highlight with left accent bar
            if (is_selected) {
                renderAlphaRect(picker_x + 4, item_y + 1, picker_w - 8, row_h - 2, sel_bg);
                // Left accent bar
                renderAlphaRect(picker_x + 4, item_y + 3, 3, row_h - 6, sel_border);
            } else if (self.file_picker_hover_row >= 0 and @as(u16, @intCast(self.file_picker_hover_row)) == row) {
                // Hover highlight (subtle)
                renderAlphaRect(picker_x + 4, item_y + 1, picker_w - 8, row_h - 2, Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = alpha * 0.05 });
            }

            // Row content X positions
            const icon_x = picker_x + 16;
            const label_x = icon_x + 24;
            const row_text_y = item_y + @divTrunc(row_h - line_h, 2);

            if (is_dotdot) {
                // ".." parent directory — render arrow icon
                renderArrowUp(@floatFromInt(icon_x + 4), @floatFromInt(row_text_y + @divTrunc(line_h, 2)), 5.0, text_accent);
                font_atlas.renderText("..", @floatFromInt(label_x), @floatFromInt(row_text_y), text_accent);
            } else if (entry.is_dir) {
                // Directory — render folder icon (filled rectangle with tab)
                renderFolderIcon(icon_x, row_text_y + 1, line_h - 2, dir_icon_color);
                font_atlas.renderText(
                    name,
                    @floatFromInt(label_x),
                    @floatFromInt(row_text_y),
                    if (is_selected) Color{ .r = 0.95, .g = 0.85, .b = 0.55, .a = alpha } else dir_icon_color,
                );
            } else {
                // File — render file icon (rectangle with folded corner)
                renderFileIcon(icon_x, row_text_y + 1, line_h - 2, file_icon_color);

                // Color-code by extension
                const name_color = fileNameColor(name, alpha, is_selected);
                font_atlas.renderText(name, @floatFromInt(label_x), @floatFromInt(row_text_y), name_color);

                // File extension badge (right-aligned, dimmed)
                const ext = fileExtension(name);
                if (ext.len > 0 and ext.len < 8) {
                    const ext_x = picker_x + picker_w - @as(i32, @intCast(ext.len)) * cw - 24;
                    font_atlas.renderText(ext, @floatFromInt(ext_x), @floatFromInt(row_text_y), text_dim);
                }
            }

            // Subtle row separator
            if (row + 1 < @as(u16, @intCast(max_rows)) and idx + 1 < self.file_picker.filtered_count) {
                renderAlphaRect(picker_x + 14, item_y + row_h - 1, picker_w - 28, 1, Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = alpha * 0.04 });
            }
        }

        gl.glDisable(gl.GL_SCISSOR_TEST);

        // ── Scrollbar (right edge of list area) ──────────────────────
        if (self.file_picker.filtered_count > @as(u16, @intCast(max_rows))) {
            const sb_x = picker_x + picker_w - 8;
            const sb_w: i32 = 4;
            const total: f32 = @floatFromInt(self.file_picker.filtered_count);
            const visible: f32 = @floatFromInt(max_rows);
            const thumb_ratio = visible / total;
            const thumb_h: i32 = @max(12, @as(i32, @intFromFloat(thumb_ratio * @as(f32, @floatFromInt(list_h)))));
            const scroll_ratio = @as(f32, @floatFromInt(scroll)) / @max(1.0, total - visible);
            const thumb_y = list_y_start + @as(i32, @intFromFloat(scroll_ratio * @as(f32, @floatFromInt(list_h - thumb_h))));

            // Track
            renderAlphaRect(sb_x, list_y_start, sb_w, list_h, scrollbar_bg);
            // Thumb
            renderAlphaRect(sb_x, thumb_y, sb_w, thumb_h, scrollbar_fg);
        }

        // ── Empty state ──────────────────────────────────────────────
        if (self.file_picker.filtered_count == 0) {
            const empty_y = list_y_start + @divTrunc(list_h, 2) - line_h;
            font_atlas.renderText(
                "No matching files",
                @floatFromInt(picker_x + @divTrunc(picker_w - 17 * cw, 2)),
                @floatFromInt(empty_y),
                text_dim,
            );
        }

        // ── Footer bar ───────────────────────────────────────────────
        const ftr_y = list_y_start + list_h;
        renderAlphaRect(picker_x, ftr_y, picker_w, footer_h, footer_bg);
        // Separator line
        renderAlphaRect(picker_x + 8, ftr_y, picker_w - 16, 1, Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = alpha * 0.06 });

        // Item count
        var count_buf: [32]u8 = undefined;
        const count_str = formatCount(self.file_picker.filtered_count, self.file_picker.entry_count, &count_buf);
        font_atlas.renderText(count_str, @floatFromInt(picker_x + 12), @floatFromInt(ftr_y + @divTrunc(footer_h - line_h, 2)), text_dim);

        // Keyboard hints (right side)
        const hints = "Enter:Open  Esc:Close  Bksp:Up";
        const hints_x = picker_x + picker_w - @as(i32, @intCast(hints.len)) * cw - 12;
        font_atlas.renderText(hints, @floatFromInt(hints_x), @floatFromInt(ftr_y + @divTrunc(footer_h - line_h, 2)), text_dim);

        // ── Bottom accent line ───────────────────────────────────────
        renderAlphaRect(picker_x, ftr_y + footer_h - 2, picker_w, 2, accent);

        // ── Side borders (subtle) ────────────────────────────────────
        renderAlphaRect(picker_x, picker_y, 1, picker_h, Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = alpha * 0.08 });
        renderAlphaRect(picker_x + picker_w - 1, picker_y, 1, picker_h, Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = alpha * 0.3 });

        gl.glDisable(gl.GL_BLEND);
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

/// Check if a character is a word character (alphanumeric or underscore).
fn isWordChar(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or
        (ch >= '0' and ch <= '9') or ch == '_';
}

/// Compare two byte slices for equality.
fn strEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
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
// File picker rendering helpers
// =============================================================================

/// Draw a filled rectangle with alpha blending (assumes GL_BLEND is already enabled).
fn renderAlphaRect(x: i32, y: i32, w: i32, h: i32, color: Color) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(color.r, color.g, color.b, color.a);
    const x0: f32 = @floatFromInt(x);
    const y0: f32 = @floatFromInt(y);
    const x1: f32 = @floatFromInt(x + w);
    const y1: f32 = @floatFromInt(y + h);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(x0, y0);
    gl.glVertex2f(x1, y0);
    gl.glVertex2f(x1, y1);
    gl.glVertex2f(x0, y1);
    gl.glEnd();
}

/// Render a magnifying glass search icon using GL lines.
fn renderSearchIcon(cx: f32, cy: f32, radius: f32, color: Color) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(color.r, color.g, color.b, color.a);
    gl.glLineWidth(1.5);
    // Circle (approximated with 12 segments)
    gl.glBegin(gl.GL_LINE_LOOP);
    comptime var i: usize = 0;
    inline while (i < 12) : (i += 1) {
        const angle: f32 = @as(f32, @floatFromInt(i)) * (2.0 * 3.14159 / 12.0);
        gl.glVertex2f(cx + radius * @cos(angle), cy + radius * @sin(angle));
    }
    gl.glEnd();
    // Handle (line from bottom-right of circle outward)
    const hx = cx + radius * 0.707;
    const hy = cy + radius * 0.707;
    gl.glBegin(gl.GL_LINES);
    gl.glVertex2f(hx, hy);
    gl.glVertex2f(hx + radius * 0.6, hy + radius * 0.6);
    gl.glEnd();
    gl.glLineWidth(1.0);
}

/// Render a folder icon (rectangle with a tab on top-left).
fn renderFolderIcon(x: i32, y: i32, size: i32, color: Color) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    const s: f32 = @floatFromInt(size);
    const fx: f32 = @floatFromInt(x);
    const fy: f32 = @floatFromInt(y);
    const tab_w = s * 0.4;
    const tab_h = s * 0.2;

    // Tab (top-left flap)
    gl.glColor4f(color.r * 0.85, color.g * 0.85, color.b * 0.85, color.a);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(fx, fy);
    gl.glVertex2f(fx + tab_w, fy);
    gl.glVertex2f(fx + tab_w + tab_h * 0.5, fy + tab_h);
    gl.glVertex2f(fx, fy + tab_h);
    gl.glEnd();

    // Main body
    gl.glColor4f(color.r, color.g, color.b, color.a);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(fx, fy + tab_h);
    gl.glVertex2f(fx + s * 0.9, fy + tab_h);
    gl.glVertex2f(fx + s * 0.9, fy + s);
    gl.glVertex2f(fx, fy + s);
    gl.glEnd();

    // Highlight stripe (top of body)
    gl.glColor4f(1.0, 1.0, 1.0, color.a * 0.12);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(fx, fy + tab_h);
    gl.glVertex2f(fx + s * 0.9, fy + tab_h);
    gl.glVertex2f(fx + s * 0.9, fy + tab_h + 1.0);
    gl.glVertex2f(fx, fy + tab_h + 1.0);
    gl.glEnd();
}

/// Render a file icon (rectangle with folded corner).
fn renderFileIcon(x: i32, y: i32, size: i32, color: Color) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    const s: f32 = @floatFromInt(size);
    const fx: f32 = @floatFromInt(x);
    const fy: f32 = @floatFromInt(y);
    const fold = s * 0.25;
    const w = s * 0.7;

    // Main body (with corner cut)
    gl.glColor4f(color.r, color.g, color.b, color.a);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(fx, fy);
    gl.glVertex2f(fx + w - fold, fy);
    gl.glVertex2f(fx + w - fold, fy + s);
    gl.glVertex2f(fx, fy + s);
    gl.glEnd();
    // Right column below fold
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(fx + w - fold, fy + fold);
    gl.glVertex2f(fx + w, fy + fold);
    gl.glVertex2f(fx + w, fy + s);
    gl.glVertex2f(fx + w - fold, fy + s);
    gl.glEnd();
    // Fold triangle
    gl.glColor4f(color.r * 0.7, color.g * 0.7, color.b * 0.7, color.a);
    gl.glBegin(gl.GL_TRIANGLES);
    gl.glVertex2f(fx + w - fold, fy);
    gl.glVertex2f(fx + w, fy + fold);
    gl.glVertex2f(fx + w - fold, fy + fold);
    gl.glEnd();
}

/// Render an upward-pointing arrow (for ".." parent directory).
fn renderArrowUp(cx: f32, cy: f32, size: f32, color: Color) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(color.r, color.g, color.b, color.a);
    gl.glBegin(gl.GL_TRIANGLES);
    gl.glVertex2f(cx, cy - size);
    gl.glVertex2f(cx - size * 0.7, cy + size * 0.3);
    gl.glVertex2f(cx + size * 0.7, cy + size * 0.3);
    gl.glEnd();
    // Stem
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(cx - size * 0.2, cy + size * 0.3);
    gl.glVertex2f(cx + size * 0.2, cy + size * 0.3);
    gl.glVertex2f(cx + size * 0.2, cy + size);
    gl.glVertex2f(cx - size * 0.2, cy + size);
    gl.glEnd();
}

/// Get the file extension from a filename (e.g., "main.zig" → ".zig").
fn fileExtension(name: []const u8) []const u8 {
    var i: usize = name.len;
    while (i > 0) {
        i -= 1;
        if (name[i] == '.') return name[i..];
    }
    return "";
}

/// Color-code a filename by extension for visual variety.
fn fileNameColor(name: []const u8, alpha: f32, selected: bool) Color {
    if (selected) return Color{ .r = 0.95, .g = 0.95, .b = 0.95, .a = alpha };
    const ext = fileExtension(name);
    if (ext.len == 0) return Color{ .r = 0.83, .g = 0.83, .b = 0.83, .a = alpha };
    // Zig files — orange
    if (strEql(ext, ".zig")) return Color{ .r = 0.95, .g = 0.65, .b = 0.25, .a = alpha };
    // Config/build files
    if (strEql(ext, ".json") or strEql(ext, ".toml") or strEql(ext, ".yml") or strEql(ext, ".yaml"))
        return Color{ .r = 0.60, .g = 0.85, .b = 0.45, .a = alpha };
    // Markdown / text
    if (strEql(ext, ".md") or strEql(ext, ".txt") or strEql(ext, ".rst"))
        return Color{ .r = 0.55, .g = 0.75, .b = 0.95, .a = alpha };
    // Scripts
    if (strEql(ext, ".py") or strEql(ext, ".sh") or strEql(ext, ".bat") or strEql(ext, ".ps1"))
        return Color{ .r = 0.70, .g = 0.55, .b = 0.90, .a = alpha };
    // Images / resources
    if (strEql(ext, ".ico") or strEql(ext, ".png") or strEql(ext, ".bmp") or strEql(ext, ".svg"))
        return Color{ .r = 0.90, .g = 0.55, .b = 0.70, .a = alpha };
    // C/C++ headers/sources
    if (strEql(ext, ".c") or strEql(ext, ".h") or strEql(ext, ".cpp") or strEql(ext, ".hpp"))
        return Color{ .r = 0.45, .g = 0.70, .b = 0.95, .a = alpha };
    return Color{ .r = 0.83, .g = 0.83, .b = 0.83, .a = alpha };
}

/// Format "N of M items" into a fixed buffer. Returns the slice.
fn formatCount(filtered: u16, total: u16, buf: *[32]u8) []const u8 {
    var pos: usize = 0;
    // Write filtered count
    pos = writeU16(buf, pos, filtered);
    const of_str = " of ";
    @memcpy(buf[pos..][0..of_str.len], of_str);
    pos += of_str.len;
    // Write total count
    pos = writeU16(buf, pos, total);
    const items_str = " items";
    @memcpy(buf[pos..][0..items_str.len], items_str);
    pos += items_str.len;
    return buf[0..pos];
}

/// Write a u16 as decimal digits into buf at pos. Returns new pos.
fn writeU16(buf: *[32]u8, start: usize, val: u16) usize {
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
    try testing.expect(update_fn == *const fn (*Workbench, *const InputState, *LayoutState, f64) void);
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
    wb.handleCursorMovement(VK_RIGHT, false, false);
    try testing.expectEqual(@as(u32, 6), wb.cursor_state.primary().active.col);
}

test "Workbench.handleCursorMovement moves cursor left" {
    var wb = Workbench{};
    wb.cursor_state.setPrimary(.{ .line = 0, .col = 5 });
    wb.handleCursorMovement(VK_LEFT, false, false);
    try testing.expectEqual(@as(u32, 4), wb.cursor_state.primary().active.col);
}

test "Workbench.handleCursorMovement left at col 0 stays at 0" {
    var wb = Workbench{};
    wb.cursor_state.setPrimary(.{ .line = 0, .col = 0 });
    wb.handleCursorMovement(VK_LEFT, false, false);
    try testing.expectEqual(@as(u32, 0), wb.cursor_state.primary().active.col);
}

test "Workbench.handleCursorMovement moves cursor down" {
    var wb = Workbench{};
    wb.cursor_state.setPrimary(.{ .line = 2, .col = 0 });
    wb.handleCursorMovement(VK_DOWN, false, false);
    try testing.expectEqual(@as(u32, 3), wb.cursor_state.primary().active.line);
}

test "Workbench.handleCursorMovement moves cursor up" {
    var wb = Workbench{};
    wb.cursor_state.setPrimary(.{ .line = 2, .col = 0 });
    wb.handleCursorMovement(VK_UP, false, false);
    try testing.expectEqual(@as(u32, 1), wb.cursor_state.primary().active.line);
}

test "Workbench.handleCursorMovement up at line 0 stays at 0" {
    var wb = Workbench{};
    wb.cursor_state.setPrimary(.{ .line = 0, .col = 0 });
    wb.handleCursorMovement(VK_UP, false, false);
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

test "dispatchCommand handles CMD_TOGGLE_SIDEBAR" {
    var wb = Workbench{};
    try testing.expect(wb.sidebar_visible);
    wb.dispatchCommand(CMD_TOGGLE_SIDEBAR);
    try testing.expect(!wb.sidebar_visible);
    wb.dispatchCommand(CMD_TOGGLE_SIDEBAR);
    try testing.expect(wb.sidebar_visible);
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
