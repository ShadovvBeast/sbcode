// src/extension/extension.zig — SBCode Extension System
//
// Defines the comptime extension interface for SBCode. Extensions are pure Zig
// modules compiled into the binary. Each extension declares its contributions
// (syntax, themes, commands, keybindings, snippets, status items) as comptime
// data, and optionally provides lifecycle hooks (activate/deactivate).
//
// Zero heap allocations — all extension data is comptime const.
//
// ## Writing an Extension
//
// An extension is a Zig file that exports a `pub const extension: Extension`.
// Example:
//
//   pub const extension = Extension{
//       .id = "sbcode.zig-lang",
//       .name = "Zig Language",
//       .version = "0.1.0",
//       .description = "Zig language support: syntax, snippets, commands",
//       .capabilities = .{ .syntax = true, .commands = true, .snippets = true },
//       .syntax = &.{zig_syntax},
//       .commands = &.{format_cmd},
//       .snippets = &.{test_snippet, fn_snippet},
//   };
//
// ## Contribution Points
//
// - syntax:     Language tokenizers with file extension mapping
// - theme:      Color palettes mapping TokenKind → Color
// - commands:   Actions registered in the command palette
// - keybindings: Key combinations bound to command IDs
// - snippets:   Text templates with tab-stop expansion
// - status_items: Persistent items rendered in the status bar
//
// ## Lifecycle
//
// Extensions are activated at workbench init via the manifest. The registry
// iterates all extensions at comptime using `inline for`, so there is zero
// runtime dispatch overhead.

pub const syntax = @import("syntax");
const Color = @import("color").Color;

// =============================================================================
// Capability flags — what an extension contributes
// =============================================================================

pub const Capabilities = packed struct(u16) {
    syntax: bool = false,
    theme: bool = false,
    commands: bool = false,
    keybindings: bool = false,
    snippets: bool = false,
    status_items: bool = false,
    _pad: u10 = 0,
};

// =============================================================================
// Syntax contribution — a language tokenizer + file extension mapping
// =============================================================================

pub const SyntaxContribution = struct {
    /// Language identifier (must match a LanguageId enum value).
    language: syntax.LanguageId,
    /// Display name shown in status bar and command palette.
    display_name: []const u8,
    /// File extensions this language handles (e.g. ".zig", ".zon").
    file_extensions: []const []const u8,
    /// Comment line prefix for toggle-comment (e.g. "//").
    line_comment: []const u8 = "",
    /// Block comment open/close (e.g. "/*", "*/"). Empty = not supported.
    block_comment_open: []const u8 = "",
    block_comment_close: []const u8 = "",
    /// Auto-closing bracket pairs.
    bracket_pairs: []const [2]u8 = &.{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
    },
    /// Tokenizer function pointer. Receives a LineSyntax and line text.
    tokenizer: *const fn (*syntax.LineSyntax, []const u8) void,
};

// =============================================================================
// Theme contribution — a named color palette
// =============================================================================

/// Maps each TokenKind to a color. Extensions can provide full themes.
pub const ThemeColors = struct {
    keyword: Color = Color.rgb(0x56, 0x9C, 0xD6),
    string_literal: Color = Color.rgb(0xCE, 0x91, 0x78),
    comment: Color = Color.rgb(0x6A, 0x99, 0x55),
    number_literal: Color = Color.rgb(0xB5, 0xCE, 0xA8),
    builtin: Color = Color.rgb(0x4E, 0xC9, 0xB0),
    type_name: Color = Color.rgb(0x4E, 0xC9, 0xB0),
    function_name: Color = Color.rgb(0xDC, 0xDC, 0xAA),
    operator: Color = Color.rgb(0xD4, 0xD4, 0xD4),
    punctuation: Color = Color.rgb(0xD4, 0xD4, 0xD4),
    preprocessor: Color = Color.rgb(0xC5, 0x86, 0xC0),
    plain: Color = Color.rgb(0xD4, 0xD4, 0xD4),

    // UI chrome colors
    editor_bg: Color = Color.rgb(0x1E, 0x1E, 0x1E),
    sidebar_bg: Color = Color.rgb(0x25, 0x25, 0x25),
    title_bar_bg: Color = Color.rgb(0x32, 0x32, 0x32),
    status_bar_bg: Color = Color.rgb(0x00, 0x7A, 0xCC),
    activity_bar_bg: Color = Color.rgb(0x33, 0x33, 0x33),
    panel_bg: Color = Color.rgb(0x1E, 0x1E, 0x1E),
    tab_active_bg: Color = Color.rgb(0x1E, 0x1E, 0x1E),
    tab_inactive_bg: Color = Color.rgb(0x2D, 0x2D, 0x2D),
    selection_bg: Color = Color.rgba(0x26, 0x4F, 0x78, 0xCC),
    cursor_color: Color = Color.rgb(0xFF, 0xFF, 0xFF),
};

pub const ThemeContribution = struct {
    /// Theme name shown in settings (e.g. "Dark+", "Monokai").
    name: []const u8,
    /// Whether this is a dark or light theme.
    is_dark: bool = true,
    /// Full color palette.
    colors: ThemeColors = .{},
};

// =============================================================================
// Command contribution — an action in the command palette
// =============================================================================

pub const CommandCategory = enum(u8) {
    file = 0,
    edit = 1,
    selection = 2,
    view = 3,
    go = 4,
    run = 5,
    terminal = 6,
    help = 7,
    editor = 8,
    general = 9,
};

pub const CommandContribution = struct {
    /// Unique command ID (must not collide with other extensions).
    id: u16,
    /// Label shown in command palette (e.g. "Zig: Format File").
    label: []const u8,
    /// Keyboard shortcut display string (e.g. "Ctrl+Shift+I").
    shortcut: []const u8 = "",
    /// Category for grouping in the palette.
    category: CommandCategory = .general,
};

// =============================================================================
// Keybinding contribution
// =============================================================================

pub const KeybindingContribution = struct {
    key_code: u16,
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,
    /// Command ID this keybinding triggers.
    command_id: u16,
};

// =============================================================================
// Snippet contribution
// =============================================================================

pub const SnippetContribution = struct {
    /// Trigger prefix typed by user (e.g. "fn", "test", "for").
    prefix: []const u8,
    /// Display label in completion list.
    label: []const u8,
    /// Description shown alongside the snippet.
    description: []const u8 = "",
    /// Snippet body with $1, $2 tab stops and $0 final cursor.
    /// Lines separated by \n.
    body: []const u8,
    /// Language scope (null = all languages).
    language: ?syntax.LanguageId = null,
};

// =============================================================================
// Status item contribution
// =============================================================================

pub const StatusAlignment = enum(u8) { left, right };

pub const StatusItemContribution = struct {
    /// Unique item ID.
    id: []const u8,
    /// Static label text (can include simple format placeholders).
    label: []const u8,
    /// Alignment in the status bar.
    alignment: StatusAlignment = .left,
    /// Sort priority (lower = further left/right).
    priority: i16 = 0,
    /// Command to execute on click (0 = no action).
    command_id: u16 = 0,
};

// =============================================================================
// Extension — the top-level descriptor
// =============================================================================

pub const Extension = struct {
    // -- Metadata --
    id: []const u8,
    name: []const u8,
    version: []const u8,
    description: []const u8 = "",

    // -- Capability flags --
    capabilities: Capabilities = .{},

    // -- Contribution points (comptime slices, null = no contribution) --
    syntax: []const SyntaxContribution = &.{},
    themes: []const ThemeContribution = &.{},
    commands: []const CommandContribution = &.{},
    keybindings: []const KeybindingContribution = &.{},
    snippets: []const SnippetContribution = &.{},
    status_items: []const StatusItemContribution = &.{},
};

// =============================================================================
// Extension Registry — comptime-resolved, zero runtime cost
// =============================================================================

/// Maximum number of extensions that can be registered.
pub const MAX_EXTENSIONS = 64;

/// Maximum total syntax contributions across all extensions.
pub const MAX_SYNTAX_LANGS = 32;

/// Maximum total snippet contributions across all extensions.
pub const MAX_SNIPPETS = 512;

/// Detect language from a filename by matching file extensions across
/// all registered syntax contributions.
pub fn detectLanguage(comptime extensions: []const Extension, filename: []const u8) syntax.LanguageId {
    // Find the last '.' in the filename
    var dot_pos: ?usize = null;
    var i: usize = filename.len;
    while (i > 0) {
        i -= 1;
        if (filename[i] == '.') {
            dot_pos = i;
            break;
        }
    }
    const ext_str = if (dot_pos) |dp| filename[dp..] else return .plain_text;

    inline for (extensions) |ext| {
        for (ext.syntax) |syn| {
            for (syn.file_extensions) |fe| {
                if (eqlIgnoreCase(ext_str, fe)) return syn.language;
            }
        }
    }
    return .plain_text;
}

/// Look up the tokenizer function for a given LanguageId.
pub fn getTokenizer(comptime extensions: []const Extension, lang: syntax.LanguageId) ?*const fn (*syntax.LineSyntax, []const u8) void {
    inline for (extensions) |ext| {
        for (ext.syntax) |syn| {
            if (syn.language == lang) return syn.tokenizer;
        }
    }
    return null;
}

/// Look up the display name for a LanguageId.
pub fn getLanguageDisplayName(comptime extensions: []const Extension, lang: syntax.LanguageId) []const u8 {
    inline for (extensions) |ext| {
        for (ext.syntax) |syn| {
            if (syn.language == lang) return syn.display_name;
        }
    }
    return "Plain Text";
}

/// Look up the line comment prefix for a LanguageId.
pub fn getLineComment(comptime extensions: []const Extension, lang: syntax.LanguageId) []const u8 {
    inline for (extensions) |ext| {
        for (ext.syntax) |syn| {
            if (syn.language == lang) return syn.line_comment;
        }
    }
    return "";
}

/// Count total extensions.
pub fn extensionCount(comptime extensions: []const Extension) usize {
    return extensions.len;
}

/// Count total syntax contributions.
pub fn syntaxCount(comptime extensions: []const Extension) usize {
    var count: usize = 0;
    for (extensions) |ext| {
        count += ext.syntax.len;
    }
    return count;
}

/// Count total command contributions.
pub fn commandCount(comptime extensions: []const Extension) usize {
    var count: usize = 0;
    for (extensions) |ext| {
        count += ext.commands.len;
    }
    return count;
}

/// Count total snippet contributions.
pub fn snippetCount(comptime extensions: []const Extension) usize {
    var count: usize = 0;
    for (extensions) |ext| {
        count += ext.snippets.len;
    }
    return count;
}

// =============================================================================
// Helpers
// =============================================================================

fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (toLower(ca) != toLower(cb)) return false;
    }
    return true;
}

fn toLower(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

// =============================================================================
// Tests
// =============================================================================

const testing = @import("std").testing;
const expect = testing.expect;

test "Extension struct default initialization" {
    const ext = Extension{
        .id = "test.ext",
        .name = "Test",
        .version = "0.0.1",
    };
    try expect(ext.syntax.len == 0);
    try expect(ext.themes.len == 0);
    try expect(ext.commands.len == 0);
    try expect(ext.keybindings.len == 0);
    try expect(ext.snippets.len == 0);
    try expect(ext.status_items.len == 0);
    try expect(!ext.capabilities.syntax);
    try expect(!ext.capabilities.theme);
}

test "Capabilities packed struct size" {
    try expect(@sizeOf(Capabilities) == 2);
}

test "detectLanguage matches file extension" {
    const dummy_tokenizer = struct {
        fn tok(_: *syntax.LineSyntax, _: []const u8) void {}
    }.tok;
    const exts = [_]Extension{.{
        .id = "test.lang",
        .name = "Test Lang",
        .version = "0.1.0",
        .capabilities = .{ .syntax = true },
        .syntax = &.{.{
            .language = .zig_lang,
            .display_name = "Zig",
            .file_extensions = &.{ ".zig", ".zon" },
            .line_comment = "//",
            .tokenizer = &dummy_tokenizer,
        }},
    }};
    try expect(detectLanguage(&exts, "main.zig") == .zig_lang);
    try expect(detectLanguage(&exts, "build.zon") == .zig_lang);
    try expect(detectLanguage(&exts, "readme.md") == .plain_text);
    try expect(detectLanguage(&exts, "noext") == .plain_text);
}

test "detectLanguage case insensitive" {
    const dummy_tokenizer = struct {
        fn tok(_: *syntax.LineSyntax, _: []const u8) void {}
    }.tok;
    const exts = [_]Extension{.{
        .id = "test.json",
        .name = "JSON",
        .version = "0.1.0",
        .syntax = &.{.{
            .language = .json_lang,
            .display_name = "JSON",
            .file_extensions = &.{".json"},
            .tokenizer = &dummy_tokenizer,
        }},
    }};
    try expect(detectLanguage(&exts, "config.JSON") == .json_lang);
    try expect(detectLanguage(&exts, "config.Json") == .json_lang);
}

test "getTokenizer returns correct function" {
    const dummy_tokenizer = struct {
        fn tok(_: *syntax.LineSyntax, _: []const u8) void {}
    }.tok;
    const exts = [_]Extension{.{
        .id = "test",
        .name = "Test",
        .version = "0.1.0",
        .syntax = &.{.{
            .language = .zig_lang,
            .display_name = "Zig",
            .file_extensions = &.{".zig"},
            .tokenizer = &dummy_tokenizer,
        }},
    }};
    try expect(getTokenizer(&exts, .zig_lang) != null);
    try expect(getTokenizer(&exts, .python) == null);
}

test "getLanguageDisplayName returns name" {
    const dummy_tokenizer = struct {
        fn tok(_: *syntax.LineSyntax, _: []const u8) void {}
    }.tok;
    const exts = [_]Extension{.{
        .id = "test",
        .name = "Test",
        .version = "0.1.0",
        .syntax = &.{.{
            .language = .zig_lang,
            .display_name = "Zig",
            .file_extensions = &.{".zig"},
            .tokenizer = &dummy_tokenizer,
        }},
    }};
    try expect(eqlSlice(getLanguageDisplayName(&exts, .zig_lang), "Zig"));
    try expect(eqlSlice(getLanguageDisplayName(&exts, .python), "Plain Text"));
}

fn eqlSlice(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

test "extensionCount and syntaxCount" {
    const dummy_tokenizer = struct {
        fn tok(_: *syntax.LineSyntax, _: []const u8) void {}
    }.tok;
    const exts = [_]Extension{
        .{
            .id = "a",
            .name = "A",
            .version = "0.1.0",
            .syntax = &.{
                .{ .language = .zig_lang, .display_name = "Zig", .file_extensions = &.{".zig"}, .tokenizer = &dummy_tokenizer },
                .{ .language = .json_lang, .display_name = "JSON", .file_extensions = &.{".json"}, .tokenizer = &dummy_tokenizer },
            },
        },
        .{
            .id = "b",
            .name = "B",
            .version = "0.1.0",
            .syntax = &.{
                .{ .language = .python, .display_name = "Python", .file_extensions = &.{".py"}, .tokenizer = &dummy_tokenizer },
            },
        },
    };
    try expect(extensionCount(&exts) == 2);
    try expect(syntaxCount(&exts) == 3);
}
