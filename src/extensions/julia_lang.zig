// src/extensions/julia_lang.zig — Julia Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const julia_syntax = ext.SyntaxContribution{
    .language = .julia,
    .display_name = "Julia",
    .file_extensions = &.{".jl"},
    .line_comment = "#",
    .block_comment_open = "#=",
    .block_comment_close = "=#",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeJulia,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "fn",
        .label = "Function",
        .description = "Julia function",
        .body = "function $1($2)\n    $0\nend",
        .language = .julia,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.julia-lang",
    .name = "Julia Language",
    .version = "0.1.0",
    .description = "Julia language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{julia_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "julia_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "julia_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "function hello()");
    try testing.expect(ls.token_count > 0);
    try testing.expect(ls.tokens[0].kind == .keyword);
}
