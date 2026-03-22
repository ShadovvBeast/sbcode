// Property-based test for TextBuffer getLine correctness
// **Validates: Requirement 5.4**
//
// Property 9: TextBuffer getLine Correctness
// For any TextBuffer with loaded content, getLine(i) for a valid line index i
// shall return a slice whose content matches the i-th newline-delimited segment
// of the raw content. getLine(i) for i >= line_count shall return null.

const std = @import("std");
const buffer = @import("buffer");
const expect = std.testing.expect;
const mem = std.mem;

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

/// Generate a random text payload with a mix of printable ASCII and newlines.
fn generateContent(rng: *Lcg, buf: []u8) []const u8 {
    const len = @as(usize, @intCast(rng.bounded(200))) + 1; // 1..200 bytes
    const actual_len = @min(len, buf.len);
    const charset = "abcdefghijklmnopqrstuvwxyz0123456789 \n\n";
    for (0..actual_len) |i| {
        buf[i] = charset[@as(usize, @intCast(rng.bounded(charset.len)))];
    }
    return buf[0..actual_len];
}

// --- Reference model: split content by newlines ---

/// Split raw content by '\n' and return the segments as slices.
/// Returns the number of segments written into `out`.
fn splitByNewlines(content: []const u8, out: *[buffer.MAX_LINES][]const u8) u32 {
    var count: u32 = 0;
    var line_start: usize = 0;
    for (content, 0..) |c, i| {
        if (c == '\n') {
            if (count < buffer.MAX_LINES) {
                out[count] = content[line_start..i];
                count += 1;
            }
            line_start = i + 1;
        }
    }
    // Last segment (after final newline, or entire content if no newline)
    if (count < buffer.MAX_LINES) {
        out[count] = content[line_start..];
        count += 1;
    }
    return count;
}

// --- Core property checker ---

/// Verify all getLine properties for a loaded TextBuffer against the original content.
fn checkGetLineProperty(tb: *const TextBuffer, original: []const u8) !void {
    // Build reference model by splitting original content on newlines
    var ref_lines: [buffer.MAX_LINES][]const u8 = undefined;
    const ref_count = splitByNewlines(original, &ref_lines);

    // line_count must match reference
    try expect(tb.line_count == ref_count);

    // Check each valid line index
    var i: u32 = 0;
    while (i < tb.line_count) : (i += 1) {
        const line = tb.getLine(i);

        // (1) getLine must return non-null for valid index
        try expect(line != null);
        const slice = line.?;

        // (2) Slice must match the corresponding reference segment
        try expect(mem.eql(u8, slice, ref_lines[i]));

        // (3) Slice must not contain any newline characters
        for (slice) |c| {
            try expect(c != '\n');
        }
    }

    // (4) getLine must return null for index >= line_count
    try expect(tb.getLine(tb.line_count) == null);
    try expect(tb.getLine(tb.line_count + 1) == null);
    try expect(tb.getLine(tb.line_count + 100) == null);

    // (5) Concatenating all getLine results with newlines reconstructs original content
    var reconstructed: [256]u8 = undefined;
    var pos: usize = 0;
    var j: u32 = 0;
    while (j < tb.line_count) : (j += 1) {
        const seg = tb.getLine(j).?;
        if (j > 0) {
            reconstructed[pos] = '\n';
            pos += 1;
        }
        @memcpy(reconstructed[pos..][0..seg.len], seg);
        pos += seg.len;
    }
    try expect(pos == original.len);
    try expect(mem.eql(u8, reconstructed[0..pos], original));
}

// --- Core property test logic ---

/// Load random content into a TextBuffer and verify getLine correctness.
fn runGetLineProperty(rng: *Lcg) !void {
    var tb = TextBuffer{};

    var content_buf: [256]u8 = undefined;
    const content = generateContent(rng, &content_buf);
    if (!tb.load(content)) return; // skip if load fails

    try checkGetLineProperty(&tb, content);
}

// --- Property tests across multiple seeds ---

test "Property 9: TextBuffer getLine correctness — basic seeds" {
    comptime var seed: u64 = 0;
    inline while (seed < 50) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runGetLineProperty(&rng);
    }
}

test "Property 9: TextBuffer getLine correctness — mid seeds" {
    comptime var seed: u64 = 100;
    inline while (seed < 150) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runGetLineProperty(&rng);
    }
}

test "Property 9: TextBuffer getLine correctness — high seeds" {
    comptime var seed: u64 = 500;
    inline while (seed < 550) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runGetLineProperty(&rng);
    }
}

test "Property 9: TextBuffer getLine correctness — empty content" {
    var tb = TextBuffer{};
    try expect(tb.load(""));
    try checkGetLineProperty(&tb, "");
}

test "Property 9: TextBuffer getLine correctness — single line no newline" {
    var tb = TextBuffer{};
    try expect(tb.load("hello"));
    try checkGetLineProperty(&tb, "hello");
}

test "Property 9: TextBuffer getLine correctness — trailing newline" {
    var tb = TextBuffer{};
    const content = "hello\nworld\n";
    try expect(tb.load(content));
    try checkGetLineProperty(&tb, content);
}

test "Property 9: TextBuffer getLine correctness — multiple consecutive newlines" {
    var tb = TextBuffer{};
    const content = "\n\n\n";
    try expect(tb.load(content));
    try checkGetLineProperty(&tb, content);
}

test "Property 9: TextBuffer getLine correctness — single newline" {
    var tb = TextBuffer{};
    const content = "\n";
    try expect(tb.load(content));
    try checkGetLineProperty(&tb, content);
}

test "Property 9: TextBuffer getLine correctness — out of bounds returns null" {
    var tb = TextBuffer{};
    try expect(tb.load("a\nb\nc"));
    try expect(tb.line_count == 3);
    try expect(tb.getLine(3) == null);
    try expect(tb.getLine(4) == null);
    try expect(tb.getLine(999) == null);
    try expect(tb.getLine(0xFFFFFFFF) == null);
}
