const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 3300, .label = "Find All References", .category = .go },
    .{ .id = 3301, .label = "Peek References", .category = .go },
};

pub const extension = ext.Extension{
    .id = "sbcode.references-view",
    .name = "References View",
    .version = "0.1.0",
    .description = "Find all references and peek references",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "references_view extension metadata" {
    try testing.expect(extension.commands.len == 2);
    try testing.expect(extension.capabilities.commands);
    try testing.expect(extension.commands[0].category == .go);
}
