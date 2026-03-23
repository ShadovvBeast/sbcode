// src/extensions/less_lang.zig — Less Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const less_syntax = ext.SyntaxContribution{
    .language = .less,
    .display_name = "Less",
    .file_extensions = &.{".less"},
    .line_comment = "//",
    .block_comment_open = "/*",
    .block_comment_close = "*/",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeCss,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "var",
        .label = "Variable",
        .description = "Less variable",
        .body = "@$1: $0;",
        .language = .less,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.less-lang",
    .name = "Less Language",
    .version = "0.1.0",
    .description = "Less language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{less_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "less_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "less_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, ".class { color: red; }");
    try testing.expect(ls.token_count > 0);
}
