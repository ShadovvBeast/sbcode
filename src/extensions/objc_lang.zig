// src/extensions/objc_lang.zig — Objective-C Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const objc_syntax = ext.SyntaxContribution{
    .language = .objc,
    .display_name = "Objective-C",
    .file_extensions = &.{ ".m", ".mm" },
    .line_comment = "//",
    .block_comment_open = "/*",
    .block_comment_close = "*/",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeCCpp,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "imp",
        .label = "Implementation",
        .description = "Objective-C implementation",
        .body = "@implementation $1\n$0\n@end",
        .language = .objc,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.objc-lang",
    .name = "Objective-C Language",
    .version = "0.1.0",
    .description = "Objective-C language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{objc_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "objc_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "objc_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "#import <Foundation/Foundation.h>");
    try testing.expect(ls.token_count > 0);
}
