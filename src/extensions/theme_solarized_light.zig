// src/extensions/theme_solarized_light.zig — Solarized Light Theme Extension
//
// Colors based on Ethan Schoonover's Solarized palette (light variant).

const ext = @import("extension");
const Color = @import("color").Color;

pub const extension = ext.Extension{
    .id = "sbcode.theme-solarized-light",
    .name = "Solarized Light",
    .version = "0.1.0",
    .description = "Solarized Light color theme",
    .capabilities = .{ .theme = true },
    .themes = &.{.{
        .name = "Solarized Light",
        .is_dark = false,
        .colors = .{
            .keyword = Color.rgb(0x85, 0x99, 0x00),
            .string_literal = Color.rgb(0x2A, 0xA1, 0x98),
            .comment = Color.rgb(0x93, 0xA1, 0xA1),
            .number_literal = Color.rgb(0xD3, 0x36, 0x82),
            .builtin = Color.rgb(0x6C, 0x71, 0xC4),
            .type_name = Color.rgb(0xB5, 0x89, 0x00),
            .function_name = Color.rgb(0x26, 0x8B, 0xD2),
            .operator = Color.rgb(0x65, 0x7B, 0x83),
            .punctuation = Color.rgb(0x65, 0x7B, 0x83),
            .preprocessor = Color.rgb(0xCB, 0x4B, 0x16),
            .plain = Color.rgb(0x65, 0x7B, 0x83),
            .editor_bg = Color.rgb(0xFD, 0xF6, 0xE3),
            .sidebar_bg = Color.rgb(0xEE, 0xE8, 0xD5),
            .title_bar_bg = Color.rgb(0xEE, 0xE8, 0xD5),
            .status_bar_bg = Color.rgb(0xEE, 0xE8, 0xD5),
            .activity_bar_bg = Color.rgb(0xEE, 0xE8, 0xD5),
            .panel_bg = Color.rgb(0xFD, 0xF6, 0xE3),
            .tab_active_bg = Color.rgb(0xFD, 0xF6, 0xE3),
            .tab_inactive_bg = Color.rgb(0xEE, 0xE8, 0xD5),
            .selection_bg = Color.rgba(0xEE, 0xE8, 0xD5, 0xCC),
            .cursor_color = Color.rgb(0x65, 0x7B, 0x83),
        },
    }},
};

const testing = @import("std").testing;

test "theme_solarized_light has correct metadata" {
    try testing.expect(extension.themes.len == 1);
    try testing.expect(extension.capabilities.theme);
    try testing.expect(!extension.themes[0].is_dark);
}
