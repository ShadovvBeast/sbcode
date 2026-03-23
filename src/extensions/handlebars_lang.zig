// src/extensions/handlebars_lang.zig — Handlebars Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const handlebars_syntax = ext.SyntaxContribution{
    .language = .handlebars,
    .display_name = "Handlebars",
    .file_extensions = &.{ ".hbs", ".handlebars" },
    .line_comment = "",
    .block_comment_open = "{{!--",
    .block_comment_close = "--}}",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '<', '>' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeHtml,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "each",
        .label = "Each Block",
        .description = "Handlebars each helper",
        .body = "{{#each $1}}\n  $0\n{{/each}}",
        .language = .handlebars,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.handlebars-lang",
    .name = "Handlebars Language",
    .version = "0.1.0",
    .description = "Handlebars template language support",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{handlebars_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "handlebars_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "handlebars_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "<div>{{name}}</div>");
    try testing.expect(ls.token_count > 0);
}
