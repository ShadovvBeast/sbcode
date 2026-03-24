const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4170, .label = "Simple Browser: Open URL", .category = .view },
    .{ .id = 4171, .label = "Simple Browser: Navigate Back", .category = .view },
    .{ .id = 4172, .label = "Simple Browser: Navigate Forward", .category = .view },
};

pub const extension = ext.Extension{
    .id = "sbcode.simple-browser",
    .name = "Simple Browser",
    .version = "0.1.0",
    .description = "Embedded simple browser for previewing web content",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "simple_browser extension metadata" {
    try testing.expect(extension.commands.len == 3);
    try testing.expect(extension.capabilities.commands);
}
