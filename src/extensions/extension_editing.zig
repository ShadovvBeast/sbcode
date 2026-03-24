const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4100, .label = "Extension: Open Manifest", .category = .file },
    .{ .id = 4101, .label = "Extension: Validate Manifest", .category = .edit },
    .{ .id = 4102, .label = "Extension: Show Contribution Points", .category = .general },
};

pub const extension = ext.Extension{
    .id = "sbcode.extension-editing",
    .name = "Extension Editing",
    .version = "0.1.0",
    .description = "Extension manifest editing and validation",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "extension_editing extension metadata" {
    try testing.expect(extension.commands.len == 3);
    try testing.expect(extension.capabilities.commands);
}
