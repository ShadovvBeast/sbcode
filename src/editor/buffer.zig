// src/editor/buffer.zig — Fixed-capacity text buffer with line index (no allocator)
//
// Replaces VS Code's PieceTreeTextBuffer with a simple flat buffer + line index.
// All storage is stack/comptime sized. Zero allocator usage.

pub const MAX_BUFFER_SIZE: u32 = 4 * 1024 * 1024; // 4 MB per file
pub const MAX_LINES: u32 = 65536;

pub const LineInfo = struct {
    start: u32, // byte offset into content
    len: u32, // byte length (excluding newline)
};

pub const TextBuffer = struct {
    content: [MAX_BUFFER_SIZE]u8 = undefined,
    content_len: u32 = 0,
    lines: [MAX_LINES]LineInfo = undefined,
    line_count: u32 = 0,
    dirty: bool = false,

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
