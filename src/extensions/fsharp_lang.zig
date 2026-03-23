// src/extensions/fsharp_lang.zig — F# Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const fsharp_syntax = ext.SyntaxContribution{
    .language = .fsharp,
    .display_name = "F#",
    .file_extensions = &.{ ".fs", ".fsi", ".fsx" },
    .line_comment = "//",
    .block_comment_open = "(*",
    .block_comment_close = "*)",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeFSharp,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "let",
        .label = "Let Binding",
        .description = "F# let binding",
        .body = "let $1 = $0",
        .language = .fsharp,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.fsharp-lang",
    .name = "F# Language",
    .version = "0.1.0",
    .description = "F# language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{fsharp_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "fsharp_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "fsharp_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "let x = 42");
    try testing.expect(ls.token_count > 0);
    try testing.expect(ls.tokens[0].kind == .keyword);
}
