// src/extensions/php_lang.zig — PHP Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const php_syntax = ext.SyntaxContribution{
    .language = .php,
    .display_name = "PHP",
    .file_extensions = &.{ ".php", ".phtml" },
    .line_comment = "//",
    .block_comment_open = "/*",
    .block_comment_close = "*/",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizePhp,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "php",
        .label = "PHP Tag",
        .description = "PHP opening tag",
        .body = "<?php\n$0\n?>",
        .language = .php,
    },
    .{
        .prefix = "echo",
        .label = "Echo",
        .description = "PHP echo statement",
        .body = "echo $1;",
        .language = .php,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.php-lang",
    .name = "PHP Language",
    .version = "0.1.0",
    .description = "PHP language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{php_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "php_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 2);
}

test "php_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "<?php echo 'hello';");
    try testing.expect(ls.token_count > 0);
}
