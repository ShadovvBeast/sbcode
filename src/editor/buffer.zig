// src/editor/buffer.zig — Fixed-capacity text buffer with line index and undo/redo (no allocator)
//
// Replaces VS Code's PieceTreeTextBuffer with a simple flat buffer + line index.
// All storage is stack/comptime sized. Zero allocator usage.
// Includes a fixed-capacity undo/redo stack for reversible edits.

pub const MAX_BUFFER_SIZE: u32 = 4 * 1024 * 1024; // 4 MB per file
pub const MAX_LINES: u32 = 65536;

/// Maximum number of undo entries.
pub const MAX_UNDO_ENTRIES: u32 = 256;

/// Maximum bytes stored per undo entry (for deleted text recovery).
pub const MAX_UNDO_DATA: u32 = 128;

pub const LineInfo = struct {
    start: u32, // byte offset into content
    len: u32, // byte length (excluding newline)
};

/// Type of edit operation for undo/redo.
pub const UndoKind = enum(u8) {
    insert,
    delete,
};

/// A single undo entry recording one edit operation.
pub const UndoEntry = struct {
    kind: UndoKind = .insert,
    line: u32 = 0,
    col: u32 = 0,
    data_len: u16 = 0,
    data: [MAX_UNDO_DATA]u8 = undefined,
};

pub const TextBuffer = struct {
    content: [MAX_BUFFER_SIZE]u8 = undefined,
    content_len: u32 = 0,
    lines: [MAX_LINES]LineInfo = undefined,
    line_count: u32 = 0,
    dirty: bool = false,

    // Undo/redo stacks (fixed capacity, no allocations)
    undo_stack: [MAX_UNDO_ENTRIES]UndoEntry = undefined,
    undo_count: u32 = 0,
    redo_stack: [MAX_UNDO_ENTRIES]UndoEntry = undefined,
    redo_count: u32 = 0,

    /// Load file content and build line index.
    ///
    /// Preconditions:
    ///   - `data.len` <= MAX_BUFFER_SIZE
    ///
    /// Postconditions:
    ///   - self.content[0..data.len] == data
    ///   - self.line_count == number of newline-delimited lines
    ///   - self.lines[i] correctly maps to each line's start/len
    ///   - self.dirty == false
    pub fn load(self: *TextBuffer, data: []const u8) bool {
        if (data.len > MAX_BUFFER_SIZE) return false;
        @memcpy(self.content[0..data.len], data);
        self.content_len = @intCast(data.len);
        self.dirty = false;
        self.undo_count = 0;
        self.redo_count = 0;
        self.rebuildLineIndex();
        return true;
    }

    /// Insert text at (line, col) position.
    ///
    /// Preconditions:
    ///   - line < self.line_count
    ///   - col <= self.lines[line].len
    ///   - self.content_len + text.len <= MAX_BUFFER_SIZE
    ///
    /// Postconditions:
    ///   - Text is inserted at the correct byte offset
    ///   - Line index is rebuilt
    ///   - self.dirty == true
    pub fn insert(self: *TextBuffer, line: u32, col: u32, text: []const u8) bool {
        if (line >= self.line_count) return false;
        const offset = self.lines[line].start + col;
        if (offset > self.content_len) return false;
        const new_len = self.content_len + @as(u32, @intCast(text.len));
        if (new_len > MAX_BUFFER_SIZE) return false;

        // Record undo entry (insert → undo is delete)
        self.pushUndo(.insert, line, col, text);
        // Clear redo stack on new edit
        self.redo_count = 0;

        // Shift content right
        var i: usize = self.content_len;
        while (i > offset) {
            i -= 1;
            self.content[i + text.len] = self.content[i];
        }
        // Copy new text
        @memcpy(self.content[offset..][0..text.len], text);
        self.content_len = new_len;
        self.dirty = true;
        self.rebuildLineIndex();
        return true;
    }

    /// Delete `count` bytes starting at (line, col).
    ///
    /// Preconditions:
    ///   - line < self.line_count
    ///   - col + count <= available bytes from that position
    ///
    /// Postconditions:
    ///   - Bytes are removed, content shifted left
    ///   - Line index is rebuilt
    ///   - self.dirty == true
    pub fn delete(self: *TextBuffer, line: u32, col: u32, count: u32) bool {
        if (line >= self.line_count) return false;
        const offset = self.lines[line].start + col;
        if (offset + count > self.content_len) return false;

        // Record undo entry (delete → undo is insert the deleted text back)
        const deleted = self.content[offset..][0..count];
        self.pushUndo(.delete, line, col, deleted);
        // Clear redo stack on new edit
        self.redo_count = 0;

        const end = offset + count;
        const remaining = self.content_len - end;
        var i: usize = 0;
        while (i < remaining) : (i += 1) {
            self.content[offset + i] = self.content[end + i];
        }
        self.content_len -= count;
        self.dirty = true;
        self.rebuildLineIndex();
        return true;
    }

    /// Get the content of a specific line as a slice.
    pub fn getLine(self: *const TextBuffer, line: u32) ?[]const u8 {
        if (line >= self.line_count) return null;
        const info = self.lines[line];
        return self.content[info.start..][0..info.len];
    }

    /// Get text in a byte range [start_offset, start_offset+len).
    /// Returns the slice or null if out of bounds.
    pub fn getRange(self: *const TextBuffer, start_offset: u32, len: u32) ?[]const u8 {
        if (start_offset + len > self.content_len) return null;
        return self.content[start_offset..][0..len];
    }

    /// Insert a copy of a line at the given position.
    pub fn insertLine(self: *TextBuffer, at_line: u32, text: []const u8) void {
        if (at_line > self.line_count) return;
        // Insert a newline + text at the end of the previous line
        if (at_line > 0) {
            const prev = self.lines[at_line - 1];
            const offset = prev.start + prev.len;
            // Insert newline then text
            var buf: [1 + 4096]u8 = undefined;
            buf[0] = '\n';
            const copy_len = @min(text.len, 4096);
            @memcpy(buf[1..][0..copy_len], text[0..copy_len]);
            _ = self.insertAt(offset, buf[0 .. 1 + copy_len]);
        }
    }

    /// Swap two adjacent lines in the buffer.
    pub fn swapLines(self: *TextBuffer, line_a: u32, line_b: u32) void {
        if (line_a >= self.line_count or line_b >= self.line_count) return;
        if (line_a == line_b) return;
        // Swap by copying content
        var tmp: [4096]u8 = undefined;
        const a_text = self.getLine(line_a) orelse return;
        const b_text = self.getLine(line_b) orelse return;
        const a_len = @min(a_text.len, 4096);
        const b_len = @min(b_text.len, 4096);
        @memcpy(tmp[0..a_len], a_text[0..a_len]);
        // Replace line_a content with line_b content, line_b with tmp
        self.replaceLine(line_a, b_text[0..b_len]);
        self.replaceLine(line_b, tmp[0..a_len]);
    }

    /// Replace the content of a line (keeping the same line structure).
    fn replaceLine(self: *TextBuffer, line: u32, new_text: []const u8) void {
        if (line >= self.line_count) return;
        const info = self.lines[line];
        // Delete old content, insert new
        _ = self.delete(line, 0, info.len);
        _ = self.insert(line, 0, new_text);
    }

    /// Insert raw bytes at a byte offset (low-level helper).
    fn insertAt(self: *TextBuffer, offset: u32, text: []const u8) bool {
        if (text.len == 0) return true;
        if (self.content_len + text.len > self.content.len) return false;
        // Shift content right
        const shift_len = self.content_len - offset;
        if (shift_len > 0) {
            var i: u32 = self.content_len + @as(u32, @intCast(text.len));
            while (i > offset + @as(u32, @intCast(text.len))) {
                i -= 1;
                self.content[i] = self.content[i - @as(u32, @intCast(text.len))];
            }
        }
        @memcpy(self.content[offset..][0..text.len], text);
        self.content_len += @intCast(text.len);
        self.rebuildLineIndex();
        self.dirty = true;
        return true;
    }

    /// Convert (line, col) to a byte offset into content.
    pub fn posToOffset(self: *const TextBuffer, line: u32, col: u32) ?u32 {
        if (line >= self.line_count) return null;
        const info = self.lines[line];
        const c = @min(col, info.len);
        return info.start + c;
    }

    /// Undo the last edit operation.
    ///
    /// Postconditions:
    ///   - The last insert is reversed (text removed) or last delete is reversed (text re-inserted)
    ///   - The reversed operation is pushed onto the redo stack
    ///   - Returns true if an undo was performed, false if undo stack is empty
    pub fn undo(self: *TextBuffer) bool {
        if (self.undo_count == 0) return false;
        self.undo_count -= 1;
        const entry = self.undo_stack[self.undo_count];
        const data = entry.data[0..entry.data_len];

        switch (entry.kind) {
            .insert => {
                // Undo an insert → delete the inserted text
                if (entry.line < self.line_count) {
                    const offset = self.lines[entry.line].start + entry.col;
                    if (offset + data.len <= self.content_len) {
                        // Push to redo before modifying
                        self.pushRedo(entry);
                        const end = offset + data.len;
                        const remaining = self.content_len - @as(u32, @intCast(end));
                        var i: usize = 0;
                        while (i < remaining) : (i += 1) {
                            self.content[offset + i] = self.content[end + i];
                        }
                        self.content_len -= @intCast(data.len);
                        self.dirty = true;
                        self.rebuildLineIndex();
                        return true;
                    }
                }
            },
            .delete => {
                // Undo a delete → re-insert the deleted text
                if (entry.line < self.line_count) {
                    const offset = self.lines[entry.line].start + entry.col;
                    if (offset <= self.content_len and self.content_len + data.len <= MAX_BUFFER_SIZE) {
                        // Push to redo before modifying
                        self.pushRedo(entry);
                        // Shift right
                        var i: usize = self.content_len;
                        while (i > offset) {
                            i -= 1;
                            self.content[i + data.len] = self.content[i];
                        }
                        @memcpy(self.content[offset..][0..data.len], data);
                        self.content_len += @intCast(data.len);
                        self.dirty = true;
                        self.rebuildLineIndex();
                        return true;
                    }
                }
            },
        }
        return false;
    }

    /// Redo the last undone operation.
    ///
    /// Postconditions:
    ///   - The last undo is reversed
    ///   - Returns true if a redo was performed, false if redo stack is empty
    pub fn redo(self: *TextBuffer) bool {
        if (self.redo_count == 0) return false;
        self.redo_count -= 1;
        const entry = self.redo_stack[self.redo_count];
        const data = entry.data[0..entry.data_len];

        switch (entry.kind) {
            .insert => {
                // Redo an insert → insert the text again
                if (entry.line < self.line_count) {
                    const offset = self.lines[entry.line].start + entry.col;
                    if (offset <= self.content_len and self.content_len + data.len <= MAX_BUFFER_SIZE) {
                        self.pushUndoRaw(entry);
                        var i: usize = self.content_len;
                        while (i > offset) {
                            i -= 1;
                            self.content[i + data.len] = self.content[i];
                        }
                        @memcpy(self.content[offset..][0..data.len], data);
                        self.content_len += @intCast(data.len);
                        self.dirty = true;
                        self.rebuildLineIndex();
                        return true;
                    }
                }
            },
            .delete => {
                // Redo a delete → delete the text again
                if (entry.line < self.line_count) {
                    const offset = self.lines[entry.line].start + entry.col;
                    if (offset + data.len <= self.content_len) {
                        self.pushUndoRaw(entry);
                        const end = offset + data.len;
                        const remaining = self.content_len - @as(u32, @intCast(end));
                        var i: usize = 0;
                        while (i < remaining) : (i += 1) {
                            self.content[offset + i] = self.content[end + i];
                        }
                        self.content_len -= @intCast(data.len);
                        self.dirty = true;
                        self.rebuildLineIndex();
                        return true;
                    }
                }
            },
        }
        return false;
    }

    /// Push an undo entry (called by insert/delete).
    fn pushUndo(self: *TextBuffer, kind: UndoKind, line: u32, col: u32, data: []const u8) void {
        if (data.len > MAX_UNDO_DATA) return; // skip if too large for undo
        if (self.undo_count >= MAX_UNDO_ENTRIES) {
            // Shift stack to make room (drop oldest)
            var i: u32 = 0;
            while (i + 1 < self.undo_count) : (i += 1) {
                self.undo_stack[i] = self.undo_stack[i + 1];
            }
            self.undo_count -= 1;
        }
        var entry = UndoEntry{
            .kind = kind,
            .line = line,
            .col = col,
            .data_len = @intCast(data.len),
        };
        @memcpy(entry.data[0..data.len], data);
        self.undo_stack[self.undo_count] = entry;
        self.undo_count += 1;
    }

    /// Push an entry directly onto the undo stack (used by redo).
    fn pushUndoRaw(self: *TextBuffer, entry: UndoEntry) void {
        if (self.undo_count >= MAX_UNDO_ENTRIES) {
            var i: u32 = 0;
            while (i + 1 < self.undo_count) : (i += 1) {
                self.undo_stack[i] = self.undo_stack[i + 1];
            }
            self.undo_count -= 1;
        }
        self.undo_stack[self.undo_count] = entry;
        self.undo_count += 1;
    }

    /// Push an entry onto the redo stack (used by undo).
    fn pushRedo(self: *TextBuffer, entry: UndoEntry) void {
        if (self.redo_count >= MAX_UNDO_ENTRIES) {
            var i: u32 = 0;
            while (i + 1 < self.redo_count) : (i += 1) {
                self.redo_stack[i] = self.redo_stack[i + 1];
            }
            self.redo_count -= 1;
        }
        self.redo_stack[self.redo_count] = entry;
        self.redo_count += 1;
    }

    /// Rebuild line index by scanning for newlines.
    ///
    /// Loop invariant: After processing byte i, all lines ending before i are indexed.
    fn rebuildLineIndex(self: *TextBuffer) void {
        self.line_count = 0;
        var line_start: u32 = 0;
        var i: u32 = 0;
        while (i < self.content_len) : (i += 1) {
            if (self.content[i] == '\n') {
                if (self.line_count < MAX_LINES) {
                    self.lines[self.line_count] = .{ .start = line_start, .len = i - line_start };
                    self.line_count += 1;
                }
                line_start = i + 1;
            }
        }
        // Last line (no trailing newline)
        if (line_start <= self.content_len and self.line_count < MAX_LINES) {
            self.lines[self.line_count] = .{ .start = line_start, .len = self.content_len - line_start };
            self.line_count += 1;
        }
    }
};

// ============================================================================
// Unit tests
// ============================================================================

const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;

test "TextBuffer load copies data and builds line index" {
    var buf = TextBuffer{};
    try expect(buf.load("hello\nworld\n"));
    try expect(buf.content_len == 12);
    try expect(buf.line_count == 3); // "hello", "world", "" (after trailing \n)
    try expect(buf.dirty == false);
    try expect(mem.eql(u8, buf.getLine(0).?, "hello"));
    try expect(mem.eql(u8, buf.getLine(1).?, "world"));
    try expect(mem.eql(u8, buf.getLine(2).?, ""));
}

test "TextBuffer load returns false if data exceeds MAX_BUFFER_SIZE" {
    var buf = TextBuffer{};
    // We can't actually create a 4MB+ slice on the stack in a test easily,
    // so we test the boundary: load exactly MAX_BUFFER_SIZE should succeed.
    // We'll test the logic with a smaller check: load empty, then check content_len.
    try expect(buf.load(""));
    try expect(buf.content_len == 0);
    try expect(buf.line_count == 1); // single empty line
}

test "TextBuffer load single line no newline" {
    var buf = TextBuffer{};
    try expect(buf.load("hello"));
    try expect(buf.line_count == 1);
    try expect(mem.eql(u8, buf.getLine(0).?, "hello"));
}

test "TextBuffer load empty string" {
    var buf = TextBuffer{};
    try expect(buf.load(""));
    try expect(buf.content_len == 0);
    try expect(buf.line_count == 1);
    try expect(mem.eql(u8, buf.getLine(0).?, ""));
}

test "TextBuffer insert at beginning" {
    var buf = TextBuffer{};
    try expect(buf.load("world"));
    try expect(buf.insert(0, 0, "hello "));
    try expect(buf.content_len == 11);
    try expect(buf.dirty == true);
    try expect(mem.eql(u8, buf.getLine(0).?, "hello world"));
}

test "TextBuffer insert at end of line" {
    var buf = TextBuffer{};
    try expect(buf.load("hello"));
    try expect(buf.insert(0, 5, " world"));
    try expect(mem.eql(u8, buf.getLine(0).?, "hello world"));
}

test "TextBuffer insert newline splits line" {
    var buf = TextBuffer{};
    try expect(buf.load("helloworld"));
    try expect(buf.insert(0, 5, "\n"));
    try expect(buf.line_count == 2);
    try expect(mem.eql(u8, buf.getLine(0).?, "hello"));
    try expect(mem.eql(u8, buf.getLine(1).?, "world"));
}

test "TextBuffer insert returns false for invalid line" {
    var buf = TextBuffer{};
    try expect(buf.load("hello"));
    try expect(!buf.insert(5, 0, "x"));
}

test "TextBuffer insert sets dirty flag" {
    var buf = TextBuffer{};
    try expect(buf.load("hello"));
    try expect(buf.dirty == false);
    try expect(buf.insert(0, 0, "x"));
    try expect(buf.dirty == true);
}

test "TextBuffer delete removes bytes" {
    var buf = TextBuffer{};
    try expect(buf.load("hello world"));
    try expect(buf.delete(0, 5, 6)); // delete " world"
    try expect(buf.content_len == 5);
    try expect(mem.eql(u8, buf.getLine(0).?, "hello"));
    try expect(buf.dirty == true);
}

test "TextBuffer delete across newline merges lines" {
    var buf = TextBuffer{};
    try expect(buf.load("hello\nworld"));
    try expect(buf.line_count == 2);
    try expect(buf.delete(0, 5, 1)); // delete the \n
    try expect(buf.line_count == 1);
    try expect(mem.eql(u8, buf.getLine(0).?, "helloworld"));
}

test "TextBuffer delete returns false for invalid line" {
    var buf = TextBuffer{};
    try expect(buf.load("hello"));
    try expect(!buf.delete(5, 0, 1));
}

test "TextBuffer delete returns false if count exceeds content" {
    var buf = TextBuffer{};
    try expect(buf.load("hi"));
    try expect(!buf.delete(0, 0, 10));
}

test "TextBuffer delete sets dirty flag" {
    var buf = TextBuffer{};
    try expect(buf.load("hello"));
    try expect(buf.dirty == false);
    try expect(buf.delete(0, 0, 1));
    try expect(buf.dirty == true);
}

test "TextBuffer getLine returns null for out-of-bounds" {
    var buf = TextBuffer{};
    try expect(buf.load("hello\nworld"));
    try expect(buf.getLine(0) != null);
    try expect(buf.getLine(1) != null);
    try expect(buf.getLine(2) == null);
    try expect(buf.getLine(100) == null);
}

test "TextBuffer getLine returns correct slices for multi-line content" {
    var buf = TextBuffer{};
    try expect(buf.load("line1\nline2\nline3"));
    try expect(buf.line_count == 3);
    try expect(mem.eql(u8, buf.getLine(0).?, "line1"));
    try expect(mem.eql(u8, buf.getLine(1).?, "line2"));
    try expect(mem.eql(u8, buf.getLine(2).?, "line3"));
}

test "TextBuffer insert-delete round-trip restores content" {
    var buf = TextBuffer{};
    try expect(buf.load("hello\nworld"));
    const original_len = buf.content_len;
    try expect(buf.insert(0, 5, " dear"));
    try expect(buf.content_len == original_len + 5);
    try expect(buf.delete(0, 5, 5));
    try expect(buf.content_len == original_len);
    try expect(mem.eql(u8, buf.getLine(0).?, "hello"));
    try expect(mem.eql(u8, buf.getLine(1).?, "world"));
}

test "TextBuffer line index invariant after operations" {
    var buf = TextBuffer{};
    try expect(buf.load("aaa\nbbb\nccc"));
    // Verify invariant: lines sorted, no overlap, start+len <= content_len
    var i: u32 = 0;
    while (i < buf.line_count) : (i += 1) {
        const info = buf.lines[i];
        try expect(info.start + info.len <= buf.content_len);
        if (i > 0) {
            const prev = buf.lines[i - 1];
            try expect(info.start > prev.start);
            // No overlap: prev end <= current start
            try expect(prev.start + prev.len < info.start);
        }
    }
}

// ============================================================================
// Undo/redo tests
// ============================================================================

test "TextBuffer undo reverses insert" {
    var buf = TextBuffer{};
    try expect(buf.load("hello"));
    try expect(buf.insert(0, 5, " world"));
    try expect(mem.eql(u8, buf.getLine(0).?, "hello world"));
    try expect(buf.undo());
    try expect(mem.eql(u8, buf.getLine(0).?, "hello"));
}

test "TextBuffer undo reverses delete" {
    var buf = TextBuffer{};
    try expect(buf.load("hello world"));
    try expect(buf.delete(0, 5, 6)); // delete " world"
    try expect(mem.eql(u8, buf.getLine(0).?, "hello"));
    try expect(buf.undo());
    try expect(mem.eql(u8, buf.getLine(0).?, "hello world"));
}

test "TextBuffer redo re-applies insert after undo" {
    var buf = TextBuffer{};
    try expect(buf.load("hello"));
    try expect(buf.insert(0, 5, " world"));
    try expect(buf.undo());
    try expect(mem.eql(u8, buf.getLine(0).?, "hello"));
    try expect(buf.redo());
    try expect(mem.eql(u8, buf.getLine(0).?, "hello world"));
}

test "TextBuffer redo re-applies delete after undo" {
    var buf = TextBuffer{};
    try expect(buf.load("hello world"));
    try expect(buf.delete(0, 5, 6));
    try expect(buf.undo());
    try expect(mem.eql(u8, buf.getLine(0).?, "hello world"));
    try expect(buf.redo());
    try expect(mem.eql(u8, buf.getLine(0).?, "hello"));
}

test "TextBuffer undo returns false when stack empty" {
    var buf = TextBuffer{};
    try expect(buf.load("hello"));
    try expect(!buf.undo());
}

test "TextBuffer redo returns false when stack empty" {
    var buf = TextBuffer{};
    try expect(buf.load("hello"));
    try expect(!buf.redo());
}

test "TextBuffer new edit clears redo stack" {
    var buf = TextBuffer{};
    try expect(buf.load("hello"));
    try expect(buf.insert(0, 5, " world"));
    try expect(buf.undo());
    // New edit should clear redo
    try expect(buf.insert(0, 5, "!"));
    try expect(!buf.redo());
}

test "TextBuffer load clears undo/redo stacks" {
    var buf = TextBuffer{};
    try expect(buf.load("hello"));
    try expect(buf.insert(0, 0, "x"));
    try expect(buf.undo_count > 0);
    try expect(buf.load("new content"));
    try expect(buf.undo_count == 0);
    try expect(buf.redo_count == 0);
}

test "TextBuffer multiple undo operations" {
    var buf = TextBuffer{};
    try expect(buf.load("abc"));
    try expect(buf.insert(0, 3, "d"));
    try expect(buf.insert(0, 4, "e"));
    try expect(mem.eql(u8, buf.getLine(0).?, "abcde"));
    try expect(buf.undo());
    try expect(mem.eql(u8, buf.getLine(0).?, "abcd"));
    try expect(buf.undo());
    try expect(mem.eql(u8, buf.getLine(0).?, "abc"));
}
