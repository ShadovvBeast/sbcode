// src/extensions/coffeescript_lang.zig — CoffeeScript Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const coffee_syntax = ext.SyntaxContribution{
    .language = .coffeescript,
    .display_name = "CoffeeScript",
    .file_extensions = &.{".coffee"},
    .line_comment = "#",
    .block_comment_open = "###",
    .block_comment_close = "###",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeCoffee,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "fn",
        .label = "Function",
        .description = "CoffeeScript function",
        .body = "$1 = ($2) ->\n  $0",
        .language = .coffeescript,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.coffeescript-lang",
    .name = "CoffeeScript Language",
    .version = "0.1.0",
    .description = "CoffeeScript language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{coffee_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "coffeescript_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "coffeescript_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "if true then 1");
    try testing.expect(ls.token_count > 0);
}
