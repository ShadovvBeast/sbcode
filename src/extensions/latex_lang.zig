// src/extensions/latex_lang.zig — LaTeX Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const latex_syntax = ext.SyntaxContribution{
    .language = .latex,
    .display_name = "LaTeX",
    .file_extensions = &.{ ".tex", ".sty", ".cls", ".bib" },
    .line_comment = "%",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeLatex,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "begin",
        .label = "Environment",
        .description = "LaTeX environment",
        .body = "\\begin{$1}\n  $0\n\\end{$1}",
        .language = .latex,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.latex-lang",
    .name = "LaTeX Language",
    .version = "0.1.0",
    .description = "LaTeX language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{latex_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "latex_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "latex_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "\\documentclass{article}");
    try testing.expect(ls.token_count > 0);
}
