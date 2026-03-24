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
    const diff_mod = b.createModule(.{
        .root_source_file = b.path("src/base/diff.zig"),
        .target = target,
        .optimize = optimize,
    });
    const glob_mod = b.createModule(.{
        .root_source_file = b.path("src/base/glob.zig"),
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
    const file_picker_mod = b.createModule(.{
        .root_source_file = b.path("src/workbench/file_picker.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "win32", .module = win32_mod },
        },
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
    const file_tree_mod = b.createModule(.{
        .root_source_file = b.path("src/workbench/file_tree.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gl", .module = gl_mod },
            .{ .name = "color", .module = color_mod },
        },
    });
    const file_icons_mod = b.createModule(.{
        .root_source_file = b.path("src/workbench/file_icons.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gl", .module = gl_mod },
            .{ .name = "win32", .module = win32_mod },
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
            .{ .name = "win32", .module = win32_mod },
        },
    });
    const context_menu_mod = b.createModule(.{
        .root_source_file = b.path("src/workbench/context_menu.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "win32", .module = win32_mod },
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
    // Extension system modules
    const extension_mod = b.createModule(.{
        .root_source_file = b.path("src/extension/extension.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "syntax", .module = syntax_mod },
            .{ .name = "color", .module = color_mod },
        },
    });
    const ext_zig_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/zig_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_json_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/json_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_markdown_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/markdown_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_typescript_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/typescript_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_javascript_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/javascript_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_python_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/python_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_c_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/c_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_cpp_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/cpp_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_rust_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/rust_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_go_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/go_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_html_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/html_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_css_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/css_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    // -- HIGH priority language extensions --
    const ext_java_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/java_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_csharp_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/csharp_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_php_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/php_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_ruby_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/ruby_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_shell_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/shell_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_sql_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/sql_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_xml_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/xml_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_yaml_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/yaml_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    // -- MEDIUM priority language extensions --
    const ext_bat_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/bat_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_dart_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/dart_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_diff_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/diff_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_docker_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/docker_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_ini_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/ini_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_less_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/less_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_lua_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/lua_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_make_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/make_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_perl_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/perl_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_powershell_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/powershell_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_r_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/r_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_scss_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/scss_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_swift_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/swift_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    // -- LOW priority language extensions --
    const ext_clojure_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/clojure_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_coffeescript_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/coffeescript_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_dotenv_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/dotenv_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_fsharp_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/fsharp_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_groovy_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/groovy_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_handlebars_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/handlebars_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_hlsl_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/hlsl_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_julia_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/julia_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_latex_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/latex_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_log_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/log_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_objc_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/objc_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_pug_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/pug_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_razor_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/razor_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_rst_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/rst_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_shaderlab_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/shaderlab_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_vb_lang_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/vb_lang.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    // -- Theme extensions --
    const ext_theme_abyss_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/theme_abyss.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "color", .module = color_mod },
        },
    });
    const ext_theme_defaults_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/theme_defaults.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "color", .module = color_mod },
        },
    });
    const ext_theme_kimbie_dark_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/theme_kimbie_dark.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "color", .module = color_mod },
        },
    });
    const ext_theme_monokai_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/theme_monokai.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "color", .module = color_mod },
        },
    });
    const ext_theme_monokai_dimmed_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/theme_monokai_dimmed.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "color", .module = color_mod },
        },
    });
    const ext_theme_quietlight_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/theme_quietlight.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "color", .module = color_mod },
        },
    });
    const ext_theme_red_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/theme_red.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "color", .module = color_mod },
        },
    });
    const ext_theme_seti_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/theme_seti.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "color", .module = color_mod },
        },
    });
    const ext_theme_solarized_dark_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/theme_solarized_dark.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "color", .module = color_mod },
        },
    });
    const ext_theme_solarized_light_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/theme_solarized_light.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "color", .module = color_mod },
        },
    });
    const ext_theme_tomorrow_night_blue_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/theme_tomorrow_night_blue.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "color", .module = color_mod },
        },
    });
    // -- Feature extensions (non-language) --
    const ext_emmet_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/emmet.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_git_ext_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/git_ext.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_merge_conflict_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/merge_conflict.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_references_view_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/references_view.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_search_result_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/search_result.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_npm_ext_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/npm_ext.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_configuration_editing_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/configuration_editing.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_media_preview_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/media_preview.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_markdown_features_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/markdown_features.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_html_features_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/html_features.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    // -- Batch 2 feature extensions --
    const ext_css_features_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/css_features.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_json_features_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/json_features.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_php_features_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/php_features.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_typescript_features_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/typescript_features.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_git_base_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/git_base.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_github_ext_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/github_ext.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_github_auth_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/github_auth.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_microsoft_auth_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/microsoft_auth.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_debug_auto_launch_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/debug_auto_launch.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_debug_server_ready_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/debug_server_ready.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_extension_editing_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/extension_editing.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_grunt_ext_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/grunt_ext.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_gulp_ext_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/gulp_ext.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_jake_ext_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/jake_ext.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_ipynb_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/ipynb.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_markdown_math_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/markdown_math.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "syntax", .module = syntax_mod },
        },
    });
    const ext_notebook_renderers_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/notebook_renderers.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_simple_browser_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/simple_browser.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_terminal_suggest_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/terminal_suggest.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_tunnel_forwarding_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/tunnel_forwarding.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const ext_siro_agent_mod = b.createModule(.{
        .root_source_file = b.path("src/extensions/siro_agent.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
        },
    });
    const manifest_mod = b.createModule(.{
        .root_source_file = b.path("src/extension/manifest.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extension", .module = extension_mod },
            .{ .name = "ext_zig_lang", .module = ext_zig_lang_mod },
            .{ .name = "ext_json_lang", .module = ext_json_lang_mod },
            .{ .name = "ext_markdown_lang", .module = ext_markdown_lang_mod },
            .{ .name = "ext_typescript_lang", .module = ext_typescript_lang_mod },
            .{ .name = "ext_javascript_lang", .module = ext_javascript_lang_mod },
            .{ .name = "ext_python_lang", .module = ext_python_lang_mod },
            .{ .name = "ext_c_lang", .module = ext_c_lang_mod },
            .{ .name = "ext_cpp_lang", .module = ext_cpp_lang_mod },
            .{ .name = "ext_rust_lang", .module = ext_rust_lang_mod },
            .{ .name = "ext_go_lang", .module = ext_go_lang_mod },
            .{ .name = "ext_html_lang", .module = ext_html_lang_mod },
            .{ .name = "ext_css_lang", .module = ext_css_lang_mod },
            .{ .name = "ext_java_lang", .module = ext_java_lang_mod },
            .{ .name = "ext_csharp_lang", .module = ext_csharp_lang_mod },
            .{ .name = "ext_php_lang", .module = ext_php_lang_mod },
            .{ .name = "ext_ruby_lang", .module = ext_ruby_lang_mod },
            .{ .name = "ext_shell_lang", .module = ext_shell_lang_mod },
            .{ .name = "ext_sql_lang", .module = ext_sql_lang_mod },
            .{ .name = "ext_xml_lang", .module = ext_xml_lang_mod },
            .{ .name = "ext_yaml_lang", .module = ext_yaml_lang_mod },
            .{ .name = "ext_bat_lang", .module = ext_bat_lang_mod },
            .{ .name = "ext_dart_lang", .module = ext_dart_lang_mod },
            .{ .name = "ext_diff_lang", .module = ext_diff_lang_mod },
            .{ .name = "ext_docker_lang", .module = ext_docker_lang_mod },
            .{ .name = "ext_ini_lang", .module = ext_ini_lang_mod },
            .{ .name = "ext_less_lang", .module = ext_less_lang_mod },
            .{ .name = "ext_lua_lang", .module = ext_lua_lang_mod },
            .{ .name = "ext_make_lang", .module = ext_make_lang_mod },
            .{ .name = "ext_perl_lang", .module = ext_perl_lang_mod },
            .{ .name = "ext_powershell_lang", .module = ext_powershell_lang_mod },
            .{ .name = "ext_r_lang", .module = ext_r_lang_mod },
            .{ .name = "ext_scss_lang", .module = ext_scss_lang_mod },
            .{ .name = "ext_swift_lang", .module = ext_swift_lang_mod },
            .{ .name = "ext_clojure_lang", .module = ext_clojure_lang_mod },
            .{ .name = "ext_coffeescript_lang", .module = ext_coffeescript_lang_mod },
            .{ .name = "ext_dotenv_lang", .module = ext_dotenv_lang_mod },
            .{ .name = "ext_fsharp_lang", .module = ext_fsharp_lang_mod },
            .{ .name = "ext_groovy_lang", .module = ext_groovy_lang_mod },
            .{ .name = "ext_handlebars_lang", .module = ext_handlebars_lang_mod },
            .{ .name = "ext_hlsl_lang", .module = ext_hlsl_lang_mod },
            .{ .name = "ext_julia_lang", .module = ext_julia_lang_mod },
            .{ .name = "ext_latex_lang", .module = ext_latex_lang_mod },
            .{ .name = "ext_log_lang", .module = ext_log_lang_mod },
            .{ .name = "ext_objc_lang", .module = ext_objc_lang_mod },
            .{ .name = "ext_pug_lang", .module = ext_pug_lang_mod },
            .{ .name = "ext_razor_lang", .module = ext_razor_lang_mod },
            .{ .name = "ext_rst_lang", .module = ext_rst_lang_mod },
            .{ .name = "ext_shaderlab_lang", .module = ext_shaderlab_lang_mod },
            .{ .name = "ext_vb_lang", .module = ext_vb_lang_mod },
            .{ .name = "ext_theme_abyss", .module = ext_theme_abyss_mod },
            .{ .name = "ext_theme_defaults", .module = ext_theme_defaults_mod },
            .{ .name = "ext_theme_kimbie_dark", .module = ext_theme_kimbie_dark_mod },
            .{ .name = "ext_theme_monokai", .module = ext_theme_monokai_mod },
            .{ .name = "ext_theme_monokai_dimmed", .module = ext_theme_monokai_dimmed_mod },
            .{ .name = "ext_theme_quietlight", .module = ext_theme_quietlight_mod },
            .{ .name = "ext_theme_red", .module = ext_theme_red_mod },
            .{ .name = "ext_theme_seti", .module = ext_theme_seti_mod },
            .{ .name = "ext_theme_solarized_dark", .module = ext_theme_solarized_dark_mod },
            .{ .name = "ext_theme_solarized_light", .module = ext_theme_solarized_light_mod },
            .{ .name = "ext_theme_tomorrow_night_blue", .module = ext_theme_tomorrow_night_blue_mod },
            .{ .name = "ext_emmet", .module = ext_emmet_mod },
            .{ .name = "ext_git_ext", .module = ext_git_ext_mod },
            .{ .name = "ext_merge_conflict", .module = ext_merge_conflict_mod },
            .{ .name = "ext_references_view", .module = ext_references_view_mod },
            .{ .name = "ext_search_result", .module = ext_search_result_mod },
            .{ .name = "ext_npm_ext", .module = ext_npm_ext_mod },
            .{ .name = "ext_configuration_editing", .module = ext_configuration_editing_mod },
            .{ .name = "ext_media_preview", .module = ext_media_preview_mod },
            .{ .name = "ext_markdown_features", .module = ext_markdown_features_mod },
            .{ .name = "ext_html_features", .module = ext_html_features_mod },
            .{ .name = "ext_css_features", .module = ext_css_features_mod },
            .{ .name = "ext_json_features", .module = ext_json_features_mod },
            .{ .name = "ext_php_features", .module = ext_php_features_mod },
            .{ .name = "ext_typescript_features", .module = ext_typescript_features_mod },
            .{ .name = "ext_git_base", .module = ext_git_base_mod },
            .{ .name = "ext_github_ext", .module = ext_github_ext_mod },
            .{ .name = "ext_github_auth", .module = ext_github_auth_mod },
            .{ .name = "ext_microsoft_auth", .module = ext_microsoft_auth_mod },
            .{ .name = "ext_debug_auto_launch", .module = ext_debug_auto_launch_mod },
            .{ .name = "ext_debug_server_ready", .module = ext_debug_server_ready_mod },
            .{ .name = "ext_extension_editing", .module = ext_extension_editing_mod },
            .{ .name = "ext_grunt_ext", .module = ext_grunt_ext_mod },
            .{ .name = "ext_gulp_ext", .module = ext_gulp_ext_mod },
            .{ .name = "ext_jake_ext", .module = ext_jake_ext_mod },
            .{ .name = "ext_ipynb", .module = ext_ipynb_mod },
            .{ .name = "ext_markdown_math", .module = ext_markdown_math_mod },
            .{ .name = "ext_notebook_renderers", .module = ext_notebook_renderers_mod },
            .{ .name = "ext_simple_browser", .module = ext_simple_browser_mod },
            .{ .name = "ext_terminal_suggest", .module = ext_terminal_suggest_mod },
            .{ .name = "ext_tunnel_forwarding", .module = ext_tunnel_forwarding_mod },
            .{ .name = "ext_siro_agent", .module = ext_siro_agent_mod },
            .{ .name = "syntax", .module = syntax_mod },
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
            .{ .name = "file_tree", .module = file_tree_mod },
            .{ .name = "file_icons", .module = file_icons_mod },
            .{ .name = "manifest", .module = manifest_mod },
            .{ .name = "extension", .module = extension_mod },
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
            .{ .name = "file_picker", .module = file_picker_mod },
            .{ .name = "buffer", .module = buffer_mod },
            .{ .name = "cursor", .module = cursor_mod },
            .{ .name = "syntax", .module = syntax_mod },
            .{ .name = "viewport", .module = viewport_mod },
            .{ .name = "keybinding", .module = keybinding_mod },
            .{ .name = "color", .module = color_mod },
            .{ .name = "rect", .module = rect_mod },
            .{ .name = "file_service", .module = file_service_mod },
            .{ .name = "status_bar", .module = status_bar_mod },
            .{ .name = "activity_bar", .module = activity_bar_mod },
            .{ .name = "sidebar", .module = sidebar_mod },
            .{ .name = "panel", .module = panel_mod },
            .{ .name = "context_menu", .module = context_menu_mod },
            .{ .name = "win32", .module = win32_mod },
            .{ .name = "file_tree", .module = file_tree_mod },
            .{ .name = "file_icons", .module = file_icons_mod },
            .{ .name = "manifest", .module = manifest_mod },
            .{ .name = "extension", .module = extension_mod },
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
            .{ .name = "workbench", .module = workbench_mod },
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
    exe.linkSystemLibrary("comdlg32");
    exe.linkSystemLibrary("shell32");

    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run SBCode");
    run_step.dependOn(&run_cmd.step);

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
                .{ .name = "file_picker", .module = file_picker_mod },
                .{ .name = "fuzzy_subsequence_prop_test", .module = fuzzy_subsequence_prop_test_mod },
                .{ .name = "fuzzy_monotonicity_prop_test", .module = fuzzy_monotonicity_prop_test_mod },
                .{ .name = "cmdpalette_filter_prop_test", .module = cmdpalette_filter_prop_test_mod },
                .{ .name = "viewport", .module = viewport_mod },
                .{ .name = "tabs", .module = tabs_mod },
                .{ .name = "activity_bar", .module = activity_bar_mod },
                .{ .name = "sidebar", .module = sidebar_mod },
                .{ .name = "file_tree", .module = file_tree_mod },
                .{ .name = "panel", .module = panel_mod },
                .{ .name = "context_menu", .module = context_menu_mod },
                .{ .name = "status_bar", .module = status_bar_mod },
                .{ .name = "workbench", .module = workbench_mod },
                .{ .name = "app", .module = app_mod },
                .{ .name = "diff", .module = diff_mod },
                .{ .name = "glob", .module = glob_mod },
                .{ .name = "extension", .module = extension_mod },
                .{ .name = "ext_zig_lang", .module = ext_zig_lang_mod },
                .{ .name = "ext_json_lang", .module = ext_json_lang_mod },
                .{ .name = "ext_markdown_lang", .module = ext_markdown_lang_mod },
                .{ .name = "ext_typescript_lang", .module = ext_typescript_lang_mod },
                .{ .name = "ext_javascript_lang", .module = ext_javascript_lang_mod },
                .{ .name = "ext_python_lang", .module = ext_python_lang_mod },
                .{ .name = "ext_c_lang", .module = ext_c_lang_mod },
                .{ .name = "ext_cpp_lang", .module = ext_cpp_lang_mod },
                .{ .name = "ext_rust_lang", .module = ext_rust_lang_mod },
                .{ .name = "ext_go_lang", .module = ext_go_lang_mod },
                .{ .name = "ext_html_lang", .module = ext_html_lang_mod },
                .{ .name = "ext_css_lang", .module = ext_css_lang_mod },
                .{ .name = "ext_java_lang", .module = ext_java_lang_mod },
                .{ .name = "ext_csharp_lang", .module = ext_csharp_lang_mod },
                .{ .name = "ext_php_lang", .module = ext_php_lang_mod },
                .{ .name = "ext_ruby_lang", .module = ext_ruby_lang_mod },
                .{ .name = "ext_shell_lang", .module = ext_shell_lang_mod },
                .{ .name = "ext_sql_lang", .module = ext_sql_lang_mod },
                .{ .name = "ext_xml_lang", .module = ext_xml_lang_mod },
                .{ .name = "ext_yaml_lang", .module = ext_yaml_lang_mod },
                .{ .name = "ext_bat_lang", .module = ext_bat_lang_mod },
                .{ .name = "ext_dart_lang", .module = ext_dart_lang_mod },
                .{ .name = "ext_diff_lang", .module = ext_diff_lang_mod },
                .{ .name = "ext_docker_lang", .module = ext_docker_lang_mod },
                .{ .name = "ext_ini_lang", .module = ext_ini_lang_mod },
                .{ .name = "ext_less_lang", .module = ext_less_lang_mod },
                .{ .name = "ext_lua_lang", .module = ext_lua_lang_mod },
                .{ .name = "ext_make_lang", .module = ext_make_lang_mod },
                .{ .name = "ext_perl_lang", .module = ext_perl_lang_mod },
                .{ .name = "ext_powershell_lang", .module = ext_powershell_lang_mod },
                .{ .name = "ext_r_lang", .module = ext_r_lang_mod },
                .{ .name = "ext_scss_lang", .module = ext_scss_lang_mod },
                .{ .name = "ext_swift_lang", .module = ext_swift_lang_mod },
                .{ .name = "ext_clojure_lang", .module = ext_clojure_lang_mod },
                .{ .name = "ext_coffeescript_lang", .module = ext_coffeescript_lang_mod },
                .{ .name = "ext_dotenv_lang", .module = ext_dotenv_lang_mod },
                .{ .name = "ext_fsharp_lang", .module = ext_fsharp_lang_mod },
                .{ .name = "ext_groovy_lang", .module = ext_groovy_lang_mod },
                .{ .name = "ext_handlebars_lang", .module = ext_handlebars_lang_mod },
                .{ .name = "ext_hlsl_lang", .module = ext_hlsl_lang_mod },
                .{ .name = "ext_julia_lang", .module = ext_julia_lang_mod },
                .{ .name = "ext_latex_lang", .module = ext_latex_lang_mod },
                .{ .name = "ext_log_lang", .module = ext_log_lang_mod },
                .{ .name = "ext_objc_lang", .module = ext_objc_lang_mod },
                .{ .name = "ext_pug_lang", .module = ext_pug_lang_mod },
                .{ .name = "ext_razor_lang", .module = ext_razor_lang_mod },
                .{ .name = "ext_rst_lang", .module = ext_rst_lang_mod },
                .{ .name = "ext_shaderlab_lang", .module = ext_shaderlab_lang_mod },
                .{ .name = "ext_vb_lang", .module = ext_vb_lang_mod },
                .{ .name = "ext_theme_abyss", .module = ext_theme_abyss_mod },
                .{ .name = "ext_theme_defaults", .module = ext_theme_defaults_mod },
                .{ .name = "ext_theme_kimbie_dark", .module = ext_theme_kimbie_dark_mod },
                .{ .name = "ext_theme_monokai", .module = ext_theme_monokai_mod },
                .{ .name = "ext_theme_monokai_dimmed", .module = ext_theme_monokai_dimmed_mod },
                .{ .name = "ext_theme_quietlight", .module = ext_theme_quietlight_mod },
                .{ .name = "ext_theme_red", .module = ext_theme_red_mod },
                .{ .name = "ext_theme_seti", .module = ext_theme_seti_mod },
                .{ .name = "ext_theme_solarized_dark", .module = ext_theme_solarized_dark_mod },
                .{ .name = "ext_theme_solarized_light", .module = ext_theme_solarized_light_mod },
                .{ .name = "ext_theme_tomorrow_night_blue", .module = ext_theme_tomorrow_night_blue_mod },
                .{ .name = "ext_emmet", .module = ext_emmet_mod },
                .{ .name = "ext_git_ext", .module = ext_git_ext_mod },
                .{ .name = "ext_merge_conflict", .module = ext_merge_conflict_mod },
                .{ .name = "ext_references_view", .module = ext_references_view_mod },
                .{ .name = "ext_search_result", .module = ext_search_result_mod },
                .{ .name = "ext_npm_ext", .module = ext_npm_ext_mod },
                .{ .name = "ext_configuration_editing", .module = ext_configuration_editing_mod },
                .{ .name = "ext_media_preview", .module = ext_media_preview_mod },
                .{ .name = "ext_markdown_features", .module = ext_markdown_features_mod },
                .{ .name = "ext_html_features", .module = ext_html_features_mod },
                .{ .name = "ext_css_features", .module = ext_css_features_mod },
                .{ .name = "ext_json_features", .module = ext_json_features_mod },
                .{ .name = "ext_php_features", .module = ext_php_features_mod },
                .{ .name = "ext_typescript_features", .module = ext_typescript_features_mod },
                .{ .name = "ext_git_base", .module = ext_git_base_mod },
                .{ .name = "ext_github_ext", .module = ext_github_ext_mod },
                .{ .name = "ext_github_auth", .module = ext_github_auth_mod },
                .{ .name = "ext_microsoft_auth", .module = ext_microsoft_auth_mod },
                .{ .name = "ext_debug_auto_launch", .module = ext_debug_auto_launch_mod },
                .{ .name = "ext_debug_server_ready", .module = ext_debug_server_ready_mod },
                .{ .name = "ext_extension_editing", .module = ext_extension_editing_mod },
                .{ .name = "ext_grunt_ext", .module = ext_grunt_ext_mod },
                .{ .name = "ext_gulp_ext", .module = ext_gulp_ext_mod },
                .{ .name = "ext_jake_ext", .module = ext_jake_ext_mod },
                .{ .name = "ext_ipynb", .module = ext_ipynb_mod },
                .{ .name = "ext_markdown_math", .module = ext_markdown_math_mod },
                .{ .name = "ext_notebook_renderers", .module = ext_notebook_renderers_mod },
                .{ .name = "ext_simple_browser", .module = ext_simple_browser_mod },
                .{ .name = "ext_terminal_suggest", .module = ext_terminal_suggest_mod },
                .{ .name = "ext_tunnel_forwarding", .module = ext_tunnel_forwarding_mod },
                .{ .name = "ext_siro_agent", .module = ext_siro_agent_mod },
                .{ .name = "manifest", .module = manifest_mod },
                .{ .name = "file_icons", .module = file_icons_mod },
            },
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&run_tests.step);
}
