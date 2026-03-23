// src/extensions/clojure_lang.zig — Clojure Language Extension

const ext = @import("extension");
const syntax = @import("syntax");

const clojure_syntax = ext.SyntaxContribution{
    .language = .clojure,
    .display_name = "Clojure",
    .file_extensions = &.{ ".clj", ".cljs", ".cljc", ".edn" },
    .line_comment = ";",
    .block_comment_open = "",
    .block_comment_close = "",
    .bracket_pairs = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    .tokenizer = &syntax.SyntaxHighlighter.tokenizeClojure,
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "defn",
        .label = "Function",
        .description = "Clojure function",
        .body = "(defn $1 [$2]\n  $0)",
        .language = .clojure,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.clojure-lang",
    .name = "Clojure Language",
    .version = "0.1.0",
    .description = "Clojure language support: syntax highlighting and snippets",
    .capabilities = .{ .syntax = true, .snippets = true },
    .syntax = &.{clojure_syntax},
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "clojure_lang extension metadata" {
    try testing.expect(extension.syntax.len == 1);
    try testing.expect(extension.snippets.len == 1);
}

test "clojure_lang tokenizer produces tokens" {
    var ls = syntax.LineSyntax{};
    extension.syntax[0].tokenizer(&ls, "(defn hello [x] x)");
    try testing.expect(ls.token_count > 0);
}
