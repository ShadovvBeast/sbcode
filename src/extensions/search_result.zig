const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 3400, .label = "Open Search Results", .category = .view },
    .{ .id = 3401, .label = "Clear Search Results", .category = .view },
};

pub const extension = ext.Extension{
    .id = "sbcode.search-result",
    .name = "Search Result",
    .version = "0.1.0",
    .description = "Search results editor and navigation",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "search_result extension metadata" {
    try testing.expect(extension.commands.len == 2);
    try testing.expect(extension.capabilities.commands);
    try testing.expect(extension.commands[0].category == .view);
}
