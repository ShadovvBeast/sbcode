// src/extensions/theme_quietlight.zig — Quiet Light Theme Extension
//
// A light theme with soft, muted colors.

const ext = @import("extension");
const Color = @import("color").Color;

pub const extension = ext.Extension{
    .id = "sbcode.theme-quietlight",
    .name = "Quiet Light",
    .version = "0.1.0",
    .description = "Quiet Light color theme",
    .capabilities = .{ .theme = true },
    .themes = &.{.{
        .name = "Quiet Light",
        .is_dark = false,
        .colors = .{
            .keyword = Color.rgb(0x4B, 0x83, 0xCD),
            .string_literal = Color.rgb(0x44, 0x8C, 0x27),
            .comment = Color.rgb(0xAA, 0xAA, 0xAA),
            .number_literal = Color.rgb(0xAB, 0x6B, 0x32),
            .builtin = Color.rgb(0x7A, 0x3E, 0x9D),
            .type_name = Color.rgb(0x7A, 0x3E, 0x9D),
            .function_name = Color.rgb(0xAA, 0x3E, 0x56),
            .operator = Color.rgb(0x33, 0x33, 0x33),
            .punctuation = Color.rgb(0x33, 0x33, 0x33),
            .preprocessor = Color.rgb(0x4B, 0x83, 0xCD),
            .plain = Color.rgb(0x33, 0x33, 0x33),
            .editor_bg = Color.rgb(0xF5, 0xF5, 0xF5),
            .sidebar_bg = Color.rgb(0xEC, 0xEC, 0xEC),
            .title_bar_bg = Color.rgb(0xE0, 0xE0, 0xE0),
            .status_bar_bg = Color.rgb(0xC8, 0xC8, 0xC8),
            .activity_bar_bg = Color.rgb(0xDD, 0xDD, 0xDD),
            .panel_bg = Color.rgb(0xF5, 0xF5, 0xF5),
            .tab_active_bg = Color.rgb(0xF5, 0xF5, 0xF5),
            .tab_inactive_bg = Color.rgb(0xEC, 0xEC, 0xEC),
            .selection_bg = Color.rgba(0xC9, 0xD0, 0xD9, 0xCC),
            .cursor_color = Color.rgb(0x00, 0x00, 0x00),
        },
    }},
};

const testing = @import("std").testing;

test "theme_quietlight has correct metadata" {
    try testing.expect(extension.themes.len == 1);
    try testing.expect(extension.capabilities.theme);
    try testing.expect(!extension.themes[0].is_dark);
}
