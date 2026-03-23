// src/workbench/file_picker.zig — GL-rendered file picker overlay
//
// Non-blocking replacement for Win32 GetOpenFileNameW / GetSaveFileNameW.
// Lists directory contents via FindFirstFileW/FindNextFileW, supports
// keyboard navigation, directory traversal, and fuzzy filtering.
// Zero heap allocations — all storage is comptime-sized.

const std = @import("std");
const w32 = @import("win32");

// =============================================================================
// Constants
// =============================================================================

/// Maximum entries displayed in the file picker.
pub const MAX_ENTRIES: usize = 256;

/// Maximum path length in UTF-16 code units.
pub const MAX_PATH_LEN: usize = 512;

/// Maximum display name length in UTF-8 bytes.
pub const MAX_NAME_LEN: usize = 260;

/// Maximum filter input length.
pub const MAX_FILTER_LEN: usize = 128;

/// Maximum visible rows in the picker list.
pub const MAX_VISIBLE_ROWS: usize = 16;

// =============================================================================
// Entry
// =============================================================================

pub const Entry = struct {
    name: [MAX_NAME_LEN]u8 = undefined,
    name_len: u16 = 0,
    is_dir: bool = false,
};

// =============================================================================
// FilePicker
// =============================================================================

pub const FilePicker = struct {
    visible: bool = false,
    mode: Mode = .open,

    // Current directory path (UTF-16, null-terminated)
    current_dir: [MAX_PATH_LEN]u16 = [_]u16{0} ** MAX_PATH_LEN,
    current_dir_len: u16 = 0,

    // Directory entries
    entries: [MAX_ENTRIES]Entry = undefined,
    entry_count: u16 = 0,

    // Filtered indices (after fuzzy filter)
    filtered: [MAX_ENTRIES]u16 = undefined,
    filtered_count: u16 = 0,

    // Filter input
    filter_buf: [MAX_FILTER_LEN]u8 = undefined,
    filter_len: u16 = 0,

    // Selection
    selected: u16 = 0,
    scroll_top: u16 = 0,

    pub const Mode = enum { open, save, folder };

    /// Open the file picker. Reads the current working directory and lists its contents.
    pub fn open(self: *FilePicker, mode: Mode) void {
        self.mode = mode;
        self.filter_len = 0;
        self.selected = 0;
        self.scroll_top = 0;
        self.visible = true;

        // Get current working directory
        const len = w32.GetCurrentDirectoryW(MAX_PATH_LEN, &self.current_dir);
        self.current_dir_len = @intCast(@min(len, MAX_PATH_LEN - 1));

        self.refreshEntries();
    }

    /// Close the file picker.
    pub fn close(self: *FilePicker) void {
        self.visible = false;
    }

    /// Navigate into a subdirectory.
    pub fn enterDirectory(self: *FilePicker, dir_name: []const u8) void {
        // Append \dirname to current_dir
        var pos: usize = self.current_dir_len;

        // Add backslash separator
        if (pos < MAX_PATH_LEN - 1) {
            self.current_dir[pos] = '\\';
            pos += 1;
        }

        // Append directory name (UTF-8 → UTF-16, ASCII subset)
        for (dir_name) |ch| {
            if (pos >= MAX_PATH_LEN - 1) break;
            self.current_dir[pos] = @as(u16, ch);
            pos += 1;
        }
        self.current_dir[pos] = 0;
        self.current_dir_len = @intCast(pos);

        self.filter_len = 0;
        self.selected = 0;
        self.scroll_top = 0;
        self.refreshEntries();
    }

    /// Navigate up to parent directory.
    pub fn goUp(self: *FilePicker) void {
        // Find last backslash
        var last_sep: usize = 0;
        var i: usize = 0;
        while (i < self.current_dir_len) : (i += 1) {
            if (self.current_dir[i] == '\\') last_sep = i;
        }
        // Don't go above root (e.g. "C:\")
        if (last_sep <= 2) {
            if (self.current_dir_len > 3) {
                self.current_dir[3] = 0;
                self.current_dir_len = 3;
            }
        } else {
            self.current_dir[last_sep] = 0;
            self.current_dir_len = @intCast(last_sep);
        }

        self.filter_len = 0;
        self.selected = 0;
        self.scroll_top = 0;
        self.refreshEntries();
    }

    /// Get the selected entry, or null if none.
    pub fn getSelected(self: *const FilePicker) ?*const Entry {
        if (self.filtered_count == 0) return null;
        if (self.selected >= self.filtered_count) return null;
        return &self.entries[self.filtered[self.selected]];
    }

    /// Build the full path for the selected entry (UTF-16, null-terminated).
    /// Returns the length, or 0 on failure.
    pub fn getSelectedPath(self: *const FilePicker, out: *[MAX_PATH_LEN]u16) u16 {
        const entry = self.getSelected() orelse return 0;
        var pos: usize = 0;

        // Copy current dir
        var di: usize = 0;
        while (di < self.current_dir_len) : (di += 1) {
            if (pos >= MAX_PATH_LEN - 1) return 0;
            out[pos] = self.current_dir[di];
            pos += 1;
        }

        // Backslash
        if (pos >= MAX_PATH_LEN - 1) return 0;
        out[pos] = '\\';
        pos += 1;

        // Entry name (UTF-8 → UTF-16 ASCII subset)
        var ni: usize = 0;
        while (ni < entry.name_len) : (ni += 1) {
            if (pos >= MAX_PATH_LEN - 1) return 0;
            out[pos] = @as(u16, entry.name[ni]);
            pos += 1;
        }
        out[pos] = 0;
        return @intCast(pos);
    }

    /// Refresh directory listing from current_dir.
    pub fn refreshEntries(self: *FilePicker) void {
        self.entry_count = 0;

        // Build search pattern: current_dir\*
        var search_path: [MAX_PATH_LEN]u16 = [_]u16{0} ** MAX_PATH_LEN;
        var sp: usize = 0;
        var ci: usize = 0;
        while (ci < self.current_dir_len) : (ci += 1) {
            if (sp >= MAX_PATH_LEN - 3) break;
            search_path[sp] = self.current_dir[ci];
            sp += 1;
        }
        search_path[sp] = '\\';
        sp += 1;
        search_path[sp] = '*';
        sp += 1;
        search_path[sp] = 0;

        var find_data: w32.WIN32_FIND_DATAW = undefined;
        const handle = w32.FindFirstFileW(@ptrCast(&search_path), &find_data);
        // FindFirstFileW returns INVALID_HANDLE_VALUE (-1) on failure, not null
        if (handle == null or @intFromPtr(handle.?) == w32.INVALID_HANDLE_VALUE) {
            self.updateFilter();
            return;
        }

        // Process first result
        self.addFindEntry(&find_data);

        // Process remaining results
        while (w32.FindNextFileW(handle, &find_data) != 0) {
            if (self.entry_count >= MAX_ENTRIES) break;
            self.addFindEntry(&find_data);
        }

        _ = w32.FindClose(handle);

        // Sort: directories first, then alphabetical
        self.sortEntries();
        self.updateFilter();
    }

    /// Add a WIN32_FIND_DATAW result as an entry.
    fn addFindEntry(self: *FilePicker, fd: *const w32.WIN32_FIND_DATAW) void {
        if (self.entry_count >= MAX_ENTRIES) return;

        // Convert UTF-16 filename to UTF-8 (ASCII subset)
        var name_buf: [MAX_NAME_LEN]u8 = undefined;
        var name_len: u16 = 0;
        for (fd.cFileName) |wc| {
            if (wc == 0) break;
            if (name_len >= MAX_NAME_LEN) break;
            name_buf[name_len] = if (wc < 128) @intCast(wc) else '?';
            name_len += 1;
        }

        // Skip "." entry
        if (name_len == 1 and name_buf[0] == '.') return;

        const idx = self.entry_count;
        @memcpy(self.entries[idx].name[0..name_len], name_buf[0..name_len]);
        self.entries[idx].name_len = name_len;
        self.entries[idx].is_dir = (fd.dwFileAttributes & w32.FILE_ATTRIBUTE_DIRECTORY) != 0;
        self.entry_count += 1;
    }

    /// Sort entries: directories first (with ".." at top), then files, alphabetical within each group.
    fn sortEntries(self: *FilePicker) void {
        if (self.entry_count <= 1) return;
        // Simple insertion sort (small N, no allocator)
        var i: u16 = 1;
        while (i < self.entry_count) : (i += 1) {
            const key = self.entries[i];
            var j: u16 = i;
            while (j > 0 and entryLessThan(&key, &self.entries[j - 1])) : (j -= 1) {
                self.entries[j] = self.entries[j - 1];
            }
            self.entries[j] = key;
        }
    }

    /// Comparison: ".." first, then dirs before files, then alphabetical.
    fn entryLessThan(a: *const Entry, b: *const Entry) bool {
        // ".." always first
        const a_dotdot = a.name_len == 2 and a.name[0] == '.' and a.name[1] == '.';
        const b_dotdot = b.name_len == 2 and b.name[0] == '.' and b.name[1] == '.';
        if (a_dotdot and !b_dotdot) return true;
        if (!a_dotdot and b_dotdot) return false;

        // Dirs before files
        if (a.is_dir and !b.is_dir) return true;
        if (!a.is_dir and b.is_dir) return false;

        // Alphabetical (case-insensitive)
        const a_name = a.name[0..a.name_len];
        const b_name = b.name[0..b.name_len];
        const min_len = @min(a_name.len, b_name.len);
        for (a_name[0..min_len], b_name[0..min_len]) |ac, bc| {
            const al = if (ac >= 'A' and ac <= 'Z') ac + 32 else ac;
            const bl = if (bc >= 'A' and bc <= 'Z') bc + 32 else bc;
            if (al < bl) return true;
            if (al > bl) return false;
        }
        return a_name.len < b_name.len;
    }

    /// Update filtered list based on filter_buf.
    pub fn updateFilter(self: *FilePicker) void {
        self.filtered_count = 0;
        const query = self.filter_buf[0..self.filter_len];

        var i: u16 = 0;
        while (i < self.entry_count) : (i += 1) {
            if (self.filtered_count >= MAX_ENTRIES) break;
            const name = self.entries[i].name[0..self.entries[i].name_len];
            if (query.len == 0 or fuzzyMatch(query, name)) {
                self.filtered[self.filtered_count] = i;
                self.filtered_count += 1;
            }
        }

        // Clamp selection
        if (self.filtered_count == 0) {
            self.selected = 0;
        } else if (self.selected >= self.filtered_count) {
            self.selected = self.filtered_count - 1;
        }
    }

    /// Simple case-insensitive subsequence match.
    fn fuzzyMatch(query: []const u8, target: []const u8) bool {
        var qi: usize = 0;
        for (target) |tc| {
            if (qi >= query.len) break;
            const ql = if (query[qi] >= 'A' and query[qi] <= 'Z') query[qi] + 32 else query[qi];
            const tl = if (tc >= 'A' and tc <= 'Z') tc + 32 else tc;
            if (ql == tl) qi += 1;
        }
        return qi >= query.len;
    }

    /// Get the current directory as a UTF-8 string (ASCII subset).
    pub fn getCurrentDirUtf8(self: *const FilePicker, out: *[MAX_PATH_LEN]u8) u16 {
        var len: u16 = 0;
        var i: usize = 0;
        while (i < self.current_dir_len) : (i += 1) {
            if (len >= MAX_PATH_LEN) break;
            out[len] = if (self.current_dir[i] < 128) @intCast(self.current_dir[i]) else '?';
            len += 1;
        }
        return len;
    }

    /// Get the current directory as a null-terminated UTF-16 path.
    pub fn getCurrentDirW(self: *FilePicker) [*:0]const u16 {
        self.current_dir[self.current_dir_len] = 0;
        return @ptrCast(&self.current_dir);
    }
};

// =============================================================================
// Tests
// =============================================================================

const testing = std.testing;

test "FilePicker default initialization" {
    const fp = FilePicker{};
    try testing.expectEqual(false, fp.visible);
    try testing.expectEqual(@as(u16, 0), fp.entry_count);
    try testing.expectEqual(@as(u16, 0), fp.filtered_count);
    try testing.expectEqual(@as(u16, 0), fp.filter_len);
    try testing.expectEqual(@as(u16, 0), fp.selected);
}

test "FilePicker.getSelected returns null when empty" {
    const fp = FilePicker{};
    try testing.expect(fp.getSelected() == null);
}

test "FilePicker.entryLessThan sorts dirs before files" {
    var dir_entry = Entry{ .is_dir = true, .name_len = 3 };
    @memcpy(dir_entry.name[0..3], "abc");
    var file_entry = Entry{ .is_dir = false, .name_len = 3 };
    @memcpy(file_entry.name[0..3], "abc");
    try testing.expect(FilePicker.entryLessThan(&dir_entry, &file_entry));
    try testing.expect(!FilePicker.entryLessThan(&file_entry, &dir_entry));
}

test "FilePicker.entryLessThan sorts dotdot first" {
    var dotdot = Entry{ .is_dir = true, .name_len = 2 };
    @memcpy(dotdot.name[0..2], "..");
    var other = Entry{ .is_dir = true, .name_len = 3 };
    @memcpy(other.name[0..3], "abc");
    try testing.expect(FilePicker.entryLessThan(&dotdot, &other));
    try testing.expect(!FilePicker.entryLessThan(&other, &dotdot));
}

test "FilePicker.fuzzyMatch basic cases" {
    try testing.expect(FilePicker.fuzzyMatch("abc", "abcdef"));
    try testing.expect(FilePicker.fuzzyMatch("adf", "abcdef"));
    try testing.expect(!FilePicker.fuzzyMatch("xyz", "abcdef"));
    try testing.expect(FilePicker.fuzzyMatch("", "anything"));
    try testing.expect(FilePicker.fuzzyMatch("ABC", "abcdef")); // case insensitive
}

test "FilePicker.updateFilter with empty filter shows all" {
    var fp = FilePicker{};
    // Manually add some entries
    fp.entries[0].name_len = 5;
    @memcpy(fp.entries[0].name[0..5], "hello");
    fp.entries[1].name_len = 5;
    @memcpy(fp.entries[1].name[0..5], "world");
    fp.entry_count = 2;
    fp.filter_len = 0;
    fp.updateFilter();
    try testing.expectEqual(@as(u16, 2), fp.filtered_count);
}

test "FilePicker.updateFilter filters correctly" {
    var fp = FilePicker{};
    fp.entries[0].name_len = 8;
    @memcpy(fp.entries[0].name[0..8], "main.zig");
    fp.entries[1].name_len = 8;
    @memcpy(fp.entries[1].name[0..8], "test.txt");
    fp.entries[2].name_len = 7;
    @memcpy(fp.entries[2].name[0..7], "app.zig");
    fp.entry_count = 3;
    @memcpy(fp.filter_buf[0..3], "zig");
    fp.filter_len = 3;
    fp.updateFilter();
    try testing.expectEqual(@as(u16, 2), fp.filtered_count); // main.zig and app.zig
}

test "FilePicker constants" {
    try testing.expectEqual(@as(usize, 256), MAX_ENTRIES);
    try testing.expectEqual(@as(usize, 512), MAX_PATH_LEN);
    try testing.expectEqual(@as(usize, 260), MAX_NAME_LEN);
}
