// src/extensions/dart_lang.zig — Dart Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const dart_syntax = ext.SyntaxContribution{
    .language = .dart,
    .display_name = "Dart",
    .file_extensions = &.{".dart"},
    .line_comment = "//",
    .block_comment_open = "/*",
    .block_comment_close = "*/",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeDart,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "main",
        .label = "Main Function",
        .description = "Dart main function",
        .body = "void main() {\n  $0\n}",
        .language = .dart,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.dart-lang",
    .name = "Dart Language",
    .version = "0.1.0",
    .description = "Dart language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{dart_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "dart_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "dart_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "void main() {");
    try testing.expect(ls.token_count > 0);
}
