const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4000, .label = "CSS: Go to Symbol in File", .category = .go },
    .{ .id = 4001, .label = "CSS: Validate Document", .category = .edit },
    .{ .id = 4002, .label = "CSS: Show Color Picker", .category = .edit },
    .{ .id = 4003, .label = "CSS: Fold All Regions", .category = .edit },
};

pub const extension = ext.Extension{
    .id = "sbcode.css-language-features",
    .name = "CSS Language Features",
    .version = "0.1.0",
    .description = "CSS completion, validation, color preview, and hover",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "css_features extension metadata" {
    try testing.expect(extension.commands.len == 4);
    try testing.expect(extension.capabilities.commands);
}
