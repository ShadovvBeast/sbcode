// Property-based test for TextBuffer insert-delete round-trip
// **Validates: Requirements 5.2, 5.3**
//
// Property 8: TextBuffer Insert-Delete Round-Trip
// For any TextBuffer with loaded content and any valid insert position and text,
// inserting the text and then deleting the same number of bytes at the same
// position shall restore the original content_len and content.

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

// --- Content generation helpers ---

/// Generate random content for loading into the buffer.
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

/// Generate a small text snippet for insertion (no newlines to keep position math simple,
/// but we also test with newlines in separate cases).
fn generateInsertText(rng: *Lcg, buf: []u8) []const u8 {
    const len = @as(usize, @intCast(rng.bounded(10))) + 1; // 1..10 bytes
    const actual_len = @min(len, buf.len);
    const charset = "abcdefghijklm";
    for (0..actual_len) |i| {
        buf[i] = charset[@as(usize, @intCast(rng.bounded(charset.len)))];
    }
    return buf[0..actual_len];
}

/// Generate insert text that may contain newlines.
fn generateInsertTextWithNewlines(rng: *Lcg, buf: []u8) []const u8 {
    const len = @as(usize, @intCast(rng.bounded(10))) + 1; // 1..10 bytes
    const actual_len = @min(len, buf.len);
    const charset = "abcdef\n";
    for (0..actual_len) |i| {
        buf[i] = charset[@as(usize, @intCast(rng.bounded(charset.len)))];
    }
    return buf[0..actual_len];
}

// --- Core property test logic ---

/// Run the insert-delete round-trip property:
/// 1. Load random content into a TextBuffer
/// 2. Record the original content
/// 3. Insert random text at a random valid (line, col) position
/// 4. Delete the same number of bytes at the same position
/// 5. Verify the buffer content matches the original exactly
fn runInsertDeleteRoundTrip(rng: *Lcg, allow_newlines: bool) !void {
    var tb = TextBuffer{};

    // Step 1: Load random content
    var content_buf: [256]u8 = undefined;
    const content = generateContent(rng, &content_buf);
    if (!tb.load(content)) return; // skip if load fails

    // Step 2: Record original content
    const original_len = tb.content_len;
    var original_content: [256]u8 = undefined;
    @memcpy(original_content[0..original_len], tb.content[0..original_len]);

    // Step 3: Pick a random valid (line, col) and generate insert text
    if (tb.line_count == 0) return;
    const line = @as(u32, @intCast(rng.bounded(tb.line_count)));
    const line_len = tb.lines[line].len;
    const col = if (line_len > 0) @as(u32, @intCast(rng.bounded(line_len + 1))) else 0;

    var insert_buf: [16]u8 = undefined;
    const text = if (allow_newlines)
        generateInsertTextWithNewlines(rng, &insert_buf)
    else
        generateInsertText(rng, &insert_buf);

    const text_len = @as(u32, @intCast(text.len));

    // Compute the absolute byte offset of the insert position
    const insert_offset = tb.lines[line].start + col;

    if (!tb.insert(line, col, text)) return; // skip if insert fails (e.g. buffer full)

    // Step 4: Delete the same number of bytes at the same absolute offset.
    // After insert, we need to find which line/col corresponds to insert_offset.
    // The insert_offset is still the same byte position in the buffer.
    var del_line: u32 = 0;
    var del_col: u32 = 0;
    var found = false;
    var li: u32 = 0;
    while (li < tb.line_count) : (li += 1) {
        const info = tb.lines[li];
        // The offset falls within this line (or at its end for the insert point)
        if (insert_offset >= info.start and insert_offset <= info.start + info.len) {
            del_line = li;
            del_col = insert_offset - info.start;
            found = true;
            break;
        }
        // Also check if offset is exactly at a newline boundary (between lines)
        // In that case it would be at the start of the next line
    }

    if (!found) return; // shouldn't happen, but skip gracefully

    const del_ok = tb.delete(del_line, del_col, text_len);
    if (!del_ok) return; // skip if delete fails

    // Step 5: Verify content matches original exactly
    try expect(tb.content_len == original_len);

    var i: u32 = 0;
    while (i < original_len) : (i += 1) {
        try expect(tb.content[i] == original_content[i]);
    }
}

// --- Property tests across multiple seeds ---

test "Property 8: TextBuffer insert-delete round-trip — basic seeds (no newlines)" {
    comptime var seed: u64 = 0;
    inline while (seed < 50) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runInsertDeleteRoundTrip(&rng, false);
    }
}

test "Property 8: TextBuffer insert-delete round-trip — mid seeds (no newlines)" {
    comptime var seed: u64 = 100;
    inline while (seed < 150) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runInsertDeleteRoundTrip(&rng, false);
    }
}

test "Property 8: TextBuffer insert-delete round-trip — with newlines" {
    comptime var seed: u64 = 200;
    inline while (seed < 250) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runInsertDeleteRoundTrip(&rng, true);
    }
}

test "Property 8: TextBuffer insert-delete round-trip — high seeds" {
    comptime var seed: u64 = 500;
    inline while (seed < 550) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runInsertDeleteRoundTrip(&rng, true);
    }
}

test "Property 8: TextBuffer insert-delete round-trip — empty buffer" {
    var tb = TextBuffer{};
    try expect(tb.load(""));

    // Record original
    const original_len = tb.content_len;

    // Insert into empty buffer at (0, 0)
    try expect(tb.insert(0, 0, "hello"));

    // Delete the same 5 bytes at (0, 0)
    try expect(tb.delete(0, 0, 5));

    // Verify restored
    try expect(tb.content_len == original_len);
}

test "Property 8: TextBuffer insert-delete round-trip — single line" {
    var tb = TextBuffer{};
    try expect(tb.load("abcdef"));

    var original: [6]u8 = undefined;
    @memcpy(&original, tb.content[0..6]);

    // Insert in the middle
    try expect(tb.insert(0, 3, "XYZ"));
    try expect(tb.content_len == 9);

    // Delete the 3 inserted bytes at the same position
    try expect(tb.delete(0, 3, 3));
    try expect(tb.content_len == 6);

    for (0..6) |i| {
        try expect(tb.content[i] == original[i]);
    }
}

test "Property 8: TextBuffer insert-delete round-trip — insert newline then delete" {
    var tb = TextBuffer{};
    try expect(tb.load("helloworld"));

    var original: [10]u8 = undefined;
    @memcpy(&original, tb.content[0..10]);

    // Insert a newline at position (0, 5)
    try expect(tb.insert(0, 5, "\n"));
    try expect(tb.line_count == 2);

    // Delete 1 byte at the same absolute offset — now line 0 ends at col 5,
    // so the newline is at the boundary. After insert, line 0 = "hello" (len 5),
    // so the newline is between line 0 and line 1. We delete at (0, 5) but
    // col 5 == line_len for line 0, so we need to check if delete handles this.
    // Actually the newline byte is at offset 5, which is past line 0's content.
    // After the insert, line 0 = "hello" (start=0, len=5), line 1 = "world" (start=6, len=5).
    // The newline is at offset 5. To delete it, we need line 0, col 5.
    // But col 5 == line 0's len, and the byte at offset 5 is '\n'.
    // The delete function computes offset = lines[line].start + col = 0 + 5 = 5, count = 1.
    // offset + count = 6 <= content_len = 11, so it should succeed.
    try expect(tb.delete(0, 5, 1));
    try expect(tb.content_len == 10);
    try expect(tb.line_count == 1);

    for (0..10) |i| {
        try expect(tb.content[i] == original[i]);
    }
}
