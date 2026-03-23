// src/extensions/make_lang.zig — Makefile Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const make_syntax = ext.SyntaxContribution{
    .language = .make,
    .display_name = "Makefile",
    .file_extensions = &.{".mk"},
    .line_comment = "#",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '(', ')' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeMake,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "target",
        .label = "Target",
        .description = "Makefile target",
        .body = "$1:\n\t$0",
        .language = .make,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.make-lang",
    .name = "Makefile Language",
    .version = "0.1.0",
    .description = "Makefile language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{make_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "make_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "make_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "all: build");
    try testing.expect(ls.token_count > 0);
}
