// src/extensions/bat_lang.zig — Batch Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const bat_syntax = ext.SyntaxContribution{
    .language = .bat,
    .display_name = "Batch",
    .file_extensions = &.{ ".bat", ".cmd" },
    .line_comment = "REM",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '(', ')' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeBat,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "echo",
        .label = "Echo",
        .description = "Batch echo",
        .body = "echo $0",
        .language = .bat,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.bat-lang",
    .name = "Batch Language",
    .version = "0.1.0",
    .description = "Batch file language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{bat_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "bat_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "bat_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "@echo off");
    try testing.expect(ls.token_count > 0);
}
