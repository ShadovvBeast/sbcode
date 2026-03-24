// src/workbench/file_icons.zig — System file icon cache
//
// Uses Win32 SHGetFileInfoW to retrieve OS-registered icons for file extensions,
// rasterizes them into GL textures via GDI DIB section, and caches by extension.
// Zero heap allocations — fixed-capacity cache with comptime-sized storage.

const gl = @import("gl");
const win32 = @import("win32");

// =============================================================================
// Constants
// =============================================================================

/// Maximum number of cached icon textures (one per unique extension).
pub const MAX_CACHED_ICONS: usize = 64;

/// Maximum extension length (including the dot), e.g. ".zig" = 4.
pub const MAX_EXT_LEN: usize = 16;

/// Icon rasterization size in pixels.
const ICON_SZ: i32 = 32;

// =============================================================================
// Icon cache entry
// =============================================================================

pub const IconCacheEntry = struct {
    ext: [MAX_EXT_LEN]u8 = undefined,
    ext_len: u8 = 0,
    texture_id: gl.GLuint = 0,
};

// =============================================================================
// FileIconCache
// =============================================================================

pub const FileIconCache = struct {
    entries: [MAX_CACHED_ICONS]IconCacheEntry = [_]IconCacheEntry{.{}} ** MAX_CACHED_ICONS,
    count: u8 = 0,

    /// Default folder icon texture (retrieved once for directories).
    folder_texture_id: gl.GLuint = 0,

    /// Default file icon texture (fallback for unknown extensions).
    default_file_texture_id: gl.GLuint = 0,

    /// Initialize the cache by loading the default folder and file icons.
    pub fn init(self: *FileIconCache) void {
        self.folder_texture_id = getSystemFolderIcon();
        self.default_file_texture_id = getSystemFileIcon(".*");
    }

    /// Look up or load the GL texture ID for a given filename.
    /// Returns the cached texture, or loads it from the system on first access.
    /// Falls back to default_file_texture_id if loading fails.
    pub fn getIconForFile(self: *FileIconCache, name: []const u8) gl.GLuint {
        const ext = extractExtension(name);
        if (ext.len == 0) return self.default_file_texture_id;

        // Search cache
        var i: u8 = 0;
        while (i < self.count) : (i += 1) {
            const e = &self.entries[i];
            if (e.ext_len == ext.len and eqlBytes(e.ext[0..e.ext_len], ext)) {
                return if (e.texture_id != 0) e.texture_id else self.default_file_texture_id;
            }
        }

        // Cache miss — load from system
        const tex = getSystemFileIcon(ext);
        if (self.count < MAX_CACHED_ICONS) {
            const idx = self.count;
            const copy_len: u8 = @intCast(@min(ext.len, MAX_EXT_LEN));
            @memcpy(self.entries[idx].ext[0..copy_len], ext[0..copy_len]);
            self.entries[idx].ext_len = copy_len;
            self.entries[idx].texture_id = tex;
            self.count += 1;
        }

        return if (tex != 0) tex else self.default_file_texture_id;
    }

    /// Get the folder icon texture ID.
    pub fn getFolderIcon(self: *const FileIconCache) gl.GLuint {
        return self.folder_texture_id;
    }

    /// Render a textured icon quad at the given position and size.
    pub fn renderIcon(texture_id: gl.GLuint, x: i32, y: i32, size: i32) void {
        if (texture_id == 0) return;
        const fx: f32 = @floatFromInt(x);
        const fy: f32 = @floatFromInt(y);
        const fx1: f32 = @floatFromInt(x + size);
        const fy1: f32 = @floatFromInt(y + size);

        gl.glEnable(gl.GL_TEXTURE_2D);
        gl.glBindTexture(gl.GL_TEXTURE_2D, texture_id);
        gl.glColor4f(1.0, 1.0, 1.0, 1.0);
        gl.glBegin(gl.GL_QUADS);
        gl.glTexCoord2f(0.0, 0.0);
        gl.glVertex2f(fx, fy);
        gl.glTexCoord2f(1.0, 0.0);
        gl.glVertex2f(fx1, fy);
        gl.glTexCoord2f(1.0, 1.0);
        gl.glVertex2f(fx1, fy1);
        gl.glTexCoord2f(0.0, 1.0);
        gl.glVertex2f(fx, fy1);
        gl.glEnd();
        gl.glDisable(gl.GL_TEXTURE_2D);
    }
};

// =============================================================================
// System icon retrieval
// =============================================================================

/// Get the system-registered icon for a file extension and rasterize to GL texture.
/// `ext` should be like ".zig", ".py", etc. Pass ".*" for default file icon.
fn getSystemFileIcon(ext: []const u8) gl.GLuint {
    // Build a fake filename: "file" + ext as UTF-16
    var fname_w: [32]u16 = [_]u16{0} ** 32;
    const prefix = "file";
    var pos: usize = 0;
    for (prefix) |ch| {
        fname_w[pos] = @intCast(ch);
        pos += 1;
    }
    for (ext) |ch| {
        if (pos >= 30) break;
        fname_w[pos] = @intCast(ch);
        pos += 1;
    }
    fname_w[pos] = 0;

    var sfi: win32.SHFILEINFOW = undefined;
    sfi.hIcon = null;
    const result = win32.SHGetFileInfoW(
        @ptrCast(&fname_w),
        win32.FILE_ATTRIBUTE_NORMAL,
        &sfi,
        @sizeOf(win32.SHFILEINFOW),
        win32.SHGFI_ICON | win32.SHGFI_SMALLICON | win32.SHGFI_USEFILEATTRIBUTES,
    );
    if (result == 0) return 0;

    const hicon = sfi.hIcon orelse return 0;
    const tex = rasterizeIconToTexture(hicon);
    _ = win32.DestroyIcon(hicon);
    return tex;
}

/// Get the system folder icon and rasterize to GL texture.
fn getSystemFolderIcon() gl.GLuint {
    const folder_name = [_]u16{ 'f', 'o', 'l', 'd', 'e', 'r', 0 };
    var sfi: win32.SHFILEINFOW = undefined;
    sfi.hIcon = null;
    const result = win32.SHGetFileInfoW(
        @ptrCast(&folder_name),
        win32.FILE_ATTRIBUTE_DIRECTORY,
        &sfi,
        @sizeOf(win32.SHFILEINFOW),
        win32.SHGFI_ICON | win32.SHGFI_SMALLICON | win32.SHGFI_USEFILEATTRIBUTES,
    );
    if (result == 0) return 0;

    const hicon = sfi.hIcon orelse return 0;
    const tex = rasterizeIconToTexture(hicon);
    _ = win32.DestroyIcon(hicon);
    return tex;
}

// =============================================================================
// Icon → GL texture (same pipeline as app.zig rasterizeIconToTexture)
// =============================================================================

/// Rasterize an HICON into a 32×32 RGBA GL texture via GDI DIB section.
fn rasterizeIconToTexture(hicon: win32.HICON) gl.GLuint {
    const dc = win32.CreateCompatibleDC(null) orelse return 0;

    var bmi: win32.BITMAPINFO = .{
        .bmiHeader = .{
            .biSize = @sizeOf(win32.BITMAPINFOHEADER),
            .biWidth = ICON_SZ,
            .biHeight = -ICON_SZ, // top-down
            .biPlanes = 1,
            .biBitCount = 32,
            .biCompression = win32.BI_RGB,
            .biSizeImage = 0,
            .biXPelsPerMeter = 0,
            .biYPelsPerMeter = 0,
            .biClrUsed = 0,
            .biClrImportant = 0,
        },
        .bmiColors = .{.{ .b = 0, .g = 0, .r = 0, .reserved = 0 }},
    };
    var dib_bits: ?*anyopaque = null;
    const bmp = win32.CreateDIBSection(dc, &bmi, win32.DIB_RGB_COLORS, &dib_bits, null, 0) orelse {
        _ = win32.DeleteDC(dc);
        return 0;
    };

    _ = win32.SelectObject(dc, @ptrCast(bmp));
    _ = win32.DrawIconEx(dc, 0, 0, hicon, ICON_SZ, ICON_SZ, 0, null, win32.DI_NORMAL);

    const bits = dib_bits orelse {
        _ = win32.DeleteObject(@ptrCast(bmp));
        _ = win32.DeleteDC(dc);
        return 0;
    };
    const src: [*]u8 = @ptrCast(bits);

    // Convert BGRA → RGBA
    const pixel_count: usize = @intCast(ICON_SZ * ICON_SZ);
    var rgba: [32 * 32 * 4]u8 = undefined;
    var px: usize = 0;
    while (px < pixel_count) : (px += 1) {
        const off = px * 4;
        rgba[off + 0] = src[off + 2]; // R
        rgba[off + 1] = src[off + 1]; // G
        rgba[off + 2] = src[off + 0]; // B
        rgba[off + 3] = src[off + 3]; // A
    }

    _ = win32.DeleteObject(@ptrCast(bmp));
    _ = win32.DeleteDC(dc);

    var tex_id: gl.GLuint = 0;
    gl.glGenTextures(1, &tex_id);
    gl.glBindTexture(gl.GL_TEXTURE_2D, tex_id);
    gl.glTexImage2D(
        gl.GL_TEXTURE_2D,
        0,
        @intCast(gl.GL_RGBA),
        ICON_SZ,
        ICON_SZ,
        0,
        gl.GL_RGBA,
        gl.GL_UNSIGNED_BYTE,
        @ptrCast(&rgba),
    );
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);
    return tex_id;
}

// =============================================================================
// Helpers
// =============================================================================

/// Extract the file extension (including dot) from a filename.
fn extractExtension(name: []const u8) []const u8 {
    var i: usize = name.len;
    while (i > 0) {
        i -= 1;
        if (name[i] == '.') return name[i..];
    }
    return "";
}

/// Compare two byte slices for equality.
fn eqlBytes(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

// =============================================================================
// Tests
// =============================================================================

const testing = @import("std").testing;

test "FileIconCache default initialization" {
    const cache = FileIconCache{};
    try testing.expectEqual(@as(u8, 0), cache.count);
    try testing.expectEqual(@as(gl.GLuint, 0), cache.folder_texture_id);
    try testing.expectEqual(@as(gl.GLuint, 0), cache.default_file_texture_id);
}

test "IconCacheEntry default initialization" {
    const entry = IconCacheEntry{};
    try testing.expectEqual(@as(u8, 0), entry.ext_len);
    try testing.expectEqual(@as(gl.GLuint, 0), entry.texture_id);
}

test "extractExtension extracts correctly" {
    try testing.expectEqualSlices(u8, ".zig", extractExtension("main.zig"));
    try testing.expectEqualSlices(u8, ".json", extractExtension("package.json"));
    try testing.expectEqualSlices(u8, "", extractExtension("Makefile"));
    try testing.expectEqualSlices(u8, ".py", extractExtension("test.py"));
    try testing.expectEqualSlices(u8, ".ts", extractExtension("app.component.ts"));
}

test "eqlBytes compares correctly" {
    try testing.expect(eqlBytes(".zig", ".zig"));
    try testing.expect(!eqlBytes(".zig", ".py"));
    try testing.expect(!eqlBytes(".zig", ".zi"));
    try testing.expect(eqlBytes("", ""));
}

test "MAX_CACHED_ICONS is 64" {
    try testing.expectEqual(@as(usize, 64), MAX_CACHED_ICONS);
}

test "MAX_EXT_LEN is 16" {
    try testing.expectEqual(@as(usize, 16), MAX_EXT_LEN);
}

test "SHFILEINFOW size matches expected" {
    // SHFILEINFOW should be a valid extern struct
    const size = @sizeOf(win32.SHFILEINFOW);
    try testing.expect(size > 0);
}

test "SHGetFileInfoW constants" {
    try testing.expectEqual(@as(win32.UINT, 0x100), win32.SHGFI_ICON);
    try testing.expectEqual(@as(win32.UINT, 0x001), win32.SHGFI_SMALLICON);
    try testing.expectEqual(@as(win32.UINT, 0x010), win32.SHGFI_USEFILEATTRIBUTES);
}

test "getIconForFile returns default for no extension" {
    var cache = FileIconCache{};
    cache.default_file_texture_id = 42;
    const tex = cache.getIconForFile("Makefile");
    try testing.expectEqual(@as(gl.GLuint, 42), tex);
}

test "getFolderIcon returns stored value" {
    var cache = FileIconCache{};
    cache.folder_texture_id = 99;
    try testing.expectEqual(@as(gl.GLuint, 99), cache.getFolderIcon());
}
