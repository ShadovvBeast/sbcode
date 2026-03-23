// src/extensions/groovy_lang.zig — Groovy Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const groovy_syntax = ext.SyntaxContribution{
    .language = .groovy,
    .display_name = "Groovy",
    .file_extensions = &.{ ".groovy", ".gradle" },
    .line_comment = "//",
    .block_comment_open = "/*",
    .block_comment_close = "*/",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeJava,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "def",
        .label = "Method",
        .description = "Groovy method",
        .body = "def $1($2) {\n    $0\n}",
        .language = .groovy,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.groovy-lang",
    .name = "Groovy Language",
    .version = "0.1.0",
    .description = "Groovy language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{groovy_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "groovy_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "groovy_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "class Main {");
    try testing.expect(ls.token_count > 0);
}
