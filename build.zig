const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
    });

    // Shared module definitions — used by both exe and test step
    const win32_mod = b.createModule(.{
        .root_source_file = b.path("src/platform/win32.zig"),
        .target = target,
        .optimize = optimize,
    });
    const gl_mod = b.createModule(.{
        .root_source_file = b.path("src/platform/gl.zig"),
        .target = target,
        .optimize = optimize,
    });
    const ring_buffer_mod = b.createModule(.{
        .root_source_file = b.path("src/base/ring_buffer.zig"),
        .target = target,
        .optimize = optimize,
    });
    const fixed_list_mod = b.createModule(.{
        .root_source_file = b.path("src/base/fixed_list.zig"),
        .target = target,
        .optimize = optimize,
    });
    const strings_mod = b.createModule(.{
        .root_source_file = b.path("src/base/strings.zig"),
        .target = target,
        .optimize = optimize,
    });
    const event_mod = b.createModule(.{
        .root_source_file = b.path("src/base/event.zig"),
        .target = target,
        .optimize = optimize,
    });
    const rect_mod = b.createModule(.{
        .root_source_file = b.path("src/base/rect.zig"),
        .target = target,
        .optimize = optimize,
    });
    const color_mod = b.createModule(.{
        .root_source_file = b.path("src/base/color.zig"),
        .target = target,
        .optimize = optimize,
    });
    const uri_mod = b.createModule(.{
        .root_source_file = b.path("src/base/uri.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "strings", .module = strings_mod },
        },
    });
    const json_mod = b.createModule(.{
        .root_source_file = b.path("src/base/json.zig"),
        .target = target,
        .optimize = optimize,
    });
    const ring_buffer_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/ring_buffer_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "ring_buffer", .module = ring_buffer_mod },
        },
    });
    const fixed_list_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/fixed_list_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "fixed_list", .module = fixed_list_mod },
        },
    });
    const strings_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/strings_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "strings", .module = strings_mod },
        },
    });
    const event_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/event_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "event", .module = event_mod },
        },
    });
    const json_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/json_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "json", .module = json_mod },
        },
    });
    const json_keypath_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/json_keypath_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "json", .module = json_mod },
        },
    });
    const buffer_mod = b.createModule(.{
        .root_source_file = b.path("src/editor/buffer.zig"),
        .target = target,
        .optimize = optimize,
    });
    const cursor_mod = b.createModule(.{
        .root_source_file = b.path("src/editor/cursor.zig"),
        .target = target,
        .optimize = optimize,
    });
    const buffer_line_index_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/buffer_line_index_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "buffer", .module = buffer_mod },
        },
    });
    const buffer_insert_delete_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/buffer_insert_delete_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "buffer", .module = buffer_mod },
        },
    });
    const buffer_getline_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/buffer_getline_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "buffer", .module = buffer_mod },
        },
    });
    const selection_geometry_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/selection_geometry_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "cursor", .module = cursor_mod },
        },
    });
    const syntax_mod = b.createModule(.{
        .root_source_file = b.path("src/editor/syntax.zig"),
        .target = target,
        .optimize = optimize,
    });
    const syntax_token_coverage_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/syntax_token_coverage_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const file_service_mod = b.createModule(.{
        .root_source_file = b.path("src/platform/file_service.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "win32", .module = win32_mod },
        },
    });
    const config_mod = b.createModule(.{
        .root_source_file = b.path("src/platform/config.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "json", .module = json_mod },
            .{ .name = "file_service", .module = file_service_mod },
            .{ .name = "win32", .module = win32_mod },
            .{ .name = "strings", .module = strings_mod },
        },
    });
    const http_mod = b.createModule(.{
        .root_source_file = b.path("src/platform/http.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "win32", .module = win32_mod },
        },
    });
    const input_mod = b.createModule(.{
        .root_source_file = b.path("src/platform/input.zig"),
        .target = target,
        .optimize = optimize,
    });
    const input_frame_reset_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/input_frame_reset_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "input", .module = input_mod },
        },
    });
    const keybinding_mod = b.createModule(.{
        .root_source_file = b.path("src/platform/keybinding.zig"),
        .target = target,
        .optimize = optimize,
    });
    const font_atlas_mod = b.createModule(.{
        .root_source_file = b.path("src/renderer/font_atlas.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "win32", .module = win32_mod },
            .{ .name = "gl", .module = gl_mod },
            .{ .name = "color", .module = color_mod },
        },
    });
    const layout_mod = b.createModule(.{
        .root_source_file = b.path("src/workbench/layout.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "rect", .module = rect_mod },
        },
    });
    const layout_nonoverlap_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/layout_nonoverlap_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "layout", .module = layout_mod },
            .{ .name = "rect", .module = rect_mod },
        },
    });
    const layout_hittest_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/layout_hittest_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "layout", .module = layout_mod },
            .{ .name = "rect", .module = rect_mod },
        },
    });
    const command_palette_mod = b.createModule(.{
        .root_source_file = b.path("src/workbench/command_palette.zig"),
        .target = target,
        .optimize = optimize,
    });
    const fuzzy_subsequence_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/fuzzy_subsequence_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "command_palette", .module = command_palette_mod },
        },
    });
    const fuzzy_monotonicity_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/fuzzy_monotonicity_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "command_palette", .module = command_palette_mod },
        },
    });
    const cmdpalette_filter_prop_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests/cmdpalette_filter_prop_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "command_palette", .module = command_palette_mod },
        },
    });
    const viewport_mod = b.createModule(.{
        .root_source_file = b.path("src/editor/viewport.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gl", .module = gl_mod },
            .{ .name = "font_atlas", .module = font_atlas_mod },
            .{ .name = "syntax", .module = syntax_mod },
            .{ .name = "buffer", .module = buffer_mod },
            .{ .name = "cursor", .module = cursor_mod },
            .{ .name = "color", .module = color_mod },
            .{ .name = "rect", .module = rect_mod },
        },
    });
    const tabs_mod = b.createModule(.{
        .root_source_file = b.path("src/editor/tabs.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gl", .module = gl_mod },
            .{ .name = "font_atlas", .module = font_atlas_mod },
            .{ .name = "color", .module = color_mod },
            .{ .name = "rect", .module = rect_mod },
        },
    });
    const activity_bar_mod = b.createModule(.{
        .root_source_file = b.path("src/workbench/activity_bar.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gl", .module = gl_mod },
            .{ .name = "font_atlas", .module = font_atlas_mod },
            .{ .name = "color", .module = color_mod },
            .{ .name = "rect", .module = rect_mod },
        },
    });
    const sidebar_mod = b.createModule(.{
        .root_source_file = b.path("src/workbench/sidebar.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gl", .module = gl_mod },
            .{ .name = "font_atlas", .module = font_atlas_mod },
            .{ .name = "color", .module = color_mod },
            .{ .name = "rect", .module = rect_mod },
        },
    });
    const panel_mod = b.createModule(.{
        .root_source_file = b.path("src/workbench/panel.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gl", .module = gl_mod },
            .{ .name = "font_atlas", .module = font_atlas_mod },
            .{ .name = "color", .module = color_mod },
            .{ .name = "rect", .module = rect_mod },
        },
    });
    const status_bar_mod = b.createModule(.{
        .root_source_file = b.path("src/workbench/status_bar.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gl", .module = gl_mod },
            .{ .name = "font_atlas", .module = font_atlas_mod },
            .{ .name = "color", .module = color_mod },
            .{ .name = "rect", .module = rect_mod },
        },
    });
    const workbench_mod = b.createModule(.{
        .root_source_file = b.path("src/workbench/workbench.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gl", .module = gl_mod },
            .{ .name = "layout", .module = layout_mod },
            .{ .name = "font_atlas", .module = font_atlas_mod },
            .{ .name = "input", .module = input_mod },
            .{ .name = "command_palette", .module = command_palette_mod },
            .{ .name = "buffer", .module = buffer_mod },
            .{ .name = "cursor", .module = cursor_mod },
            .{ .name = "syntax", .module = syntax_mod },
            .{ .name = "viewport", .module = viewport_mod },
            .{ .name = "keybinding", .module = keybinding_mod },
            .{ .name = "color", .module = color_mod },
            .{ .name = "rect", .module = rect_mod },
            .{ .name = "file_service", .module = file_service_mod },
            .{ .name = "status_bar", .module = status_bar_mod },
            .{ .name = "win32", .module = win32_mod },
        },
    });
    const app_mod = b.createModule(.{
        .root_source_file = b.path("src/app.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "win32", .module = win32_mod },
            .{ .name = "gl", .module = gl_mod },
            .{ .name = "font_atlas", .module = font_atlas_mod },
            .{ .name = "layout", .module = layout_mod },
            .{ .name = "input", .module = input_mod },
            .{ .name = "color", .module = color_mod },
            .{ .name = "rect", .module = rect_mod },
        },
    });
    // Main executable — imports win32 and app so main.zig can use them
    const exe = b.addExecutable(.{
        .name = "sbcode",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = false,
            .imports = &.{
                .{ .name = "win32", .module = win32_mod },
                .{ .name = "app", .module = app_mod },
            },
        }),
    });

    exe.subsystem = .Windows;

    // Embed application icon resource
    exe.addWin32ResourceFile(.{ .file = b.path("src/sbcode.rc") });

    // Link system libraries
    exe.linkSystemLibrary("opengl32");
    exe.linkSystemLibrary("gdi32");
    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("kernel32");
    exe.linkSystemLibrary("winhttp");
    exe.linkSystemLibrary("bcrypt");

    b.installArtifact(exe);

    // Test step
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "win32", .module = win32_mod },
                .{ .name = "gl", .module = gl_mod },
                .{ .name = "ring_buffer", .module = ring_buffer_mod },
                .{ .name = "ring_buffer_prop_test", .module = ring_buffer_prop_test_mod },
                .{ .name = "fixed_list", .module = fixed_list_mod },
                .{ .name = "fixed_list_prop_test", .module = fixed_list_prop_test_mod },
                .{ .name = "strings", .module = strings_mod },
                .{ .name = "strings_prop_test", .module = strings_prop_test_mod },
                .{ .name = "event", .module = event_mod },
                .{ .name = "event_prop_test", .module = event_prop_test_mod },
                .{ .name = "json_prop_test", .module = json_prop_test_mod },
                .{ .name = "json_keypath_prop_test", .module = json_keypath_prop_test_mod },
                .{ .name = "rect", .module = rect_mod },
                .{ .name = "color", .module = color_mod },
                .{ .name = "uri", .module = uri_mod },
                .{ .name = "json", .module = json_mod },
                .{ .name = "buffer", .module = buffer_mod },
                .{ .name = "buffer_line_index_prop_test", .module = buffer_line_index_prop_test_mod },
                .{ .name = "buffer_insert_delete_prop_test", .module = buffer_insert_delete_prop_test_mod },
                .{ .name = "buffer_getline_prop_test", .module = buffer_getline_prop_test_mod },
                .{ .name = "cursor", .module = cursor_mod },
                .{ .name = "selection_geometry_prop_test", .module = selection_geometry_prop_test_mod },
                .{ .name = "syntax", .module = syntax_mod },
                .{ .name = "syntax_token_coverage_prop_test", .module = syntax_token_coverage_prop_test_mod },
                .{ .name = "file_service", .module = file_service_mod },
                .{ .name = "config", .module = config_mod },
                .{ .name = "http", .module = http_mod },
                .{ .name = "input", .module = input_mod },
                .{ .name = "input_frame_reset_prop_test", .module = input_frame_reset_prop_test_mod },
                .{ .name = "keybinding", .module = keybinding_mod },
                .{ .name = "font_atlas", .module = font_atlas_mod },
                .{ .name = "layout", .module = layout_mod },
                .{ .name = "layout_nonoverlap_prop_test", .module = layout_nonoverlap_prop_test_mod },
                .{ .name = "layout_hittest_prop_test", .module = layout_hittest_prop_test_mod },
                .{ .name = "command_palette", .module = command_palette_mod },
                .{ .name = "fuzzy_subsequence_prop_test", .module = fuzzy_subsequence_prop_test_mod },
                .{ .name = "fuzzy_monotonicity_prop_test", .module = fuzzy_monotonicity_prop_test_mod },
                .{ .name = "cmdpalette_filter_prop_test", .module = cmdpalette_filter_prop_test_mod },
                .{ .name = "viewport", .module = viewport_mod },
                .{ .name = "tabs", .module = tabs_mod },
                .{ .name = "activity_bar", .module = activity_bar_mod },
                .{ .name = "sidebar", .module = sidebar_mod },
                .{ .name = "panel", .module = panel_mod },
                .{ .name = "status_bar", .module = status_bar_mod },
                .{ .name = "workbench", .module = workbench_mod },
                .{ .name = "app", .module = app_mod },
            },
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&run_tests.step);
}
