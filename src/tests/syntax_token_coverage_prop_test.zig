// Property-based test for Syntax Token Coverage Invariant
// **Validates: Requirements 7.1, 7.2, 7.4**
//
// Property 11: Syntax Token Coverage Invariant
// For any line of text tokenized by the SyntaxHighlighter, the resulting
// tokens shall be non-overlapping, ordered by start_col, and their lengths
// shall sum to the total line length. For consecutive tokens,
// token[i].start_col + token[i].len shall equal token[i+1].start_col.

const std = @import("std");
const syntax = @import("syntax");
const expect = std.testing.expect;

const SyntaxHighlighter = syntax.SyntaxHighlighter;
const LanguageId = syntax.LanguageId;
const LineSyntax = syntax.LineSyntax;

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

// --- Line generation helpers ---

/// Character classes that exercise different tokenizer paths.
const zig_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@\"'//+-*=%!<>&|^~(){}[];:,.# \t";
const json_chars = "abcdefghijklmnopqrstuvwxyz0123456789\"{}[]:, .-+eEnulltruefalse\t";
const plain_chars = "abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;':\",./<>?\t";

/// Generate a random line of text from a given character set.
fn generateLine(comptime max_len: usize, rng: *Lcg, charset: []const u8) struct { buf: [max_len]u8, len: usize } {
    var result: struct { buf: [max_len]u8, len: usize } = undefined;
    const line_len = @as(usize, @intCast(rng.bounded(max_len))) + 1; // 1..max_len
    for (0..line_len) |i| {
        result.buf[i] = charset[@as(usize, @intCast(rng.bounded(charset.len)))];
    }
    result.len = line_len;
    return result;
}

// --- Core property verification ---

/// Verify the token coverage invariant for a given LineSyntax and line length.
/// 1. Tokens are ordered by start_col (non-decreasing)
/// 2. Tokens are non-overlapping (each token starts where the previous one ends)
/// 3. First token starts at column 0
/// 4. Sum of all token lengths equals the line length (full coverage)
/// 5. All token lengths are > 0
fn verifyCoverageInvariant(ls: *const LineSyntax, line_len: u16) !void {
    if (line_len == 0) {
        // Property 6: Empty lines produce zero tokens
        try expect(ls.token_count == 0);
        return;
    }

    try expect(ls.token_count > 0);

    var total_len: u16 = 0;
    var i: u16 = 0;
    while (i < ls.token_count) : (i += 1) {
        const tok = ls.tokens[i];

        // Property 5: All token lengths are > 0
        try expect(tok.len > 0);

        if (i == 0) {
            // Property 3: First token starts at column 0
            try expect(tok.start_col == 0);
        } else {
            const prev = ls.tokens[i - 1];
            // Property 1: Tokens ordered by start_col (non-decreasing)
            try expect(tok.start_col >= prev.start_col);
            // Property 2: Non-overlapping — each token starts where previous ends
            try expect(tok.start_col == prev.start_col + prev.len);
        }

        total_len += tok.len;
    }

    // Property 4: Sum of all token lengths equals line length
    try expect(total_len == line_len);
}

// --- Property tests: plain_text tokenizer ---

test "Property 11: Token coverage — plain_text random lines" {
    comptime var seed: u64 = 0;
    inline while (seed < 50) : (seed += 1) {
        var rng = Lcg.init(seed);
        var sh = SyntaxHighlighter{ .language = .plain_text };
        const gen = generateLine(128, &rng, plain_chars);
        const line = gen.buf[0..gen.len];
        sh.tokenizeLine(0, line);
        try verifyCoverageInvariant(&sh.line_syntax[0], @intCast(line.len));
    }
}

test "Property 11: Token coverage — plain_text empty line" {
    var sh = SyntaxHighlighter{ .language = .plain_text };
    sh.tokenizeLine(0, "");
    try verifyCoverageInvariant(&sh.line_syntax[0], 0);
}

// --- Property tests: zig_lang tokenizer ---

test "Property 11: Token coverage — zig_lang random lines" {
    comptime var seed: u64 = 100;
    inline while (seed < 150) : (seed += 1) {
        var rng = Lcg.init(seed);
        var sh = SyntaxHighlighter{ .language = .zig_lang };
        const gen = generateLine(128, &rng, zig_chars);
        const line = gen.buf[0..gen.len];
        sh.tokenizeLine(0, line);
        try verifyCoverageInvariant(&sh.line_syntax[0], @intCast(line.len));
    }
}

test "Property 11: Token coverage — zig_lang keyword-heavy lines" {
    const keyword_lines = [_][]const u8{
        "const x = 42;",
        "pub fn main() void {}",
        "var y: u32 = @intCast(z);",
        "if (true) return else break;",
        "while (i < 10) : (i += 1) {}",
        "switch (x) { .a => {}, .b => {} }",
        "for (items) |item| { _ = item; }",
        "defer cleanup();",
        "errdefer handleError();",
        "comptime { _ = @sizeOf(u8); }",
    };
    for (keyword_lines) |line| {
        var sh = SyntaxHighlighter{ .language = .zig_lang };
        sh.tokenizeLine(0, line);
        try verifyCoverageInvariant(&sh.line_syntax[0], @intCast(line.len));
    }
}

test "Property 11: Token coverage — zig_lang empty line" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "");
    try verifyCoverageInvariant(&sh.line_syntax[0], 0);
}

test "Property 11: Token coverage — zig_lang strings and comments" {
    comptime var seed: u64 = 200;
    inline while (seed < 230) : (seed += 1) {
        var rng = Lcg.init(seed);
        var sh = SyntaxHighlighter{ .language = .zig_lang };
        // Generate lines that start with string or comment patterns
        const patterns = [_][]const u8{
            "\"hello world\"",
            "// this is a comment",
            "'a'",
            "\"escape\\\"inside\"",
            "@import(\"std\")",
            "0xFF + 42",
        };
        const idx = @as(usize, @intCast(rng.bounded(patterns.len)));
        sh.tokenizeLine(0, patterns[idx]);
        try verifyCoverageInvariant(&sh.line_syntax[0], @intCast(patterns[idx].len));
    }
}

// --- Property tests: json_lang tokenizer ---

test "Property 11: Token coverage — json_lang random lines" {
    comptime var seed: u64 = 300;
    inline while (seed < 350) : (seed += 1) {
        var rng = Lcg.init(seed);
        var sh = SyntaxHighlighter{ .language = .json_lang };
        const gen = generateLine(128, &rng, json_chars);
        const line = gen.buf[0..gen.len];
        sh.tokenizeLine(0, line);
        try verifyCoverageInvariant(&sh.line_syntax[0], @intCast(line.len));
    }
}

test "Property 11: Token coverage — json_lang structured lines" {
    const json_lines = [_][]const u8{
        "{\"name\": \"kiro\", \"version\": 1}",
        "[1, 2, 3, 4, 5]",
        "{\"enabled\": true, \"count\": null}",
        "\"hello world\"",
        "-3.14e+10",
        "{\"nested\": {\"key\": false}}",
        "[]",
        "{}",
    };
    for (json_lines) |line| {
        var sh = SyntaxHighlighter{ .language = .json_lang };
        sh.tokenizeLine(0, line);
        try verifyCoverageInvariant(&sh.line_syntax[0], @intCast(line.len));
    }
}

test "Property 11: Token coverage — json_lang empty line" {
    var sh = SyntaxHighlighter{ .language = .json_lang };
    sh.tokenizeLine(0, "");
    try verifyCoverageInvariant(&sh.line_syntax[0], 0);
}

// --- Cross-language property test ---

test "Property 11: Token coverage — all languages same input" {
    comptime var seed: u64 = 400;
    inline while (seed < 430) : (seed += 1) {
        var rng = Lcg.init(seed);
        const gen = generateLine(64, &rng, plain_chars);
        const line = gen.buf[0..gen.len];

        // plain_text
        var sh_plain = SyntaxHighlighter{ .language = .plain_text };
        sh_plain.tokenizeLine(0, line);
        try verifyCoverageInvariant(&sh_plain.line_syntax[0], @intCast(line.len));

        // zig_lang
        var sh_zig = SyntaxHighlighter{ .language = .zig_lang };
        sh_zig.tokenizeLine(0, line);
        try verifyCoverageInvariant(&sh_zig.line_syntax[0], @intCast(line.len));

        // json_lang
        var sh_json = SyntaxHighlighter{ .language = .json_lang };
        sh_json.tokenizeLine(0, line);
        try verifyCoverageInvariant(&sh_json.line_syntax[0], @intCast(line.len));
    }
}
