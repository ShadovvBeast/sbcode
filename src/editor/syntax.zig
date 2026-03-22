// src/editor/syntax.zig — Token-based syntax highlighting (no allocator)
//
// Replaces VS Code's ITokenizationSupport with per-language tokenizers
// producing non-overlapping, ordered syntax tokens for each line.
// All storage is stack/comptime sized. Zero allocator usage.

pub const TokenKind = enum(u8) {
    plain,
    keyword,
    string_literal,
    number_literal,
    comment,
    type_name,
    function_name,
    operator,
    punctuation,
    preprocessor,
    builtin,
};

pub const SyntaxToken = struct {
    start_col: u16,
    len: u16,
    kind: TokenKind,
};

pub const MAX_TOKENS_PER_LINE = 128;

pub const LineSyntax = struct {
    tokens: [MAX_TOKENS_PER_LINE]SyntaxToken = undefined,
    token_count: u16 = 0,

    fn addToken(self: *LineSyntax, start: u16, length: u16, kind: TokenKind) void {
        if (self.token_count >= MAX_TOKENS_PER_LINE or length == 0) return;
        self.tokens[self.token_count] = .{ .start_col = start, .len = length, .kind = kind };
        self.token_count += 1;
    }
};

pub const MAX_SYNTAX_LINES = 65536;

pub const LanguageId = enum(u8) {
    plain_text,
    zig_lang,
    json_lang,
    markdown,
    typescript,
    javascript,
    python,
    c_lang,
    cpp_lang,
    rust_lang,
    go_lang,
    html,
    css,
};

pub const SyntaxHighlighter = struct {
    line_syntax: [MAX_SYNTAX_LINES]LineSyntax = undefined,
    language: LanguageId = .plain_text,

    /// Tokenize a single line for syntax highlighting.
    ///
    /// Preconditions:
    ///   - `line_idx` < MAX_SYNTAX_LINES
    ///
    /// Postconditions:
    ///   - self.line_syntax[line_idx] contains tokens covering the full line
    ///   - Token spans are non-overlapping and ordered by start_col
    ///   - Sum of all token lengths == line_text.len
    pub fn tokenizeLine(self: *SyntaxHighlighter, line_idx: u32, line_text: []const u8) void {
        if (line_idx >= MAX_SYNTAX_LINES) return;
        var ls = &self.line_syntax[line_idx];
        ls.token_count = 0;

        if (line_text.len == 0) return;

        switch (self.language) {
            .zig_lang => tokenizeZig(ls, line_text),
            .json_lang => tokenizeJson(ls, line_text),
            else => {
                // Plain text: single token for entire line
                ls.addToken(0, @intCast(line_text.len), .plain);
            },
        }
    }

    // ========================================================================
    // Zig tokenizer
    // ========================================================================

    const zig_keywords = [_][]const u8{
        "addrspace", "align",     "allowzero",   "and",
        "anyframe",  "anytype",   "asm",         "async",
        "await",     "break",     "callconv",    "catch",
        "comptime",  "const",     "continue",    "defer",
        "else",      "enum",      "errdefer",    "error",
        "export",    "extern",    "false",       "fn",
        "for",       "if",        "inline",      "linksection",
        "noalias",   "nosuspend", "null",        "opaque",
        "or",        "orelse",    "packed",      "pub",
        "resume",    "return",    "struct",      "suspend",
        "switch",    "test",      "threadlocal", "true",
        "try",       "undefined", "union",       "unreachable",
        "var",       "volatile",  "while",
    };

    fn isZigKeyword(word: []const u8) bool {
        for (zig_keywords) |kw| {
            if (eql(word, kw)) return true;
        }
        return false;
    }

    fn eql(a: []const u8, b: []const u8) bool {
        if (a.len != b.len) return false;
        for (a, b) |ca, cb| {
            if (ca != cb) return false;
        }
        return true;
    }

    fn isAlpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
    }

    fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    fn isAlnum(c: u8) bool {
        return isAlpha(c) or isDigit(c);
    }

    fn isHexDigit(c: u8) bool {
        return isDigit(c) or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
    }

    fn isWhitespace(c: u8) bool {
        return c == ' ' or c == '\t' or c == '\r';
    }

    fn tokenizeZig(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);

        while (pos < len) {
            if (ls.token_count >= MAX_TOKENS_PER_LINE - 1) {
                // Reserve last slot for remainder
                ls.addToken(pos, len - pos, .plain);
                return;
            }

            const c = text[pos];

            // Line comment: // to end of line
            if (pos + 1 < len and c == '/' and text[pos + 1] == '/') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }

            // String literal: "..."
            if (c == '"') {
                const start = pos;
                pos += 1;
                while (pos < len) {
                    if (text[pos] == '\\' and pos + 1 < len) {
                        pos += 2; // skip escape
                    } else if (text[pos] == '"') {
                        pos += 1;
                        break;
                    } else {
                        pos += 1;
                    }
                }
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            // Character literal: '...'
            if (c == '\'') {
                const start = pos;
                pos += 1;
                while (pos < len) {
                    if (text[pos] == '\\' and pos + 1 < len) {
                        pos += 2;
                    } else if (text[pos] == '\'') {
                        pos += 1;
                        break;
                    } else {
                        pos += 1;
                    }
                }
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            // Builtin: @identifier
            if (c == '@' and pos + 1 < len and isAlpha(text[pos + 1])) {
                const start = pos;
                pos += 1; // skip @
                while (pos < len and isAlnum(text[pos])) : (pos += 1) {}
                ls.addToken(start, pos - start, .builtin);
                continue;
            }

            // Number: decimal or hex (0x...)
            if (isDigit(c)) {
                const start = pos;
                if (c == '0' and pos + 1 < len and (text[pos + 1] == 'x' or text[pos + 1] == 'X')) {
                    pos += 2; // skip 0x
                    while (pos < len and (isHexDigit(text[pos]) or text[pos] == '_')) : (pos += 1) {}
                } else {
                    while (pos < len and (isDigit(text[pos]) or text[pos] == '_' or text[pos] == '.')) : (pos += 1) {}
                }
                ls.addToken(start, pos - start, .number_literal);
                continue;
            }

            // Identifier or keyword
            if (isAlpha(c)) {
                const start = pos;
                while (pos < len and isAlnum(text[pos])) : (pos += 1) {}
                const word = text[start..pos];
                const kind: TokenKind = if (isZigKeyword(word)) .keyword else .plain;
                ls.addToken(start, pos - start, kind);
                continue;
            }

            // Whitespace
            if (isWhitespace(c)) {
                const start = pos;
                while (pos < len and isWhitespace(text[pos])) : (pos += 1) {}
                ls.addToken(start, pos - start, .plain);
                continue;
            }

            // Operators
            if (c == '+' or c == '-' or c == '*' or c == '/' or
                c == '%' or c == '=' or c == '!' or c == '<' or
                c == '>' or c == '&' or c == '|' or c == '^' or c == '~')
            {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }

            // Punctuation
            if (c == '(' or c == ')' or c == '{' or c == '}' or
                c == '[' or c == ']' or c == ';' or c == ':' or
                c == ',' or c == '.' or c == '#')
            {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }

            // Anything else: plain
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // JSON tokenizer
    // ========================================================================

    fn tokenizeJson(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);

        while (pos < len) {
            if (ls.token_count >= MAX_TOKENS_PER_LINE - 1) {
                ls.addToken(pos, len - pos, .plain);
                return;
            }

            const c = text[pos];

            // String: "..."
            if (c == '"') {
                const start = pos;
                pos += 1;
                while (pos < len) {
                    if (text[pos] == '\\' and pos + 1 < len) {
                        pos += 2;
                    } else if (text[pos] == '"') {
                        pos += 1;
                        break;
                    } else {
                        pos += 1;
                    }
                }
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            // Number: optional minus, digits, optional decimal
            if (isDigit(c) or (c == '-' and pos + 1 < len and isDigit(text[pos + 1]))) {
                const start = pos;
                if (c == '-') pos += 1;
                while (pos < len and isDigit(text[pos])) : (pos += 1) {}
                if (pos < len and text[pos] == '.') {
                    pos += 1;
                    while (pos < len and isDigit(text[pos])) : (pos += 1) {}
                }
                // Exponent
                if (pos < len and (text[pos] == 'e' or text[pos] == 'E')) {
                    pos += 1;
                    if (pos < len and (text[pos] == '+' or text[pos] == '-')) pos += 1;
                    while (pos < len and isDigit(text[pos])) : (pos += 1) {}
                }
                ls.addToken(start, pos - start, .number_literal);
                continue;
            }

            // true / false / null
            if (matchLiteral(text, pos, "true") or matchLiteral(text, pos, "false")) {
                const word_len: u16 = if (text[pos] == 't') 4 else 5;
                ls.addToken(pos, word_len, .keyword);
                pos += word_len;
                continue;
            }
            if (matchLiteral(text, pos, "null")) {
                ls.addToken(pos, 4, .keyword);
                pos += 4;
                continue;
            }

            // Punctuation: { } [ ] : ,
            if (c == '{' or c == '}' or c == '[' or c == ']' or c == ':' or c == ',') {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }

            // Whitespace
            if (isWhitespace(c)) {
                const start = pos;
                while (pos < len and isWhitespace(text[pos])) : (pos += 1) {}
                ls.addToken(start, pos - start, .plain);
                continue;
            }

            // Anything else: plain
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    fn matchLiteral(text: []const u8, pos: u16, literal: []const u8) bool {
        if (pos + literal.len > text.len) return false;
        for (literal, 0..) |ch, i| {
            if (text[pos + i] != ch) return false;
        }
        // Ensure the literal is not part of a longer identifier
        const end = pos + @as(u16, @intCast(literal.len));
        if (end < text.len and isAlpha(text[end])) return false;
        return true;
    }
};

// ============================================================================
// Unit tests
// ============================================================================

const std = @import("std");
const expect = std.testing.expect;

// --- Helper: verify token coverage invariant ---
fn verifyTokenCoverage(ls: *const LineSyntax, line_len: u16) !void {
    if (line_len == 0) {
        try expect(ls.token_count == 0);
        return;
    }
    try expect(ls.token_count > 0);

    // Tokens are ordered and non-overlapping
    var total_len: u16 = 0;
    var i: u16 = 0;
    while (i < ls.token_count) : (i += 1) {
        const tok = ls.tokens[i];
        if (i > 0) {
            const prev = ls.tokens[i - 1];
            try expect(tok.start_col == prev.start_col + prev.len);
        } else {
            try expect(tok.start_col == 0);
        }
        try expect(tok.len > 0);
        total_len += tok.len;
    }
    try expect(total_len == line_len);
}

// --- Plain text tests ---

test "SyntaxHighlighter plain text — single token for entire line" {
    var sh = SyntaxHighlighter{ .language = .plain_text };
    sh.tokenizeLine(0, "hello world");
    const ls = sh.line_syntax[0];
    try expect(ls.token_count == 1);
    try expect(ls.tokens[0].start_col == 0);
    try expect(ls.tokens[0].len == 11);
    try expect(ls.tokens[0].kind == .plain);
    try verifyTokenCoverage(&ls, 11);
}

test "SyntaxHighlighter plain text — empty line produces zero tokens" {
    var sh = SyntaxHighlighter{ .language = .plain_text };
    sh.tokenizeLine(0, "");
    try expect(sh.line_syntax[0].token_count == 0);
}

test "SyntaxHighlighter plain text — unsupported language falls back to plain" {
    var sh = SyntaxHighlighter{ .language = .python };
    sh.tokenizeLine(0, "def foo():");
    const ls = sh.line_syntax[0];
    try expect(ls.token_count == 1);
    try expect(ls.tokens[0].kind == .plain);
    try verifyTokenCoverage(&ls, 10);
}

// --- Zig tokenizer tests ---

test "SyntaxHighlighter Zig — keywords recognized" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "const x = 5;");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .keyword); // const
    try verifyTokenCoverage(&ls, 12);
}

test "SyntaxHighlighter Zig — fn keyword" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "pub fn main() void {");
    const ls = sh.line_syntax[0];
    // pub = keyword, space, fn = keyword, space, main = plain, ...
    try expect(ls.tokens[0].kind == .keyword); // pub
    try expect(ls.tokens[2].kind == .keyword); // fn
    try verifyTokenCoverage(&ls, 20);
}

test "SyntaxHighlighter Zig — string literal" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "const s = \"hello\";");
    const ls = sh.line_syntax[0];
    // Find the string token
    var found_string = false;
    var i: u16 = 0;
    while (i < ls.token_count) : (i += 1) {
        if (ls.tokens[i].kind == .string_literal) {
            found_string = true;
            break;
        }
    }
    try expect(found_string);
    try verifyTokenCoverage(&ls, 18);
}

test "SyntaxHighlighter Zig — line comment" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "x = 1; // comment");
    const ls = sh.line_syntax[0];
    // Last token should be a comment
    try expect(ls.token_count > 0);
    try expect(ls.tokens[ls.token_count - 1].kind == .comment);
    try verifyTokenCoverage(&ls, 17);
}

test "SyntaxHighlighter Zig — number decimal" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "42");
    const ls = sh.line_syntax[0];
    try expect(ls.token_count == 1);
    try expect(ls.tokens[0].kind == .number_literal);
    try verifyTokenCoverage(&ls, 2);
}

test "SyntaxHighlighter Zig — number hex" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "0xFF");
    const ls = sh.line_syntax[0];
    try expect(ls.token_count == 1);
    try expect(ls.tokens[0].kind == .number_literal);
    try expect(ls.tokens[0].len == 4);
    try verifyTokenCoverage(&ls, 4);
}

test "SyntaxHighlighter Zig — builtin @import" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "@import(\"std\")");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .builtin);
    try verifyTokenCoverage(&ls, 14);
}

test "SyntaxHighlighter Zig — operators and punctuation" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "a + b;");
    const ls = sh.line_syntax[0];
    try verifyTokenCoverage(&ls, 6);
    // Find operator +
    var found_op = false;
    var i: u16 = 0;
    while (i < ls.token_count) : (i += 1) {
        if (ls.tokens[i].kind == .operator) {
            found_op = true;
            break;
        }
    }
    try expect(found_op);
}

test "SyntaxHighlighter Zig — string with escape" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "\"he\\\"llo\"");
    const ls = sh.line_syntax[0];
    try expect(ls.token_count == 1);
    try expect(ls.tokens[0].kind == .string_literal);
    try expect(ls.tokens[0].len == 9);
    try verifyTokenCoverage(&ls, 9);
}

test "SyntaxHighlighter Zig — full line comment" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "// this is a comment");
    const ls = sh.line_syntax[0];
    try expect(ls.token_count == 1);
    try expect(ls.tokens[0].kind == .comment);
    try expect(ls.tokens[0].len == 20);
    try verifyTokenCoverage(&ls, 20);
}

// --- JSON tokenizer tests ---

test "SyntaxHighlighter JSON — string key-value" {
    var sh = SyntaxHighlighter{ .language = .json_lang };
    sh.tokenizeLine(0, "\"key\": \"value\"");
    const ls = sh.line_syntax[0];
    try verifyTokenCoverage(&ls, 14);
    // First token should be a string
    try expect(ls.tokens[0].kind == .string_literal);
}

test "SyntaxHighlighter JSON — number" {
    var sh = SyntaxHighlighter{ .language = .json_lang };
    sh.tokenizeLine(0, "42");
    const ls = sh.line_syntax[0];
    try expect(ls.token_count == 1);
    try expect(ls.tokens[0].kind == .number_literal);
    try verifyTokenCoverage(&ls, 2);
}

test "SyntaxHighlighter JSON — negative number" {
    var sh = SyntaxHighlighter{ .language = .json_lang };
    sh.tokenizeLine(0, "-3.14");
    const ls = sh.line_syntax[0];
    try expect(ls.token_count == 1);
    try expect(ls.tokens[0].kind == .number_literal);
    try verifyTokenCoverage(&ls, 5);
}

test "SyntaxHighlighter JSON — true false null" {
    var sh = SyntaxHighlighter{ .language = .json_lang };
    sh.tokenizeLine(0, "true");
    try expect(sh.line_syntax[0].tokens[0].kind == .keyword);
    try verifyTokenCoverage(&sh.line_syntax[0], 4);

    sh.tokenizeLine(1, "false");
    try expect(sh.line_syntax[1].tokens[0].kind == .keyword);
    try verifyTokenCoverage(&sh.line_syntax[1], 5);

    sh.tokenizeLine(2, "null");
    try expect(sh.line_syntax[2].tokens[0].kind == .keyword);
    try verifyTokenCoverage(&sh.line_syntax[2], 4);
}

test "SyntaxHighlighter JSON — punctuation" {
    var sh = SyntaxHighlighter{ .language = .json_lang };
    sh.tokenizeLine(0, "{[]}:,");
    const ls = sh.line_syntax[0];
    try expect(ls.token_count == 6);
    var i: u16 = 0;
    while (i < ls.token_count) : (i += 1) {
        try expect(ls.tokens[i].kind == .punctuation);
    }
    try verifyTokenCoverage(&ls, 6);
}

test "SyntaxHighlighter JSON — mixed line" {
    var sh = SyntaxHighlighter{ .language = .json_lang };
    sh.tokenizeLine(0, "{\"name\": \"kiro\", \"v\": 1}");
    const ls = sh.line_syntax[0];
    try verifyTokenCoverage(&ls, 24);
}

// --- Edge cases ---

test "SyntaxHighlighter line_idx out of bounds is no-op" {
    var sh = SyntaxHighlighter{ .language = .plain_text };
    sh.tokenizeLine(MAX_SYNTAX_LINES, "hello");
    // No crash, no-op
}

test "SyntaxHighlighter Zig — empty line" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "");
    try expect(sh.line_syntax[0].token_count == 0);
}

test "SyntaxHighlighter JSON — empty line" {
    var sh = SyntaxHighlighter{ .language = .json_lang };
    sh.tokenizeLine(0, "");
    try expect(sh.line_syntax[0].token_count == 0);
}

test "SyntaxHighlighter Zig — whitespace only" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "   \t  ");
    const ls = sh.line_syntax[0];
    try verifyTokenCoverage(&ls, 6);
    try expect(ls.tokens[0].kind == .plain);
}

test "SyntaxHighlighter JSON — string with escape" {
    var sh = SyntaxHighlighter{ .language = .json_lang };
    sh.tokenizeLine(0, "\"he\\\"llo\"");
    const ls = sh.line_syntax[0];
    try expect(ls.token_count == 1);
    try expect(ls.tokens[0].kind == .string_literal);
    try verifyTokenCoverage(&ls, 9);
}
