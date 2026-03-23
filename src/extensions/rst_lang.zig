// src/extensions/rst_lang.zig — reStructuredText Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const rst_syntax = ext.SyntaxContribution{
    .language = .restructuredtext,
    .display_name = "reStructuredText",
    .file_extensions = &.{ ".rst", ".rest" },
    .line_comment = "..",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{},
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeRst,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "title",
        .label = "Title",
        .description = "RST title",
        .body = "$1\n====\n$0",
        .language = .restructuredtext,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.rst-lang",
    .name = "reStructuredText Language",
    .version = "0.1.0",
    .description = "reStructuredText language support",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{rst_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "rst_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "rst_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "Title");
    try testing.expect(ls.token_count > 0);
}
