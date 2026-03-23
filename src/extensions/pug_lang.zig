// src/extensions/pug_lang.zig — Pug Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const pug_syntax = ext.SyntaxContribution{
    .language = .pug,
    .display_name = "Pug",
    .file_extensions = &.{ ".pug", ".jade" },
    .line_comment = "//-",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeHtml,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "div",
        .label = "Div",
        .description = "Pug div element",
        .body = "div\n  $0",
        .language = .pug,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.pug-lang",
    .name = "Pug Language",
    .version = "0.1.0",
    .description = "Pug template language support",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{pug_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "pug_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "pug_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "<div>hello</div>");
    try testing.expect(ls.token_count > 0);
}
