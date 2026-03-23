// src/extensions/powershell_lang.zig — PowerShell Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const powershell_syntax = ext.SyntaxContribution{
    .language = .powershell,
    .display_name = "PowerShell",
    .file_extensions = &.{ ".ps1", ".psm1", ".psd1" },
    .line_comment = "#",
    .block_comment_open = "<#",
    .block_comment_close = "#>",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizePowershell,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "fn",
        .label = "Function",
        .description = "PowerShell function",
        .body = "function $1 {\n    $0\n}",
        .language = .powershell,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.powershell-lang",
    .name = "PowerShell Language",
    .version = "0.1.0",
    .description = "PowerShell language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{powershell_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "powershell_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "powershell_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "function Get-Item {");
    try testing.expect(ls.token_count > 0);
    try testing.expect(ls.tokens[0].kind == .keyword);
}
