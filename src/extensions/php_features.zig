const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4020, .label = "PHP: Go to Definition", .category = .go },
    .{ .id = 4021, .label = "PHP: Find All References", .category = .go },
    .{ .id = 4022, .label = "PHP: Show Hover Info", .category = .edit },
    .{ .id = 4023, .label = "PHP: Signature Help", .category = .edit },
};

pub const extension = ext.Extension{
    .id = "sbcode.php-language-features",
    .name = "PHP Language Features",
    .version = "0.1.0",
    .description = "PHP completion, hover, and signature help",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "php_features extension metadata" {
    try testing.expect(extension.commands.len == 4);
    try testing.expect(extension.capabilities.commands);
}
