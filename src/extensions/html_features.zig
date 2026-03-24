const ext = @import("extension");
const syntax = @import("syntax");

const commands = [_]ext.CommandContribution{
    .{ .id = 3900, .label = "HTML: Close Tag", .category = .edit },
    .{ .id = 3901, .label = "HTML: Format Document", .category = .edit },
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "a",
        .label = "Anchor",
        .description = "HTML anchor tag",
        .body = "<a href=\"$1\">$0</a>",
        .language = .html,
    },
    .{
        .prefix = "img",
        .label = "Image",
        .description = "HTML image tag",
        .body = "<img src=\"$1\" alt=\"$2\">",
        .language = .html,
    },
    .{
        .prefix = "table",
        .label = "Table",
        .description = "HTML table structure",
        .body = "<table>\n    <tr>\n        <th>$1</th>\n    </tr>\n    <tr>\n        <td>$0</td>\n    </tr>\n</table>",
        .language = .html,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.html-language-features",
    .name = "HTML Language Features",
    .version = "0.1.0",
    .description = "HTML close tag, formatting, and snippets",
    .capabilities = .{ .commands = true, .snippets = true },
    .commands = &commands,
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "html_features extension metadata" {
    try testing.expect(extension.commands.len == 2);
    try testing.expect(extension.snippets.len == 3);
    try testing.expect(extension.capabilities.commands);
    try testing.expect(extension.capabilities.snippets);
    try testing.expect(!extension.capabilities.syntax);
    try testing.expect(extension.snippets[0].language.? == .html);
}
