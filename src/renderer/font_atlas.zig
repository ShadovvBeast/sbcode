// src/renderer/font_atlas.zig — GDI-rasterized bitmap font → OpenGL texture atlas
//
// Rasterizes printable ASCII glyphs (32..126) via Win32 GDI into a comptime-sized
// RGBA bitmap, uploads to an OpenGL texture with GL_NEAREST filtering, and provides
// immediate mode textured quad rendering for each glyph.

const w32 = @import("win32");
const gl = @import("gl");
const Color = @import("color").Color;

// =============================================================================
// Constants
// =============================================================================

pub const ATLAS_SIZE: i32 = 1024;
pub const FIRST_CHAR: u8 = 32;
pub const LAST_CHAR: u8 = 126;
pub const GLYPH_COUNT: usize = LAST_CHAR - FIRST_CHAR + 1; // 95 printable ASCII
pub const GLYPH_COLS: i32 = 16;
pub const GLYPH_ROWS: i32 = 6; // ceil(95 / 16) = 6

// =============================================================================
// GlyphMetrics
// =============================================================================

pub const GlyphMetrics = struct {
    u0: f32 = 0, // top-left U
    v0: f32 = 0, // top-left V
    u1: f32 = 0, // bottom-right U
    v1: f32 = 0, // bottom-right V
    width: i32 = 0,
    height: i32 = 0,
    advance: i32 = 0,
};

// =============================================================================
// FontAtlas
// =============================================================================

pub const FontAtlas = struct {
    texture_id: gl.GLuint = 0,
    glyphs: [GLYPH_COUNT]GlyphMetrics = [_]GlyphMetrics{.{}} ** GLYPH_COUNT,
    cell_w: i32 = 0,
    cell_h: i32 = 0,
    bitmap: [ATLAS_SIZE * ATLAS_SIZE * 4]u8 = [_]u8{0} ** (ATLAS_SIZE * ATLAS_SIZE * 4),

    /// Rasterize system font glyphs via GDI into bitmap, then upload to GL texture.
    ///
    /// Preconditions:
    ///   - `font_name` is a valid system font name (null-terminated UTF-16)
    ///   - `font_size` > 0
    ///   - OpenGL context is current (wglMakeCurrent called)
    ///
    /// Postconditions:
    ///   - self.texture_id is a valid GL texture with all glyphs rasterized
    ///   - self.glyphs[c - FIRST_CHAR] contains correct UV coords for each printable codepoint c
    ///   - self.cell_w and self.cell_h reflect the monospace cell dimensions
    pub fn init(self: *FontAtlas, font_name: [*:0]const u16, font_size: i32) void {
        // Step 1: Create GDI font (FW_NORMAL=400, DEFAULT_CHARSET=1)
        const hfont = w32.CreateFontW(
            font_size,
            0,
            0,
            0,
            400,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            font_name,
        ) orelse return;

        // Step 2: Create memory DC
        const hdc = w32.CreateCompatibleDC(null) orelse return;

        // Compute cell dimensions from font size
        self.cell_w = @divTrunc(font_size * 3, 5); // approximate monospace width
        if (self.cell_w < 1) self.cell_w = 1;
        self.cell_h = font_size;
        if (self.cell_h < 1) self.cell_h = 1;

        // Step 3: Create DIB section for rasterization
        var bmi: w32.BITMAPINFO = .{
            .bmiHeader = .{
                .biSize = @sizeOf(w32.BITMAPINFOHEADER),
                .biWidth = ATLAS_SIZE,
                .biHeight = -ATLAS_SIZE, // top-down
                .biPlanes = 1,
                .biBitCount = 32,
                .biCompression = w32.BI_RGB,
                .biSizeImage = 0,
                .biXPelsPerMeter = 0,
                .biYPelsPerMeter = 0,
                .biClrUsed = 0,
                .biClrImportant = 0,
            },
            .bmiColors = .{.{ .b = 0, .g = 0, .r = 0, .reserved = 0 }},
        };

        var dib_bits: ?*anyopaque = null;
        const hbmp = w32.CreateDIBSection(hdc, &bmi, w32.DIB_RGB_COLORS, &dib_bits, null, 0) orelse {
            _ = w32.DeleteDC(hdc);
            return;
        };

        // Select bitmap and font into DC
        _ = w32.SelectObject(hdc, @ptrCast(hbmp));
        _ = w32.SelectObject(hdc, @ptrCast(hfont));
        _ = w32.SetTextColor(hdc, 0x00FFFFFF); // white text
        _ = w32.SetBkMode(hdc, w32.TRANSPARENT);

        // Step 4: Rasterize each glyph
        var i: usize = 0;
        while (i < GLYPH_COUNT) : (i += 1) {
            const ch: u8 = FIRST_CHAR + @as(u8, @intCast(i));
            const col: i32 = @intCast(i % @as(usize, @intCast(GLYPH_COLS)));
            const row: i32 = @intCast(i / @as(usize, @intCast(GLYPH_COLS)));

            const gx = col * self.cell_w;
            const gy = row * self.cell_h;

            // Render glyph via GDI TextOutW
            var char_buf: [1:0]u16 = .{@as(u16, ch)};
            _ = w32.TextOutW(hdc, gx, gy, &char_buf, 1);

            // Record glyph metrics with UV coordinates
            const atlas_f: f32 = @floatFromInt(ATLAS_SIZE);
            self.glyphs[i] = .{
                .u0 = @as(f32, @floatFromInt(gx)) / atlas_f,
                .v0 = @as(f32, @floatFromInt(gy)) / atlas_f,
                .u1 = @as(f32, @floatFromInt(gx + self.cell_w)) / atlas_f,
                .v1 = @as(f32, @floatFromInt(gy + self.cell_h)) / atlas_f,
                .width = self.cell_w,
                .height = self.cell_h,
                .advance = self.cell_w,
            };
        }

        // Step 5: Copy DIB pixel data into our RGBA bitmap
        if (dib_bits) |bits| {
            const src: [*]const u8 = @ptrCast(bits);
            const atlas_size_u: usize = @intCast(ATLAS_SIZE);
            const pixel_count = atlas_size_u * atlas_size_u;
            var px: usize = 0;
            while (px < pixel_count) : (px += 1) {
                const src_off = px * 4; // BGRA from GDI
                const dst_off = px * 4; // RGBA for GL
                self.bitmap[dst_off + 0] = src[src_off + 2]; // R
                self.bitmap[dst_off + 1] = src[src_off + 1]; // G
                self.bitmap[dst_off + 2] = src[src_off + 0]; // B
                self.bitmap[dst_off + 3] = if (src[src_off + 2] > 0 or src[src_off + 1] > 0 or src[src_off + 0] > 0) 255 else 0;
            }
        }

        // Cleanup GDI resources
        _ = w32.DeleteObject(@ptrCast(hbmp));
        _ = w32.DeleteObject(@ptrCast(hfont));
        _ = w32.DeleteDC(hdc);

        // Step 6: Upload to OpenGL texture
        gl.glGenTextures(1, &self.texture_id);
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.texture_id);
        gl.glTexImage2D(
            gl.GL_TEXTURE_2D,
            0,
            @intCast(gl.GL_RGBA),
            ATLAS_SIZE,
            ATLAS_SIZE,
            0,
            gl.GL_RGBA,
            gl.GL_UNSIGNED_BYTE,
            @ptrCast(&self.bitmap),
        );
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_NEAREST);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_NEAREST);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);
    }

    /// Render a single glyph as a textured quad at (x, y).
    ///
    /// Preconditions:
    ///   - self.texture_id is bound (glBindTexture called)
    ///   - GL_TEXTURE_2D is enabled
    ///   - `codepoint` is in range FIRST_CHAR..LAST_CHAR
    ///
    /// Postconditions:
    ///   - A textured quad is emitted via glBegin/glEnd
    ///   - Returns the x-advance for cursor positioning
    pub fn renderGlyph(self: *const FontAtlas, codepoint: u8, x: f32, y: f32) f32 {
        if (codepoint < FIRST_CHAR or codepoint > LAST_CHAR) {
            // Non-printable: advance by cell width as a space
            return @floatFromInt(self.cell_w);
        }

        const idx = codepoint - FIRST_CHAR;
        const g = self.glyphs[idx];
        const x1 = x + @as(f32, @floatFromInt(g.width));
        const y1 = y + @as(f32, @floatFromInt(g.height));

        gl.glBegin(gl.GL_QUADS);
        gl.glTexCoord2f(g.u0, g.v0);
        gl.glVertex2f(x, y);
        gl.glTexCoord2f(g.u1, g.v0);
        gl.glVertex2f(x1, y);
        gl.glTexCoord2f(g.u1, g.v1);
        gl.glVertex2f(x1, y1);
        gl.glTexCoord2f(g.u0, g.v1);
        gl.glVertex2f(x, y1);
        gl.glEnd();

        return @as(f32, @floatFromInt(g.advance));
    }

    /// Render a string of text starting at (start_x, y).
    ///
    /// Enables GL_TEXTURE_2D, binds the atlas texture, sets the color,
    /// iterates over each byte, renders the corresponding glyph, and
    /// advances the x position by each glyph's advance value.
    pub fn renderText(self: *const FontAtlas, text: []const u8, start_x: f32, y: f32, color: Color) void {
        gl.glEnable(gl.GL_TEXTURE_2D);
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.texture_id);
        gl.glColor4f(color.r, color.g, color.b, color.a);

        var x = start_x;
        for (text) |ch| {
            x += self.renderGlyph(ch, x, y);
        }

        gl.glDisable(gl.GL_TEXTURE_2D);
    }
};

// =============================================================================
// Tests — minimal (Win32 GDI externs not available in test environment)
// =============================================================================

const std = @import("std");
const testing = std.testing;

test "GlyphMetrics default initialization" {
    const gm = GlyphMetrics{};
    try testing.expectEqual(@as(f32, 0), gm.u0);
    try testing.expectEqual(@as(f32, 0), gm.v0);
    try testing.expectEqual(@as(f32, 0), gm.u1);
    try testing.expectEqual(@as(f32, 0), gm.v1);
    try testing.expectEqual(@as(i32, 0), gm.width);
    try testing.expectEqual(@as(i32, 0), gm.height);
    try testing.expectEqual(@as(i32, 0), gm.advance);
}

test "FontAtlas constants are correct" {
    try testing.expectEqual(@as(i32, 1024), ATLAS_SIZE);
    try testing.expectEqual(@as(u8, 32), FIRST_CHAR);
    try testing.expectEqual(@as(u8, 126), LAST_CHAR);
    try testing.expectEqual(@as(usize, 95), GLYPH_COUNT);
    try testing.expectEqual(@as(i32, 16), GLYPH_COLS);
    try testing.expectEqual(@as(i32, 6), GLYPH_ROWS);
}

test "FontAtlas default initialization" {
    const atlas = FontAtlas{};
    try testing.expectEqual(@as(gl.GLuint, 0), atlas.texture_id);
    try testing.expectEqual(@as(i32, 0), atlas.cell_w);
    try testing.expectEqual(@as(i32, 0), atlas.cell_h);
    // All glyphs should be default-initialized
    for (atlas.glyphs) |gm| {
        try testing.expectEqual(@as(f32, 0), gm.u0);
        try testing.expectEqual(@as(i32, 0), gm.advance);
    }
}

test "GLYPH_COUNT covers all printable ASCII" {
    // Printable ASCII: space (32) through tilde (126) = 95 characters
    try testing.expectEqual(@as(usize, 95), GLYPH_COUNT);
    try testing.expect(LAST_CHAR >= FIRST_CHAR);
    try testing.expectEqual(GLYPH_COUNT, @as(usize, LAST_CHAR - FIRST_CHAR + 1));
}

test "GLYPH_ROWS sufficient for GLYPH_COUNT" {
    // GLYPH_ROWS * GLYPH_COLS must be >= GLYPH_COUNT
    const total_cells: usize = @intCast(GLYPH_ROWS * GLYPH_COLS);
    try testing.expect(total_cells >= GLYPH_COUNT);
}
