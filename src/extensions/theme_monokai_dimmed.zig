// src/extensions/theme_monokai_dimmed.zig — Monokai Dimmed Theme Extension
//
// A softer variant of Monokai with reduced contrast.

const ext = @import("extension");
const Color = @import("color").Color;

pub const extension = ext.Extension{
    .id = "sbcode.theme-monokai-dimmed",
    .name = "Monokai Dimmed",
    .version = "0.1.0",
    .description = "Monokai Dimmed color theme",
    .capabilities = .{ .theme = true },
    .themes = &.{.{
        .name = "Monokai Dimmed",
        .is_dark = true,
        .colors = .{
            .keyword = Color.rgb(0xC7, 0x44, 0x4A),
            .string_literal = Color.rgb(0x9A, 0xA8, 0x3A),
            .comment = Color.rgb(0x6B, 0x6B, 0x5E),
            .number_literal = Color.rgb(0x6C, 0x99, 0xBB),
            .builtin = Color.rgb(0x9E, 0x7E, 0xC4),
            .type_name = Color.rgb(0x9E, 0x7E, 0xC4),
            .function_name = Color.rgb(0xC8, 0xC8, 0xAF),
            .operator = Color.rgb(0xC5, 0xC8, 0xC6),
            .punctuation = Color.rgb(0xC5, 0xC8, 0xC6),
            .preprocessor = Color.rgb(0xC7, 0x44, 0x4A),
            .plain = Color.rgb(0xC5, 0xC8, 0xC6),
            .editor_bg = Color.rgb(0x1E, 0x1E, 0x1E),
            .sidebar_bg = Color.rgb(0x25, 0x25, 0x25),
            .title_bar_bg = Color.rgb(0x1E, 0x1E, 0x1E),
            .status_bar_bg = Color.rgb(0x41, 0x43, 0x39),
            .activity_bar_bg = Color.rgb(0x33, 0x33, 0x33),
            .panel_bg = Color.rgb(0x1E, 0x1E, 0x1E),
            .tab_active_bg = Color.rgb(0x1E, 0x1E, 0x1E),
            .tab_inactive_bg = Color.rgb(0x2D, 0x2D, 0x2D),
            .selection_bg = Color.rgba(0x67, 0x6B, 0x71, 0x80),
            .cursor_color = Color.rgb(0xF8, 0xF8, 0xF0),
        },
    }},
};

const testing = @import("std").testing;

test "theme_monokai_dimmed has correct metadata" {
    try testing.expect(extension.themes.len == 1);
    try testing.expect(extension.capabilities.theme);
}
