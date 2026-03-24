const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4070, .label = "Microsoft Auth: Sign In", .category = .general },
    .{ .id = 4071, .label = "Microsoft Auth: Sign Out", .category = .general },
    .{ .id = 4072, .label = "Microsoft Auth: Show Account", .category = .general },
};

pub const extension = ext.Extension{
    .id = "sbcode.microsoft-authentication",
    .name = "Microsoft Authentication",
    .version = "0.1.0",
    .description = "Microsoft account authentication provider",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "microsoft_auth extension metadata" {
    try testing.expect(extension.commands.len == 3);
    try testing.expect(extension.capabilities.commands);
}
