// src/extensions/theme_tomorrow_night_blue.zig — Tomorrow Night Blue Theme
//
// A dark blue theme from the Tomorrow family.

const ext = @import("extension");
const Color = @import("color").Color;

pub const extension = ext.Extension{
    .id = "sbcode.theme-tomorrow-night-blue",
    .name = "Tomorrow Night Blue",
    .version = "0.1.0",
    .description = "Tomorrow Night Blue color theme",
    .capabilities = .{ .theme = true },
    .themes = &.{.{
        .name = "Tomorrow Night Blue",
        .is_dark = true,
        .colors = .{
            .keyword = Color.rgb(0xEB, 0xBF, 0x83),
            .string_literal = Color.rgb(0xD1, 0xF1, 0xA9),
            .comment = Color.rgb(0x7B, 0x83, 0x9E),
            .number_literal = Color.rgb(0xFF, 0xC5, 0x8F),
            .builtin = Color.rgb(0xFF, 0xC5, 0x8F),
            .type_name = Color.rgb(0xFF, 0xC5, 0x8F),
            .function_name = Color.rgb(0xBB, 0xDA, 0xFF),
            .operator = Color.rgb(0xFF, 0xFF, 0xFF),
            .punctuation = Color.rgb(0xFF, 0xFF, 0xFF),
            .preprocessor = Color.rgb(0xEB, 0xBF, 0x83),
            .plain = Color.rgb(0xFF, 0xFF, 0xFF),
            .editor_bg = Color.rgb(0x00, 0x2A, 0x51),
            .sidebar_bg = Color.rgb(0x00, 0x1F, 0x3E),
            .title_bar_bg = Color.rgb(0x00, 0x1F, 0x3E),
            .status_bar_bg = Color.rgb(0x00, 0x1F, 0x3E),
            .activity_bar_bg = Color.rgb(0x00, 0x1F, 0x3E),
            .panel_bg = Color.rgb(0x00, 0x2A, 0x51),
            .tab_active_bg = Color.rgb(0x00, 0x2A, 0x51),
            .tab_inactive_bg = Color.rgb(0x00, 0x1F, 0x3E),
            .selection_bg = Color.rgba(0x00, 0x4D, 0x99, 0xCC),
            .cursor_color = Color.rgb(0xFF, 0xFF, 0xFF),
        },
    }},
};

const testing = @import("std").testing;

test "theme_tomorrow_night_blue has correct metadata" {
    try testing.expect(extension.themes.len == 1);
    try testing.expect(extension.capabilities.theme);
}
