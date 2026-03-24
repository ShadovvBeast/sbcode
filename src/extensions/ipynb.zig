const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 4140, .label = "Notebook: Open as Text", .category = .file },
    .{ .id = 4141, .label = "Notebook: Run Cell", .category = .run },
    .{ .id = 4142, .label = "Notebook: Run All Cells", .category = .run },
    .{ .id = 4143, .label = "Notebook: Clear All Outputs", .category = .edit },
};

pub const extension = ext.Extension{
    .id = "sbcode.ipynb",
    .name = "Jupyter Notebook",
    .version = "0.1.0",
    .description = "Jupyter notebook (.ipynb) support",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "ipynb extension metadata" {
    try testing.expect(extension.commands.len == 4);
    try testing.expect(extension.capabilities.commands);
}
