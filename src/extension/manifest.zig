// src/extension/manifest.zig — Comptime extension manifest
//
// Central registry of all compiled-in extensions. The workbench uses this
// to activate extensions at init time. Adding a new extension requires:
//
//   1. Create src/extensions/my_ext.zig exporting `pub const extension`
//   2. Add the module to build.zig with b.createModule
//   3. Add an @import line below and append to `extensions`
//   4. Add the module as an import to manifest_mod in build.zig
//
// All resolution happens at comptime — zero runtime cost.

const ext = @import("extension");

// -- Import all extension modules --
const zig_lang = @import("ext_zig_lang");
const json_lang = @import("ext_json_lang");

/// Master list of all compiled-in extensions.
pub const extensions = [_]ext.Extension{
    zig_lang.extension,
    json_lang.extension,
};

/// Total number of extensions.
pub const count = extensions.len;

/// Detect language from filename using all registered syntax contributions.
pub fn detectLanguage(filename: []const u8) ext.syntax.LanguageId {
    return ext.detectLanguage(&extensions, filename);
}

/// Get tokenizer for a language.
pub fn getTokenizer(lang: ext.syntax.LanguageId) ?*const fn (*ext.syntax.LineSyntax, []const u8) void {
    return ext.getTokenizer(&extensions, lang);
}

/// Get display name for a language.
pub fn getLanguageDisplayName(lang: ext.syntax.LanguageId) []const u8 {
    return ext.getLanguageDisplayName(&extensions, lang);
}

/// Get line comment prefix for a language.
pub fn getLineComment(lang: ext.syntax.LanguageId) []const u8 {
    return ext.getLineComment(&extensions, lang);
}

// =============================================================================
// Tests
// =============================================================================

const testing = @import("std").testing;
const expect = testing.expect;

test "manifest has extensions registered" {
    try expect(count >= 2);
}

test "manifest detectLanguage routes to zig extension" {
    try expect(detectLanguage("main.zig") == .zig_lang);
    try expect(detectLanguage("build.zon") == .zig_lang);
}

test "manifest detectLanguage routes to json extension" {
    try expect(detectLanguage("config.json") == .json_lang);
    try expect(detectLanguage("package.json") == .json_lang);
}

test "manifest detectLanguage returns plain_text for unknown" {
    try expect(detectLanguage("readme.txt") == .plain_text);
    try expect(detectLanguage("Makefile") == .plain_text);
}

test "manifest getTokenizer returns non-null for registered languages" {
    try expect(getTokenizer(.zig_lang) != null);
    try expect(getTokenizer(.json_lang) != null);
}

test "manifest getTokenizer returns null for unregistered languages" {
    try expect(getTokenizer(.python) == null);
    try expect(getTokenizer(.rust_lang) == null);
}

test "manifest getLanguageDisplayName" {
    const zig_name = getLanguageDisplayName(.zig_lang);
    try expect(zig_name.len > 0);
    const json_name = getLanguageDisplayName(.json_lang);
    try expect(json_name.len > 0);
}
