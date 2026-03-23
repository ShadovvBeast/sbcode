// src/extensions/rust_lang.zig — Rust Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const rust_syntax = ext.SyntaxContribution{
    .language = .rust_lang,
    .display_name = "Rust",
    .file_extensions = &.{".rs"},
    .line_comment = "//",
    .block_comment_open = "/*",
    .block_comment_close = "*/",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
        .{ '<', '>' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeRust,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "fn",
        .label = "Function",
        .description = "Rust function",
        .body = "fn $1($2) -> $3 {\n    $0\n}",
        .language = .rust_lang,
    },
    .{
        .prefix = "struct",
        .label = "Struct",
        .description = "Rust struct",
        .body = "struct $1 {\n    $0\n}",
        .language = .rust_lang,
    },
    .{
        .prefix = "impl",
        .label = "Impl Block",
        .description = "Rust impl block",
        .body = "impl $1 {\n    $0\n}",
        .language = .rust_lang,
    },
    .{
        .prefix = "enum",
        .label = "Enum",
        .description = "Rust enum",
        .body = "enum $1 {\n    $0\n}",
        .language = .rust_lang,
    },
    .{
        .prefix = "match",
        .label = "Match",
        .description = "Rust match expression",
        .body = "match $1 {\n    $2 => $0,\n}",
        .language = .rust_lang,
    },
    .{
        .prefix = "test",
        .label = "Test",
        .description = "Rust test function",
        .body = "#[test]\nfn $1() {\n    $0\n}",
        .language = .rust_lang,
    },
};

const commands = [_]ext.CommandContribution{
    .{
        .id = 2200,
        .label = "Rust: Build Project",
        .shortcut = "Ctrl+Shift+B",
        .category = .run,
    },
    .{
        .id = 2201,
        .label = "Rust: Run Tests",
        .category = .run,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.rust-lang",
    .name = "Rust Language",
    .version = "0.1.0",
    .description = "Rust language support: syntax highlighting, snippets, and commands",
    .capabilities = .{ .syntax = true, .snippets = true, .commands = true },
    .syntax = &.{rust_syntax},
    .snippets = &snippets,
    .commands = &commands,
};

const testing = @import("std").testing;
const expect = testing.expect;

test "rust_lang extension has correct metadata" {
    try expect(extension.syntax.len == 1);
    try expect(extension.snippets.len == 6);
    try expect(extension.commands.len == 2);
    try expect(extension.capabilities.syntax);
    try expect(extension.capabilities.snippets);
    try expect(extension.capabilities.commands);
}

test "rust_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "fn main() {");
    try expect(ls.token_count > 0);
    try expect(ls.tokens[0].kind == .keyword);
}
