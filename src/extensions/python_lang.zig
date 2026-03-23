// src/extensions/python_lang.zig — Python Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const py_syntax = ext.SyntaxContribution{
    .language = .python,
    .display_name = "Python",
    .file_extensions = &.{ ".py", ".pyw", ".pyi" },
    .line_comment = "#",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizePython,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "def",
        .label = "Function",
        .description = "Python function definition",
        .body = "def $1($2):\n    $0",
        .language = .python,
    },
    .{
        .prefix = "class",
        .label = "Class",
        .description = "Python class definition",
        .body = "class $1:\n    def __init__(self$2):\n        $0",
        .language = .python,
    },
    .{
        .prefix = "if",
        .label = "If Statement",
        .description = "Python if statement",
        .body = "if $1:\n    $0",
        .language = .python,
    },
    .{
        .prefix = "for",
        .label = "For Loop",
        .description = "Python for loop",
        .body = "for $1 in $2:\n    $0",
        .language = .python,
    },
    .{
        .prefix = "with",
        .label = "With Statement",
        .description = "Python with statement",
        .body = "with $1 as $2:\n    $0",
        .language = .python,
    },
    .{
        .prefix = "try",
        .label = "Try-Except",
        .description = "Python try-except block",
        .body = "try:\n    $1\nexcept $2:\n    $0",
        .language = .python,
    },
    .{
        .prefix = "import",
        .label = "Import",
        .description = "Python import statement",
        .body = "from $1 import $0",
        .language = .python,
    },
};

const commands = [_]ext.CommandContribution{
    .{
        .id = 2100,
        .label = "Python: Run File",
        .shortcut = "Ctrl+F5",
        .category = .run,
    },
    .{
        .id = 2101,
        .label = "Python: Select Interpreter",
        .category = .general,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.python-lang",
    .name = "Python Language",
    .version = "0.1.0",
    .description = "Python language support: syntax highlighting, snippets, and commands",
    .capabilities = .{ .syntax = true, .snippets = true, .commands = true },
    .syntax = &.{py_syntax},
    .snippets = &snippets,
    .commands = &commands,
};

const testing = @import("std").testing;
const expect = testing.expect;

test "python_lang extension has correct metadata" {
    try expect(extension.syntax.len == 1);
    try expect(extension.snippets.len == 7);
    try expect(extension.commands.len == 2);
    try expect(extension.capabilities.syntax);
    try expect(extension.capabilities.snippets);
    try expect(extension.capabilities.commands);
}

test "python_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "def foo():");
    try expect(ls.token_count > 0);
    try expect(ls.tokens[0].kind == .keyword);
}
