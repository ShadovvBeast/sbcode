// src/extensions/log_lang.zig — Log File Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const log_syntax = ext.SyntaxContribution{
    .language = .log,
    .display_name = "Log",
    .file_extensions = &.{".log"},
    .line_comment = "",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{},
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeLog,
};

const snippets = [_]ext.SnippetContribution{};

pub const extension = ext.Extension{
    .id = "sbcode.log-lang",
    .name = "Log File Language",
    .version = "0.1.0",
    .description = "Log file syntax highlighting",
    .capabilities = .{ .syntax = true, .snippets = false },
    .syntax = &.{log_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "log_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 0);
}

test "log_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "[ERROR] something failed");
    try testing.expect(ls.token_count > 0);
}
