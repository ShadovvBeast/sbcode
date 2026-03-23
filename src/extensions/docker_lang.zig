// src/extensions/docker_lang.zig — Dockerfile Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const docker_syntax = ext.SyntaxContribution{
    .language = .docker,
    .display_name = "Dockerfile",
    .file_extensions = &.{".dockerfile"},
    .line_comment = "#",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '[', ']' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeDocker,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "from",
        .label = "FROM",
        .description = "Dockerfile FROM instruction",
        .body = "FROM $0",
        .language = .docker,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.docker-lang",
    .name = "Dockerfile Language",
    .version = "0.1.0",
    .description = "Dockerfile language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{docker_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "docker_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "docker_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "FROM ubuntu:latest");
    try testing.expect(ls.token_count > 0);
    try testing.expect(ls.tokens[0].kind == .keyword);
}
