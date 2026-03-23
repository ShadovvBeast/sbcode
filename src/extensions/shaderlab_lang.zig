// src/extensions/shaderlab_lang.zig — ShaderLab Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const shaderlab_syntax = ext.SyntaxContribution{
    .language = .shaderlab,
    .display_name = "ShaderLab",
    .file_extensions = &.{".shader"},
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
        .prefix = "shader",
        .label = "Shader",
        .description = "ShaderLab shader",
        .body = "Shader \"$1\" {\n    $0\n}",
        .language = .shaderlab,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.shaderlab-lang",
    .name = "ShaderLab Language",
    .version = "0.1.0",
    .description = "ShaderLab language support",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{shaderlab_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "shaderlab_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "shaderlab_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "Shader \"Custom\" {");
    try testing.expect(ls.token_count > 0);
}
