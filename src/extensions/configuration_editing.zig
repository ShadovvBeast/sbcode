const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 3600, .label = "Open Settings", .category = .general },
    .{ .id = 3601, .label = "Open Keyboard Shortcuts", .category = .general },
};

pub const extension = ext.Extension{
    .id = "sbcode.configuration-editing",
    .name = "Configuration Editing",
    .version = "0.1.0",
    .description = "Settings and keyboard shortcuts editor",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "configuration_editing extension metadata" {
    try testing.expect(extension.commands.len == 2);
    try testing.expect(extension.capabilities.commands);
    try testing.expect(extension.commands[0].category == .general);
}
