// src/extensions/json_lang.zig — JSON Language Extension
//
// Provides JSON syntax highlighting and language configuration.
// Uses the tokenizer from the syntax module.
//
// File extensions: .json, .jsonc, .jsonl

const ext = @import("extension");
const syntax = @import("syntax");

// =============================================================================
// Syntax contribution
// =============================================================================

const json_syntax = ext.SyntaxContribution{
    .language = .json_lang,
    .display_name = "JSON",
    .file_extensions = &.{ ".json", ".jsonc", ".jsonl" },
    .line_comment = "",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '{', '}' },
        .{ '[', ']' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeJson,
};

// =============================================================================
// Snippets
// =============================================================================

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "obj",
        .label = "Object",
        .description = "JSON object",
        .body = "{\n    \"$1\": $0\n}",
        .language = .json_lang,
    },
    .{
        .prefix = "arr",
        .label = "Array",
        .description = "JSON array",
        .body = "[\n    $0\n]",
        .language = .json_lang,
    },
    .{
        .prefix = "kv",
        .label = "Key-Value",
        .description = "JSON key-value pair",
        .body = "\"$1\": \"$0\"",
        .language = .json_lang,
    },
};

// =============================================================================
// Extension descriptor
// =============================================================================

pub const extension = ext.Extension{
    .id = "sbcode.json-lang",
    .name = "JSON Language",
    .version = "0.1.0",
    .description = "JSON language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{json_syntax},
    .snippets = &snippets,
};

// =============================================================================
// Tests
// =============================================================================

const testing = @import("std").testing;
const expect = testing.expect;

test "json_lang extension has correct metadata" {
    try expect(extension.syntax.len == 1);
    try expect(extension.snippets.len == 3);
    try expect(extension.capabilities.syntax);
    try expect(extension.capabilities.snippets);
    try expect(!extension.capabilities.commands);
}

test "json_lang syntax handles .jsonc extension" {
    const syn = extension.syntax[0];
    try expect(syn.file_extensions.len == 3);
}

test "json_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "{\"key\": 42}");
    try expect(ls.token_count > 0);
}
