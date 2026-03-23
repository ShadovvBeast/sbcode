// src/extensions/r_lang.zig — R Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const r_syntax = ext.SyntaxContribution{
    .language = .r_lang,
    .display_name = "R",
    .file_extensions = &.{ ".r", ".R", ".rmd" },
    .line_comment = "#",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeR,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "fn",
        .label = "Function",
        .description = "R function",
        .body = "$1 <- function($2) {\n  $0\n}",
        .language = .r_lang,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.r-lang",
    .name = "R Language",
    .version = "0.1.0",
    .description = "R language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{r_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "r_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "r_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "library(ggplot2)");
    try testing.expect(ls.token_count > 0);
    try testing.expect(ls.tokens[0].kind == .keyword);
}
