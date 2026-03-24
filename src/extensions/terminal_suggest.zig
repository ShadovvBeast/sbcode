const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4180, .label = "Terminal: Toggle Suggestions", .category = .terminal },
    .{ .id = 4181, .label = "Terminal: Accept Suggestion", .category = .terminal },
    .{ .id = 4182, .label = "Terminal: Dismiss Suggestion", .category = .terminal },
};

pub const extension = ext.Extension{
    .id = "sbcode.terminal-suggest",
    .name = "Terminal Suggest",
    .version = "0.1.0",
    .description = "Terminal command suggestions and completions",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "terminal_suggest extension metadata" {
    try testing.expect(extension.commands.len == 3);
    try testing.expect(extension.capabilities.commands);
}
