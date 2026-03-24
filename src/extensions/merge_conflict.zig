const ext = @import("extension");

const commands = [_]ext.CommandContribution{
    .{ .id = 3200, .label = "Merge Conflict: Accept Current", .category = .edit },
    .{ .id = 3201, .label = "Merge Conflict: Accept Incoming", .category = .edit },
    .{ .id = 3202, .label = "Merge Conflict: Accept Both", .category = .edit },
    .{ .id = 3203, .label = "Merge Conflict: Next Conflict", .category = .edit },
    .{ .id = 3204, .label = "Merge Conflict: Previous Conflict", .category = .edit },
};

pub const extension = ext.Extension{
    .id = "sbcode.merge-conflict",
    .name = "Merge Conflict",
    .version = "0.1.0",
    .description = "Merge conflict resolution helpers",
    .capabilities = .{ .commands = true },
    .commands = &commands,
};

const testing = @import("std").testing;

test "merge_conflict extension metadata" {
    try testing.expect(extension.commands.len == 5);
    try testing.expect(extension.capabilities.commands);
    try testing.expect(extension.commands[0].id == 3200);
    try testing.expect(extension.commands[4].id == 3204);
}
