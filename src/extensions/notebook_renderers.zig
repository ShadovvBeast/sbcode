const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4160, .label = "Notebook: Select Renderer", .category = .view },
    .{ .id = 4161, .label = "Notebook: Render as HTML", .category = .view },
    .{ .id = 4162, .label = "Notebook: Render as Plain Text", .category = .view },
};

pub const extension = ext.Extension{
    .id = "sbcode.notebook-renderers",
    .name = "Notebook Renderers",
    .version = "0.1.0",
    .description = "Built-in notebook output renderers",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "notebook_renderers extension metadata" {
    try testing.expect(extension.commands.len == 3);
    try testing.expect(extension.capabilities.commands);
}
