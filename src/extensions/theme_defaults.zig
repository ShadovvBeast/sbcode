// src/extensions/theme_defaults.zig — Default Dark+ Theme Extension
//
// Provides the built-in "Dark+" theme (VS Code default dark theme).
// Colors sourced from extensions/theme-defaults/themes/dark_plus.json.

const ext = @import("extension");
const Color = @import("color").Color;

pub const extension = ext.Extension{
    .id = "sbcode.theme-defaults",
    .name = "Default Dark+",
    .version = "0.1.0",
    .description = "Default Dark+ color theme",
    .capabilities = .{ .theme = true },
    .themes = &.{.{
        .name = "Dark+ (default dark)",
        .is_dark = true,
        .colors = .{
            .keyword = Color.rgb(0x56, 0x9C, 0xD6),
            .string_literal = Color.rgb(0xCE, 0x91, 0x78),
            .comment = Color.rgb(0x6A, 0x99, 0x55),
            .number_literal = Color.rgb(0xB5, 0xCE, 0xA8),
            .builtin = Color.rgb(0x4E, 0xC9, 0xB0),
            .type_name = Color.rgb(0x4E, 0xC9, 0xB0),
            .function_name = Color.rgb(0xDC, 0xDC, 0xAA),
            .operator = Color.rgb(0xD4, 0xD4, 0xD4),
            .punctuation = Color.rgb(0xD4, 0xD4, 0xD4),
            .preprocessor = Color.rgb(0xC5, 0x86, 0xC0),
            .plain = Color.rgb(0xD4, 0xD4, 0xD4),
            .editor_bg = Color.rgb(0x1E, 0x1E, 0x1E),
            .sidebar_bg = Color.rgb(0x25, 0x25, 0x25),
            .title_bar_bg = Color.rgb(0x32, 0x32, 0x32),
            .status_bar_bg = Color.rgb(0x00, 0x7A, 0xCC),
            .activity_bar_bg = Color.rgb(0x33, 0x33, 0x33),
            .panel_bg = Color.rgb(0x1E, 0x1E, 0x1E),
            .tab_active_bg = Color.rgb(0x1E, 0x1E, 0x1E),
            .tab_inactive_bg = Color.rgb(0x2D, 0x2D, 0x2D),
            .selection_bg = Color.rgba(0x26, 0x4F, 0x78, 0xCC),
            .cursor_color = Color.rgb(0xFF, 0xFF, 0xFF),
        },
    }},
};

const testing = @import("std").testing;

test "theme_defaults has correct metadata" {
    try testing.expect(extension.themes.len == 1);
    try testing.expect(extension.capabilities.theme);
    try testing.expect(!extension.capabilities.syntax);
}
