// src/extensions/javascript_lang.zig — JavaScript Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const js_syntax = ext.SyntaxContribution{
    .language = .javascript,
    .display_name = "JavaScript",
    .file_extensions = &.{ ".js", ".jsx", ".mjs", ".cjs" },
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
        .prefix = "fn",
        .label = "Function",
        .description = "JavaScript function",
        .body = "function $1($2) {\n    $0\n}",
        .language = .javascript,
    },
    .{
        .prefix = "arrow",
        .label = "Arrow Function",
        .description = "Arrow function expression",
        .body = "const $1 = ($2) => {\n    $0\n};",
        .language = .javascript,
    },
    .{
        .prefix = "class",
        .label = "Class",
        .description = "JavaScript class",
        .body = "class $1 {\n    constructor($2) {\n        $0\n    }\n}",
        .language = .javascript,
    },
    .{
        .prefix = "import",
        .label = "Import",
        .description = "ES module import",
        .body = "import { $1 } from '$2';",
        .language = .javascript,
    },
    .{
        .prefix = "for",
        .label = "For-Of Loop",
        .description = "For-of loop",
        .body = "for (const $1 of $2) {\n    $0\n}",
        .language = .javascript,
    },
    .{
        .prefix = "try",
        .label = "Try-Catch",
        .description = "Try-catch block",
        .body = "try {\n    $1\n} catch ($2) {\n    $0\n}",
        .language = .javascript,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.javascript-lang",
    .name = "JavaScript Language",
    .version = "0.1.0",
    .description = "JavaScript language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{js_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;
const expect = testing.expect;

test "javascript_lang extension has correct metadata" {
    try expect(extension.syntax.len == 1);
    try expect(extension.snippets.len == 6);
    try expect(extension.capabilities.syntax);
    try expect(extension.capabilities.snippets);
}

test "javascript_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "const x = 5;");
    try expect(ls.token_count > 0);
    try expect(ls.tokens[0].kind == .keyword);
}
