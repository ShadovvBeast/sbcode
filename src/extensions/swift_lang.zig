// src/extensions/swift_lang.zig — Swift Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const swift_syntax = ext.SyntaxContribution{
    .language = .swift,
    .display_name = "Swift",
    .file_extensions = &.{".swift"},
    .line_comment = "//",
    .block_comment_open = "/*",
    .block_comment_close = "*/",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeSwift,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "fn",
        .label = "Function",
        .description = "Swift function",
        .body = "func $1($2) -> $3 {\n    $0\n}",
        .language = .swift,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.swift-lang",
    .name = "Swift Language",
    .version = "0.1.0",
    .description = "Swift language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{swift_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "swift_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "swift_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "import Foundation");
    try testing.expect(ls.token_count > 0);
}
