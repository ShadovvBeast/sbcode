// src/extensions/theme_kimbie_dark.zig — Kimbie Dark Theme Extension
//
// Colors sourced from extensions/theme-kimbie-dark/themes/kimbie-dark-color-theme.json.

const ext = @import("extension");
const Color = @import("color").Color;

pub const extension = ext.Extension{
    .id = "sbcode.theme-kimbie-dark",
    .name = "Kimbie Dark",
    .version = "0.1.0",
    .description = "Kimbie Dark color theme",
    .capabilities = .{ .theme = true },
    .themes = &.{.{
        .name = "Kimbie Dark",
        .is_dark = true,
        .colors = .{
            .keyword = Color.rgb(0x98, 0x67, 0x6A),
            .string_literal = Color.rgb(0x88, 0x9B, 0x4A),
            .comment = Color.rgb(0xA5, 0x7A, 0x4C),
            .number_literal = Color.rgb(0xF7, 0x9A, 0x32),
            .builtin = Color.rgb(0x7E, 0x60, 0x2C),
            .type_name = Color.rgb(0xF0, 0x64, 0x31),
            .function_name = Color.rgb(0x8A, 0xB1, 0xB0),
            .operator = Color.rgb(0xD3, 0xAF, 0x86),
            .punctuation = Color.rgb(0xD3, 0xAF, 0x86),
            .preprocessor = Color.rgb(0x98, 0x67, 0x6A),
            .plain = Color.rgb(0xD3, 0xAF, 0x86),
            .editor_bg = Color.rgb(0x22, 0x1A, 0x0F),
            .sidebar_bg = Color.rgb(0x36, 0x27, 0x12),
            .title_bar_bg = Color.rgb(0x42, 0x35, 0x23),
            .status_bar_bg = Color.rgb(0x42, 0x35, 0x23),
            .activity_bar_bg = Color.rgb(0x22, 0x1A, 0x0F),
            .panel_bg = Color.rgb(0x22, 0x1A, 0x0F),
            .tab_active_bg = Color.rgb(0x22, 0x1A, 0x0F),
            .tab_inactive_bg = Color.rgb(0x13, 0x15, 0x10),
            .selection_bg = Color.rgba(0x84, 0x61, 0x3D, 0xAA),
            .cursor_color = Color.rgb(0xD3, 0xAF, 0x86),
        },
    }},
};

const testing = @import("std").testing;

test "theme_kimbie_dark has correct metadata" {
    try testing.expect(extension.themes.len == 1);
    try testing.expect(extension.capabilities.theme);
}
