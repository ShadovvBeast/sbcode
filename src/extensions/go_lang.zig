// src/extensions/go_lang.zig — Go Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const go_syntax = ext.SyntaxContribution{
    .language = .go_lang,
    .display_name = "Go",
    .file_extensions = &.{".go"},
    .line_comment = "//",
    .block_comment_open = "/*",
    .block_comment_close = "*/",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeGo,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "func",
        .label = "Function",
        .description = "Go function",
        .body = "func $1($2) $3 {\n    $0\n}",
        .language = .go_lang,
    },
    .{
        .prefix = "main",
        .label = "Main Function",
        .description = "Go main function",
        .body = "func main() {\n    $0\n}",
        .language = .go_lang,
    },
    .{
        .prefix = "struct",
        .label = "Struct",
        .description = "Go struct type",
        .body = "type $1 struct {\n    $0\n}",
        .language = .go_lang,
    },
    .{
        .prefix = "interface",
        .label = "Interface",
        .description = "Go interface type",
        .body = "type $1 interface {\n    $0\n}",
        .language = .go_lang,
    },
    .{
        .prefix = "if",
        .label = "If Statement",
        .description = "Go if statement",
        .body = "if $1 {\n    $0\n}",
        .language = .go_lang,
    },
    .{
        .prefix = "iferr",
        .label = "If Error",
        .description = "Go error check pattern",
        .body = "if err != nil {\n    $0\n}",
        .language = .go_lang,
    },
    .{
        .prefix = "for",
        .label = "For Loop",
        .description = "Go for loop",
        .body = "for $1 := range $2 {\n    $0\n}",
        .language = .go_lang,
    },
};

const commands = [_]ext.CommandContribution{
    .{
        .id = 2300,
        .label = "Go: Build Project",
        .shortcut = "Ctrl+Shift+B",
        .category = .run,
    },
    .{
        .id = 2301,
        .label = "Go: Run Tests",
        .category = .run,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.go-lang",
    .name = "Go Language",
    .version = "0.1.0",
    .description = "Go language support: syntax highlighting, snippets, and commands",
    .capabilities = .{ .syntax = true, .snippets = true, .commands = true },
    .syntax = &.{go_syntax},
    .snippets = &snippets,
    .commands = &commands,
};

const testing = @import("std").testing;
const expect = testing.expect;

test "go_lang extension has correct metadata" {
    try expect(extension.syntax.len == 1);
    try expect(extension.snippets.len == 7);
    try expect(extension.commands.len == 2);
    try expect(extension.capabilities.syntax);
    try expect(extension.capabilities.snippets);
    try expect(extension.capabilities.commands);
}

test "go_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "func main() {");
    try expect(ls.token_count > 0);
    try expect(ls.tokens[0].kind == .keyword);
}
