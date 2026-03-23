// src/extensions/perl_lang.zig — Perl Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const perl_syntax = ext.SyntaxContribution{
    .language = .perl,
    .display_name = "Perl",
    .file_extensions = &.{ ".pl", ".pm", ".t" },
    .line_comment = "#",
    .block_comment_open = "=pod",
    .block_comment_close = "=cut",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizePerl,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "sub",
        .label = "Subroutine",
        .description = "Perl subroutine",
        .body = "sub $1 {\n    $0\n}",
        .language = .perl,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.perl-lang",
    .name = "Perl Language",
    .version = "0.1.0",
    .description = "Perl language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{perl_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "perl_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "perl_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "use strict;");
    try testing.expect(ls.token_count > 0);
    try testing.expect(ls.tokens[0].kind == .keyword);
}
