// src/extensions/zig_lang.zig — Zig Language Extension
//
// Provides Zig syntax highlighting, snippets, and language configuration.
// Uses the tokenizer from the syntax module.
//
// File extensions: .zig, .zon

const ext = @import("extension");
const syntax = @import("syntax");

// =============================================================================
// Syntax contribution — delegates to the existing Zig tokenizer
// =============================================================================

const zig_syntax = ext.SyntaxContribution{
    .language = .zig_lang,
    .display_name = "Zig",
    .file_extensions = &.{ ".zig", ".zon" },
    .line_comment = "//",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeZig,
};

// =============================================================================
// Snippets
// =============================================================================

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "fn",
        .label = "Function",
        .description = "Zig function declaration",
        .body = "fn $1($2) $3 {\n    $0\n}",
        .language = .zig_lang,
    },
    .{
        .prefix = "pubfn",
        .label = "Public Function",
        .description = "Public Zig function declaration",
        .body = "pub fn $1($2) $3 {\n    $0\n}",
        .language = .zig_lang,
    },
    .{
        .prefix = "test",
        .label = "Test Block",
        .description = "Zig test declaration",
        .body = "test \"$1\" {\n    $0\n}",
        .language = .zig_lang,
    },
    .{
        .prefix = "struct",
        .label = "Struct",
        .description = "Zig struct declaration",
        .body = "const $1 = struct {\n    $0\n};",
        .language = .zig_lang,
    },
    .{
        .prefix = "enum",
        .label = "Enum",
        .description = "Zig enum declaration",
        .body = "const $1 = enum {\n    $0\n};",
        .language = .zig_lang,
    },
    .{
        .prefix = "for",
        .label = "For Loop",
        .description = "Zig for loop",
        .body = "for ($1) |$2| {\n    $0\n}",
        .language = .zig_lang,
    },
    .{
        .prefix = "while",
        .label = "While Loop",
        .description = "Zig while loop",
        .body = "while ($1) {\n    $0\n}",
        .language = .zig_lang,
    },
    .{
        .prefix = "switch",
        .label = "Switch",
        .description = "Zig switch expression",
        .body = "switch ($1) {\n    $2 => $0,\n}",
        .language = .zig_lang,
    },
    .{
        .prefix = "if",
        .label = "If Statement",
        .description = "Zig if statement",
        .body = "if ($1) {\n    $0\n}",
        .language = .zig_lang,
    },
    .{
        .prefix = "ifelse",
        .label = "If-Else",
        .description = "Zig if-else statement",
        .body = "if ($1) {\n    $2\n} else {\n    $0\n}",
        .language = .zig_lang,
    },
    .{
        .prefix = "import",
        .label = "Import",
        .description = "Zig @import statement",
        .body = "const $1 = @import(\"$2\");",
        .language = .zig_lang,
    },
    .{
        .prefix = "errdefer",
        .label = "Error Defer",
        .description = "Zig errdefer block",
        .body = "errdefer {\n    $0\n}",
        .language = .zig_lang,
    },
    .{
        .prefix = "union",
        .label = "Tagged Union",
        .description = "Zig tagged union",
        .body = "const $1 = union(enum) {\n    $0\n};",
        .language = .zig_lang,
    },
};

// =============================================================================
// Commands
// =============================================================================

const commands = [_]ext.CommandContribution{
    .{
        .id = 2000,
        .label = "Zig: Format File",
        .shortcut = "Ctrl+Shift+I",
        .category = .edit,
    },
    .{
        .id = 2001,
        .label = "Zig: Restart Language Server",
        .category = .general,
    },
    .{
        .id = 2002,
        .label = "Zig: Build Project",
        .shortcut = "Ctrl+Shift+B",
        .category = .run,
    },
    .{
        .id = 2003,
        .label = "Zig: Run Tests",
        .category = .run,
    },
};

// =============================================================================
// Extension descriptor
// =============================================================================

pub const extension = ext.Extension{
    .id = "sbcode.zig-lang",
    .name = "Zig Language",
    .version = "0.1.0",
    .description = "Zig language support: syntax highlighting, snippets, and commands",
    .capabilities = .{ .syntax = true, .commands = true, .snippets = true },
    .syntax = &.{zig_syntax},
    .commands = &commands,
    .snippets = &snippets,
};

// =============================================================================
// Tests
// =============================================================================

const testing = @import("std").testing;
const expect = testing.expect;

test "zig_lang extension has correct metadata" {
    try expect(extension.syntax.len == 1);
    try expect(extension.commands.len == 4);
    try expect(extension.snippets.len == 13);
    try expect(extension.capabilities.syntax);
    try expect(extension.capabilities.commands);
    try expect(extension.capabilities.snippets);
    try expect(!extension.capabilities.theme);
}

test "zig_lang syntax contribution has correct file extensions" {
    const syn = extension.syntax[0];
    try expect(syn.file_extensions.len == 2);
    try expect(syn.language == .zig_lang);
}

test "zig_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "const x = 5;");
    try expect(ls.token_count > 0);
    // First token should be keyword "const"
    try expect(ls.tokens[0].kind == .keyword);
    try expect(ls.tokens[0].len == 5);
}
