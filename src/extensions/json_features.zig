const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4010, .label = "JSON: Validate Document", .category = .edit },
    .{ .id = 4011, .label = "JSON: Format Document", .category = .edit },
    .{ .id = 4012, .label = "JSON: Sort Keys", .category = .edit },
    .{ .id = 4013, .label = "JSON: Select Schema", .category = .edit },
};

pub const extension = ext.Extension{
    .id = "sbcode.json-language-features",
    .name = "JSON Language Features",
    .version = "0.1.0",
    .description = "JSON completion, validation, and schema support",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "json_features extension metadata" {
    try testing.expect(extension.commands.len == 4);
    try testing.expect(extension.capabilities.commands);
}
