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

    pub fn addToken(self: *LineSyntax, start: u16, length: u16, kind: TokenKind) void {
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
    // HIGH priority
    java,
    csharp,
    php,
    ruby,
    shellscript,
    sql,
    xml,
    yaml,
    // MEDIUM priority
    bat,
    dart,
    diff_lang,
    docker,
    ini,
    less,
    lua,
    make,
    perl,
    powershell,
    r_lang,
    scss,
    swift,
    // LOW priority
    clojure,
    coffeescript,
    dotenv,
    fsharp,
    groovy,
    handlebars,
    hlsl,
    julia,
    latex,
    log,
    objc,
    pug,
    razor,
    restructuredtext,
    shaderlab,
    vb,
};

pub const SyntaxHighlighter = struct {
    line_syntax: [MAX_SYNTAX_LINES]LineSyntax = undefined,
    language: LanguageId = .plain_text,

    pub fn tokenizeLine(self: *SyntaxHighlighter, line_idx: u32, line_text: []const u8) void {
        if (line_idx >= MAX_SYNTAX_LINES) return;
        var ls = &self.line_syntax[line_idx];
        ls.token_count = 0;

        if (line_text.len == 0) return;

        switch (self.language) {
            .zig_lang => tokenizeZig(ls, line_text),
            .json_lang => tokenizeJson(ls, line_text),
            .markdown => tokenizeMarkdown(ls, line_text),
            .typescript, .javascript => tokenizeJsTsCommon(ls, line_text),
            .python => tokenizePython(ls, line_text),
            .c_lang, .cpp_lang => tokenizeCCpp(ls, line_text),
            .rust_lang => tokenizeRust(ls, line_text),
            .go_lang => tokenizeGo(ls, line_text),
            .html => tokenizeHtml(ls, line_text),
            .css => tokenizeCss(ls, line_text),
            .java => tokenizeJava(ls, line_text),
            .csharp => tokenizeCSharp(ls, line_text),
            .php => tokenizePhp(ls, line_text),
            .ruby => tokenizeRuby(ls, line_text),
            .shellscript => tokenizeShell(ls, line_text),
            .sql => tokenizeSql(ls, line_text),
            .xml => tokenizeXml(ls, line_text),
            .yaml => tokenizeYaml(ls, line_text),
            .bat => tokenizeBat(ls, line_text),
            .dart => tokenizeDart(ls, line_text),
            .diff_lang => tokenizeDiff(ls, line_text),
            .docker => tokenizeDocker(ls, line_text),
            .ini => tokenizeIni(ls, line_text),
            .less, .scss => tokenizeCss(ls, line_text),
            .lua => tokenizeLua(ls, line_text),
            .make => tokenizeMake(ls, line_text),
            .perl => tokenizePerl(ls, line_text),
            .powershell => tokenizePowershell(ls, line_text),
            .r_lang => tokenizeR(ls, line_text),
            .swift => tokenizeSwift(ls, line_text),
            .clojure => tokenizeClojure(ls, line_text),
            .coffeescript => tokenizeCoffee(ls, line_text),
            .dotenv => tokenizeIni(ls, line_text),
            .fsharp => tokenizeFSharp(ls, line_text),
            .groovy => tokenizeJava(ls, line_text),
            .handlebars => tokenizeHtml(ls, line_text),
            .hlsl => tokenizeCCpp(ls, line_text),
            .julia => tokenizeJulia(ls, line_text),
            .latex => tokenizeLatex(ls, line_text),
            .log => tokenizeLog(ls, line_text),
            .objc => tokenizeCCpp(ls, line_text),
            .pug => tokenizeHtml(ls, line_text),
            .razor => tokenizeHtml(ls, line_text),
            .restructuredtext => tokenizeRst(ls, line_text),
            .shaderlab => tokenizeCCpp(ls, line_text),
            .vb => tokenizeVb(ls, line_text),
            else => {
                ls.addToken(0, @intCast(line_text.len), .plain);
            },
        }
    }

    // ========================================================================
    // Shared helpers
    // ========================================================================

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

    fn matchLiteral(text: []const u8, pos: u16, literal: []const u8) bool {
        if (pos + literal.len > text.len) return false;
        for (literal, 0..) |ch, i| {
            if (text[pos + i] != ch) return false;
        }
        const end = pos + @as(u16, @intCast(literal.len));
        if (end < text.len and isAlpha(text[end])) return false;
        return true;
    }

    fn isKeywordIn(word: []const u8, keywords: []const []const u8) bool {
        for (keywords) |kw| {
            if (eql(word, kw)) return true;
        }
        return false;
    }

    /// Shared: skip a double-quoted string starting at pos, return new pos.
    fn skipDoubleQuotedString(text: []const u8, start: u16, len: u16) u16 {
        var pos = start + 1;
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
        return pos;
    }

    /// Shared: skip a single-quoted string starting at pos, return new pos.
    fn skipSingleQuotedString(text: []const u8, start: u16, len: u16) u16 {
        var pos = start + 1;
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
        return pos;
    }

    /// Shared: tokenize a C-family number (decimal, hex, float).
    fn tokenizeNumber(text: []const u8, start: u16, len: u16) u16 {
        var pos = start;
        const c = text[pos];
        if (c == '0' and pos + 1 < len and (text[pos + 1] == 'x' or text[pos + 1] == 'X')) {
            pos += 2;
            while (pos < len and (isHexDigit(text[pos]) or text[pos] == '_')) : (pos += 1) {}
        } else {
            while (pos < len and (isDigit(text[pos]) or text[pos] == '_' or text[pos] == '.')) : (pos += 1) {}
            // Exponent
            if (pos < len and (text[pos] == 'e' or text[pos] == 'E')) {
                pos += 1;
                if (pos < len and (text[pos] == '+' or text[pos] == '-')) pos += 1;
                while (pos < len and isDigit(text[pos])) : (pos += 1) {}
            }
        }
        // Type suffix (f, l, u, etc.)
        while (pos < len and isAlpha(text[pos])) : (pos += 1) {}
        return pos;
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

    pub fn tokenizeZig(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);

        while (pos < len) {
            if (ls.token_count >= MAX_TOKENS_PER_LINE - 1) {
                ls.addToken(pos, len - pos, .plain);
                return;
            }

            const c = text[pos];

            if (pos + 1 < len and c == '/' and text[pos + 1] == '/') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }

            if (c == '"') {
                const start = pos;
                pos = skipDoubleQuotedString(text, pos, len);
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            if (c == '\'') {
                const start = pos;
                pos = skipSingleQuotedString(text, pos, len);
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            if (c == '@' and pos + 1 < len and isAlpha(text[pos + 1])) {
                const start = pos;
                pos += 1;
                while (pos < len and isAlnum(text[pos])) : (pos += 1) {}
                ls.addToken(start, pos - start, .builtin);
                continue;
            }

            if (isDigit(c)) {
                const start = pos;
                pos = tokenizeNumber(text, pos, len);
                ls.addToken(start, pos - start, .number_literal);
                continue;
            }

            if (isAlpha(c)) {
                const start = pos;
                while (pos < len and isAlnum(text[pos])) : (pos += 1) {}
                const word = text[start..pos];
                const kind: TokenKind = if (isKeywordIn(word, &zig_keywords)) .keyword else .plain;
                ls.addToken(start, pos - start, kind);
                continue;
            }

            if (isWhitespace(c)) {
                const start = pos;
                while (pos < len and isWhitespace(text[pos])) : (pos += 1) {}
                ls.addToken(start, pos - start, .plain);
                continue;
            }

            if (c == '+' or c == '-' or c == '*' or c == '/' or
                c == '%' or c == '=' or c == '!' or c == '<' or
                c == '>' or c == '&' or c == '|' or c == '^' or c == '~')
            {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }

            if (c == '(' or c == ')' or c == '{' or c == '}' or
                c == '[' or c == ']' or c == ';' or c == ':' or
                c == ',' or c == '.' or c == '#')
            {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }

            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // JSON tokenizer
    // ========================================================================

    pub fn tokenizeJson(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);

        while (pos < len) {
            if (ls.token_count >= MAX_TOKENS_PER_LINE - 1) {
                ls.addToken(pos, len - pos, .plain);
                return;
            }

            const c = text[pos];

            if (c == '"') {
                const start = pos;
                pos = skipDoubleQuotedString(text, pos, len);
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            if (isDigit(c) or (c == '-' and pos + 1 < len and isDigit(text[pos + 1]))) {
                const start = pos;
                if (c == '-') pos += 1;
                while (pos < len and isDigit(text[pos])) : (pos += 1) {}
                if (pos < len and text[pos] == '.') {
                    pos += 1;
                    while (pos < len and isDigit(text[pos])) : (pos += 1) {}
                }
                if (pos < len and (text[pos] == 'e' or text[pos] == 'E')) {
                    pos += 1;
                    if (pos < len and (text[pos] == '+' or text[pos] == '-')) pos += 1;
                    while (pos < len and isDigit(text[pos])) : (pos += 1) {}
                }
                ls.addToken(start, pos - start, .number_literal);
                continue;
            }

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

            if (c == '{' or c == '}' or c == '[' or c == ']' or c == ':' or c == ',') {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }

            if (isWhitespace(c)) {
                const start = pos;
                while (pos < len and isWhitespace(text[pos])) : (pos += 1) {}
                ls.addToken(start, pos - start, .plain);
                continue;
            }

            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // Markdown tokenizer
    // ========================================================================

    pub fn tokenizeMarkdown(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);

        // Heading: lines starting with #
        if (len > 0 and text[0] == '#') {
            ls.addToken(0, len, .keyword);
            return;
        }

        // Horizontal rule: ---, ***, ___
        if (len >= 3) {
            var all_same = true;
            const first = text[0];
            if (first == '-' or first == '*' or first == '_') {
                for (text[0..len]) |ch| {
                    if (ch != first and ch != ' ') {
                        all_same = false;
                        break;
                    }
                }
                if (all_same) {
                    ls.addToken(0, len, .punctuation);
                    return;
                }
            }
        }

        while (pos < len) {
            if (ls.token_count >= MAX_TOKENS_PER_LINE - 1) {
                ls.addToken(pos, len - pos, .plain);
                return;
            }

            const c = text[pos];

            // Inline code: `...`
            if (c == '`') {
                const start = pos;
                pos += 1;
                while (pos < len and text[pos] != '`') : (pos += 1) {}
                if (pos < len) pos += 1;
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            // Bold/italic markers: ** __ * _
            if (c == '*' or c == '_') {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }

            // Link/image: [...](...) or ![...](...) — mark brackets as punctuation
            if (c == '[' or c == ']' or c == '(' or c == ')' or c == '!') {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }

            // Block quote marker
            if (c == '>' and pos == 0) {
                ls.addToken(pos, 1, .comment);
                pos += 1;
                continue;
            }

            // List markers: - + at start of line (after optional whitespace)
            if ((c == '-' or c == '+') and pos < len - 1 and text[pos + 1] == ' ') {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }

            // Plain text run
            const start = pos;
            while (pos < len and text[pos] != '`' and text[pos] != '*' and
                text[pos] != '_' and text[pos] != '[' and text[pos] != ']' and
                text[pos] != '(' and text[pos] != ')' and text[pos] != '!')
            {
                pos += 1;
            }
            if (pos > start) {
                ls.addToken(start, pos - start, .plain);
            }
        }
    }

    // ========================================================================
    // JavaScript / TypeScript tokenizer (shared)
    // ========================================================================

    const js_ts_keywords = [_][]const u8{
        "abstract",   "arguments", "async",   "await",
        "boolean",    "break",     "byte",    "case",
        "catch",      "class",     "const",   "continue",
        "debugger",   "default",   "delete",  "do",
        "else",       "enum",      "export",  "extends",
        "false",      "final",     "finally", "for",
        "from",       "function",  "get",     "if",
        "implements", "import",    "in",      "instanceof",
        "interface",  "let",       "new",     "null",
        "of",         "package",   "private", "protected",
        "public",     "return",    "set",     "static",
        "super",      "switch",    "this",    "throw",
        "true",       "try",       "type",    "typeof",
        "undefined",  "var",       "void",    "while",
        "with",       "yield",
    };

    pub fn tokenizeJsTsCommon(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);

        while (pos < len) {
            if (ls.token_count >= MAX_TOKENS_PER_LINE - 1) {
                ls.addToken(pos, len - pos, .plain);
                return;
            }

            const c = text[pos];

            // Line comment
            if (pos + 1 < len and c == '/' and text[pos + 1] == '/') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }

            // Block comment start (single-line only for line tokenizer)
            if (pos + 1 < len and c == '/' and text[pos + 1] == '*') {
                const start = pos;
                pos += 2;
                while (pos + 1 < len) {
                    if (text[pos] == '*' and text[pos + 1] == '/') {
                        pos += 2;
                        break;
                    }
                    pos += 1;
                }
                if (pos >= len and !(pos >= 2 and text[pos - 2] == '*' and text[pos - 1] == '/')) {
                    pos = len;
                }
                ls.addToken(start, pos - start, .comment);
                continue;
            }

            // String: double-quoted
            if (c == '"') {
                const start = pos;
                pos = skipDoubleQuotedString(text, pos, len);
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            // String: single-quoted
            if (c == '\'') {
                const start = pos;
                pos = skipSingleQuotedString(text, pos, len);
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            // Template literal: `...`
            if (c == '`') {
                const start = pos;
                pos += 1;
                while (pos < len and text[pos] != '`') {
                    if (text[pos] == '\\' and pos + 1 < len) {
                        pos += 2;
                    } else {
                        pos += 1;
                    }
                }
                if (pos < len) pos += 1;
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            // Number
            if (isDigit(c)) {
                const start = pos;
                pos = tokenizeNumber(text, pos, len);
                ls.addToken(start, pos - start, .number_literal);
                continue;
            }

            // Identifier or keyword
            if (isAlpha(c) or c == '$') {
                const start = pos;
                while (pos < len and (isAlnum(text[pos]) or text[pos] == '$')) : (pos += 1) {}
                const word = text[start..pos];
                const kind: TokenKind = if (isKeywordIn(word, &js_ts_keywords)) .keyword else .plain;
                ls.addToken(start, pos - start, kind);
                continue;
            }

            if (isWhitespace(c)) {
                const start = pos;
                while (pos < len and isWhitespace(text[pos])) : (pos += 1) {}
                ls.addToken(start, pos - start, .plain);
                continue;
            }

            if (c == '+' or c == '-' or c == '*' or c == '/' or
                c == '%' or c == '=' or c == '!' or c == '<' or
                c == '>' or c == '&' or c == '|' or c == '^' or
                c == '~' or c == '?')
            {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }

            if (c == '(' or c == ')' or c == '{' or c == '}' or
                c == '[' or c == ']' or c == ';' or c == ':' or
                c == ',' or c == '.' or c == '@' or c == '#')
            {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }

            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // Python tokenizer
    // ========================================================================

    const python_keywords = [_][]const u8{
        "False",   "None",     "True",     "and",
        "as",      "assert",   "async",    "await",
        "break",   "class",    "continue", "def",
        "del",     "elif",     "else",     "except",
        "finally", "for",      "from",     "global",
        "if",      "import",   "in",       "is",
        "lambda",  "nonlocal", "not",      "or",
        "pass",    "raise",    "return",   "try",
        "while",   "with",     "yield",
    };

    const python_builtins = [_][]const u8{
        "print",        "len",       "range",    "int",
        "str",          "float",     "list",     "dict",
        "set",          "tuple",     "bool",     "type",
        "isinstance",   "hasattr",   "getattr",  "setattr",
        "open",         "super",     "property", "classmethod",
        "staticmethod", "enumerate", "zip",      "map",
        "filter",       "sorted",    "reversed", "input",
        "abs",          "min",       "max",      "sum",
        "any",          "all",       "iter",     "next",
        "repr",         "id",        "hex",      "oct",
        "bin",          "chr",       "ord",      "round",
    };

    pub fn tokenizePython(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);

        while (pos < len) {
            if (ls.token_count >= MAX_TOKENS_PER_LINE - 1) {
                ls.addToken(pos, len - pos, .plain);
                return;
            }

            const c = text[pos];

            // Comment: # to end of line
            if (c == '#') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }

            // Triple-quoted strings: """ or '''
            if (pos + 2 < len and ((c == '"' and text[pos + 1] == '"' and text[pos + 2] == '"') or
                (c == '\'' and text[pos + 1] == '\'' and text[pos + 2] == '\'')))
            {
                const start = pos;
                const quote = c;
                pos += 3;
                while (pos + 2 < len) {
                    if (text[pos] == quote and text[pos + 1] == quote and text[pos + 2] == quote) {
                        pos += 3;
                        break;
                    }
                    if (text[pos] == '\\' and pos + 1 < len) {
                        pos += 2;
                    } else {
                        pos += 1;
                    }
                } else {
                    pos = len; // unclosed triple-quote on this line
                }
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            if (c == '"') {
                const start = pos;
                pos = skipDoubleQuotedString(text, pos, len);
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            if (c == '\'') {
                const start = pos;
                pos = skipSingleQuotedString(text, pos, len);
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            if (isDigit(c)) {
                const start = pos;
                pos = tokenizeNumber(text, pos, len);
                ls.addToken(start, pos - start, .number_literal);
                continue;
            }

            // Decorator: @name
            if (c == '@' and pos + 1 < len and isAlpha(text[pos + 1])) {
                const start = pos;
                pos += 1;
                while (pos < len and (isAlnum(text[pos]) or text[pos] == '.')) : (pos += 1) {}
                ls.addToken(start, pos - start, .preprocessor);
                continue;
            }

            if (isAlpha(c)) {
                const start = pos;
                while (pos < len and isAlnum(text[pos])) : (pos += 1) {}
                const word = text[start..pos];
                const kind: TokenKind = if (isKeywordIn(word, &python_keywords))
                    .keyword
                else if (isKeywordIn(word, &python_builtins))
                    .builtin
                else
                    .plain;
                ls.addToken(start, pos - start, kind);
                continue;
            }

            if (isWhitespace(c)) {
                const start = pos;
                while (pos < len and isWhitespace(text[pos])) : (pos += 1) {}
                ls.addToken(start, pos - start, .plain);
                continue;
            }

            if (c == '+' or c == '-' or c == '*' or c == '/' or
                c == '%' or c == '=' or c == '!' or c == '<' or
                c == '>' or c == '&' or c == '|' or c == '^' or
                c == '~')
            {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }

            if (c == '(' or c == ')' or c == '{' or c == '}' or
                c == '[' or c == ']' or c == ':' or c == ';' or
                c == ',' or c == '.')
            {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }

            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // C / C++ tokenizer (shared)
    // ========================================================================

    const c_cpp_keywords = [_][]const u8{
        "auto",     "break",     "case",      "char",
        "class",    "const",     "constexpr", "continue",
        "default",  "delete",    "do",        "double",
        "else",     "enum",      "explicit",  "extern",
        "false",    "float",     "for",       "friend",
        "goto",     "if",        "inline",    "int",
        "long",     "mutable",   "namespace", "new",
        "noexcept", "nullptr",   "operator",  "override",
        "private",  "protected", "public",    "register",
        "return",   "short",     "signed",    "sizeof",
        "static",   "struct",    "switch",    "template",
        "this",     "throw",     "true",      "try",
        "typedef",  "typename",  "union",     "unsigned",
        "using",    "virtual",   "void",      "volatile",
        "while",
    };

    pub fn tokenizeCCpp(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);

        while (pos < len) {
            if (ls.token_count >= MAX_TOKENS_PER_LINE - 1) {
                ls.addToken(pos, len - pos, .plain);
                return;
            }

            const c = text[pos];

            // Line comment
            if (pos + 1 < len and c == '/' and text[pos + 1] == '/') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }

            // Block comment (single-line portion)
            if (pos + 1 < len and c == '/' and text[pos + 1] == '*') {
                const start = pos;
                pos += 2;
                while (pos + 1 < len) {
                    if (text[pos] == '*' and text[pos + 1] == '/') {
                        pos += 2;
                        break;
                    }
                    pos += 1;
                }
                if (pos >= len and !(pos >= 2 and text[pos - 2] == '*' and text[pos - 1] == '/')) {
                    pos = len;
                }
                ls.addToken(start, pos - start, .comment);
                continue;
            }

            // Preprocessor: # at start of line (after optional whitespace)
            if (c == '#') {
                // Check if this is at the start (only whitespace before)
                var is_preproc = true;
                var j: u16 = 0;
                while (j < pos) : (j += 1) {
                    if (!isWhitespace(text[j])) {
                        is_preproc = false;
                        break;
                    }
                }
                if (is_preproc) {
                    ls.addToken(pos, len - pos, .preprocessor);
                    return;
                }
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }

            if (c == '"') {
                const start = pos;
                pos = skipDoubleQuotedString(text, pos, len);
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            if (c == '\'') {
                const start = pos;
                pos = skipSingleQuotedString(text, pos, len);
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            if (isDigit(c)) {
                const start = pos;
                pos = tokenizeNumber(text, pos, len);
                ls.addToken(start, pos - start, .number_literal);
                continue;
            }

            if (isAlpha(c)) {
                const start = pos;
                while (pos < len and isAlnum(text[pos])) : (pos += 1) {}
                const word = text[start..pos];
                const kind: TokenKind = if (isKeywordIn(word, &c_cpp_keywords)) .keyword else .plain;
                ls.addToken(start, pos - start, kind);
                continue;
            }

            if (isWhitespace(c)) {
                const start = pos;
                while (pos < len and isWhitespace(text[pos])) : (pos += 1) {}
                ls.addToken(start, pos - start, .plain);
                continue;
            }

            if (c == '+' or c == '-' or c == '*' or c == '/' or
                c == '%' or c == '=' or c == '!' or c == '<' or
                c == '>' or c == '&' or c == '|' or c == '^' or
                c == '~' or c == '?')
            {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }

            if (c == '(' or c == ')' or c == '{' or c == '}' or
                c == '[' or c == ']' or c == ';' or c == ':' or
                c == ',' or c == '.')
            {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }

            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // Rust tokenizer
    // ========================================================================

    const rust_keywords = [_][]const u8{
        "as",     "async",    "await",  "break",
        "const",  "continue", "crate",  "dyn",
        "else",   "enum",     "extern", "false",
        "fn",     "for",      "if",     "impl",
        "in",     "let",      "loop",   "match",
        "mod",    "move",     "mut",    "pub",
        "ref",    "return",   "self",   "Self",
        "static", "struct",   "super",  "trait",
        "true",   "type",     "unsafe", "use",
        "where",  "while",    "yield",
    };

    pub fn tokenizeRust(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);

        while (pos < len) {
            if (ls.token_count >= MAX_TOKENS_PER_LINE - 1) {
                ls.addToken(pos, len - pos, .plain);
                return;
            }

            const c = text[pos];

            // Line comment
            if (pos + 1 < len and c == '/' and text[pos + 1] == '/') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }

            // Block comment
            if (pos + 1 < len and c == '/' and text[pos + 1] == '*') {
                const start = pos;
                pos += 2;
                while (pos + 1 < len) {
                    if (text[pos] == '*' and text[pos + 1] == '/') {
                        pos += 2;
                        break;
                    }
                    pos += 1;
                }
                if (pos >= len and !(pos >= 2 and text[pos - 2] == '*' and text[pos - 1] == '/')) {
                    pos = len;
                }
                ls.addToken(start, pos - start, .comment);
                continue;
            }

            if (c == '"') {
                const start = pos;
                pos = skipDoubleQuotedString(text, pos, len);
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            if (c == '\'') {
                // Could be char literal or lifetime — check context
                if (pos + 1 < len and isAlpha(text[pos + 1])) {
                    // Lifetime: 'a, 'static, etc.
                    const start = pos;
                    pos += 1;
                    while (pos < len and isAlnum(text[pos])) : (pos += 1) {}
                    // If followed by ' it's a char literal
                    if (pos < len and text[pos] == '\'') {
                        pos += 1;
                        ls.addToken(start, pos - start, .string_literal);
                    } else {
                        ls.addToken(start, pos - start, .type_name);
                    }
                    continue;
                }
                const start = pos;
                pos = skipSingleQuotedString(text, pos, len);
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            // Attribute: #[...] or #![...]
            if (c == '#' and pos + 1 < len and (text[pos + 1] == '[' or text[pos + 1] == '!')) {
                const start = pos;
                pos += 1;
                if (pos < len and text[pos] == '!') pos += 1;
                if (pos < len and text[pos] == '[') {
                    pos += 1;
                    while (pos < len and text[pos] != ']') : (pos += 1) {}
                    if (pos < len) pos += 1;
                }
                ls.addToken(start, pos - start, .preprocessor);
                continue;
            }

            if (isDigit(c)) {
                const start = pos;
                pos = tokenizeNumber(text, pos, len);
                ls.addToken(start, pos - start, .number_literal);
                continue;
            }

            if (isAlpha(c)) {
                const start = pos;
                while (pos < len and isAlnum(text[pos])) : (pos += 1) {}
                const word = text[start..pos];
                const kind: TokenKind = if (isKeywordIn(word, &rust_keywords)) .keyword else .plain;
                ls.addToken(start, pos - start, kind);
                continue;
            }

            if (isWhitespace(c)) {
                const start = pos;
                while (pos < len and isWhitespace(text[pos])) : (pos += 1) {}
                ls.addToken(start, pos - start, .plain);
                continue;
            }

            if (c == '+' or c == '-' or c == '*' or c == '/' or
                c == '%' or c == '=' or c == '!' or c == '<' or
                c == '>' or c == '&' or c == '|' or c == '^' or
                c == '~' or c == '?')
            {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }

            if (c == '(' or c == ')' or c == '{' or c == '}' or
                c == '[' or c == ']' or c == ';' or c == ':' or
                c == ',' or c == '.' or c == '@' or c == '#')
            {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }

            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // Go tokenizer
    // ========================================================================

    const go_keywords = [_][]const u8{
        "break",       "case",    "chan",   "const",
        "continue",    "default", "defer",  "else",
        "fallthrough", "false",   "for",    "func",
        "go",          "goto",    "if",     "import",
        "interface",   "map",     "nil",    "package",
        "range",       "return",  "select", "struct",
        "switch",      "true",    "type",   "var",
    };

    const go_builtins = [_][]const u8{
        "append",  "cap",    "close",   "complex",
        "copy",    "delete", "imag",    "len",
        "make",    "new",    "panic",   "print",
        "println", "real",   "recover",
    };

    pub fn tokenizeGo(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);

        while (pos < len) {
            if (ls.token_count >= MAX_TOKENS_PER_LINE - 1) {
                ls.addToken(pos, len - pos, .plain);
                return;
            }

            const c = text[pos];

            if (pos + 1 < len and c == '/' and text[pos + 1] == '/') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }

            if (pos + 1 < len and c == '/' and text[pos + 1] == '*') {
                const start = pos;
                pos += 2;
                while (pos + 1 < len) {
                    if (text[pos] == '*' and text[pos + 1] == '/') {
                        pos += 2;
                        break;
                    }
                    pos += 1;
                }
                if (pos >= len and !(pos >= 2 and text[pos - 2] == '*' and text[pos - 1] == '/')) {
                    pos = len;
                }
                ls.addToken(start, pos - start, .comment);
                continue;
            }

            if (c == '"') {
                const start = pos;
                pos = skipDoubleQuotedString(text, pos, len);
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            // Raw string: `...`
            if (c == '`') {
                const start = pos;
                pos += 1;
                while (pos < len and text[pos] != '`') : (pos += 1) {}
                if (pos < len) pos += 1;
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            if (c == '\'') {
                const start = pos;
                pos = skipSingleQuotedString(text, pos, len);
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            if (isDigit(c)) {
                const start = pos;
                pos = tokenizeNumber(text, pos, len);
                ls.addToken(start, pos - start, .number_literal);
                continue;
            }

            if (isAlpha(c)) {
                const start = pos;
                while (pos < len and isAlnum(text[pos])) : (pos += 1) {}
                const word = text[start..pos];
                const kind: TokenKind = if (isKeywordIn(word, &go_keywords))
                    .keyword
                else if (isKeywordIn(word, &go_builtins))
                    .builtin
                else
                    .plain;
                ls.addToken(start, pos - start, kind);
                continue;
            }

            if (isWhitespace(c)) {
                const start = pos;
                while (pos < len and isWhitespace(text[pos])) : (pos += 1) {}
                ls.addToken(start, pos - start, .plain);
                continue;
            }

            if (c == '+' or c == '-' or c == '*' or c == '/' or
                c == '%' or c == '=' or c == '!' or c == '<' or
                c == '>' or c == '&' or c == '|' or c == '^')
            {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }

            if (c == '(' or c == ')' or c == '{' or c == '}' or
                c == '[' or c == ']' or c == ';' or c == ':' or
                c == ',' or c == '.')
            {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }

            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // HTML tokenizer
    // ========================================================================

    pub fn tokenizeHtml(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);

        while (pos < len) {
            if (ls.token_count >= MAX_TOKENS_PER_LINE - 1) {
                ls.addToken(pos, len - pos, .plain);
                return;
            }

            const c = text[pos];

            // HTML comment: <!-- ... -->
            if (pos + 3 < len and c == '<' and text[pos + 1] == '!' and
                text[pos + 2] == '-' and text[pos + 3] == '-')
            {
                const start = pos;
                pos += 4;
                while (pos + 2 < len) {
                    if (text[pos] == '-' and text[pos + 1] == '-' and text[pos + 2] == '>') {
                        pos += 3;
                        break;
                    }
                    pos += 1;
                }
                if (pos + 2 >= len and !(pos >= 3 and text[pos - 3] == '-' and text[pos - 2] == '-' and text[pos - 1] == '>')) {
                    pos = len;
                }
                ls.addToken(start, pos - start, .comment);
                continue;
            }

            // Tag: <tagname or </tagname or <!DOCTYPE
            if (c == '<') {
                const start = pos;
                pos += 1;
                // Skip / for closing tags
                if (pos < len and text[pos] == '/') pos += 1;
                // Skip ! for doctype
                if (pos < len and text[pos] == '!') pos += 1;
                // Tag name
                while (pos < len and (isAlnum(text[pos]) or text[pos] == '-')) : (pos += 1) {}
                ls.addToken(start, pos - start, .keyword);

                // Attributes inside the tag
                while (pos < len and text[pos] != '>') {
                    if (ls.token_count >= MAX_TOKENS_PER_LINE - 1) {
                        ls.addToken(pos, len - pos, .plain);
                        return;
                    }

                    if (text[pos] == '"') {
                        const attr_start = pos;
                        pos = skipDoubleQuotedString(text, pos, len);
                        ls.addToken(attr_start, pos - attr_start, .string_literal);
                        continue;
                    }

                    if (text[pos] == '\'') {
                        const attr_start = pos;
                        pos = skipSingleQuotedString(text, pos, len);
                        ls.addToken(attr_start, pos - attr_start, .string_literal);
                        continue;
                    }

                    if (text[pos] == '=') {
                        ls.addToken(pos, 1, .operator);
                        pos += 1;
                        continue;
                    }

                    if (isWhitespace(text[pos])) {
                        const ws_start = pos;
                        while (pos < len and isWhitespace(text[pos])) : (pos += 1) {}
                        ls.addToken(ws_start, pos - ws_start, .plain);
                        continue;
                    }

                    if (isAlpha(text[pos])) {
                        const attr_start = pos;
                        while (pos < len and (isAlnum(text[pos]) or text[pos] == '-')) : (pos += 1) {}
                        ls.addToken(attr_start, pos - attr_start, .type_name);
                        continue;
                    }

                    // Self-closing /
                    if (text[pos] == '/') {
                        ls.addToken(pos, 1, .punctuation);
                        pos += 1;
                        continue;
                    }

                    ls.addToken(pos, 1, .plain);
                    pos += 1;
                }

                // Closing >
                if (pos < len and text[pos] == '>') {
                    ls.addToken(pos, 1, .keyword);
                    pos += 1;
                }
                continue;
            }

            // Entity: &amp; &lt; &#123; etc.
            if (c == '&') {
                const start = pos;
                pos += 1;
                while (pos < len and text[pos] != ';' and pos - start < 10) : (pos += 1) {}
                if (pos < len and text[pos] == ';') pos += 1;
                ls.addToken(start, pos - start, .builtin);
                continue;
            }

            // Plain text content
            const start = pos;
            while (pos < len and text[pos] != '<' and text[pos] != '&') : (pos += 1) {}
            if (pos > start) {
                ls.addToken(start, pos - start, .plain);
            }
        }
    }

    // ========================================================================
    // CSS tokenizer
    // ========================================================================

    pub fn tokenizeCss(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);

        while (pos < len) {
            if (ls.token_count >= MAX_TOKENS_PER_LINE - 1) {
                ls.addToken(pos, len - pos, .plain);
                return;
            }

            const c = text[pos];

            // Comment: /* ... */
            if (pos + 1 < len and c == '/' and text[pos + 1] == '*') {
                const start = pos;
                pos += 2;
                while (pos + 1 < len) {
                    if (text[pos] == '*' and text[pos + 1] == '/') {
                        pos += 2;
                        break;
                    }
                    pos += 1;
                }
                if (pos >= len and !(pos >= 2 and text[pos - 2] == '*' and text[pos - 1] == '/')) {
                    pos = len;
                }
                ls.addToken(start, pos - start, .comment);
                continue;
            }

            if (c == '"') {
                const start = pos;
                pos = skipDoubleQuotedString(text, pos, len);
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            if (c == '\'') {
                const start = pos;
                pos = skipSingleQuotedString(text, pos, len);
                ls.addToken(start, pos - start, .string_literal);
                continue;
            }

            // At-rule: @media, @import, @keyframes, etc.
            if (c == '@') {
                const start = pos;
                pos += 1;
                while (pos < len and (isAlnum(text[pos]) or text[pos] == '-')) : (pos += 1) {}
                ls.addToken(start, pos - start, .keyword);
                continue;
            }

            // Selector: . # (class/id selectors)
            if (c == '.' or c == '#') {
                const start = pos;
                pos += 1;
                while (pos < len and (isAlnum(text[pos]) or text[pos] == '-' or text[pos] == '_')) : (pos += 1) {}
                ls.addToken(start, pos - start, .type_name);
                continue;
            }

            // Number with optional unit
            if (isDigit(c) or (c == '-' and pos + 1 < len and isDigit(text[pos + 1]))) {
                const start = pos;
                if (c == '-') pos += 1;
                while (pos < len and (isDigit(text[pos]) or text[pos] == '.')) : (pos += 1) {}
                // Unit suffix: px, em, rem, %, vh, vw, etc.
                while (pos < len and (isAlpha(text[pos]) or text[pos] == '%')) : (pos += 1) {}
                ls.addToken(start, pos - start, .number_literal);
                continue;
            }

            // Color hex: #fff or #ffffff (only if not already handled as selector)
            // Already handled by # above as type_name, which is fine for CSS

            // Property name or tag selector (identifier)
            if (isAlpha(c) or c == '-') {
                const start = pos;
                while (pos < len and (isAlnum(text[pos]) or text[pos] == '-')) : (pos += 1) {}
                ls.addToken(start, pos - start, .plain);
                continue;
            }

            if (isWhitespace(c)) {
                const start = pos;
                while (pos < len and isWhitespace(text[pos])) : (pos += 1) {}
                ls.addToken(start, pos - start, .plain);
                continue;
            }

            if (c == '{' or c == '}' or c == ';' or c == ':' or c == ',' or
                c == '(' or c == ')' or c == '[' or c == ']')
            {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }

            if (c == '+' or c == '>' or c == '~' or c == '=' or c == '!' or c == '*') {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }

            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }
    // ========================================================================
    // Java tokenizer
    // ========================================================================

    const java_keywords = [_][]const u8{
        "abstract", "assert", "boolean",    "break",     "byte",       "case",      "catch",
        "char",     "class",  "const",      "continue",  "default",    "do",        "double",
        "else",     "enum",   "extends",    "final",     "finally",    "float",     "for",
        "goto",     "if",     "implements", "import",    "instanceof", "int",       "interface",
        "long",     "native", "new",        "package",   "private",    "protected", "public",
        "return",   "short",  "static",     "strictfp",  "super",      "switch",    "synchronized",
        "this",     "throw",  "throws",     "transient", "try",        "void",      "volatile",
        "while",
    };

    pub fn tokenizeJava(ls: *LineSyntax, text: []const u8) void {
        tokenizeCStyleLang(ls, text, &java_keywords);
    }

    // ========================================================================
    // C# tokenizer
    // ========================================================================

    const csharp_keywords = [_][]const u8{
        "abstract",  "as",         "base",      "bool",     "break",    "byte",      "case",    "catch",
        "char",      "checked",    "class",     "const",    "continue", "decimal",   "default", "delegate",
        "do",        "double",     "else",      "enum",     "event",    "explicit",  "extern",  "false",
        "finally",   "fixed",      "float",     "for",      "foreach",  "goto",      "if",      "implicit",
        "in",        "int",        "interface", "internal", "is",       "lock",      "long",    "namespace",
        "new",       "null",       "object",    "operator", "out",      "override",  "params",  "private",
        "protected", "public",     "readonly",  "ref",      "return",   "sbyte",     "sealed",  "short",
        "sizeof",    "stackalloc", "static",    "string",   "struct",   "switch",    "this",    "throw",
        "true",      "try",        "typeof",    "uint",     "ulong",    "unchecked", "unsafe",  "ushort",
        "using",     "var",        "virtual",   "void",     "volatile", "while",     "yield",   "async",
        "await",
    };

    pub fn tokenizeCSharp(ls: *LineSyntax, text: []const u8) void {
        tokenizeCStyleLang(ls, text, &csharp_keywords);
    }

    // ========================================================================
    // PHP tokenizer
    // ========================================================================

    const php_keywords = [_][]const u8{
        "abstract",   "and",     "array",      "as",       "break",      "callable",   "case",
        "catch",      "class",   "clone",      "const",    "continue",   "declare",    "default",
        "do",         "echo",    "else",       "elseif",   "empty",      "enddeclare", "endfor",
        "endforeach", "endif",   "endswitch",  "endwhile", "eval",       "exit",       "extends",
        "final",      "finally", "fn",         "for",      "foreach",    "function",   "global",
        "goto",       "if",      "implements", "include",  "instanceof", "interface",  "isset",
        "list",       "match",   "namespace",  "new",      "or",         "print",      "private",
        "protected",  "public",  "readonly",   "require",  "return",     "static",     "switch",
        "throw",      "trait",   "try",        "unset",    "use",        "var",        "while",
        "xor",        "yield",
    };

    pub fn tokenizePhp(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            // Comments
            if (c == '/' and pos + 1 < len) {
                if (text[pos + 1] == '/') {
                    ls.addToken(pos, len - pos, .comment);
                    return;
                }
                if (text[pos + 1] == '*') {
                    var e = pos + 2;
                    while (e + 1 < len) : (e += 1) {
                        if (text[e] == '*' and text[e + 1] == '/') {
                            e += 2;
                            break;
                        }
                    }
                    ls.addToken(pos, e - pos, .comment);
                    pos = e;
                    continue;
                }
            }
            if (c == '#') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            // Strings
            if (c == '"' or c == '\'') {
                const end = skipQuotedString(text, pos, len, c);
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            // Variables ($name)
            if (c == '$' and pos + 1 < len and isAlpha(text[pos + 1])) {
                var e = pos + 1;
                while (e < len and isAlnum(text[e])) : (e += 1) {}
                ls.addToken(pos, e - pos, .builtin);
                pos = e;
                continue;
            }
            // Numbers
            if (isDigit(c)) {
                var e = pos + 1;
                while (e < len and (isDigit(text[e]) or text[e] == '.' or text[e] == '_')) : (e += 1) {}
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            // Identifiers / keywords
            if (isAlpha(c)) {
                var e = pos;
                while (e < len and isAlnum(text[e])) : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, &php_keywords)) .keyword else if (e < len and text[e] == '(') .function_name else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            if (isPunct(c)) {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            if (isOp(c)) {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // Ruby tokenizer
    // ========================================================================

    const ruby_keywords = [_][]const u8{
        "BEGIN",  "END",         "alias",       "and",           "begin", "break", "case",    "class",
        "def",    "defined?",    "do",          "else",          "elsif", "end",   "ensure",  "false",
        "for",    "if",          "in",          "module",        "next",  "nil",   "not",     "or",
        "redo",   "rescue",      "retry",       "return",        "self",  "super", "then",    "true",
        "undef",  "unless",      "until",       "when",          "while", "yield", "require", "include",
        "extend", "attr_reader", "attr_writer", "attr_accessor", "raise", "puts",  "print",   "lambda",
        "proc",
    };

    pub fn tokenizeRuby(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '#') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            if (c == '"' or c == '\'') {
                const end = skipQuotedString(text, pos, len, c);
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (c == ':' and pos + 1 < len and isAlpha(text[pos + 1])) {
                var e = pos + 1;
                while (e < len and isAlnum(text[e])) : (e += 1) {}
                ls.addToken(pos, e - pos, .builtin);
                pos = e;
                continue;
            }
            if (c == '@') {
                var e = pos + 1;
                if (e < len and text[e] == '@') e += 1;
                while (e < len and isAlnum(text[e])) : (e += 1) {}
                ls.addToken(pos, e - pos, .builtin);
                pos = e;
                continue;
            }
            if (isDigit(c)) {
                var e = pos + 1;
                while (e < len and (isDigit(text[e]) or text[e] == '.' or text[e] == '_')) : (e += 1) {}
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            if (isAlpha(c)) {
                var e = pos;
                while (e < len and (isAlnum(text[e]) or text[e] == '?' or text[e] == '!')) : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, &ruby_keywords)) .keyword else if (e < len and text[e] == '(') .function_name else if (c >= 'A' and c <= 'Z') .type_name else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            if (isPunct(c)) {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            if (isOp(c)) {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // Shell (bash) tokenizer
    // ========================================================================

    const shell_keywords = [_][]const u8{
        "if",    "then",   "else",     "elif",     "fi",      "for",   "while",  "do",     "done",
        "case",  "esac",   "in",       "function", "select",  "until", "return", "break",  "continue",
        "local", "export", "readonly", "declare",  "typeset", "unset", "shift",  "source", "exit",
        "exec",  "eval",   "set",      "trap",     "wait",    "true",  "false",
    };

    pub fn tokenizeShell(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '#') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            if (c == '"' or c == '\'') {
                const end = skipQuotedString(text, pos, len, c);
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (c == '$') {
                var e = pos + 1;
                if (e < len and text[e] == '{') {
                    while (e < len and text[e] != '}') : (e += 1) {}
                    if (e < len) e += 1;
                } else {
                    while (e < len and isAlnum(text[e])) : (e += 1) {}
                }
                ls.addToken(pos, e - pos, .builtin);
                pos = e;
                continue;
            }
            if (isDigit(c)) {
                var e = pos + 1;
                while (e < len and isDigit(text[e])) : (e += 1) {}
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            if (isAlpha(c)) {
                var e = pos;
                while (e < len and (isAlnum(text[e]) or text[e] == '-')) : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, &shell_keywords)) .keyword else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            if (isPunct(c)) {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            if (isOp(c) or c == '|' or c == '&') {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // SQL tokenizer
    // ========================================================================

    const sql_keywords = [_][]const u8{
        "SELECT",     "FROM",    "WHERE",     "INSERT",   "INTO",    "VALUES",  "UPDATE",
        "SET",        "DELETE",  "CREATE",    "TABLE",    "DROP",    "ALTER",   "INDEX",
        "JOIN",       "LEFT",    "RIGHT",     "INNER",    "OUTER",   "ON",      "AND",
        "OR",         "NOT",     "NULL",      "IS",       "IN",      "BETWEEN", "LIKE",
        "ORDER",      "BY",      "GROUP",     "HAVING",   "LIMIT",   "OFFSET",  "AS",
        "DISTINCT",   "COUNT",   "SUM",       "AVG",      "MIN",     "MAX",     "UNION",
        "ALL",        "EXISTS",  "CASE",      "WHEN",     "THEN",    "ELSE",    "END",
        "BEGIN",      "COMMIT",  "ROLLBACK",  "PRIMARY",  "KEY",     "FOREIGN", "REFERENCES",
        "CONSTRAINT", "DEFAULT", "VARCHAR",   "INT",      "INTEGER", "TEXT",    "BOOLEAN",
        "DATE",       "FLOAT",   "DOUBLE",    "DECIMAL",  "CHAR",    "BLOB",    "TIMESTAMP",
        "VIEW",       "TRIGGER", "PROCEDURE", "FUNCTION", "GRANT",   "REVOKE",  "select",
        "from",       "where",   "insert",    "into",     "values",  "update",  "set",
        "delete",     "create",  "table",     "drop",     "alter",   "index",   "join",
        "left",       "right",   "inner",     "outer",    "on",      "and",     "or",
        "not",        "null",    "is",        "in",       "between", "like",    "order",
        "by",         "group",   "having",    "limit",    "offset",  "as",      "distinct",
    };

    pub fn tokenizeSql(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '-' and pos + 1 < len and text[pos + 1] == '-') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            if (c == '\'' or c == '"') {
                const end = skipQuotedString(text, pos, len, c);
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (isDigit(c)) {
                var e = pos + 1;
                while (e < len and (isDigit(text[e]) or text[e] == '.')) : (e += 1) {}
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            if (isAlpha(c) or c == '_') {
                var e = pos;
                while (e < len and (isAlnum(text[e]) or text[e] == '_')) : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, &sql_keywords)) .keyword else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            if (isPunct(c)) {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            if (isOp(c)) {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // XML tokenizer (reuses HTML-like approach)
    // ========================================================================

    pub fn tokenizeXml(ls: *LineSyntax, text: []const u8) void {
        tokenizeHtml(ls, text);
    }

    // ========================================================================
    // YAML tokenizer
    // ========================================================================

    pub fn tokenizeYaml(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '#') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            if (c == '"' or c == '\'') {
                const end = skipQuotedString(text, pos, len, c);
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (c == '-' and pos + 1 < len and text[pos + 1] == '-' and pos + 2 < len and text[pos + 2] == '-') {
                ls.addToken(pos, 3, .keyword);
                pos += 3;
                continue;
            }
            if (isDigit(c) or (c == '-' and pos + 1 < len and isDigit(text[pos + 1]))) {
                var e = pos;
                if (c == '-') e += 1;
                while (e < len and (isDigit(text[e]) or text[e] == '.')) : (e += 1) {}
                if (e > pos) {
                    ls.addToken(pos, e - pos, .number_literal);
                    pos = e;
                    continue;
                }
            }
            if (isAlpha(c) or c == '_') {
                var e = pos;
                while (e < len and (isAlnum(text[e]) or text[e] == '_' or text[e] == '-')) : (e += 1) {}
                if (e < len and text[e] == ':') {
                    ls.addToken(pos, e - pos, .keyword);
                    pos = e;
                    continue;
                }
                const word = text[pos..e];
                const kind: TokenKind = if (eql(word, "true") or eql(word, "false") or eql(word, "null") or eql(word, "yes") or eql(word, "no"))
                    .builtin
                else
                    .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            if (c == ':') {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            if (c == '-' or c == '>' or c == '|' or c == '&' or c == '*') {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            if (isPunct(c)) {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // Bat (Windows batch) tokenizer
    // ========================================================================

    const bat_keywords = [_][]const u8{
        "echo", "set",   "if",      "else",       "for",   "in",      "do",         "goto",  "call",
        "exit", "pause", "rem",     "not",        "exist", "defined", "errorlevel", "equ",   "neq",
        "lss",  "leq",   "gtr",     "geq",        "off",   "on",      "ECHO",       "SET",   "IF",
        "ELSE", "FOR",   "IN",      "DO",         "GOTO",  "CALL",    "EXIT",       "PAUSE", "REM",
        "NOT",  "EXIST", "DEFINED", "ERRORLEVEL",
    };

    pub fn tokenizeBat(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        // REM comment
        if (len >= 3 and (text[0] == 'R' or text[0] == 'r') and
            (text[1] == 'E' or text[1] == 'e') and (text[2] == 'M' or text[2] == 'm') and
            (len == 3 or text[3] == ' '))
        {
            ls.addToken(0, len, .comment);
            return;
        }
        if (len >= 2 and text[0] == ':' and text[1] == ':') {
            ls.addToken(0, len, .comment);
            return;
        }
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '%') {
                var e = pos + 1;
                while (e < len and text[e] != '%' and !isWhitespace(text[e])) : (e += 1) {}
                if (e < len and text[e] == '%') e += 1;
                ls.addToken(pos, e - pos, .builtin);
                pos = e;
                continue;
            }
            if (c == '"') {
                const end = skipQuotedString(text, pos, len, '"');
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (c == '@') {
                ls.addToken(pos, 1, .preprocessor);
                pos += 1;
                continue;
            }
            if (isDigit(c)) {
                var e = pos + 1;
                while (e < len and isDigit(text[e])) : (e += 1) {}
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            if (isAlpha(c)) {
                var e = pos;
                while (e < len and isAlnum(text[e])) : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, &bat_keywords)) .keyword else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            if (isPunct(c) or isOp(c)) {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // Dart tokenizer
    // ========================================================================

    const dart_keywords = [_][]const u8{
        "abstract", "as",       "assert",     "async",    "await",     "break",     "case",
        "catch",    "class",    "const",      "continue", "covariant", "default",   "deferred",
        "do",       "dynamic",  "else",       "enum",     "export",    "extends",   "extension",
        "external", "factory",  "false",      "final",    "finally",   "for",       "get",
        "hide",     "if",       "implements", "import",   "in",        "interface", "is",
        "late",     "library",  "mixin",      "new",      "null",      "on",        "operator",
        "part",     "required", "rethrow",    "return",   "sealed",    "set",       "show",
        "static",   "super",    "switch",     "sync",     "this",      "throw",     "true",
        "try",      "typedef",  "var",        "void",     "while",     "with",      "yield",
    };

    pub fn tokenizeDart(ls: *LineSyntax, text: []const u8) void {
        tokenizeCStyleLang(ls, text, &dart_keywords);
    }

    // ========================================================================
    // Diff tokenizer
    // ========================================================================

    pub fn tokenizeDiff(ls: *LineSyntax, text: []const u8) void {
        const len: u16 = @intCast(text.len);
        if (len == 0) return;
        if (text[0] == '+') {
            ls.addToken(0, len, .string_literal);
            return;
        }
        if (text[0] == '-') {
            ls.addToken(0, len, .keyword);
            return;
        }
        if (text[0] == '@') {
            ls.addToken(0, len, .builtin);
            return;
        }
        if (len >= 4 and eql(text[0..4], "diff")) {
            ls.addToken(0, len, .preprocessor);
            return;
        }
        if (len >= 5 and eql(text[0..5], "index")) {
            ls.addToken(0, len, .comment);
            return;
        }
        if (len >= 3 and eql(text[0..3], "---")) {
            ls.addToken(0, len, .keyword);
            return;
        }
        if (len >= 3 and eql(text[0..3], "+++")) {
            ls.addToken(0, len, .string_literal);
            return;
        }
        ls.addToken(0, len, .plain);
    }

    // ========================================================================
    // Dockerfile tokenizer
    // ========================================================================

    const docker_keywords = [_][]const u8{
        "FROM",    "RUN",        "CMD",         "LABEL",  "MAINTAINER", "EXPOSE",  "ENV",
        "ADD",     "COPY",       "ENTRYPOINT",  "VOLUME", "USER",       "WORKDIR", "ARG",
        "ONBUILD", "STOPSIGNAL", "HEALTHCHECK", "SHELL",
    };

    pub fn tokenizeDocker(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '#') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            if (c == '"' or c == '\'') {
                const end = skipQuotedString(text, pos, len, c);
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (c == '$') {
                var e = pos + 1;
                if (e < len and text[e] == '{') {
                    while (e < len and text[e] != '}') : (e += 1) {}
                    if (e < len) e += 1;
                } else {
                    while (e < len and isAlnum(text[e])) : (e += 1) {}
                }
                ls.addToken(pos, e - pos, .builtin);
                pos = e;
                continue;
            }
            if (isAlpha(c)) {
                var e = pos;
                while (e < len and (isAlnum(text[e]) or text[e] == '_')) : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, &docker_keywords)) .keyword else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            if (isDigit(c)) {
                var e = pos + 1;
                while (e < len and (isDigit(text[e]) or text[e] == '.')) : (e += 1) {}
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // INI / dotenv tokenizer
    // ========================================================================

    pub fn tokenizeIni(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        if (len == 0) return;
        // Skip leading whitespace
        while (pos < len and isWhitespace(text[pos])) : (pos += 1) {}
        if (pos >= len) return;
        if (text[pos] == ';' or text[pos] == '#') {
            ls.addToken(pos, len - pos, .comment);
            return;
        }
        if (text[pos] == '[') {
            var e = pos + 1;
            while (e < len and text[e] != ']') : (e += 1) {}
            if (e < len) e += 1;
            ls.addToken(pos, e - pos, .keyword);
            pos = e;
            if (pos < len) ls.addToken(pos, len - pos, .plain);
            return;
        }
        // key = value
        var e = pos;
        while (e < len and text[e] != '=' and text[e] != ':') : (e += 1) {}
        if (e < len) {
            ls.addToken(pos, e - pos, .keyword);
            ls.addToken(e, 1, .operator);
            if (e + 1 < len) ls.addToken(e + 1, len - e - 1, .string_literal);
        } else {
            ls.addToken(pos, len - pos, .plain);
        }
    }

    // ========================================================================
    // Lua tokenizer
    // ========================================================================

    const lua_keywords = [_][]const u8{
        "and",      "break",  "do",   "else", "elseif", "end",   "false", "for",
        "function", "goto",   "if",   "in",   "local",  "nil",   "not",   "or",
        "repeat",   "return", "then", "true", "until",  "while",
    };

    pub fn tokenizeLua(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '-' and pos + 1 < len and text[pos + 1] == '-') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            if (c == '"' or c == '\'') {
                const end = skipQuotedString(text, pos, len, c);
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (isDigit(c)) {
                var e = pos + 1;
                while (e < len and (isDigit(text[e]) or text[e] == '.' or text[e] == 'x' or isHexDigit(text[e]))) : (e += 1) {}
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            if (isAlpha(c)) {
                var e = pos;
                while (e < len and isAlnum(text[e])) : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, &lua_keywords)) .keyword else if (e < len and text[e] == '(') .function_name else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            if (isPunct(c)) {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            if (isOp(c) or c == '#' or c == '~') {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // Makefile tokenizer
    // ========================================================================

    pub fn tokenizeMake(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        if (len == 0) return;
        if (text[0] == '#') {
            ls.addToken(0, len, .comment);
            return;
        }
        if (text[0] == '\t') {
            ls.addToken(0, len, .plain);
            return;
        }
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '$') {
                var e = pos + 1;
                if (e < len and (text[e] == '(' or text[e] == '{')) {
                    const close: u8 = if (text[e] == '(') ')' else '}';
                    while (e < len and text[e] != close) : (e += 1) {}
                    if (e < len) e += 1;
                }
                ls.addToken(pos, e - pos, .builtin);
                pos = e;
                continue;
            }
            if (c == '"' or c == '\'') {
                const end = skipQuotedString(text, pos, len, c);
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (c == ':' or c == '=') {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            if (isAlpha(c) or c == '_' or c == '.' or c == '/') {
                var e = pos;
                while (e < len and !isWhitespace(text[e]) and text[e] != ':' and text[e] != '=' and text[e] != '#') : (e += 1) {}
                ls.addToken(pos, e - pos, .plain);
                pos = e;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // Perl tokenizer
    // ========================================================================

    const perl_keywords = [_][]const u8{
        "my",     "our",   "local",   "sub",     "if",      "elsif",  "else",    "unless",
        "while",  "until", "for",     "foreach", "do",      "last",   "next",    "redo",
        "return", "die",   "warn",    "print",   "say",     "use",    "require", "package",
        "BEGIN",  "END",   "chomp",   "chop",    "defined", "delete", "each",    "exists",
        "grep",   "join",  "keys",    "map",     "pop",     "push",   "shift",   "sort",
        "splice", "split", "unshift", "values",  "eval",
    };

    pub fn tokenizePerl(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '#') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            if (c == '"' or c == '\'') {
                const end = skipQuotedString(text, pos, len, c);
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (c == '$' or c == '@' or c == '%') {
                var e = pos + 1;
                while (e < len and isAlnum(text[e])) : (e += 1) {}
                ls.addToken(pos, e - pos, .builtin);
                pos = e;
                continue;
            }
            if (isDigit(c)) {
                var e = pos + 1;
                while (e < len and (isDigit(text[e]) or text[e] == '.' or text[e] == '_')) : (e += 1) {}
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            if (isAlpha(c) or c == '_') {
                var e = pos;
                while (e < len and isAlnum(text[e])) : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, &perl_keywords)) .keyword else if (e < len and text[e] == '(') .function_name else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            if (isPunct(c)) {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            if (isOp(c)) {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // PowerShell tokenizer
    // ========================================================================

    const powershell_keywords = [_][]const u8{
        "Begin",   "Break",        "Catch",    "Class",   "Continue", "Data",   "Define",
        "Do",      "DynamicParam", "Else",     "ElseIf",  "End",      "Exit",   "Filter",
        "Finally", "For",          "ForEach",  "From",    "Function", "If",     "In",
        "Param",   "Process",      "Return",   "Switch",  "Throw",    "Trap",   "Try",
        "Until",   "Using",        "Var",      "While",   "Workflow", "begin",  "break",
        "catch",   "class",        "continue", "do",      "else",     "elseif", "end",
        "exit",    "filter",       "finally",  "for",     "foreach",  "from",   "function",
        "if",      "in",           "param",    "process", "return",   "switch", "throw",
        "trap",    "try",          "until",    "using",   "while",
    };

    pub fn tokenizePowershell(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '#') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            if (c == '"' or c == '\'') {
                const end = skipQuotedString(text, pos, len, c);
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (c == '$') {
                var e = pos + 1;
                while (e < len and isAlnum(text[e])) : (e += 1) {}
                ls.addToken(pos, e - pos, .builtin);
                pos = e;
                continue;
            }
            if (c == '-' and pos + 1 < len and isAlpha(text[pos + 1])) {
                var e = pos + 1;
                while (e < len and isAlnum(text[e])) : (e += 1) {}
                ls.addToken(pos, e - pos, .keyword);
                pos = e;
                continue;
            }
            if (isDigit(c)) {
                var e = pos + 1;
                while (e < len and (isDigit(text[e]) or text[e] == '.')) : (e += 1) {}
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            if (isAlpha(c)) {
                var e = pos;
                while (e < len and (isAlnum(text[e]) or text[e] == '-')) : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, &powershell_keywords)) .keyword else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            if (isPunct(c) or isOp(c) or c == '|' or c == '&') {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // R tokenizer
    // ========================================================================

    const r_keywords = [_][]const u8{
        "if",      "else",    "repeat", "while",  "function", "for", "in", "next",
        "break",   "TRUE",    "FALSE",  "NULL",   "Inf",      "NaN", "NA", "return",
        "library", "require", "source", "switch",
    };

    pub fn tokenizeR(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '#') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            if (c == '"' or c == '\'') {
                const end = skipQuotedString(text, pos, len, c);
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (isDigit(c)) {
                var e = pos + 1;
                while (e < len and (isDigit(text[e]) or text[e] == '.' or text[e] == 'e' or text[e] == 'L')) : (e += 1) {}
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            if (isAlpha(c) or c == '.') {
                var e = pos;
                while (e < len and (isAlnum(text[e]) or text[e] == '.' or text[e] == '_')) : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, &r_keywords)) .keyword else if (e < len and text[e] == '(') .function_name else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            if (c == '<' and pos + 1 < len and text[pos + 1] == '-') {
                ls.addToken(pos, 2, .operator);
                pos += 2;
                continue;
            }
            if (isPunct(c)) {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            if (isOp(c) or c == '|' or c == '&' or c == '~') {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // Swift tokenizer
    // ========================================================================

    const swift_keywords = [_][]const u8{
        "associatedtype", "class",    "deinit",    "enum",      "extension", "fileprivate",
        "func",           "import",   "init",      "inout",     "internal",  "let",
        "open",           "operator", "private",   "protocol",  "public",    "rethrows",
        "static",         "struct",   "subscript", "typealias", "var",       "break",
        "case",           "continue", "default",   "defer",     "do",        "else",
        "fallthrough",    "for",      "guard",     "if",        "in",        "repeat",
        "return",         "switch",   "where",     "while",     "as",        "catch",
        "false",          "is",       "nil",       "self",      "super",     "throw",
        "throws",         "true",     "try",       "async",     "await",
    };

    pub fn tokenizeSwift(ls: *LineSyntax, text: []const u8) void {
        tokenizeCStyleLang(ls, text, &swift_keywords);
    }

    // ========================================================================
    // Clojure tokenizer
    // ========================================================================

    const clojure_keywords = [_][]const u8{
        "def",   "defn",    "defmacro", "defonce", "fn",      "let",   "loop",   "recur",
        "if",    "when",    "cond",     "case",    "do",      "quote", "var",    "try",
        "catch", "finally", "throw",    "ns",      "require", "use",   "import", "in-ns",
        "refer", "nil",     "true",     "false",
    };

    pub fn tokenizeClojure(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c) or c == ',') {
                pos += 1;
                continue;
            }
            if (c == ';') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            if (c == '"') {
                const end = skipQuotedString(text, pos, len, '"');
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (c == ':') {
                var e = pos + 1;
                while (e < len and (isAlnum(text[e]) or text[e] == '-' or text[e] == '/' or text[e] == '.')) : (e += 1) {}
                ls.addToken(pos, e - pos, .builtin);
                pos = e;
                continue;
            }
            if (isDigit(c)) {
                var e = pos + 1;
                while (e < len and (isDigit(text[e]) or text[e] == '.')) : (e += 1) {}
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            if (c == '(' or c == ')' or c == '[' or c == ']' or c == '{' or c == '}') {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            if (isAlpha(c) or c == '-' or c == '_' or c == '*' or c == '+' or c == '!' or c == '?') {
                var e = pos;
                while (e < len and !isWhitespace(text[e]) and text[e] != ')' and text[e] != ']' and text[e] != '}' and text[e] != ',') : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, &clojure_keywords)) .keyword else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // CoffeeScript tokenizer
    // ========================================================================

    const coffee_keywords = [_][]const u8{
        "if",         "else",   "unless",    "then",     "for",    "in",     "of",      "while",
        "until",      "loop",   "break",     "continue", "return", "switch", "when",    "class",
        "extends",    "new",    "do",        "throw",    "try",    "catch",  "finally", "typeof",
        "instanceof", "delete", "and",       "or",       "not",    "is",     "isnt",    "true",
        "false",      "null",   "undefined", "yes",      "no",     "on",     "off",     "this",
        "super",      "import", "export",    "default",
    };

    pub fn tokenizeCoffee(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '#') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            if (c == '"' or c == '\'') {
                const end = skipQuotedString(text, pos, len, c);
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (c == '@') {
                var e = pos + 1;
                while (e < len and isAlnum(text[e])) : (e += 1) {}
                ls.addToken(pos, e - pos, .builtin);
                pos = e;
                continue;
            }
            if (isDigit(c)) {
                var e = pos + 1;
                while (e < len and (isDigit(text[e]) or text[e] == '.')) : (e += 1) {}
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            if (isAlpha(c) or c == '_') {
                var e = pos;
                while (e < len and isAlnum(text[e])) : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, &coffee_keywords)) .keyword else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            if (c == '-' and pos + 1 < len and text[pos + 1] == '>') {
                ls.addToken(pos, 2, .operator);
                pos += 2;
                continue;
            }
            if (c == '=' and pos + 1 < len and text[pos + 1] == '>') {
                ls.addToken(pos, 2, .operator);
                pos += 2;
                continue;
            }
            if (isPunct(c)) {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            if (isOp(c)) {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // F# tokenizer
    // ========================================================================

    const fsharp_keywords = [_][]const u8{
        "abstract",  "and",       "as",        "assert", "base",     "begin",   "class",
        "default",   "delegate",  "do",        "done",   "downcast", "downto",  "elif",
        "else",      "end",       "exception", "extern", "false",    "finally", "for",
        "fun",       "function",  "global",    "if",     "in",       "inherit", "inline",
        "interface", "internal",  "lazy",      "let",    "match",    "member",  "module",
        "mutable",   "namespace", "new",       "not",    "null",     "of",      "open",
        "or",        "override",  "private",   "public", "rec",      "return",  "static",
        "struct",    "then",      "to",        "true",   "try",      "type",    "upcast",
        "use",       "val",       "void",      "when",   "while",    "with",    "yield",
    };

    pub fn tokenizeFSharp(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '/' and pos + 1 < len and text[pos + 1] == '/') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            if (c == '"') {
                const end = skipQuotedString(text, pos, len, '"');
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (isDigit(c)) {
                var e = pos + 1;
                while (e < len and (isDigit(text[e]) or text[e] == '.' or text[e] == '_')) : (e += 1) {}
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            if (isAlpha(c) or c == '_') {
                var e = pos;
                while (e < len and (isAlnum(text[e]) or text[e] == '\'')) : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, &fsharp_keywords)) .keyword else if (c >= 'A' and c <= 'Z') .type_name else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            if (c == '|' and pos + 1 < len and text[pos + 1] == '>') {
                ls.addToken(pos, 2, .operator);
                pos += 2;
                continue;
            }
            if (isPunct(c)) {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            if (isOp(c)) {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // Julia tokenizer
    // ========================================================================

    const julia_keywords = [_][]const u8{
        "abstract", "baremodule", "begin", "break",    "catch",  "const",
        "continue", "do",         "else",  "elseif",   "end",    "export",
        "false",    "finally",    "for",   "function", "global", "if",
        "import",   "in",         "let",   "local",    "macro",  "module",
        "mutable",  "nothing",    "quote", "return",   "struct", "true",
        "try",      "type",       "using", "while",
    };

    pub fn tokenizeJulia(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '#') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            if (c == '"') {
                const end = skipQuotedString(text, pos, len, '"');
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (c == '\'') {
                if (pos + 2 < len and text[pos + 2] == '\'') {
                    ls.addToken(pos, 3, .string_literal);
                    pos += 3;
                    continue;
                }
            }
            if (isDigit(c)) {
                var e = pos + 1;
                while (e < len and (isDigit(text[e]) or text[e] == '.' or text[e] == '_' or text[e] == 'e')) : (e += 1) {}
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            if (isAlpha(c) or c == '_') {
                var e = pos;
                while (e < len and (isAlnum(text[e]) or text[e] == '_' or text[e] == '!')) : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, &julia_keywords)) .keyword else if (e < len and text[e] == '(') .function_name else if (c >= 'A' and c <= 'Z') .type_name else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            if (isPunct(c)) {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            if (isOp(c) or c == '|' or c == '&') {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // LaTeX tokenizer
    // ========================================================================

    pub fn tokenizeLatex(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '%') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            if (c == '\\') {
                var e = pos + 1;
                while (e < len and isAlpha(text[e])) : (e += 1) {}
                if (e == pos + 1 and e < len) e += 1;
                ls.addToken(pos, e - pos, .keyword);
                pos = e;
                continue;
            }
            if (c == '$') {
                var e = pos + 1;
                while (e < len and text[e] != '$') : (e += 1) {}
                if (e < len) e += 1;
                ls.addToken(pos, e - pos, .builtin);
                pos = e;
                continue;
            }
            if (c == '{' or c == '}' or c == '[' or c == ']') {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            if (c == '&' or c == '~' or c == '^' or c == '_') {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            var e = pos;
            while (e < len and text[e] != '\\' and text[e] != '%' and text[e] != '$' and
                text[e] != '{' and text[e] != '}' and text[e] != '[' and text[e] != ']') : (e += 1)
            {}
            if (e > pos) {
                ls.addToken(pos, e - pos, .plain);
                pos = e;
            } else {
                pos += 1;
            }
        }
    }

    // ========================================================================
    // Log file tokenizer
    // ========================================================================

    pub fn tokenizeLog(ls: *LineSyntax, text: []const u8) void {
        const len: u16 = @intCast(text.len);
        if (len == 0) return;
        // Color entire line based on log level keywords
        var i: u16 = 0;
        while (i + 4 < len) : (i += 1) {
            const slice = text[i..];
            if (slice.len >= 5 and eql(slice[0..5], "ERROR")) {
                ls.addToken(0, len, .keyword);
                return;
            }
            if (slice.len >= 4 and eql(slice[0..4], "WARN")) {
                ls.addToken(0, len, .preprocessor);
                return;
            }
            if (slice.len >= 4 and eql(slice[0..4], "INFO")) {
                ls.addToken(0, len, .string_literal);
                return;
            }
            if (slice.len >= 5 and eql(slice[0..5], "DEBUG")) {
                ls.addToken(0, len, .comment);
                return;
            }
            if (slice.len >= 5 and eql(slice[0..5], "TRACE")) {
                ls.addToken(0, len, .comment);
                return;
            }
            if (slice.len >= 5 and eql(slice[0..5], "FATAL")) {
                ls.addToken(0, len, .keyword);
                return;
            }
        }
        ls.addToken(0, len, .plain);
    }

    // ========================================================================
    // reStructuredText tokenizer
    // ========================================================================

    pub fn tokenizeRst(ls: *LineSyntax, text: []const u8) void {
        const len: u16 = @intCast(text.len);
        if (len == 0) return;
        // Directives: .. directive::
        if (len >= 2 and text[0] == '.' and text[1] == '.') {
            ls.addToken(0, len, .keyword);
            return;
        }
        // Section underlines (===, ---, ~~~, etc.)
        if (len >= 3 and (text[0] == '=' or text[0] == '-' or text[0] == '~' or text[0] == '^' or text[0] == '*')) {
            var all_same = true;
            var j: u16 = 1;
            while (j < len) : (j += 1) {
                if (text[j] != text[0]) {
                    all_same = false;
                    break;
                }
            }
            if (all_same) {
                ls.addToken(0, len, .preprocessor);
                return;
            }
        }
        // Inline markup
        var pos: u16 = 0;
        while (pos < len) {
            const c = text[pos];
            if (c == '`') {
                var e = pos + 1;
                while (e < len and text[e] != '`') : (e += 1) {}
                if (e < len) e += 1;
                ls.addToken(pos, e - pos, .string_literal);
                pos = e;
                continue;
            }
            if (c == ':' and pos + 1 < len) {
                var e = pos + 1;
                while (e < len and text[e] != ':') : (e += 1) {}
                if (e < len and e > pos + 1) {
                    e += 1;
                    ls.addToken(pos, e - pos, .builtin);
                    pos = e;
                    continue;
                }
            }
            pos += 1;
        }
        if (ls.token_count == 0) ls.addToken(0, len, .plain);
    }

    // ========================================================================
    // VB / VB.NET tokenizer
    // ========================================================================

    const vb_keywords = [_][]const u8{
        "AddHandler",  "AddressOf",    "Alias",      "And",           "AndAlso",        "As",
        "Boolean",     "ByRef",        "Byte",       "ByVal",         "Call",           "Case",
        "Catch",       "CBool",        "CByte",      "CChar",         "CDate",          "CDbl",
        "CDec",        "Char",         "CInt",       "Class",         "CLng",           "CObj",
        "Const",       "Continue",     "CSByte",     "CShort",        "CSng",           "CStr",
        "CType",       "CUInt",        "CULng",      "CUShort",       "Date",           "Decimal",
        "Declare",     "Default",      "Delegate",   "Dim",           "DirectCast",     "Do",
        "Double",      "Each",         "Else",       "ElseIf",        "End",            "Enum",
        "Erase",       "Error",        "Event",      "Exit",          "False",          "Finally",
        "For",         "Friend",       "Function",   "Get",           "GetType",        "GoTo",
        "Handles",     "If",           "Implements", "Imports",       "In",             "Inherits",
        "Integer",     "Interface",    "Is",         "IsNot",         "Let",            "Lib",
        "Like",        "Long",         "Loop",       "Me",            "Mod",            "Module",
        "MustInherit", "MustOverride", "MyBase",     "MyClass",       "Namespace",      "Narrowing",
        "New",         "Next",         "Not",        "Nothing",       "NotInheritable", "NotOverridable",
        "Object",      "Of",           "On",         "Operator",      "Option",         "Optional",
        "Or",          "OrElse",       "Overloads",  "Overridable",   "Overrides",      "ParamArray",
        "Partial",     "Private",      "Property",   "Protected",     "Public",         "RaiseEvent",
        "ReadOnly",    "ReDim",        "REM",        "RemoveHandler", "Resume",         "Return",
        "SByte",       "Select",       "Set",        "Shadows",       "Shared",         "Short",
        "Single",      "Static",       "Step",       "Stop",          "String",         "Structure",
        "Sub",         "SyncLock",     "Then",       "Throw",         "To",             "True",
        "Try",         "TryCast",      "TypeOf",     "UInteger",      "ULong",          "UShort",
        "Using",       "Variant",      "Wend",       "When",          "While",          "Widening",
        "With",        "WithEvents",   "WriteOnly",
    };

    pub fn tokenizeVb(ls: *LineSyntax, text: []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            if (c == '\'') {
                ls.addToken(pos, len - pos, .comment);
                return;
            }
            if (c == '"') {
                const end = skipQuotedString(text, pos, len, '"');
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            if (isDigit(c)) {
                var e = pos + 1;
                while (e < len and (isDigit(text[e]) or text[e] == '.')) : (e += 1) {}
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            if (isAlpha(c) or c == '_') {
                var e = pos;
                while (e < len and isAlnum(text[e])) : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, &vb_keywords)) .keyword else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            if (isPunct(c)) {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            if (isOp(c)) {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }

    // ========================================================================
    // Shared helpers for new tokenizers
    // ========================================================================

    fn isPunct(c: u8) bool {
        return c == '(' or c == ')' or c == '[' or c == ']' or c == '{' or c == '}' or c == ';' or c == ',' or c == '.';
    }

    fn isOp(c: u8) bool {
        return c == '+' or c == '-' or c == '*' or c == '/' or c == '=' or c == '<' or c == '>' or c == '!' or c == '%' or c == '^';
    }

    fn skipQuotedString(text: []const u8, start: u16, len: u16, quote: u8) u16 {
        var pos = start + 1;
        while (pos < len) {
            if (text[pos] == '\\' and pos + 1 < len) {
                pos += 2;
                continue;
            }
            if (text[pos] == quote) {
                pos += 1;
                break;
            }
            pos += 1;
        }
        return pos;
    }

    /// Generic C-style language tokenizer (Java, C#, Dart, Swift, etc.)
    fn tokenizeCStyleLang(ls: *LineSyntax, text: []const u8, keywords: []const []const u8) void {
        var pos: u16 = 0;
        const len: u16 = @intCast(text.len);
        while (pos < len) {
            const c = text[pos];
            if (isWhitespace(c)) {
                pos += 1;
                continue;
            }
            // Line comment
            if (c == '/' and pos + 1 < len) {
                if (text[pos + 1] == '/') {
                    ls.addToken(pos, len - pos, .comment);
                    return;
                }
                if (text[pos + 1] == '*') {
                    var e = pos + 2;
                    while (e + 1 < len) : (e += 1) {
                        if (text[e] == '*' and text[e + 1] == '/') {
                            e += 2;
                            break;
                        }
                    }
                    ls.addToken(pos, e - pos, .comment);
                    pos = e;
                    continue;
                }
            }
            // Strings
            if (c == '"' or c == '\'') {
                const end = skipQuotedString(text, pos, len, c);
                ls.addToken(pos, end - pos, .string_literal);
                pos = end;
                continue;
            }
            // Preprocessor (#include, #define, etc.)
            if (c == '#' and pos == 0) {
                ls.addToken(pos, len - pos, .preprocessor);
                return;
            }
            // Numbers
            if (isDigit(c) or (c == '.' and pos + 1 < len and isDigit(text[pos + 1]))) {
                var e = pos;
                if (c == '0' and e + 1 < len and (text[e + 1] == 'x' or text[e + 1] == 'X')) {
                    e += 2;
                    while (e < len and isHexDigit(text[e])) : (e += 1) {}
                } else {
                    while (e < len and (isDigit(text[e]) or text[e] == '.' or text[e] == '_' or
                        text[e] == 'e' or text[e] == 'E' or text[e] == 'f' or text[e] == 'F' or
                        text[e] == 'l' or text[e] == 'L')) : (e += 1)
                    {}
                }
                if (e == pos) e = pos + 1;
                ls.addToken(pos, e - pos, .number_literal);
                pos = e;
                continue;
            }
            // Identifiers / keywords
            if (isAlpha(c)) {
                var e = pos;
                while (e < len and isAlnum(text[e])) : (e += 1) {}
                const word = text[pos..e];
                const kind: TokenKind = if (isKeywordIn(word, keywords)) .keyword else if (e < len and text[e] == '(') .function_name else if (c >= 'A' and c <= 'Z') .type_name else .plain;
                ls.addToken(pos, e - pos, kind);
                pos = e;
                continue;
            }
            // Annotation (@Override, etc.)
            if (c == '@' and pos + 1 < len and isAlpha(text[pos + 1])) {
                var e = pos + 1;
                while (e < len and isAlnum(text[e])) : (e += 1) {}
                ls.addToken(pos, e - pos, .preprocessor);
                pos = e;
                continue;
            }
            if (isPunct(c)) {
                ls.addToken(pos, 1, .punctuation);
                pos += 1;
                continue;
            }
            if (isOp(c) or c == '|' or c == '&' or c == '~' or c == '?') {
                ls.addToken(pos, 1, .operator);
                pos += 1;
                continue;
            }
            ls.addToken(pos, 1, .plain);
            pos += 1;
        }
    }
};

// ============================================================================
// Unit tests
// ============================================================================

const std = @import("std");
const expect = std.testing.expect;

fn verifyTokenCoverage(ls: *const LineSyntax, line_len: u16) !void {
    if (line_len == 0) {
        try expect(ls.token_count == 0);
        return;
    }
    try expect(ls.token_count > 0);

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

// --- Zig tokenizer tests ---

test "SyntaxHighlighter Zig — keywords recognized" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "const x = 5;");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .keyword);
    try verifyTokenCoverage(&ls, 12);
}

test "SyntaxHighlighter Zig — fn keyword" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "pub fn main() void {");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .keyword);
    try expect(ls.tokens[2].kind == .keyword);
    try verifyTokenCoverage(&ls, 20);
}

test "SyntaxHighlighter Zig — string literal" {
    var sh = SyntaxHighlighter{ .language = .zig_lang };
    sh.tokenizeLine(0, "const s = \"hello\";");
    const ls = sh.line_syntax[0];
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

// --- Python tokenizer tests ---

test "SyntaxHighlighter Python — keyword def" {
    var sh = SyntaxHighlighter{ .language = .python };
    sh.tokenizeLine(0, "def foo():");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .keyword);
    try expect(ls.tokens[0].len == 3);
    try verifyTokenCoverage(&ls, 10);
}

test "SyntaxHighlighter Python — comment" {
    var sh = SyntaxHighlighter{ .language = .python };
    sh.tokenizeLine(0, "x = 1 # comment");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[ls.token_count - 1].kind == .comment);
    try verifyTokenCoverage(&ls, 15);
}

test "SyntaxHighlighter Python — string" {
    var sh = SyntaxHighlighter{ .language = .python };
    sh.tokenizeLine(0, "\"hello\"");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .string_literal);
    try verifyTokenCoverage(&ls, 7);
}

test "SyntaxHighlighter Python — decorator" {
    var sh = SyntaxHighlighter{ .language = .python };
    sh.tokenizeLine(0, "@property");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .preprocessor);
    try verifyTokenCoverage(&ls, 9);
}

test "SyntaxHighlighter Python — builtin" {
    var sh = SyntaxHighlighter{ .language = .python };
    sh.tokenizeLine(0, "print(len(x))");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .builtin);
    try verifyTokenCoverage(&ls, 13);
}

// --- JavaScript/TypeScript tokenizer tests ---

test "SyntaxHighlighter JS — keywords" {
    var sh = SyntaxHighlighter{ .language = .javascript };
    sh.tokenizeLine(0, "const x = 5;");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .keyword);
    try verifyTokenCoverage(&ls, 12);
}

test "SyntaxHighlighter TS — keywords" {
    var sh = SyntaxHighlighter{ .language = .typescript };
    sh.tokenizeLine(0, "interface Foo {}");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .keyword);
    try verifyTokenCoverage(&ls, 16);
}

test "SyntaxHighlighter JS — template literal" {
    var sh = SyntaxHighlighter{ .language = .javascript };
    sh.tokenizeLine(0, "`hello`");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .string_literal);
    try verifyTokenCoverage(&ls, 7);
}

test "SyntaxHighlighter JS — line comment" {
    var sh = SyntaxHighlighter{ .language = .javascript };
    sh.tokenizeLine(0, "// comment");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .comment);
    try verifyTokenCoverage(&ls, 10);
}

// --- C/C++ tokenizer tests ---

test "SyntaxHighlighter C — keywords" {
    var sh = SyntaxHighlighter{ .language = .c_lang };
    sh.tokenizeLine(0, "int main() {");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .keyword);
    try verifyTokenCoverage(&ls, 12);
}

test "SyntaxHighlighter C++ — keywords" {
    var sh = SyntaxHighlighter{ .language = .cpp_lang };
    sh.tokenizeLine(0, "class Foo {};");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .keyword);
    try verifyTokenCoverage(&ls, 13);
}

test "SyntaxHighlighter C — preprocessor" {
    var sh = SyntaxHighlighter{ .language = .c_lang };
    sh.tokenizeLine(0, "#include <stdio.h>");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .preprocessor);
    try verifyTokenCoverage(&ls, 18);
}

test "SyntaxHighlighter C — line comment" {
    var sh = SyntaxHighlighter{ .language = .c_lang };
    sh.tokenizeLine(0, "// comment");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .comment);
    try verifyTokenCoverage(&ls, 10);
}

// --- Rust tokenizer tests ---

test "SyntaxHighlighter Rust — keywords" {
    var sh = SyntaxHighlighter{ .language = .rust_lang };
    sh.tokenizeLine(0, "fn main() {");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .keyword);
    try verifyTokenCoverage(&ls, 11);
}

test "SyntaxHighlighter Rust — attribute" {
    var sh = SyntaxHighlighter{ .language = .rust_lang };
    sh.tokenizeLine(0, "#[derive(Debug)]");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .preprocessor);
    try verifyTokenCoverage(&ls, 16);
}

test "SyntaxHighlighter Rust — string" {
    var sh = SyntaxHighlighter{ .language = .rust_lang };
    sh.tokenizeLine(0, "\"hello\"");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .string_literal);
    try verifyTokenCoverage(&ls, 7);
}

// --- Go tokenizer tests ---

test "SyntaxHighlighter Go — keywords" {
    var sh = SyntaxHighlighter{ .language = .go_lang };
    sh.tokenizeLine(0, "func main() {");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .keyword);
    try verifyTokenCoverage(&ls, 13);
}

test "SyntaxHighlighter Go — builtin" {
    var sh = SyntaxHighlighter{ .language = .go_lang };
    sh.tokenizeLine(0, "make([]int, 0)");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .builtin);
    try verifyTokenCoverage(&ls, 14);
}

test "SyntaxHighlighter Go — raw string" {
    var sh = SyntaxHighlighter{ .language = .go_lang };
    sh.tokenizeLine(0, "`raw`");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .string_literal);
    try verifyTokenCoverage(&ls, 5);
}

// --- Markdown tokenizer tests ---

test "SyntaxHighlighter Markdown — heading" {
    var sh = SyntaxHighlighter{ .language = .markdown };
    sh.tokenizeLine(0, "# Hello");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .keyword);
    try verifyTokenCoverage(&ls, 7);
}

test "SyntaxHighlighter Markdown — inline code" {
    var sh = SyntaxHighlighter{ .language = .markdown };
    sh.tokenizeLine(0, "use `code` here");
    const ls = sh.line_syntax[0];
    var found_str = false;
    var i: u16 = 0;
    while (i < ls.token_count) : (i += 1) {
        if (ls.tokens[i].kind == .string_literal) {
            found_str = true;
            break;
        }
    }
    try expect(found_str);
    try verifyTokenCoverage(&ls, 15);
}

// --- HTML tokenizer tests ---

test "SyntaxHighlighter HTML — tag" {
    var sh = SyntaxHighlighter{ .language = .html };
    sh.tokenizeLine(0, "<div>");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .keyword);
    try verifyTokenCoverage(&ls, 5);
}

test "SyntaxHighlighter HTML — comment" {
    var sh = SyntaxHighlighter{ .language = .html };
    sh.tokenizeLine(0, "<!-- comment -->");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .comment);
    try verifyTokenCoverage(&ls, 16);
}

test "SyntaxHighlighter HTML — attribute" {
    var sh = SyntaxHighlighter{ .language = .html };
    sh.tokenizeLine(0, "<a href=\"url\">");
    const ls = sh.line_syntax[0];
    try verifyTokenCoverage(&ls, 14);
}

// --- CSS tokenizer tests ---

test "SyntaxHighlighter CSS — at-rule" {
    var sh = SyntaxHighlighter{ .language = .css };
    sh.tokenizeLine(0, "@media screen {");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .keyword);
    try verifyTokenCoverage(&ls, 15);
}

test "SyntaxHighlighter CSS — class selector" {
    var sh = SyntaxHighlighter{ .language = .css };
    sh.tokenizeLine(0, ".container {");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .type_name);
    try verifyTokenCoverage(&ls, 12);
}

test "SyntaxHighlighter CSS — comment" {
    var sh = SyntaxHighlighter{ .language = .css };
    sh.tokenizeLine(0, "/* comment */");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .comment);
    try verifyTokenCoverage(&ls, 13);
}

test "SyntaxHighlighter CSS — number with unit" {
    var sh = SyntaxHighlighter{ .language = .css };
    sh.tokenizeLine(0, "10px");
    const ls = sh.line_syntax[0];
    try expect(ls.tokens[0].kind == .number_literal);
    try verifyTokenCoverage(&ls, 4);
}
