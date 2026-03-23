// src/workbench/command_palette.zig — VS Code-style command palette
//
// Comprehensive action registry with fuzzy filtering, categories, and
// keyboard shortcut display. All system actions are registered at init.
// Pure Zig, zero dependencies, zero allocators, stack/comptime only.

/// Fuzzy score a query against a target string.
///
/// Returns -1 if query is not a case-insensitive subsequence of target.
/// Returns score >= 0 otherwise, with bonuses for:
///   - Consecutive character matches
///   - Matches at word boundaries (after '.', '/', '_', '-', ' ', ':')
///   - Exact case matches
pub fn fuzzyScore(query: []const u8, target: []const u8) i32 {
    if (query.len == 0) return 0;
    if (target.len == 0) return -1;

    var qi: usize = 0;
    var score: i32 = 0;
    var consecutive: i32 = 0;
    var prev_match_idx: i32 = -1;

    for (target, 0..) |tc, ti| {
        if (qi >= query.len) break;

        const qc_lower = toLower(query[qi]);
        const tc_lower = toLower(tc);

        if (qc_lower == tc_lower) {
            score += 1;
            if (prev_match_idx == @as(i32, @intCast(ti)) - 1) {
                consecutive += 1;
                score += consecutive * 2;
            } else {
                consecutive = 0;
            }
            if (ti == 0 or isBoundary(target[ti - 1])) {
                score += 5;
            }
            if (query[qi] == tc) {
                score += 1;
            }
            prev_match_idx = @intCast(ti);
            qi += 1;
        }
    }

    if (qi < query.len) return -1;
    return score;
}

fn toLower(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

fn isBoundary(c: u8) bool {
    return c == '.' or c == '/' or c == '_' or c == '-' or c == ' ' or c == ':';
}

// =============================================================================
// Action — a single command/action in the system
// =============================================================================

pub const Action = struct {
    id: u16,
    label: [80]u8 = undefined,
    label_len: u8 = 0,
    shortcut: [32]u8 = undefined,
    shortcut_len: u8 = 0,
    category: Category = .general,
};

pub const Category = enum(u8) {
    file = 0,
    edit = 1,
    selection = 2,
    view = 3,
    go = 4,
    run = 5,
    terminal = 6,
    help = 7,
    editor = 8,
    general = 9,
};

/// Category display names for rendering.
pub const CATEGORY_NAMES = [_][]const u8{
    "File",
    "Edit",
    "Selection",
    "View",
    "Go",
    "Run",
    "Terminal",
    "Help",
    "Editor",
    "General",
};
// =============================================================================
// CommandPalette — zero-allocation action registry with fuzzy filtering
// =============================================================================

pub const CommandPalette = struct {
    pub const MAX_ACTIONS: usize = 256;
    pub const MAX_RESULTS: usize = 50;
    pub const MAX_VISIBLE: usize = 12;

    actions: [MAX_ACTIONS]Action = undefined,
    action_count: usize = 0,

    // Filtered results (indices into actions array, sorted by score)
    filtered_indices: [MAX_RESULTS]usize = undefined,
    filtered_scores: [MAX_RESULTS]i32 = undefined,
    filtered_count: usize = 0,

    // Input state
    input_buf: [256]u8 = undefined,
    input_len: usize = 0,
    selected_index: usize = 0,
    scroll_top: usize = 0,

    // Visibility and animation
    visible: bool = false,
    anim: f32 = 0.0, // 0..1 open animation

    // Mouse hover row (-1 = none)
    hover_row: i16 = -1,

    /// Register an action. Returns false if full.
    pub fn registerAction(self: *CommandPalette, id: u16, label: []const u8, shortcut: []const u8, category: Category) bool {
        if (self.action_count >= MAX_ACTIONS) return false;
        var act = Action{ .id = id, .category = category };
        const llen: u8 = @intCast(@min(label.len, 80));
        @memcpy(act.label[0..llen], label[0..llen]);
        act.label_len = llen;
        const slen: u8 = @intCast(@min(shortcut.len, 32));
        @memcpy(act.shortcut[0..slen], shortcut[0..slen]);
        act.shortcut_len = slen;
        self.actions[self.action_count] = act;
        self.action_count += 1;
        return true;
    }

    /// Convenience: register from comptime MenuItem-like data.
    pub fn reg(self: *CommandPalette, id: u16, label: []const u8, shortcut: []const u8, cat: Category) void {
        _ = self.registerAction(id, label, shortcut, cat);
    }

    /// Update filtered results based on current input.
    pub fn updateFilter(self: *CommandPalette) void {
        self.filtered_count = 0;
        const query = self.input_buf[0..self.input_len];

        if (query.len == 0) {
            // Show all actions up to MAX_RESULTS
            const limit = @min(self.action_count, MAX_RESULTS);
            for (0..limit) |i| {
                self.filtered_indices[i] = i;
                self.filtered_scores[i] = 0;
            }
            self.filtered_count = limit;
        } else {
            // Fuzzy match each action label
            for (0..self.action_count) |i| {
                if (self.filtered_count >= MAX_RESULTS) break;
                const act = &self.actions[i];
                const label = act.label[0..act.label_len];
                const score = fuzzyScore(query, label);
                if (score >= 0) {
                    self.filtered_indices[self.filtered_count] = i;
                    self.filtered_scores[self.filtered_count] = score;
                    self.filtered_count += 1;
                }
            }
            // Insertion sort by score descending
            if (self.filtered_count > 1) {
                var i: usize = 1;
                while (i < self.filtered_count) : (i += 1) {
                    const key_idx = self.filtered_indices[i];
                    const key_score = self.filtered_scores[i];
                    var j: usize = i;
                    while (j > 0 and self.filtered_scores[j - 1] < key_score) : (j -= 1) {
                        self.filtered_indices[j] = self.filtered_indices[j - 1];
                        self.filtered_scores[j] = self.filtered_scores[j - 1];
                    }
                    self.filtered_indices[j] = key_idx;
                    self.filtered_scores[j] = key_score;
                }
            }
        }

        // Clamp selection and scroll
        if (self.filtered_count == 0) {
            self.selected_index = 0;
            self.scroll_top = 0;
        } else {
            if (self.selected_index >= self.filtered_count) {
                self.selected_index = self.filtered_count - 1;
            }
        }
    }

    /// Toggle visibility. When opening, clear input and reset state.
    pub fn toggle(self: *CommandPalette) void {
        self.visible = !self.visible;
        if (self.visible) {
            self.input_len = 0;
            self.selected_index = 0;
            self.scroll_top = 0;
            self.anim = 0.0;
            self.hover_row = -1;
            self.updateFilter();
        }
    }

    /// Open the palette (idempotent).
    pub fn open(self: *CommandPalette) void {
        if (!self.visible) self.toggle();
    }

    /// Close the palette.
    pub fn close(self: *CommandPalette) void {
        self.visible = false;
        self.anim = 0.0;
    }

    /// Get the currently selected action, or null if none.
    pub fn getSelectedAction(self: *const CommandPalette) ?*const Action {
        if (self.filtered_count == 0) return null;
        if (self.selected_index >= self.filtered_count) return null;
        const act_idx = self.filtered_indices[self.selected_index];
        return &self.actions[act_idx];
    }

    /// Move selection up.
    pub fn moveUp(self: *CommandPalette) void {
        if (self.selected_index > 0) {
            self.selected_index -= 1;
            if (self.selected_index < self.scroll_top) {
                self.scroll_top = self.selected_index;
            }
        }
    }

    /// Move selection down.
    pub fn moveDown(self: *CommandPalette) void {
        if (self.filtered_count > 0 and self.selected_index < self.filtered_count - 1) {
            self.selected_index += 1;
            if (self.selected_index >= self.scroll_top + MAX_VISIBLE) {
                self.scroll_top = self.selected_index - MAX_VISIBLE + 1;
            }
        }
    }

    /// Append a character to the input buffer.
    pub fn appendChar(self: *CommandPalette, ch: u8) void {
        if (self.input_len < 256) {
            self.input_buf[self.input_len] = ch;
            self.input_len += 1;
            self.selected_index = 0;
            self.scroll_top = 0;
            self.updateFilter();
        }
    }

    /// Delete the last character from the input buffer.
    pub fn backspace(self: *CommandPalette) void {
        if (self.input_len > 0) {
            self.input_len -= 1;
            self.updateFilter();
        }
    }

    // =========================================================================
    // Backward compatibility — old API used by existing code
    // =========================================================================

    /// Old API: registerCommand maps to registerAction with .general category.
    pub fn registerCommand(self: *CommandPalette, id: u16, label: []const u8, keybinding_index: ?u16, callback_index: u16) bool {
        _ = keybinding_index;
        _ = callback_index;
        return self.registerAction(id, label, "", .general);
    }

    /// Old API: getSelectedCommand maps to getSelectedAction.
    /// Returns a compat struct with .callback_index = action.id.
    pub fn getSelectedCommand(self: *const CommandPalette) ?CompatCommand {
        const act = self.getSelectedAction() orelse return null;
        return CompatCommand{ .callback_index = act.id, .id = act.id };
    }

    pub const CompatCommand = struct {
        id: u16,
        callback_index: u16,
    };
};
// =============================================================================
// Comprehensive action registration — all system commands
// =============================================================================

/// Register all system actions into the command palette.
/// This covers File, Edit, Selection, View, Go, Run, Terminal, Help menus
/// plus editor-specific actions. IDs match context_menu command IDs.
pub fn registerAllActions(cp: *CommandPalette) void {
    // -- File (600-649) --
    cp.reg(600, "File: New File", "Ctrl+N", .file);
    cp.reg(601, "File: New Window", "Ctrl+Shift+N", .file);
    cp.reg(602, "File: Open File...", "Ctrl+O", .file);
    cp.reg(603, "File: Open Folder...", "Ctrl+K Ctrl+O", .file);
    cp.reg(604, "File: Open Recent", "", .file);
    cp.reg(610, "File: Save", "Ctrl+S", .file);
    cp.reg(611, "File: Save As...", "Ctrl+Shift+S", .file);
    cp.reg(612, "File: Save All", "Ctrl+K S", .file);
    cp.reg(620, "File: Auto Save", "", .file);
    cp.reg(625, "File: Preferences", "", .file);
    cp.reg(630, "File: Revert File", "", .file);
    cp.reg(631, "File: Close Editor", "Ctrl+W", .file);
    cp.reg(632, "File: Close Folder", "", .file);
    cp.reg(633, "File: Close Window", "Alt+F4", .file);
    cp.reg(640, "File: Exit", "", .file);

    // -- Edit (700-749) --
    cp.reg(700, "Edit: Undo", "Ctrl+Z", .edit);
    cp.reg(701, "Edit: Redo", "Ctrl+Y", .edit);
    cp.reg(710, "Edit: Cut", "Ctrl+X", .edit);
    cp.reg(711, "Edit: Copy", "Ctrl+C", .edit);
    cp.reg(712, "Edit: Paste", "Ctrl+V", .edit);
    cp.reg(720, "Edit: Find", "Ctrl+F", .edit);
    cp.reg(721, "Edit: Replace", "Ctrl+H", .edit);
    cp.reg(730, "Edit: Find in Files", "Ctrl+Shift+F", .edit);
    cp.reg(731, "Edit: Replace in Files", "Ctrl+Shift+H", .edit);
    cp.reg(740, "Edit: Toggle Line Comment", "Ctrl+/", .edit);
    cp.reg(741, "Edit: Toggle Block Comment", "Ctrl+Shift+/", .edit);

    // -- Selection (800-849) --
    cp.reg(800, "Selection: Select All", "Ctrl+A", .selection);
    cp.reg(801, "Selection: Expand Selection", "Shift+Alt+Right", .selection);
    cp.reg(802, "Selection: Shrink Selection", "Shift+Alt+Left", .selection);
    cp.reg(810, "Selection: Copy Line Up", "Shift+Alt+Up", .selection);
    cp.reg(811, "Selection: Copy Line Down", "Shift+Alt+Down", .selection);
    cp.reg(812, "Selection: Move Line Up", "Alt+Up", .selection);
    cp.reg(813, "Selection: Move Line Down", "Alt+Down", .selection);
    cp.reg(814, "Selection: Duplicate Selection", "", .selection);
    cp.reg(820, "Selection: Add Cursor Above", "Ctrl+Alt+Up", .selection);
    cp.reg(821, "Selection: Add Cursor Below", "Ctrl+Alt+Down", .selection);
    cp.reg(822, "Selection: Add Cursors to Line Ends", "Shift+Alt+I", .selection);
    cp.reg(823, "Selection: Add Next Occurrence", "Ctrl+D", .selection);
    cp.reg(824, "Selection: Select All Occurrences", "Ctrl+Shift+L", .selection);

    // -- View (900-969) --
    cp.reg(900, "View: Command Palette", "Ctrl+Shift+P", .view);
    cp.reg(901, "View: Open View...", "", .view);
    cp.reg(910, "View: Appearance", "", .view);
    cp.reg(911, "View: Editor Layout", "", .view);
    cp.reg(920, "View: Explorer", "Ctrl+Shift+E", .view);
    cp.reg(921, "View: Search", "Ctrl+Shift+F", .view);
    cp.reg(922, "View: Source Control", "Ctrl+Shift+G", .view);
    cp.reg(923, "View: Run and Debug", "Ctrl+Shift+D", .view);
    cp.reg(924, "View: Extensions", "Ctrl+Shift+X", .view);
    cp.reg(930, "View: Problems", "Ctrl+Shift+M", .view);
    cp.reg(931, "View: Output", "Ctrl+Shift+U", .view);
    cp.reg(932, "View: Debug Console", "Ctrl+Shift+Y", .view);
    cp.reg(933, "View: Terminal", "Ctrl+`", .view);
    cp.reg(940, "View: Word Wrap", "Alt+Z", .view);
    cp.reg(941, "View: Minimap", "", .view);
    cp.reg(942, "View: Breadcrumbs", "", .view);
    cp.reg(950, "View: Zoom In", "Ctrl+=", .view);
    cp.reg(951, "View: Zoom Out", "Ctrl+-", .view);
    cp.reg(952, "View: Reset Zoom", "Ctrl+0", .view);
    cp.reg(960, "View: Full Screen", "F11", .view);
    cp.reg(2, "View: Toggle Sidebar", "Ctrl+B", .view);
    cp.reg(3, "View: Toggle Panel", "Ctrl+J", .view);

    // -- Go (1000-1059) --
    cp.reg(1000, "Go: Back", "Alt+Left", .go);
    cp.reg(1001, "Go: Forward", "Alt+Right", .go);
    cp.reg(1002, "Go: Last Edit Location", "Ctrl+K Ctrl+Q", .go);
    cp.reg(1010, "Go: Go to File...", "Ctrl+P", .go);
    cp.reg(1011, "Go: Go to Symbol in Workspace", "Ctrl+T", .go);
    cp.reg(1020, "Go: Go to Symbol in Editor", "Ctrl+Shift+O", .go);
    cp.reg(1021, "Go: Go to Definition", "F12", .go);
    cp.reg(1022, "Go: Go to Declaration", "", .go);
    cp.reg(1023, "Go: Go to Type Definition", "", .go);
    cp.reg(1024, "Go: Go to Implementations", "Ctrl+F12", .go);
    cp.reg(1025, "Go: Go to References", "Shift+F12", .go);
    cp.reg(1030, "Go: Go to Line/Column...", "Ctrl+G", .go);
    cp.reg(1031, "Go: Go to Bracket", "Ctrl+Shift+\\", .go);
    cp.reg(1040, "Go: Next Problem", "F8", .go);
    cp.reg(1041, "Go: Previous Problem", "Shift+F8", .go);
    cp.reg(1050, "Go: Next Change", "Alt+F5", .go);
    cp.reg(1051, "Go: Previous Change", "Shift+Alt+F5", .go);

    // -- Run (1100-1159) --
    cp.reg(1100, "Run: Start Debugging", "F5", .run);
    cp.reg(1101, "Run: Run Without Debugging", "Ctrl+F5", .run);
    cp.reg(1102, "Run: Stop Debugging", "Shift+F5", .run);
    cp.reg(1103, "Run: Restart Debugging", "Ctrl+Shift+F5", .run);
    cp.reg(1110, "Run: Open Configurations", "", .run);
    cp.reg(1111, "Run: Add Configuration...", "", .run);
    cp.reg(1120, "Run: Step Over", "F10", .run);
    cp.reg(1121, "Run: Step Into", "F11", .run);
    cp.reg(1122, "Run: Step Out", "Shift+F11", .run);
    cp.reg(1123, "Run: Continue", "F5", .run);
    cp.reg(1130, "Run: Toggle Breakpoint", "F9", .run);
    cp.reg(1131, "Run: New Breakpoint", "", .run);

    // -- Terminal (1200-1239) --
    cp.reg(1200, "Terminal: New Terminal", "Ctrl+Shift+`", .terminal);
    cp.reg(1201, "Terminal: Split Terminal", "", .terminal);
    cp.reg(1210, "Terminal: Run Task...", "", .terminal);
    cp.reg(1211, "Terminal: Run Build Task...", "Ctrl+Shift+B", .terminal);
    cp.reg(1220, "Terminal: Run Active File", "", .terminal);
    cp.reg(1221, "Terminal: Run Selected Text", "", .terminal);
    cp.reg(1230, "Terminal: Configure Tasks...", "", .terminal);

    // -- Help (1300-1359) --
    cp.reg(1300, "Help: Welcome", "", .help);
    cp.reg(1301, "Help: Show All Commands", "Ctrl+Shift+P", .help);
    cp.reg(1302, "Help: Documentation", "", .help);
    cp.reg(1310, "Help: Release Notes", "", .help);
    cp.reg(1320, "Help: Keyboard Shortcuts", "Ctrl+K Ctrl+R", .help);
    cp.reg(1330, "Help: Report Issue", "", .help);
    cp.reg(1340, "Help: Toggle Developer Tools", "Ctrl+Shift+I", .help);
    cp.reg(1350, "Help: About", "", .help);

    // -- Editor actions (100-179) --
    cp.reg(100, "Editor: Go to Definition", "F12", .editor);
    cp.reg(120, "Editor: Rename Symbol", "F2", .editor);
    cp.reg(130, "Editor: Cut", "Ctrl+X", .editor);
    cp.reg(131, "Editor: Copy", "Ctrl+C", .editor);
    cp.reg(132, "Editor: Paste", "Ctrl+V", .editor);
    cp.reg(140, "Editor: Format Document", "Shift+Alt+F", .editor);
    cp.reg(160, "Editor: Toggle Line Comment", "Ctrl+/", .editor);
    cp.reg(170, "Editor: Command Palette", "Ctrl+Shift+P", .editor);
}
// =============================================================================
// Unit tests
// =============================================================================
const std = @import("std");
const expect = std.testing.expect;

test "fuzzyScore: exact match scores high" {
    const score = fuzzyScore("open", "open");
    try expect(score >= 0);
    try expect(score > 10);
}

test "fuzzyScore: subsequence match returns >= 0" {
    const score = fuzzyScore("ofl", "open_file");
    try expect(score >= 0);
}

test "fuzzyScore: non-match returns -1" {
    try expect(fuzzyScore("xyz", "open") == -1);
    try expect(fuzzyScore("zz", "abcdef") == -1);
}

test "fuzzyScore: case insensitive matching" {
    try expect(fuzzyScore("OPEN", "open") >= 0);
    try expect(fuzzyScore("open", "OPEN") >= 0);
}

test "fuzzyScore: consecutive bonus > scattered" {
    const consecutive_score = fuzzyScore("op", "open");
    const scattered_score = fuzzyScore("op", "o_x_p");
    try expect(consecutive_score > scattered_score);
}

test "fuzzyScore: word boundary bonus" {
    const boundary_score = fuzzyScore("f", "open_file");
    const mid_score = fuzzyScore("i", "open_file");
    try expect(boundary_score > mid_score);
}

test "fuzzyScore: empty query returns 0" {
    try expect(fuzzyScore("", "anything") == 0);
}

test "fuzzyScore: empty target returns -1 for non-empty query" {
    try expect(fuzzyScore("a", "") == -1);
}

test "fuzzyScore: both empty returns 0" {
    try expect(fuzzyScore("", "") == 0);
}

test "fuzzyScore: query longer than target returns -1" {
    try expect(fuzzyScore("abcdef", "abc") == -1);
}

test "fuzzyScore: exact case bonus higher than mismatched case" {
    const exact = fuzzyScore("Open", "Open");
    const nocase = fuzzyScore("open", "Open");
    try expect(exact > nocase);
}

test "fuzzyScore: path-like boundary scoring" {
    const score = fuzzyScore("c", "src/command");
    try expect(score >= 0);
    try expect(score > 1);
}

test "CommandPalette: registerAction stores actions" {
    var cp = CommandPalette{};
    try expect(cp.registerAction(1, "Open File", "Ctrl+O", .file));
    try expect(cp.registerAction(2, "Save File", "Ctrl+S", .file));
    try expect(cp.action_count == 2);
    try expect(cp.actions[0].id == 1);
    try expect(cp.actions[0].category == .file);
    try expect(std.mem.eql(u8, cp.actions[0].label[0..cp.actions[0].label_len], "Open File"));
    try expect(std.mem.eql(u8, cp.actions[0].shortcut[0..cp.actions[0].shortcut_len], "Ctrl+O"));
}

test "CommandPalette: registerAction returns false when full" {
    var cp = CommandPalette{};
    for (0..CommandPalette.MAX_ACTIONS) |i| {
        try expect(cp.registerAction(@intCast(i), "cmd", "", .general));
    }
    try expect(cp.action_count == CommandPalette.MAX_ACTIONS);
    try expect(!cp.registerAction(9999, "overflow", "", .general));
}

test "CommandPalette: updateFilter with empty input shows all" {
    var cp = CommandPalette{};
    _ = cp.registerAction(1, "Open File", "", .file);
    _ = cp.registerAction(2, "Save File", "", .file);
    _ = cp.registerAction(3, "Close Tab", "", .general);
    cp.input_len = 0;
    cp.updateFilter();
    try expect(cp.filtered_count == 3);
}

test "CommandPalette: updateFilter with filter text matches correctly" {
    var cp = CommandPalette{};
    _ = cp.registerAction(1, "Open File", "", .file);
    _ = cp.registerAction(2, "Save File", "", .file);
    _ = cp.registerAction(3, "Close Tab", "", .general);
    _ = cp.registerAction(4, "Toggle Sidebar", "", .view);
    const query = "file";
    @memcpy(cp.input_buf[0..query.len], query);
    cp.input_len = query.len;
    cp.updateFilter();
    try expect(cp.filtered_count == 2);
}

test "CommandPalette: updateFilter sorts by score descending" {
    var cp = CommandPalette{};
    _ = cp.registerAction(1, "o_p_e_n_scattered", "", .general);
    _ = cp.registerAction(2, "open", "", .general);
    const query = "open";
    @memcpy(cp.input_buf[0..query.len], query);
    cp.input_len = query.len;
    cp.updateFilter();
    try expect(cp.filtered_count == 2);
    try expect(cp.filtered_indices[0] == 1);
    try expect(cp.filtered_scores[0] >= cp.filtered_scores[1]);
}

test "CommandPalette: non-matching query yields zero results" {
    var cp = CommandPalette{};
    _ = cp.registerAction(1, "Open File", "", .file);
    const query = "zzz";
    @memcpy(cp.input_buf[0..query.len], query);
    cp.input_len = query.len;
    cp.updateFilter();
    try expect(cp.filtered_count == 0);
}

test "CommandPalette: selected_index clamped after filtering" {
    var cp = CommandPalette{};
    _ = cp.registerAction(1, "Open File", "", .file);
    _ = cp.registerAction(2, "Save File", "", .file);
    _ = cp.registerAction(3, "Close Tab", "", .general);
    cp.selected_index = 4;
    const query = "file";
    @memcpy(cp.input_buf[0..query.len], query);
    cp.input_len = query.len;
    cp.updateFilter();
    try expect(cp.filtered_count == 2);
    try expect(cp.selected_index <= cp.filtered_count - 1);
}

test "CommandPalette: toggle makes visible, clears input" {
    var cp = CommandPalette{};
    _ = cp.registerAction(1, "Open File", "", .file);
    cp.input_len = 3;
    cp.selected_index = 2;
    cp.visible = false;
    cp.toggle();
    try expect(cp.visible == true);
    try expect(cp.input_len == 0);
    try expect(cp.selected_index == 0);
}

test "CommandPalette: getSelectedAction returns correct action" {
    var cp = CommandPalette{};
    _ = cp.registerAction(10, "Alpha", "", .file);
    _ = cp.registerAction(20, "Beta", "", .edit);
    _ = cp.registerAction(30, "Gamma", "", .view);
    cp.input_len = 0;
    cp.updateFilter();
    cp.selected_index = 2;
    const act = cp.getSelectedAction();
    try expect(act != null);
    try expect(act.?.id == 30);
}

test "CommandPalette: getSelectedAction returns null when empty" {
    var cp = CommandPalette{};
    cp.updateFilter();
    try expect(cp.getSelectedAction() == null);
}

test "CommandPalette: moveUp and moveDown" {
    var cp = CommandPalette{};
    _ = cp.registerAction(1, "A", "", .general);
    _ = cp.registerAction(2, "B", "", .general);
    _ = cp.registerAction(3, "C", "", .general);
    cp.updateFilter();
    try expect(cp.selected_index == 0);
    cp.moveDown();
    try expect(cp.selected_index == 1);
    cp.moveDown();
    try expect(cp.selected_index == 2);
    cp.moveDown(); // should not go past end
    try expect(cp.selected_index == 2);
    cp.moveUp();
    try expect(cp.selected_index == 1);
    cp.moveUp();
    try expect(cp.selected_index == 0);
    cp.moveUp(); // should not go below 0
    try expect(cp.selected_index == 0);
}

test "CommandPalette: appendChar and backspace" {
    var cp = CommandPalette{};
    _ = cp.registerAction(1, "Open File", "", .file);
    _ = cp.registerAction(2, "Save File", "", .file);
    _ = cp.registerAction(3, "Close Tab", "", .general);
    cp.updateFilter();
    try expect(cp.filtered_count == 3);
    cp.appendChar('t');
    cp.appendChar('a');
    cp.appendChar('b');
    try expect(cp.input_len == 3);
    try expect(cp.filtered_count == 1); // only "Close Tab"
    cp.backspace();
    try expect(cp.input_len == 2);
    // "ta" matches "Close Tab"
    try expect(cp.filtered_count >= 1);
}

test "CommandPalette: registerAllActions populates actions" {
    var cp = CommandPalette{};
    registerAllActions(&cp);
    try expect(cp.action_count > 80); // should have 100+ actions
    // Verify a few known actions exist
    var found_save = false;
    var found_undo = false;
    var found_debug = false;
    for (0..cp.action_count) |i| {
        if (cp.actions[i].id == 610) found_save = true;
        if (cp.actions[i].id == 700) found_undo = true;
        if (cp.actions[i].id == 1100) found_debug = true;
    }
    try expect(found_save);
    try expect(found_undo);
    try expect(found_debug);
}

test "CommandPalette: backward compat registerCommand" {
    var cp = CommandPalette{};
    try expect(cp.registerCommand(1, "Test", null, 1));
    try expect(cp.action_count == 1);
    const cmd = cp.getSelectedCommand();
    // No filter run yet, so no results
    try expect(cmd == null);
    cp.updateFilter();
    const cmd2 = cp.getSelectedCommand();
    try expect(cmd2 != null);
    try expect(cmd2.?.callback_index == 1);
}

test "CommandPalette: category names array" {
    try expect(CATEGORY_NAMES.len == 10);
    try expect(std.mem.eql(u8, CATEGORY_NAMES[0], "File"));
    try expect(std.mem.eql(u8, CATEGORY_NAMES[9], "General"));
}
