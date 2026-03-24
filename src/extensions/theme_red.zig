// src/extensions/theme_red.zig — Red Theme Extension
//
// A dark theme with red accents.

const ext = @import("extension");
const Color = @import("color").Color;

pub const extension = ext.Extension{
    .id = "sbcode.theme-red",
    .name = "Red",
    .version = "0.1.0",
    .description = "Red color theme",
    .capabilities = .{ .theme = true },
    .themes = &.{.{
        .name = "Red",
        .is_dark = true,
        .colors = .{
            .keyword = Color.rgb(0xFF, 0x6D, 0x7E),
            .string_literal = Color.rgb(0xFF, 0x8F, 0x70),
            .comment = Color.rgb(0x5F, 0x5F, 0x5F),
            .number_literal = Color.rgb(0xFF, 0x9D, 0xA4),
            .builtin = Color.rgb(0xE0, 0x80, 0x80),
            .type_name = Color.rgb(0xE0, 0x80, 0x80),
            .function_name = Color.rgb(0xD4, 0xD4, 0xD4),
            .operator = Color.rgb(0xD4, 0xD4, 0xD4),
            .punctuation = Color.rgb(0xD4, 0xD4, 0xD4),
            .preprocessor = Color.rgb(0xFF, 0x6D, 0x7E),
            .plain = Color.rgb(0xD4, 0xD4, 0xD4),
            .editor_bg = Color.rgb(0x39, 0x0C, 0x0C),
            .sidebar_bg = Color.rgb(0x2D, 0x08, 0x08),
            .title_bar_bg = Color.rgb(0x4D, 0x10, 0x10),
            .status_bar_bg = Color.rgb(0x8C, 0x22, 0x22),
            .activity_bar_bg = Color.rgb(0x33, 0x0A, 0x0A),
            .panel_bg = Color.rgb(0x39, 0x0C, 0x0C),
            .tab_active_bg = Color.rgb(0x39, 0x0C, 0x0C),
            .tab_inactive_bg = Color.rgb(0x2D, 0x08, 0x08),
            .selection_bg = Color.rgba(0x8C, 0x22, 0x22, 0xAA),
            .cursor_color = Color.rgb(0xFF, 0xFF, 0xFF),
        },
    }},
};

const testing = @import("std").testing;

test "theme_red has correct metadata" {
    try testing.expect(extension.themes.len == 1);
    try testing.expect(extension.capabilities.theme);
}
