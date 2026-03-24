// src/extensions/theme_abyss.zig — Abyss Theme Extension
//
// Colors sourced from extensions/theme-abyss/themes/abyss-color-theme.json.

const ext = @import("extension");
const Color = @import("color").Color;

pub const extension = ext.Extension{
    .id = "sbcode.theme-abyss",
    .name = "Abyss",
    .version = "0.1.0",
    .description = "Abyss color theme",
    .capabilities = .{ .theme = true },
    .themes = &.{.{
        .name = "Abyss",
        .is_dark = true,
        .colors = .{
            .keyword = Color.rgb(0x22, 0x55, 0x88),
            .string_literal = Color.rgb(0x22, 0xAA, 0x44),
            .comment = Color.rgb(0x38, 0x48, 0x87),
            .number_literal = Color.rgb(0xF2, 0x80, 0xD0),
            .builtin = Color.rgb(0x99, 0x66, 0xB8),
            .type_name = Color.rgb(0xFF, 0xEE, 0xBB),
            .function_name = Color.rgb(0xDD, 0xBB, 0x88),
            .operator = Color.rgb(0x66, 0x88, 0xCC),
            .punctuation = Color.rgb(0x66, 0x88, 0xCC),
            .preprocessor = Color.rgb(0x22, 0x55, 0x88),
            .plain = Color.rgb(0x66, 0x88, 0xCC),
            .editor_bg = Color.rgb(0x00, 0x0C, 0x18),
            .sidebar_bg = Color.rgb(0x06, 0x06, 0x21),
            .title_bar_bg = Color.rgb(0x10, 0x19, 0x2C),
            .status_bar_bg = Color.rgb(0x10, 0x19, 0x2C),
            .activity_bar_bg = Color.rgb(0x05, 0x13, 0x36),
            .panel_bg = Color.rgb(0x00, 0x0C, 0x18),
            .tab_active_bg = Color.rgb(0x00, 0x0C, 0x18),
            .tab_inactive_bg = Color.rgb(0x10, 0x19, 0x2C),
            .selection_bg = Color.rgba(0x77, 0x08, 0x11, 0xCC),
            .cursor_color = Color.rgb(0xDD, 0xBB, 0x88),
        },
    }},
};

const testing = @import("std").testing;

test "theme_abyss has correct metadata" {
    try testing.expect(extension.themes.len == 1);
    try testing.expect(extension.capabilities.theme);
}
