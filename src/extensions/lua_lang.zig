// src/extensions/lua_lang.zig — Lua Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const lua_syntax = ext.SyntaxContribution{
    .language = .lua,
    .display_name = "Lua",
    .file_extensions = &.{".lua"},
    .line_comment = "--",
    .block_comment_open = "--[[",
    .block_comment_close = "]]",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeLua,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "fn",
        .label = "Function",
        .description = "Lua function",
        .body = "function $1($2)\n  $0\nend",
        .language = .lua,
    },
    .{
        .prefix = "for",
        .label = "For Loop",
        .description = "Lua numeric for",
        .body = "for $1 = 1, $2 do\n  $0\nend",
        .language = .lua,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.lua-lang",
    .name = "Lua Language",
    .version = "0.1.0",
    .description = "Lua language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{lua_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "lua_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 2);
}

test "lua_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "local x = 10");
    try testing.expect(ls.token_count > 0);
    try testing.expect(ls.tokens[0].kind == .keyword);
}
