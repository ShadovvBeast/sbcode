// src/extensions/sql_lang.zig — SQL Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const sql_syntax = ext.SyntaxContribution{
    .language = .sql,
    .display_name = "SQL",
    .file_extensions = &.{ ".sql", ".ddl", ".dml" },
    .line_comment = "--",
    .block_comment_open = "/*",
    .block_comment_close = "*/",
    .bracket_pairs = &.{
        .{ '(', ')' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeSql,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "sel",
        .label = "SELECT",
        .description = "SQL SELECT statement",
        .body = "SELECT $1 FROM $2 WHERE $3;",
        .language = .sql,
    },
    .{
        .prefix = "ins",
        .label = "INSERT",
        .description = "SQL INSERT statement",
        .body = "INSERT INTO $1 ($2) VALUES ($3);",
        .language = .sql,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.sql-lang",
    .name = "SQL Language",
    .version = "0.1.0",
    .description = "SQL language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{sql_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "sql_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 2);
}

test "sql_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "SELECT * FROM users;");
    try testing.expect(ls.token_count > 0);
    try testing.expect(ls.tokens[0].kind == .keyword);
}
