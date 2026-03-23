// src/extensions/dotenv_lang.zig — Dotenv Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const dotenv_syntax = ext.SyntaxContribution{
    .language = .dotenv,
    .display_name = "Dotenv",
    .file_extensions = &.{".env"},
    .line_comment = "#",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{},
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeIni,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "var",
        .label = "Variable",
        .description = "Environment variable",
        .body = "$1=$0",
        .language = .dotenv,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.dotenv-lang",
    .name = "Dotenv Language",
    .version = "0.1.0",
    .description = "Dotenv file syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{dotenv_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "dotenv_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "dotenv_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "KEY=value");
    try testing.expect(ls.token_count > 0);
}
