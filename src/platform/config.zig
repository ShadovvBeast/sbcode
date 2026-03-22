// src/platform/config.zig — Application configuration with fallback defaults
//
// Reads config.json via FileService + JsonParser. Falls back to compiled
// defaults if the file is missing or unparseable. Zero allocations — all
// storage is stack/comptime.

const json = @import("json");
const file_service = @import("file_service");
const strings = @import("strings");
const win32 = @import("win32");

pub const MAX_THEME_LEN = 64;
pub const MAX_FONT_NAME_LEN = 64;

pub const Config = struct {
    font_size: i32 = 16,
    tab_size: u8 = 4,
    word_wrap: bool = false,
    line_numbers: bool = true,
    minimap_enabled: bool = true,
    sidebar_visible: bool = true,
    panel_visible: bool = true,
    theme: [MAX_THEME_LEN]u8 = paddedDefault("dark", MAX_THEME_LEN),
    theme_len: usize = 4,
    font_name: [MAX_FONT_NAME_LEN]u8 = paddedDefault("Consolas", MAX_FONT_NAME_LEN),
    font_name_len: usize = 8,

    /// Return a Config with all compiled defaults.
    pub fn defaults() Config {
        return Config{};
    }

    /// Parse a JSON source string and extract config values.
    /// Falls back to defaults for any missing or invalid fields.
    /// This is testable without Win32 file I/O.
    pub fn parseFromJson(source: []const u8) Config {
        var cfg = Config.defaults();
        var parser = json.JsonParser{};

        if (!parser.parse(source)) return cfg;

        // font_size
        if (parser.getNumber("font_size")) |v| {
            const iv = floatToI32(v);
            if (iv > 0 and iv <= 200) cfg.font_size = iv;
        }

        // tab_size
        if (parser.getNumber("tab_size")) |v| {
            const iv = floatToI32(v);
            if (iv > 0 and iv <= 32) cfg.tab_size = @intCast(@as(u32, @intCast(iv)));
        }

        // word_wrap
        if (parser.getBool("word_wrap")) |v| cfg.word_wrap = v;

        // line_numbers
        if (parser.getBool("line_numbers")) |v| cfg.line_numbers = v;

        // minimap_enabled
        if (parser.getBool("minimap_enabled")) |v| cfg.minimap_enabled = v;

        // sidebar_visible
        if (parser.getBool("sidebar_visible")) |v| cfg.sidebar_visible = v;

        // panel_visible
        if (parser.getBool("panel_visible")) |v| cfg.panel_visible = v;

        // theme
        if (parser.getString("theme")) |v| {
            if (v.len > 0 and v.len <= MAX_THEME_LEN) {
                @memcpy(cfg.theme[0..v.len], v);
                // Zero remaining bytes
                for (cfg.theme[v.len..]) |*b| b.* = 0;
                cfg.theme_len = v.len;
            }
        }

        // font_name
        if (parser.getString("font_name")) |v| {
            if (v.len > 0 and v.len <= MAX_FONT_NAME_LEN) {
                @memcpy(cfg.font_name[0..v.len], v);
                for (cfg.font_name[v.len..]) |*b| b.* = 0;
                cfg.font_name_len = v.len;
            }
        }

        return cfg;
    }

    /// Attempt to load config.json from disk via FileService, parse it,
    /// and return the resulting Config. Falls back to defaults() if the
    /// file is missing or unparseable.
    pub fn load() Config {
        var buf: [file_service.MAX_FILE_SIZE]u8 = undefined;
        const path = win32.L("config.json");
        const result = file_service.readFile(path, &buf);

        if (!result.success or result.bytes_read == 0) {
            return Config.defaults();
        }

        return Config.parseFromJson(buf[0..result.bytes_read]);
    }

    /// Get theme as a slice.
    pub fn themeSlice(self: *const Config) []const u8 {
        return self.theme[0..self.theme_len];
    }

    /// Get font_name as a slice.
    pub fn fontNameSlice(self: *const Config) []const u8 {
        return self.font_name[0..self.font_name_len];
    }
};

fn paddedDefault(comptime s: []const u8, comptime len: usize) [len]u8 {
    var buf: [len]u8 = [_]u8{0} ** len;
    for (s, 0..) |c, i| {
        buf[i] = c;
    }
    return buf;
}

fn floatToI32(v: f64) i32 {
    if (v < -2147483648.0 or v > 2147483647.0) return 0;
    return @intFromFloat(v);
}

// =============================================================================
// Tests
// =============================================================================

const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;

test "Config.defaults returns correct default values" {
    const cfg = Config.defaults();
    try expect(cfg.font_size == 16);
    try expect(cfg.tab_size == 4);
    try expect(cfg.word_wrap == false);
    try expect(cfg.line_numbers == true);
    try expect(cfg.minimap_enabled == true);
    try expect(cfg.sidebar_visible == true);
    try expect(cfg.panel_visible == true);
    try expect(mem.eql(u8, cfg.themeSlice(), "dark"));
    try expect(mem.eql(u8, cfg.fontNameSlice(), "Consolas"));
}

test "Config.parseFromJson with valid full JSON" {
    const source =
        \\{"font_size":20,"tab_size":2,"word_wrap":true,"line_numbers":false,"minimap_enabled":false,"sidebar_visible":false,"panel_visible":false,"theme":"light","font_name":"Fira Code"}
    ;
    const cfg = Config.parseFromJson(source);
    try expect(cfg.font_size == 20);
    try expect(cfg.tab_size == 2);
    try expect(cfg.word_wrap == true);
    try expect(cfg.line_numbers == false);
    try expect(cfg.minimap_enabled == false);
    try expect(cfg.sidebar_visible == false);
    try expect(cfg.panel_visible == false);
    try expect(mem.eql(u8, cfg.themeSlice(), "light"));
    try expect(mem.eql(u8, cfg.fontNameSlice(), "Fira Code"));
}

test "Config.parseFromJson with partial JSON uses defaults for missing fields" {
    const source =
        \\{"font_size":24,"theme":"monokai"}
    ;
    const cfg = Config.parseFromJson(source);
    try expect(cfg.font_size == 24);
    try expect(cfg.tab_size == 4); // default
    try expect(cfg.word_wrap == false); // default
    try expect(cfg.line_numbers == true); // default
    try expect(mem.eql(u8, cfg.themeSlice(), "monokai"));
    try expect(mem.eql(u8, cfg.fontNameSlice(), "Consolas")); // default
}

test "Config.parseFromJson with invalid JSON falls back to defaults" {
    const cfg = Config.parseFromJson("{invalid json");
    try expect(cfg.font_size == 16);
    try expect(cfg.tab_size == 4);
    try expect(cfg.word_wrap == false);
    try expect(mem.eql(u8, cfg.themeSlice(), "dark"));
}

test "Config.parseFromJson with empty string falls back to defaults" {
    const cfg = Config.parseFromJson("");
    try expect(cfg.font_size == 16);
    try expect(cfg.tab_size == 4);
}

test "Config.parseFromJson with empty object uses all defaults" {
    const cfg = Config.parseFromJson("{}");
    try expect(cfg.font_size == 16);
    try expect(cfg.tab_size == 4);
    try expect(cfg.word_wrap == false);
    try expect(cfg.line_numbers == true);
    try expect(cfg.minimap_enabled == true);
    try expect(cfg.sidebar_visible == true);
    try expect(cfg.panel_visible == true);
    try expect(mem.eql(u8, cfg.themeSlice(), "dark"));
    try expect(mem.eql(u8, cfg.fontNameSlice(), "Consolas"));
}

test "Config.parseFromJson ignores out-of-range font_size" {
    const cfg = Config.parseFromJson("{\"font_size\":-5}");
    try expect(cfg.font_size == 16); // default, -5 is invalid

    const cfg2 = Config.parseFromJson("{\"font_size\":999}");
    try expect(cfg2.font_size == 16); // default, 999 > 200
}

test "Config.parseFromJson ignores out-of-range tab_size" {
    const cfg = Config.parseFromJson("{\"tab_size\":0}");
    try expect(cfg.tab_size == 4); // default

    const cfg2 = Config.parseFromJson("{\"tab_size\":99}");
    try expect(cfg2.tab_size == 4); // default
}
