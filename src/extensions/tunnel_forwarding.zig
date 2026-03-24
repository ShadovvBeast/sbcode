const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4190, .label = "Tunnel: Forward Port", .category = .general },
    .{ .id = 4191, .label = "Tunnel: Stop Forwarding", .category = .general },
    .{ .id = 4192, .label = "Tunnel: Show Forwarded Ports", .category = .general },
};

const status_items = [_]ext.StatusItemContribution{
    .{ .id = "tunnel.ports", .label = "Ports", .alignment = .right, .priority = 60 },
};

pub const extension = ext.Extension{
    .id = "sbcode.tunnel-forwarding",
    .name = "Tunnel Forwarding",
    .version = "0.1.0",
    .description = "Port and tunnel forwarding for remote development",
    .capabilities = .{ .commands = true, .status_items = true },
    .commands = &commands,
    .status_items = &status_items,
};

const testing = @import("std").testing;

test "tunnel_forwarding extension metadata" {
    try testing.expect(extension.commands.len == 3);
    try testing.expect(extension.status_items.len == 1);
    try testing.expect(extension.capabilities.commands);
    try testing.expect(extension.capabilities.status_items);
}
