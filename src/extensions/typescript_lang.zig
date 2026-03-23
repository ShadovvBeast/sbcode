// src/extensions/typescript_lang.zig — TypeScript Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const ts_syntax = ext.SyntaxContribution{
    .language = .typescript,
    .display_name = "TypeScript",
    .file_extensions = &.{ ".ts", ".tsx", ".mts", ".cts" },
    .line_comment = "//",
    .block_comment_open = "/*",
    .block_comment_close = "*/",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeJsTsCommon,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "interface",
        .label = "Interface",
        .description = "TypeScript interface",
        .body = "interface $1 {\n    $0\n}",
        .language = .typescript,
    },
    .{
        .prefix = "type",
        .label = "Type Alias",
        .description = "TypeScript type alias",
        .body = "type $1 = $0;",
        .language = .typescript,
    },
    .{
        .prefix = "class",
        .label = "Class",
        .description = "TypeScript class",
        .body = "class $1 {\n    constructor($2) {\n        $0\n    }\n}",
        .language = .typescript,
    },
    .{
        .prefix = "fn",
        .label = "Function",
        .description = "TypeScript function",
        .body = "function $1($2): $3 {\n    $0\n}",
        .language = .typescript,
    },
    .{
        .prefix = "arrow",
        .label = "Arrow Function",
        .description = "Arrow function expression",
        .body = "const $1 = ($2) => {\n    $0\n};",
        .language = .typescript,
    },
    .{
        .prefix = "import",
        .label = "Import",
        .description = "ES module import",
        .body = "import { $1 } from '$2';",
        .language = .typescript,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.typescript-lang",
    .name = "TypeScript Language",
    .version = "0.1.0",
    .description = "TypeScript language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{ts_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;
const expect = testing.expect;

test "typescript_lang extension has correct metadata" {
    try expect(extension.syntax.len == 1);
    try expect(extension.snippets.len == 6);
    try expect(extension.capabilities.syntax);
    try expect(extension.capabilities.snippets);
}

test "typescript_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "const x: number = 5;");
    try expect(ls.token_count > 0);
    try expect(ls.tokens[0].kind == .keyword);
}
