// src/extensions/cpp_lang.zig — C++ Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const cpp_syntax = ext.SyntaxContribution{
    .language = .cpp_lang,
    .display_name = "C++",
    .file_extensions = &.{ ".cpp", ".cxx", ".cc", ".hpp", ".hxx", ".hh" },
    .line_comment = "//",
    .block_comment_open = "/*",
    .block_comment_close = "*/",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
        .{ '<', '>' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeCCpp,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "class",
        .label = "Class",
        .description = "C++ class definition",
        .body = "class $1 {\npublic:\n    $1($2);\n    ~$1();\n\nprivate:\n    $0\n};",
        .language = .cpp_lang,
    },
    .{
        .prefix = "main",
        .label = "Main Function",
        .description = "C++ main function",
        .body = "int main(int argc, char* argv[]) {\n    $0\n    return 0;\n}",
        .language = .cpp_lang,
    },
    .{
        .prefix = "inc",
        .label = "Include",
        .description = "Include header",
        .body = "#include <$1>",
        .language = .cpp_lang,
    },
    .{
        .prefix = "for",
        .label = "Range For",
        .description = "C++ range-based for loop",
        .body = "for (auto& $1 : $2) {\n    $0\n}",
        .language = .cpp_lang,
    },
    .{
        .prefix = "ns",
        .label = "Namespace",
        .description = "C++ namespace",
        .body = "namespace $1 {\n    $0\n}",
        .language = .cpp_lang,
    },
    .{
        .prefix = "template",
        .label = "Template",
        .description = "C++ template",
        .body = "template <typename $1>\n$0",
        .language = .cpp_lang,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.cpp-lang",
    .name = "C++ Language",
    .version = "0.1.0",
    .description = "C++ language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{cpp_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;
const expect = testing.expect;

test "cpp_lang extension has correct metadata" {
    try expect(extension.syntax.len == 1);
    try expect(extension.snippets.len == 6);
    try expect(extension.capabilities.syntax);
    try expect(extension.capabilities.snippets);
}

test "cpp_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "class Foo {};");
    try expect(ls.token_count > 0);
    try expect(ls.tokens[0].kind == .keyword);
}
