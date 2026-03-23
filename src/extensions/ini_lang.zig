// src/extensions/ini_lang.zig — INI Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const ini_syntax = ext.SyntaxContribution{
    .language = .ini,
    .display_name = "INI",
    .file_extensions = &.{ ".ini", ".cfg", ".conf", ".properties" },
    .line_comment = ";",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '[', ']' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeIni,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "section",
        .label = "Section",
        .description = "INI section",
        .body = "[$1]\n$0",
        .language = .ini,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.ini-lang",
    .name = "INI Language",
    .version = "0.1.0",
    .description = "INI file language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{ini_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "ini_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "ini_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "[section]");
    try testing.expect(ls.token_count > 0);
}
