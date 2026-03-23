// src/extensions/markdown_lang.zig — Markdown Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const md_syntax = ext.SyntaxContribution{
    .language = .markdown,
    .display_name = "Markdown",
    .file_extensions = &.{ ".md", ".markdown", ".mdown", ".mkd" },
    .line_comment = "",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeMarkdown,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "link",
        .label = "Link",
        .description = "Markdown link",
        .body = "[$1]($2)",
        .language = .markdown,
    },
    .{
        .prefix = "img",
        .label = "Image",
        .description = "Markdown image",
        .body = "![$1]($2)",
        .language = .markdown,
    },
    .{
        .prefix = "code",
        .label = "Code Block",
        .description = "Fenced code block",
        .body = "```$1\n$0\n```",
        .language = .markdown,
    },
    .{
        .prefix = "table",
        .label = "Table",
        .description = "Markdown table",
        .body = "| $1 | $2 |\n| --- | --- |\n| $0 |  |",
        .language = .markdown,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.markdown-lang",
    .name = "Markdown Language",
    .version = "0.1.0",
    .description = "Markdown language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{md_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;
const expect = testing.expect;

test "markdown_lang extension has correct metadata" {
    try expect(extension.syntax.len == 1);
    try expect(extension.snippets.len == 4);
    try expect(extension.capabilities.syntax);
    try expect(extension.capabilities.snippets);
}

test "markdown_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "# Hello");
    try expect(ls.token_count > 0);
}
