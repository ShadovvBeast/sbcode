const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4050, .label = "GitHub: Open Pull Request", .category = .general },
    .{ .id = 4051, .label = "GitHub: Create Issue", .category = .general },
    .{ .id = 4052, .label = "GitHub: Browse Repository", .category = .general },
    .{ .id = 4053, .label = "GitHub: Copy Permalink", .category = .general },
};

pub const extension = ext.Extension{
    .id = "sbcode.github",
    .name = "GitHub",
    .version = "0.1.0",
    .description = "GitHub issues and pull request integration",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "github_ext extension metadata" {
    try testing.expect(extension.commands.len == 4);
    try testing.expect(extension.capabilities.commands);
}
