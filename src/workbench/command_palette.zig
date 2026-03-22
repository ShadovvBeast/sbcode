// src/workbench/command_palette.zig — Fuzzy scoring and command palette
//
// Pure Zig, zero dependencies, zero allocators, stack/comptime only.
// fuzzyScore: case-insensitive subsequence matching with consecutive,
// word boundary, and exact case bonuses.

/// Fuzzy score a query against a target string.
///
/// Returns -1 if query is not a case-insensitive subsequence of target.
/// Returns score >= 0 otherwise, with bonuses for:
///   - Consecutive character matches
///   - Matches at word boundaries (after '.', '/', '_', '-', ' ')
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
            // Base match score
            score += 1;

            // Consecutive bonus
            if (prev_match_idx == @as(i32, @intCast(ti)) - 1) {
                consecutive += 1;
                score += consecutive * 2;
            } else {
                consecutive = 0;
            }

            // Word boundary bonus
            if (ti == 0 or isBoundary(target[ti - 1])) {
                score += 5;
            }

            // Exact case bonus
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
    return c == '.' or c == '/' or c == '_' or c == '-' or c == ' ';
}

// ---------------------------------------------------------------------------
// CommandPalette — zero-allocation command registry with fuzzy filtering
// ---------------------------------------------------------------------------

pub const CommandPalette = struct {
    pub const MAX_COMMANDS: usize = 1024;
    pub const MAX_RESULTS: usize = 50;

    pub const Command = struct {
        id: u16,
        label: [128]u8,
        label_len: u8,
        keybinding_index: ?u16,
        callback_index: u16,
    };

    commands: [MAX_COMMANDS]Command = undefined,
    command_count: usize = 0,
    filtered_indices: [MAX_RESULTS]usize = undefined,
    filtered_scores: [MAX_RESULTS]i32 = undefined,
    filtered_count: usize = 0,
    input_buf: [256]u8 = undefined,
    input_len: usize = 0,
    selected_index: usize = 0,
    visible: bool = false,

    /// Register a command. Returns false if MAX_COMMANDS reached.
    pub fn registerCommand(self: *CommandPalette, id: u16, label: []const u8, keybinding_index: ?u16, callback_index: u16) bool {
        if (self.command_count >= MAX_COMMANDS) return false;
        var cmd = Command{
            .id = id,
            .label = undefined,
            .label_len = 0,
            .keybinding_index = keybinding_index,
            .callback_index = callback_index,
        };
        const copy_len: u8 = @intCast(@min(label.len, 128));
        @memcpy(cmd.label[0..copy_len], label[0..copy_len]);
        cmd.label_len = copy_len;
        self.commands[self.command_count] = cmd;
        self.command_count += 1;
        return true;
    }

    /// Update filtered results based on current input.
    /// Empty input → show all commands up to MAX_RESULTS.
    /// Non-empty → fuzzy match, collect with scores, sort by score descending.
    /// Clamps selected_index after filtering.
    pub fn updateFilter(self: *CommandPalette) void {
        self.filtered_count = 0;
        const query = self.input_buf[0..self.input_len];

        if (query.len == 0) {
            // Show all commands up to MAX_RESULTS
            const limit = @min(self.command_count, MAX_RESULTS);
            for (0..limit) |i| {
                self.filtered_indices[i] = i;
                self.filtered_scores[i] = 0;
            }
            self.filtered_count = limit;
        } else {
            // Fuzzy match each command label, collect matches with scores
            for (0..self.command_count) |i| {
                if (self.filtered_count >= MAX_RESULTS) break;
                const cmd = &self.commands[i];
                const label = cmd.label[0..cmd.label_len];
                const score = fuzzyScore(query, label);
                if (score >= 0) {
                    self.filtered_indices[self.filtered_count] = i;
                    self.filtered_scores[self.filtered_count] = score;
                    self.filtered_count += 1;
                }
            }
            // Insertion sort by score descending (small N, no allocator needed)
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

        // Clamp selected_index
        if (self.filtered_count == 0) {
            self.selected_index = 0;
        } else if (self.selected_index >= self.filtered_count) {
            self.selected_index = self.filtered_count - 1;
        }
    }

    /// Toggle visibility. When becoming visible, clear input, reset selection, update filter.
    pub fn toggle(self: *CommandPalette) void {
        self.visible = !self.visible;
        if (self.visible) {
            self.input_len = 0;
            self.selected_index = 0;
            self.updateFilter();
        }
    }

    /// Get the currently selected command, or null if none.
    pub fn getSelectedCommand(self: *const CommandPalette) ?*const Command {
        if (self.filtered_count == 0) return null;
        if (self.selected_index >= self.filtered_count) return null;
        const cmd_idx = self.filtered_indices[self.selected_index];
        return &self.commands[cmd_idx];
    }
};

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------
const std = @import("std");
const expect = std.testing.expect;

test "fuzzyScore: exact match scores high" {
    const score = fuzzyScore("open", "open");
    try expect(score >= 0);
    // 4 chars, all consecutive after first, all at exact case, first char at boundary (ti==0)
    // Should be a high score
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
    const score = fuzzyScore("OPEN", "open");
    try expect(score >= 0);

    const score2 = fuzzyScore("open", "OPEN");
    try expect(score2 >= 0);
}

test "fuzzyScore: consecutive bonus > scattered" {
    // "op" in "open" is consecutive; "op" in "o_x_p" is scattered
    const consecutive_score = fuzzyScore("op", "open");
    const scattered_score = fuzzyScore("op", "o_x_p");
    try expect(consecutive_score > scattered_score);
}

test "fuzzyScore: word boundary bonus" {
    // 'f' after '_' gets boundary bonus in "open_file"
    const boundary_score = fuzzyScore("f", "open_file");
    // 'i' in middle of "file" gets no boundary bonus
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
    // 'c' after '/' gets boundary bonus
    const score = fuzzyScore("c", "src/command");
    try expect(score >= 0);
    // Verify boundary bonus is awarded (score should include +5 for boundary)
    try expect(score > 1);
}

// ---------------------------------------------------------------------------
// CommandPalette unit tests
// ---------------------------------------------------------------------------

fn makeTestPalette() CommandPalette {
    var cp = CommandPalette{};
    _ = cp.registerCommand(1, "Open File", null, 0);
    _ = cp.registerCommand(2, "Save File", null, 1);
    _ = cp.registerCommand(3, "Close Tab", 0, 2);
    _ = cp.registerCommand(4, "Toggle Sidebar", null, 3);
    _ = cp.registerCommand(5, "Format Document", 1, 4);
    return cp;
}

test "CommandPalette: registerCommand stores commands" {
    var cp = CommandPalette{};
    try expect(cp.registerCommand(1, "Open File", null, 0));
    try expect(cp.registerCommand(2, "Save File", 0, 1));
    try expect(cp.command_count == 2);

    const cmd0 = cp.commands[0];
    try expect(cmd0.id == 1);
    try expect(cmd0.callback_index == 0);
    try expect(cmd0.keybinding_index == null);
    try expect(std.mem.eql(u8, cmd0.label[0..cmd0.label_len], "Open File"));

    const cmd1 = cp.commands[1];
    try expect(cmd1.id == 2);
    try expect(cmd1.keybinding_index.? == 0);
}

test "CommandPalette: registerCommand returns false when full" {
    var cp = CommandPalette{};
    for (0..CommandPalette.MAX_COMMANDS) |i| {
        try expect(cp.registerCommand(@intCast(i), "cmd", null, 0));
    }
    try expect(cp.command_count == CommandPalette.MAX_COMMANDS);
    // Next registration should fail
    try expect(!cp.registerCommand(9999, "overflow", null, 0));
    try expect(cp.command_count == CommandPalette.MAX_COMMANDS);
}

test "CommandPalette: updateFilter with empty input shows all commands" {
    var cp = makeTestPalette();
    cp.input_len = 0;
    cp.updateFilter();
    try expect(cp.filtered_count == 5);
    // Should be indices 0..4
    for (0..5) |i| {
        try expect(cp.filtered_indices[i] == i);
    }
}

test "CommandPalette: updateFilter with empty input caps at MAX_RESULTS" {
    var cp = CommandPalette{};
    // Register more than MAX_RESULTS commands
    for (0..CommandPalette.MAX_RESULTS + 10) |i| {
        _ = cp.registerCommand(@intCast(i), "command", null, 0);
    }
    cp.input_len = 0;
    cp.updateFilter();
    try expect(cp.filtered_count == CommandPalette.MAX_RESULTS);
}

test "CommandPalette: updateFilter with filter text matches correctly" {
    var cp = makeTestPalette();
    // Filter for "file" — should match "Open File" and "Save File"
    const query = "file";
    @memcpy(cp.input_buf[0..query.len], query);
    cp.input_len = query.len;
    cp.updateFilter();
    try expect(cp.filtered_count == 2);
    // Both matched commands should be "Open File" (idx 0) and "Save File" (idx 1)
    var found_open = false;
    var found_save = false;
    for (0..cp.filtered_count) |i| {
        const idx = cp.filtered_indices[i];
        if (idx == 0) found_open = true;
        if (idx == 1) found_save = true;
    }
    try expect(found_open);
    try expect(found_save);
}

test "CommandPalette: updateFilter sorts by score descending" {
    var cp = CommandPalette{};
    // "open" should score higher against "open" than against "o_p_e_n" (scattered)
    _ = cp.registerCommand(1, "o_p_e_n_scattered", null, 0);
    _ = cp.registerCommand(2, "open", null, 1);
    const query = "open";
    @memcpy(cp.input_buf[0..query.len], query);
    cp.input_len = query.len;
    cp.updateFilter();
    try expect(cp.filtered_count == 2);
    // The exact match "open" (idx 1) should come first (higher score)
    try expect(cp.filtered_indices[0] == 1);
    try expect(cp.filtered_scores[0] >= cp.filtered_scores[1]);
}

test "CommandPalette: updateFilter non-matching query yields zero results" {
    var cp = makeTestPalette();
    const query = "zzz";
    @memcpy(cp.input_buf[0..query.len], query);
    cp.input_len = query.len;
    cp.updateFilter();
    try expect(cp.filtered_count == 0);
}

test "CommandPalette: selected_index clamped after filtering" {
    var cp = makeTestPalette();
    // Set selected_index high
    cp.selected_index = 4;
    // Filter to only 2 results
    const query = "file";
    @memcpy(cp.input_buf[0..query.len], query);
    cp.input_len = query.len;
    cp.updateFilter();
    try expect(cp.filtered_count == 2);
    try expect(cp.selected_index <= cp.filtered_count - 1);
}

test "CommandPalette: selected_index clamped to 0 when no results" {
    var cp = makeTestPalette();
    cp.selected_index = 3;
    const query = "zzz";
    @memcpy(cp.input_buf[0..query.len], query);
    cp.input_len = query.len;
    cp.updateFilter();
    try expect(cp.filtered_count == 0);
    try expect(cp.selected_index == 0);
}

test "CommandPalette: toggle makes visible, clears input, resets selection" {
    var cp = makeTestPalette();
    // Set some state
    cp.input_len = 3;
    cp.selected_index = 2;
    cp.visible = false;

    cp.toggle();
    try expect(cp.visible == true);
    try expect(cp.input_len == 0);
    try expect(cp.selected_index == 0);
    // After toggle visible, updateFilter was called with empty input
    try expect(cp.filtered_count == 5);
}

test "CommandPalette: toggle off then on resets state" {
    var cp = makeTestPalette();
    cp.toggle(); // visible = true
    try expect(cp.visible == true);
    cp.toggle(); // visible = false
    try expect(cp.visible == false);
    cp.toggle(); // visible = true again
    try expect(cp.visible == true);
    try expect(cp.input_len == 0);
    try expect(cp.selected_index == 0);
}

test "CommandPalette: getSelectedCommand returns correct command" {
    var cp = makeTestPalette();
    cp.input_len = 0;
    cp.updateFilter();
    cp.selected_index = 2;
    const cmd = cp.getSelectedCommand();
    try expect(cmd != null);
    try expect(cmd.?.id == 3); // "Close Tab" is at index 2
}

test "CommandPalette: getSelectedCommand returns null when no results" {
    var cp = makeTestPalette();
    const query = "zzz";
    @memcpy(cp.input_buf[0..query.len], query);
    cp.input_len = query.len;
    cp.updateFilter();
    try expect(cp.getSelectedCommand() == null);
}

test "CommandPalette: getSelectedCommand returns null on empty palette" {
    var cp = CommandPalette{};
    cp.updateFilter();
    try expect(cp.getSelectedCommand() == null);
}
