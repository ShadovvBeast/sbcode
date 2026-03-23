// src/extensions/ruby_lang.zig — Ruby Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const ruby_syntax = ext.SyntaxContribution{
    .language = .ruby,
    .display_name = "Ruby",
    .file_extensions = &.{ ".rb", ".rake", ".gemspec", ".ru" },
    .line_comment = "#",
    .block_comment_open = "=begin",
    .block_comment_close = "=end",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeRuby,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "def",
        .label = "Method",
        .description = "Ruby method definition",
        .body = "def $1\n  $0\nend",
        .language = .ruby,
    },
    .{
        .prefix = "class",
        .label = "Class",
        .description = "Ruby class",
        .body = "class $1\n  $0\nend",
        .language = .ruby,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.ruby-lang",
    .name = "Ruby Language",
    .version = "0.1.0",
    .description = "Ruby language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{ruby_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "ruby_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 2);
}

test "ruby_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "def hello");
    try testing.expect(ls.token_count > 0);
    try testing.expect(ls.tokens[0].kind == .keyword);
}
