const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4130, .label = "Jake: Run Task", .category = .terminal },
    .{ .id = 4131, .label = "Jake: List Tasks", .category = .terminal },
    .{ .id = 4132, .label = "Jake: Terminate Task", .category = .terminal },
};

pub const extension = ext.Extension{
    .id = "sbcode.jake",
    .name = "Jake",
    .version = "0.1.0",
    .description = "Jake task runner integration",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "jake_ext extension metadata" {
    try testing.expect(extension.commands.len == 3);
    try testing.expect(extension.capabilities.commands);
}
