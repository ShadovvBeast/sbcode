// src/extensions/yaml_lang.zig — YAML Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const yaml_syntax = ext.SyntaxContribution{
    .language = .yaml,
    .display_name = "YAML",
    .file_extensions = &.{ ".yml", ".yaml" },
    .line_comment = "#",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeYaml,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "key",
        .label = "Key-Value",
        .description = "YAML key-value pair",
        .body = "$1: $0",
        .language = .yaml,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.yaml-lang",
    .name = "YAML Language",
    .version = "0.1.0",
    .description = "YAML language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{yaml_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "yaml_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "yaml_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "name: value");
    try testing.expect(ls.token_count > 0);
}
