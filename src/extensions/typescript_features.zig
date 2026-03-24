const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4030, .label = "TypeScript: Go to Definition", .category = .go },
    .{ .id = 4031, .label = "TypeScript: Find All References", .category = .go },
    .{ .id = 4032, .label = "TypeScript: Rename Symbol", .category = .edit },
    .{ .id = 4033, .label = "TypeScript: Organize Imports", .category = .edit },
    .{ .id = 4034, .label = "TypeScript: Show Diagnostics", .category = .edit },
    .{ .id = 4035, .label = "TypeScript: Restart Server", .category = .general },
};

pub const extension = ext.Extension{
    .id = "sbcode.typescript-language-features",
    .name = "TypeScript Language Features",
    .version = "0.1.0",
    .description = "TypeScript/JavaScript IntelliSense, diagnostics, and refactoring",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "typescript_features extension metadata" {
    try testing.expect(extension.commands.len == 6);
    try testing.expect(extension.capabilities.commands);
}
