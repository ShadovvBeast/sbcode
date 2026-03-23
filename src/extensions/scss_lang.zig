// src/extensions/scss_lang.zig — SCSS Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const scss_syntax = ext.SyntaxContribution{
    .language = .scss,
    .display_name = "SCSS",
    .file_extensions = &.{".scss"},
    .line_comment = "//",
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
        .prefix = "var",
        .label = "Variable",
        .description = "SCSS variable",
        .body = "$$1: $0;",
        .language = .scss,
    },
    .{
        .prefix = "mixin",
        .label = "Mixin",
        .description = "SCSS mixin",
        .body = "@mixin $1 {\n  $0\n}",
        .language = .scss,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.scss-lang",
    .name = "SCSS Language",
    .version = "0.1.0",
    .description = "SCSS language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{scss_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "scss_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 2);
}

test "scss_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, ".class { color: red; }");
    try testing.expect(ls.token_count > 0);
}
