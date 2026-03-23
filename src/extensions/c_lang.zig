// src/extensions/c_lang.zig — C Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const c_syntax = ext.SyntaxContribution{
    .language = .c_lang,
    .display_name = "C",
    .file_extensions = &.{ ".c", ".h" },
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
        .prefix = "main",
        .label = "Main Function",
        .description = "C main function",
        .body = "int main(int argc, char *argv[]) {\n    $0\n    return 0;\n}",
        .language = .c_lang,
    },
    .{
        .prefix = "inc",
        .label = "Include",
        .description = "Include header",
        .body = "#include <$1>",
        .language = .c_lang,
    },
    .{
        .prefix = "for",
        .label = "For Loop",
        .description = "C for loop",
        .body = "for (int $1 = 0; $1 < $2; $1++) {\n    $0\n}",
        .language = .c_lang,
    },
    .{
        .prefix = "struct",
        .label = "Struct",
        .description = "C struct definition",
        .body = "typedef struct {\n    $0\n} $1;",
        .language = .c_lang,
    },
    .{
        .prefix = "if",
        .label = "If Statement",
        .description = "C if statement",
        .body = "if ($1) {\n    $0\n}",
        .language = .c_lang,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.c-lang",
    .name = "C Language",
    .version = "0.1.0",
    .description = "C language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{c_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;
const expect = testing.expect;

test "c_lang extension has correct metadata" {
    try expect(extension.syntax.len == 1);
    try expect(extension.snippets.len == 5);
    try expect(extension.capabilities.syntax);
    try expect(extension.capabilities.snippets);
}

test "c_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "int main() {");
    try expect(ls.token_count > 0);
    try expect(ls.tokens[0].kind == .keyword);
}
