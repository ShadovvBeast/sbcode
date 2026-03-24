const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4060, .label = "GitHub Auth: Sign In", .category = .general },
    .{ .id = 4061, .label = "GitHub Auth: Sign Out", .category = .general },
    .{ .id = 4062, .label = "GitHub Auth: Show Account", .category = .general },
};

const status_items = [_]ext.StatusItemContribution{
    .{ .id = "github.account", .label = "GitHub", .alignment = .right, .priority = 90 },
};

pub const extension = ext.Extension{
    .id = "sbcode.github-authentication",
    .name = "GitHub Authentication",
    .version = "0.1.0",
    .description = "GitHub OAuth authentication provider",
    .capabilities = .{ .commands = true, .status_items = true },
    .commands = &commands,
    .status_items = &status_items,
};

const testing = @import("std").testing;

test "github_auth extension metadata" {
    try testing.expect(extension.commands.len == 3);
    try testing.expect(extension.status_items.len == 1);
    try testing.expect(extension.capabilities.commands);
    try testing.expect(extension.capabilities.status_items);
}
