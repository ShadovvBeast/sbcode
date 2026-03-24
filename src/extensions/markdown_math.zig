const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4150, .label = "Markdown Math: Toggle Equation", .category = .edit },
    .{ .id = 4151, .label = "Markdown Math: Insert Block Equation", .category = .edit },
    .{ .id = 4152, .label = "Markdown Math: Preview Math", .category = .edit },
};

const snippets = [_]ext.SnippetContribution{
    .{ .prefix = "math", .label = "Inline Math", .description = "Inline math expression", .body = "$${1:expression}$", .language = .markdown },
    .{ .prefix = "mathblock", .label = "Math Block", .description = "Display math block", .body = "$$\n${1:expression}\n$$", .language = .markdown },
};

pub const extension = ext.Extension{
    .id = "sbcode.markdown-math",
    .name = "Markdown Math",
    .version = "0.1.0",
    .description = "Math formula rendering in markdown preview",
    .capabilities = .{ .commands = true, .snippets = true },
    .commands = &commands,
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "markdown_math extension metadata" {
    try testing.expect(extension.commands.len == 3);
    try testing.expect(extension.snippets.len == 2);
    try testing.expect(extension.capabilities.commands);
    try testing.expect(extension.capabilities.snippets);
}
