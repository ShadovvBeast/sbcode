// src/extensions/html_lang.zig — HTML Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const html_syntax = ext.SyntaxContribution{
    .language = .html,
    .display_name = "HTML",
    .file_extensions = &.{ ".html", ".htm", ".xhtml" },
    .line_comment = "",
    .block_comment_open = "<!--",
    .block_comment_close = "-->",
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
        .prefix = "html5",
        .label = "HTML5 Boilerplate",
        .description = "HTML5 document template",
        .body = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n    <meta charset=\"UTF-8\">\n    <title>$1</title>\n</head>\n<body>\n    $0\n</body>\n</html>",
        .language = .html,
    },
    .{
        .prefix = "div",
        .label = "Div",
        .description = "HTML div element",
        .body = "<div class=\"$1\">\n    $0\n</div>",
        .language = .html,
    },
    .{
        .prefix = "a",
        .label = "Anchor",
        .description = "HTML anchor link",
        .body = "<a href=\"$1\">$0</a>",
        .language = .html,
    },
    .{
        .prefix = "img",
        .label = "Image",
        .description = "HTML image element",
        .body = "<img src=\"$1\" alt=\"$2\">",
        .language = .html,
    },
    .{
        .prefix = "ul",
        .label = "Unordered List",
        .description = "HTML unordered list",
        .body = "<ul>\n    <li>$0</li>\n</ul>",
        .language = .html,
    },
    .{
        .prefix = "script",
        .label = "Script Tag",
        .description = "HTML script element",
        .body = "<script>\n    $0\n</script>",
        .language = .html,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.html-lang",
    .name = "HTML Language",
    .version = "0.1.0",
    .description = "HTML language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{html_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;
const expect = testing.expect;

test "html_lang extension has correct metadata" {
    try expect(extension.syntax.len == 1);
    try expect(extension.snippets.len == 6);
    try expect(extension.capabilities.syntax);
    try expect(extension.capabilities.snippets);
}

test "html_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "<div>");
    try expect(ls.token_count > 0);
    try expect(ls.tokens[0].kind == .keyword);
}
