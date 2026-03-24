// src/extensions/theme_solarized_dark.zig — Solarized Dark Theme Extension
//
// Colors based on Ethan Schoonover's Solarized palette.

const ext = @import("extension");
const Color = @import("color").Color;

pub const extension = ext.Extension{
    .id = "sbcode.theme-solarized-dark",
    .name = "Solarized Dark",
    .version = "0.1.0",
    .description = "Solarized Dark color theme",
    .capabilities = .{ .theme = true },
    .themes = &.{.{
        .name = "Solarized Dark",
        .is_dark = true,
        .colors = .{
            .keyword = Color.rgb(0x85, 0x99, 0x00),
            .string_literal = Color.rgb(0x2A, 0xA1, 0x98),
            .comment = Color.rgb(0x58, 0x6E, 0x75),
            .number_literal = Color.rgb(0xD3, 0x36, 0x82),
            .builtin = Color.rgb(0x6C, 0x71, 0xC4),
            .type_name = Color.rgb(0xB5, 0x89, 0x00),
            .function_name = Color.rgb(0x26, 0x8B, 0xD2),
            .operator = Color.rgb(0x83, 0x94, 0x96),
            .punctuation = Color.rgb(0x83, 0x94, 0x96),
            .preprocessor = Color.rgb(0xCB, 0x4B, 0x16),
            .plain = Color.rgb(0x83, 0x94, 0x96),
            .editor_bg = Color.rgb(0x00, 0x2B, 0x36),
            .sidebar_bg = Color.rgb(0x00, 0x25, 0x2F),
            .title_bar_bg = Color.rgb(0x00, 0x25, 0x2F),
            .status_bar_bg = Color.rgb(0x00, 0x3B, 0x49),
            .activity_bar_bg = Color.rgb(0x00, 0x25, 0x2F),
            .panel_bg = Color.rgb(0x00, 0x2B, 0x36),
            .tab_active_bg = Color.rgb(0x00, 0x2B, 0x36),
            .tab_inactive_bg = Color.rgb(0x00, 0x25, 0x2F),
            .selection_bg = Color.rgba(0x27, 0x48, 0x42, 0xCC),
            .cursor_color = Color.rgb(0xD3, 0x03, 0x02),
        },
    }},
};

const testing = @import("std").testing;

test "theme_solarized_dark has correct metadata" {
    try testing.expect(extension.themes.len == 1);
    try testing.expect(extension.capabilities.theme);
}
