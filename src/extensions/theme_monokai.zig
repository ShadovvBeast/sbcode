// src/extensions/theme_monokai.zig — Monokai Theme Extension
//
// Colors sourced from extensions/theme-monokai/themes/monokai-color-theme.json.

const ext = @import("extension");
const Color = @import("color").Color;

pub const extension = ext.Extension{
    .id = "sbcode.theme-monokai",
    .name = "Monokai",
    .version = "0.1.0",
    .description = "Monokai color theme",
    .capabilities = .{ .theme = true },
    .themes = &.{.{
        .name = "Monokai",
        .is_dark = true,
        .colors = .{
            .keyword = Color.rgb(0xF9, 0x26, 0x72),
            .string_literal = Color.rgb(0xE6, 0xDB, 0x74),
            .comment = Color.rgb(0x88, 0x84, 0x6F),
            .number_literal = Color.rgb(0xAE, 0x81, 0xFF),
            .builtin = Color.rgb(0x66, 0xD9, 0xEF),
            .type_name = Color.rgb(0xA6, 0xE2, 0x2E),
            .function_name = Color.rgb(0xA6, 0xE2, 0x2E),
            .operator = Color.rgb(0xF8, 0xF8, 0xF2),
            .punctuation = Color.rgb(0xF8, 0xF8, 0xF2),
            .preprocessor = Color.rgb(0xF9, 0x26, 0x72),
            .plain = Color.rgb(0xF8, 0xF8, 0xF2),
            .editor_bg = Color.rgb(0x27, 0x28, 0x22),
            .sidebar_bg = Color.rgb(0x1E, 0x1F, 0x1C),
            .title_bar_bg = Color.rgb(0x1E, 0x1F, 0x1C),
            .status_bar_bg = Color.rgb(0x41, 0x43, 0x39),
            .activity_bar_bg = Color.rgb(0x27, 0x28, 0x22),
            .panel_bg = Color.rgb(0x27, 0x28, 0x22),
            .tab_active_bg = Color.rgb(0x27, 0x28, 0x22),
            .tab_inactive_bg = Color.rgb(0x34, 0x35, 0x2F),
            .selection_bg = Color.rgba(0x87, 0x8B, 0x91, 0x80),
            .cursor_color = Color.rgb(0xF8, 0xF8, 0xF0),
        },
    }},
};

const testing = @import("std").testing;

test "theme_monokai has correct metadata" {
    try testing.expect(extension.themes.len == 1);
    try testing.expect(extension.capabilities.theme);
}
