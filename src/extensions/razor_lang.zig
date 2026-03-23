// src/extensions/razor_lang.zig — Razor Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const razor_syntax = ext.SyntaxContribution{
    .language = .razor,
    .display_name = "Razor",
    .file_extensions = &.{ ".cshtml", ".razor" },
    .line_comment = "",
    .block_comment_open = "@*",
    .block_comment_close = "*@",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
        .{ '<', '>' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeHtml,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "code",
        .label = "Code Block",
        .description = "Razor code block",
        .body = "@{\n    $0\n}",
        .language = .razor,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.razor-lang",
    .name = "Razor Language",
    .version = "0.1.0",
    .description = "Razor template language support",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{razor_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "razor_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "razor_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "<div>@Model.Name</div>");
    try testing.expect(ls.token_count > 0);
}
