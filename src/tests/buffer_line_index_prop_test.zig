// Property-based test for TextBuffer line index invariant
// **Validates: Requirements 5.1, 5.2, 5.3, 5.7**
//
// Property 7: TextBuffer Line Index Invariant
// For any sequence of load, insert, and delete operations on a TextBuffer,
// the following invariants shall hold: (a) line_count equals the number of
// newline-delimited lines in content, (b) every LineInfo entry satisfies
// start + len <= content_len, (c) lines are sorted by start offset, and
// (d) no two lines overlap. Additionally, line_count > 0 for any loaded buffer.

const std = @import("std");
const buffer = @import("buffer");
const expect = std.testing.expect;

const TextBuffer = buffer.TextBuffer;

// --- Custom comptime LCG-based pseudo-random generator (zero dependencies) ---

const Lcg = struct {
    state: u64,

    const A: u64 = 6364136223846793005;
    const C: u64 = 1442695040888963407;

    fn init(seed: u64) Lcg {
        return .{ .state = seed };
    }

    fn next(self: *Lcg) u64 {
        self.state = self.state *% A +% C;
        return self.state;
    }

    /// Returns a value in [0, bound).
    fn bounded(self: *Lcg, bound: u64) u64 {
        return self.next() % bound;
    }
};

// --- Operation types ---

const OpKind = enum { insert, delete };

// --- Content generation helpers ---

/// Generate a random text payload for loading into the buffer.
/// Produces a mix of printable ASCII and newlines.
fn generateContent(rng: *Lcg, buf: []u8) []const u8 {
    const len = @as(usize, @intCast(rng.bounded(200))) + 1; // 1..200 bytes
    const actual_len = @min(len, buf.len);
    const charset = "abcdefghijklmnopqrstuvwxyz0123456789 \n\n";
    for (0..actual_len) |i| {
        buf[i] = charset[@as(usize, @intCast(rng.bounded(charset.len)))];
    }
    return buf[0..actual_len];
}

/// Generate a small text snippet for insertion (may contain newlines).
fn generateInsertText(rng: *Lcg, buf: []u8) []const u8 {
    const len = @as(usize, @intCast(rng.bounded(10))) + 1; // 1..10 bytes
    const actual_len = @min(len, buf.len);
    const charset = "abcdef\n";
    for (0..actual_len) |i| {
        buf[i] = charset[@as(usize, @intCast(rng.bounded(charset.len)))];
    }
    return buf[0..actual_len];
}

// --- Invariant checker ---

/// Verify all line index invariants on the given TextBuffer.
/// Returns an error if any invariant is violated.
fn checkLineIndexInvariants(buf: *const TextBuffer) !void {
    // Invariant: line_count > 0 for any loaded buffer
    try expect(buf.line_count > 0);

    // Count expected lines by scanning content for newlines
    var expected_lines: u32 = 1; // at least one line (the last segment)
    var i: u32 = 0;
    while (i < buf.content_len) : (i += 1) {
        if (buf.content[i] == '\n') {
            expected_lines += 1;
        }
    }
    // (a) line_count equals the number of newline-delimited lines
    try expect(buf.line_count == expected_lines);

    var prev_end: u32 = 0;
    var line_idx: u32 = 0;
    while (line_idx < buf.line_count) : (line_idx += 1) {
        const info = buf.lines[line_idx];

        // (b) Every LineInfo entry satisfies start + len <= content_len
        try expect(info.start + info.len <= buf.content_len);

        // (c) Lines are sorted by start offset (non-decreasing)
        if (line_idx > 0) {
            const prev_info = buf.lines[line_idx - 1];
            try expect(info.start > prev_info.start or (info.start == prev_info.start and info.len == 0 and prev_info.len == 0));
        }

        // (d) No two lines overlap: current start >= previous start + previous len
        if (line_idx > 0) {
            try expect(info.start >= prev_end);
        }

        // Lines cover content: line start should match expected position
        // (accounting for newline separators between lines)
        if (line_idx == 0) {
            try expect(info.start == 0);
        }

        prev_end = info.start + info.len;

        // Verify the line content doesn't contain newlines
        const line_content = buf.content[info.start..][0..info.len];
        for (line_content) |c| {
            try expect(c != '\n');
        }
    }
}

// --- Core property test logic ---

/// Run a random sequence of load/insert/delete operations and verify
/// the line index invariant holds after each operation.
fn runLineIndexProperty(rng: *Lcg) !void {
    var tb = TextBuffer{};

    // Generate and load initial content
    var content_buf: [256]u8 = undefined;
    const content = generateContent(rng, &content_buf);
    if (!tb.load(content)) return; // skip if load fails

    // Check invariant after load
    try checkLineIndexInvariants(&tb);

    // Perform a random sequence of insert/delete operations
    const num_ops = @as(usize, @intCast(rng.bounded(10))) + 1;

    for (0..num_ops) |_| {
        if (tb.line_count == 0) break;

        const op: OpKind = if (rng.bounded(2) == 0) .insert else .delete;

        switch (op) {
            .insert => {
                // Pick a random valid line and column
                const line = @as(u32, @intCast(rng.bounded(tb.line_count)));
                const line_len = tb.lines[line].len;
                const col = if (line_len > 0) @as(u32, @intCast(rng.bounded(line_len + 1))) else 0;

                var insert_buf: [16]u8 = undefined;
                const text = generateInsertText(rng, &insert_buf);

                _ = tb.insert(line, col, text);
                // Check invariant after insert (whether it succeeded or not)
                try checkLineIndexInvariants(&tb);
            },
            .delete => {
                // Pick a random valid line and column
                const line = @as(u32, @intCast(rng.bounded(tb.line_count)));
                const line_len = tb.lines[line].len;
                if (line_len == 0) continue; // nothing to delete on empty line

                const col = @as(u32, @intCast(rng.bounded(line_len)));
                const max_count = line_len - col;
                const count = @as(u32, @intCast(rng.bounded(max_count))) + 1;

                _ = tb.delete(line, col, count);
                // Check invariant after delete (whether it succeeded or not)
                try checkLineIndexInvariants(&tb);
            },
        }
    }
}

// --- Property tests across multiple seeds ---

test "Property 7: TextBuffer line index invariant — basic seeds" {
    comptime var seed: u64 = 0;
    inline while (seed < 50) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runLineIndexProperty(&rng);
    }
}

test "Property 7: TextBuffer line index invariant — mid seeds" {
    comptime var seed: u64 = 100;
    inline while (seed < 150) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runLineIndexProperty(&rng);
    }
}

test "Property 7: TextBuffer line index invariant — high seeds" {
    comptime var seed: u64 = 500;
    inline while (seed < 550) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runLineIndexProperty(&rng);
    }
}

test "Property 7: TextBuffer line index invariant — empty content" {
    var tb = TextBuffer{};
    try expect(tb.load(""));
    try checkLineIndexInvariants(&tb);

    // Insert into empty buffer
    try expect(tb.insert(0, 0, "hello\nworld"));
    try checkLineIndexInvariants(&tb);
}

test "Property 7: TextBuffer line index invariant — single line no newline" {
    var tb = TextBuffer{};
    try expect(tb.load("hello"));
    try checkLineIndexInvariants(&tb);
    try expect(tb.line_count == 1);
}

test "Property 7: TextBuffer line index invariant — trailing newline" {
    var tb = TextBuffer{};
    try expect(tb.load("hello\nworld\n"));
    try checkLineIndexInvariants(&tb);
    try expect(tb.line_count == 3); // "hello", "world", ""
}

test "Property 7: TextBuffer line index invariant — multiple newlines" {
    var tb = TextBuffer{};
    try expect(tb.load("\n\n\n"));
    try checkLineIndexInvariants(&tb);
    try expect(tb.line_count == 4); // "", "", "", ""
}

test "Property 7: TextBuffer line index invariant — insert then delete round-trip" {
    var tb = TextBuffer{};
    try expect(tb.load("aaa\nbbb\nccc"));
    try checkLineIndexInvariants(&tb);

    // Insert a newline in the middle of line 1
    try expect(tb.insert(1, 1, "\n"));
    try checkLineIndexInvariants(&tb);

    // Delete the newline we just inserted
    try expect(tb.delete(1, 1, 1));
    try checkLineIndexInvariants(&tb);
}
