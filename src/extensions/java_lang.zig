// src/extensions/java_lang.zig — Java Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const java_syntax = ext.SyntaxContribution{
    .language = .java,
    .display_name = "Java",
    .file_extensions = &.{".java"},
    .line_comment = "//",
    .block_comment_open = "/*",
    .block_comment_close = "*/",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeJava,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "main",
        .label = "Main Method",
        .description = "Java main method",
        .body = "public static void main(String[] args) {\n    $0\n}",
        .language = .java,
    },
    .{
        .prefix = "sout",
        .label = "Print Line",
        .description = "System.out.println",
        .body = "System.out.println($1);",
        .language = .java,
    },
    .{
        .prefix = "for",
        .label = "For Loop",
        .description = "Java for loop",
        .body = "for (int $1 = 0; $1 < $2; $1++) {\n    $0\n}",
        .language = .java,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.java-lang",
    .name = "Java Language",
    .version = "0.1.0",
    .description = "Java language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{java_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "java_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 3);
}

test "java_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "public class Main {");
    try testing.expect(ls.token_count > 0);
    try testing.expect(ls.tokens[0].kind == .keyword);
}
