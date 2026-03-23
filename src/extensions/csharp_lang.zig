// src/extensions/csharp_lang.zig — C# Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const csharp_syntax = ext.SyntaxContribution{
    .language = .csharp,
    .display_name = "C#",
    .file_extensions = &.{ ".cs", ".csx" },
    .line_comment = "//",
    .block_comment_open = "/*",
    .block_comment_close = "*/",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeCSharp,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "cw",
        .label = "Console.WriteLine",
        .description = "Console write line",
        .body = "Console.WriteLine($1);",
        .language = .csharp,
    },
    .{
        .prefix = "class",
        .label = "Class",
        .description = "C# class",
        .body = "public class $1\n{\n    $0\n}",
        .language = .csharp,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.csharp-lang",
    .name = "C# Language",
    .version = "0.1.0",
    .description = "C# language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{csharp_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "csharp_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 2);
}

test "csharp_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "using System;");
    try testing.expect(ls.token_count > 0);
}
