// src/extensions/css_lang.zig — CSS Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const css_syntax = ext.SyntaxContribution{
    .language = .css,
    .display_name = "CSS",
    .file_extensions = &.{ ".css", ".scss", ".less" },
    .line_comment = "",
    .block_comment_open = "/*",
    .block_comment_close = "*/",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeCss,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "rule",
        .label = "CSS Rule",
        .description = "CSS rule block",
        .body = "$1 {\n    $0\n}",
        .language = .css,
    },
    .{
        .prefix = "media",
        .label = "Media Query",
        .description = "CSS media query",
        .body = "@media ($1) {\n    $0\n}",
        .language = .css,
    },
    .{
        .prefix = "flex",
        .label = "Flexbox Container",
        .description = "CSS flexbox layout",
        .body = "display: flex;\njustify-content: $1;\nalign-items: $2;",
        .language = .css,
    },
    .{
        .prefix = "grid",
        .label = "Grid Container",
        .description = "CSS grid layout",
        .body = "display: grid;\ngrid-template-columns: $1;\ngap: $2;",
        .language = .css,
    },
    .{
        .prefix = "var",
        .label = "CSS Variable",
        .description = "CSS custom property",
        .body = "var(--$1)",
        .language = .css,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.css-lang",
    .name = "CSS Language",
    .version = "0.1.0",
    .description = "CSS language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{css_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;
const expect = testing.expect;

test "css_lang extension has correct metadata" {
    try expect(extension.syntax.len == 1);
    try expect(extension.snippets.len == 5);
    try expect(extension.capabilities.syntax);
    try expect(extension.capabilities.snippets);
}

test "css_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, ".container {");
    try expect(ls.token_count > 0);
    try expect(ls.tokens[0].kind == .type_name);
}
