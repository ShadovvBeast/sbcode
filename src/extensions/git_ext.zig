const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 3100, .label = "Git: Clone", .category = .general },
    .{ .id = 3101, .label = "Git: Init", .category = .general },
    .{ .id = 3102, .label = "Git: Commit", .category = .general },
    .{ .id = 3103, .label = "Git: Push", .category = .general },
    .{ .id = 3104, .label = "Git: Pull", .category = .general },
    .{ .id = 3105, .label = "Git: Fetch", .category = .general },
    .{ .id = 3106, .label = "Git: Checkout", .category = .general },
    .{ .id = 3107, .label = "Git: Create Branch", .category = .general },
    .{ .id = 3108, .label = "Git: Delete Branch", .category = .general },
    .{ .id = 3109, .label = "Git: Merge", .category = .general },
    .{ .id = 3110, .label = "Git: Stash", .category = .general },
    .{ .id = 3111, .label = "Git: Stash Pop", .category = .general },
    .{ .id = 3112, .label = "Git: Show Log", .category = .general },
    .{ .id = 3113, .label = "Git: Stage File", .category = .general },
    .{ .id = 3114, .label = "Git: Unstage File", .category = .general },
};

const status_items = [_]ext.StatusItemContribution{
    .{
        .id = "git.branch",
        .label = "main",
        .alignment = .right,
        .priority = 100,
    },
};

pub const extension = ext.Extension{
    .id = "sbcode.git",
    .name = "Git",
    .version = "0.1.0",
    .description = "Git source control integration",
    .capabilities = .{ .commands = true, .status_items = true },
    .commands = &commands,
    .status_items = &status_items,
};

const testing = @import("std").testing;

test "git extension metadata" {
    try testing.expect(extension.commands.len == 15);
    try testing.expect(extension.status_items.len == 1);
    try testing.expect(extension.capabilities.commands);
    try testing.expect(extension.capabilities.status_items);
    try testing.expect(extension.status_items[0].alignment == .right);
    try testing.expect(extension.status_items[0].priority == 100);
}
