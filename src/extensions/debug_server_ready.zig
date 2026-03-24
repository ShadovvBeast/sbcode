const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4090, .label = "Debug: Open Browser on Server Ready", .category = .run },
    .{ .id = 4091, .label = "Debug: Configure Server Ready Pattern", .category = .run },
    .{ .id = 4092, .label = "Debug: Show Server Ready Status", .category = .run },
};

pub const extension = ext.Extension{
    .id = "sbcode.debug-server-ready",
    .name = "Debug Server Ready",
    .version = "0.1.0",
    .description = "Open browser when debug server is ready",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "debug_server_ready extension metadata" {
    try testing.expect(extension.commands.len == 3);
    try testing.expect(extension.capabilities.commands);
}
