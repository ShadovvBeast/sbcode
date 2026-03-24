const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4110, .label = "Grunt: Run Task", .category = .terminal },
    .{ .id = 4111, .label = "Grunt: List Tasks", .category = .terminal },
    .{ .id = 4112, .label = "Grunt: Terminate Task", .category = .terminal },
};

pub const extension = ext.Extension{
    .id = "sbcode.grunt",
    .name = "Grunt",
    .version = "0.1.0",
    .description = "Grunt task runner integration",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "grunt_ext extension metadata" {
    try testing.expect(extension.commands.len == 3);
    try testing.expect(extension.capabilities.commands);
}
