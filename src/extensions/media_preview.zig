const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 3700, .label = "Media: Open Preview", .category = .view },
    .{ .id = 3701, .label = "Media: Open Preview to Side", .category = .view },
};

pub const extension = ext.Extension{
    .id = "sbcode.media-preview",
    .name = "Media Preview",
    .version = "0.1.0",
    .description = "Image and media file preview",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "media_preview extension metadata" {
    try testing.expect(extension.commands.len == 2);
    try testing.expect(extension.capabilities.commands);
    try testing.expect(extension.commands[0].category == .view);
}
