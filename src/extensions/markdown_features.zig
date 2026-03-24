const ext = @import("extension");
const syntax = @import("syntax");

const commands = [_]ext.CommandContribution{
    .{ .id = 3800, .label = "Markdown: Open Preview", .shortcut = "Ctrl+Shift+V", .category = .edit },
    .{ .id = 3801, .label = "Markdown: Open Preview to Side", .category = .edit },
    .{ .id = 3802, .label = "Markdown: Toggle Bold", .category = .edit },
    .{ .id = 3803, .label = "Markdown: Toggle Italic", .category = .edit },
    .{ .id = 3804, .label = "Markdown: Insert Link", .category = .edit },
    .{ .id = 3805, .label = "Markdown: Insert Image", .category = .edit },
};

const keybindings = [_]ext.KeybindingContribution{
    // Ctrl+Shift+V — Markdown preview (editor context)
    .{ .key_code = 0x56, .ctrl = true, .shift = true, .command_id = 3800, .context = .editor },
};

const snippets = [_]ext.SnippetContribution{
    .{
        .prefix = "link",
        .label = "Link",
        .description = "Markdown link",
        .body = "[${1:text}](${2:url})",
        .language = .markdown,
    },
    .{
        .prefix = "img",
        .label = "Image",
        .description = "Markdown image",
        .body = "![${1:alt}](${2:url})",
        .language = .markdown,
    },
    .{
        .prefix = "code",
        .label = "Code Block",
        .description = "Fenced code block",
        .body = "```${1:lang}\n$0\n```",
        .language = .markdown,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.markdown-language-features",
    .name = "Markdown Language Features",
    .version = "0.1.0",
    .description = "Markdown preview, formatting, and snippets",
    .capabilities = .{ .commands = true, .keybindings = true, .snippets = true },
    .commands = &commands,
    .keybindings = &keybindings,
    .snippets = &snippets,
};

const testing = @import("std").testing;

test "markdown_features extension metadata" {
    try testing.expect(extension.commands.len == 6);
    try testing.expect(extension.keybindings.len == 1);
    try testing.expect(extension.snippets.len == 3);
    try testing.expect(extension.capabilities.commands);
    try testing.expect(extension.capabilities.keybindings);
    try testing.expect(extension.capabilities.snippets);
    try testing.expect(extension.keybindings[0].command_id == 3800);
    try testing.expect(extension.snippets[0].language.? == .markdown);
}
