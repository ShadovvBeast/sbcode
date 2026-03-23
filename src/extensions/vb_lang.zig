// src/extensions/vb_lang.zig — Visual Basic Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const vb_syntax = ext.SyntaxContribution{
    .language = .vb,
    .display_name = "Visual Basic",
    .file_extensions = &.{ ".vb", ".bas" },
    .line_comment = "'",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '(', ')' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeVb,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "sub",
        .label = "Sub",
        .description = "VB Sub procedure",
        .body = "Sub $1()\n    $0\nEnd Sub",
        .language = .vb,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.vb-lang",
    .name = "Visual Basic Language",
    .version = "0.1.0",
    .description = "Visual Basic language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{vb_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "vb_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "vb_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "Dim x As Integer");
    try testing.expect(ls.token_count > 0);
    try testing.expect(ls.tokens[0].kind == .keyword);
}
