// src/extensions/xml_lang.zig — XML Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const xml_syntax = ext.SyntaxContribution{
    .language = .xml,
    .display_name = "XML",
    .file_extensions = &.{ ".xml", ".xsl", ".xsd", ".svg", ".xhtml" },
    .line_comment = "",
    .block_comment_open = "<!--",
    .block_comment_close = "-->",
    .bracket_pairs = &.{
        .{ '<', '>' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeXml,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "tag",
        .label = "XML Tag",
        .description = "XML element",
        .body = "<$1>$0</$1>",
        .language = .xml,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.xml-lang",
    .name = "XML Language",
    .version = "0.1.0",
    .description = "XML language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{xml_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "xml_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "xml_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "<root>");
    try testing.expect(ls.token_count > 0);
}
