const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4040, .label = "Git Base: Detect Repository", .category = .general },
    .{ .id = 4041, .label = "Git Base: Get HEAD", .category = .general },
    .{ .id = 4042, .label = "Git Base: List Remotes", .category = .general },
};

pub const extension = ext.Extension{
    .id = "sbcode.git-base",
    .name = "Git Base",
    .version = "0.1.0",
    .description = "Git base API and repository detection",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "git_base extension metadata" {
    try testing.expect(extension.commands.len == 3);
    try testing.expect(extension.capabilities.commands);
}
