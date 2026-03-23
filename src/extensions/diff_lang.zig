// src/extensions/diff_lang.zig — Diff Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const diff_syntax = ext.SyntaxContribution{
    .language = .diff_lang,
    .display_name = "Diff",
    .file_extensions = &.{ ".diff", ".patch" },
    .line_comment = "",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{},
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeDiff,
};

const snippets = [_]ext.SnippetContribution{};

pub const extension = ext.Extension{
    .id = "sbcode.diff-lang",
    .name = "Diff Language",
    .version = "0.1.0",
    .description = "Diff/patch file syntax highlighting",
    .capabilities = .{ .syntax = true, .snippets = false },
    .syntax = &.{diff_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "diff_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 0);
}

test "diff_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "+added line");
    try testing.expect(ls.token_count > 0);
}
