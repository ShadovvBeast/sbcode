const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 3500, .label = "NPM: Install", .category = .terminal },
    .{ .id = 3501, .label = "NPM: Run Script", .category = .terminal },
    .{ .id = 3502, .label = "NPM: Init", .category = .terminal },
};

pub const extension = ext.Extension{
    .id = "sbcode.npm",
    .name = "NPM",
    .version = "0.1.0",
    .description = "NPM script detection and task running",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "npm extension metadata" {
    try testing.expect(extension.commands.len == 3);
    try testing.expect(extension.capabilities.commands);
    try testing.expect(extension.commands[0].category == .terminal);
}
