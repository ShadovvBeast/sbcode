const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4120, .label = "Gulp: Run Task", .category = .terminal },
    .{ .id = 4121, .label = "Gulp: List Tasks", .category = .terminal },
    .{ .id = 4122, .label = "Gulp: Terminate Task", .category = .terminal },
};

pub const extension = ext.Extension{
    .id = "sbcode.gulp",
    .name = "Gulp",
    .version = "0.1.0",
    .description = "Gulp task runner integration",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "gulp_ext extension metadata" {
    try testing.expect(extension.commands.len == 3);
    try testing.expect(extension.capabilities.commands);
}
