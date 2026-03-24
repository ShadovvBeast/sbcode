const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4080, .label = "Debug: Toggle Auto Launch", .category = .run },
    .{ .id = 4081, .label = "Debug: Configure Auto Launch", .category = .run },
    .{ .id = 4082, .label = "Debug: Show Auto Launch Status", .category = .run },
};

const status_items = [_]ext.StatusItemContribution{
    .{ .id = "debug.autolaunch", .label = "Auto Launch", .alignment = .left, .priority = 50 },
};

pub const extension = ext.Extension{
    .id = "sbcode.debug-auto-launch",
    .name = "Debug Auto Launch",
    .version = "0.1.0",
    .description = "Automatically launch debug sessions for detected configurations",
    .capabilities = .{ .commands = true, .status_items = true },
    .commands = &commands,
    .status_items = &status_items,
};

const testing = @import("std").testing;

test "debug_auto_launch extension metadata" {
    try testing.expect(extension.commands.len == 3);
    try testing.expect(extension.status_items.len == 1);
    try testing.expect(extension.capabilities.commands);
    try testing.expect(extension.capabilities.status_items);
}
