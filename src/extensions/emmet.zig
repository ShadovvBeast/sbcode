const ext = @import("extension");
const syntax = @import("syntax");

const commands = [_]ext.CommandContribution{
    .{ .id = 3000, .label = "Emmet: Expand Abbreviation", .category = .edit },
    .{ .id = 3001, .label = "Emmet: Wrap with Abbreviation", .category = .edit },
    .{ .id = 3002, .label = "Emmet: Remove Tag", .category = .edit },
    .{ .id = 3003, .label = "Emmet: Update Tag", .category = .edit },
    .{ .id = 3004, .label = "Emmet: Balance Inward", .category = .edit },
    .{ .id = 3005, .label = "Emmet: Balance Outward", .category = .edit },
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "!",
        .label = "HTML5 Boilerplate",
        .description = "HTML5 boilerplate template",
        .body = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n    <meta charset=\"UTF-8\">\n    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n    <title>$1</title>\n</head>\n<body>\n    $0\n</body>\n</html>",
        .language = .html,
    },
    .{
        .prefix = "div",
        .label = "div",
        .description = "HTML div element",
        .body = "<div>$0</div>",
        .language = .html,
    },
    .{
        .prefix = "link:css",
        .label = "link:css",
        .description = "CSS stylesheet link",
        .body = "<link rel=\"stylesheet\" href=\"$1\">",
        .language = .html,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.emmet",
    .name = "Emmet",
    .version = "0.1.0",
    .description = "Emmet abbreviation expansion for HTML and CSS",
    .capabilities = .{ .commands = true, .snippets = true },
    .commands = &commands,
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "emmet extension metadata" {
    try testing.expect(extension.commands.len == 6);
    try testing.expect(extension.snippets.len == 3);
    try testing.expect(extension.capabilities.commands);
    try testing.expect(extension.capabilities.snippets);
    try testing.expect(!extension.capabilities.syntax);
}
