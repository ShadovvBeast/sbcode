// src/extensions/hlsl_lang.zig — HLSL Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const hlsl_syntax = ext.SyntaxContribution{
    .language = .hlsl,
    .display_name = "HLSL",
    .file_extensions = &.{ ".hlsl", ".hlsli", ".fx", ".fxh" },
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
        .prefix = "vs",
        .label = "Vertex Shader",
        .description = "HLSL vertex shader",
        .body = "float4 VSMain(float4 pos : POSITION) : SV_POSITION {\n    $0\n}",
        .language = .hlsl,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.hlsl-lang",
    .name = "HLSL Language",
    .version = "0.1.0",
    .description = "HLSL shader language support",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{hlsl_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "hlsl_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "hlsl_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "float4 color;");
    try testing.expect(ls.token_count > 0);
}
