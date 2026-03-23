// src/extensions/shell_lang.zig — Shell Script Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const shell_syntax = ext.SyntaxContribution{
    .language = .shellscript,
    .display_name = "Shell Script",
    .file_extensions = &.{ ".sh", ".bash", ".zsh", ".fish" },
    .line_comment = "#",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeShell,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "shebang",
        .label = "Shebang",
        .description = "Bash shebang line",
        .body = "#!/bin/bash\n$0",
        .language = .shellscript,
    },
    .{
        .prefix = "if",
        .label = "If Statement",
        .description = "Shell if statement",
        .body = "if [ $1 ]; then\n    $0\nfi",
        .language = .shellscript,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.shell-lang",
    .name = "Shell Script Language",
    .version = "0.1.0",
    .description = "Shell script language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{shell_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "shell_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 2);
}

test "shell_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "#!/bin/bash");
    try testing.expect(ls.token_count > 0);
}
