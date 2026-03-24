// src/extensions/theme_seti.zig — Seti Theme Extension
//
// A dark theme inspired by the Seti UI icon theme colors.

const ext = @import("extension");
const Color = @import("color").Color;

pub const extension = ext.Extension{
    .id = "sbcode.theme-seti",
    .name = "Seti",
    .version = "0.1.0",
    .description = "Seti color theme",
    .capabilities = .{ .theme = true },
    .themes = &.{.{
        .name = "Seti",
        .is_dark = true,
        .colors = .{
            .keyword = Color.rgb(0xE6, 0xCD, 0x69),
            .string_literal = Color.rgb(0x55, 0xB5, 0xDB),
            .comment = Color.rgb(0x41, 0x53, 0x5B),
            .number_literal = Color.rgb(0xCD, 0x3F, 0x45),
            .builtin = Color.rgb(0x55, 0xB5, 0xDB),
            .type_name = Color.rgb(0x9F, 0xCA, 0x56),
            .function_name = Color.rgb(0xA0, 0x74, 0xC4),
            .operator = Color.rgb(0xCC, 0xCC, 0xCC),
            .punctuation = Color.rgb(0xCC, 0xCC, 0xCC),
            .preprocessor = Color.rgb(0xE6, 0xCD, 0x69),
            .plain = Color.rgb(0xCC, 0xCC, 0xCC),
            .editor_bg = Color.rgb(0x15, 0x1E, 0x21),
            .sidebar_bg = Color.rgb(0x0E, 0x16, 0x18),
            .title_bar_bg = Color.rgb(0x0E, 0x16, 0x18),
            .status_bar_bg = Color.rgb(0x0E, 0x16, 0x18),
            .activity_bar_bg = Color.rgb(0x0E, 0x16, 0x18),
            .panel_bg = Color.rgb(0x15, 0x1E, 0x21),
            .tab_active_bg = Color.rgb(0x15, 0x1E, 0x21),
            .tab_inactive_bg = Color.rgb(0x0E, 0x16, 0x18),
            .selection_bg = Color.rgba(0x26, 0x4F, 0x78, 0xCC),
            .cursor_color = Color.rgb(0xFF, 0xFF, 0xFF),
        },
    }},
};

const testing = @import("std").testing;

test "theme_seti has correct metadata" {
    try testing.expect(extension.themes.len == 1);
    try testing.expect(extension.capabilities.theme);
}
