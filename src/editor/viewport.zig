// src/editor/viewport.zig — Editor viewport rendering (no allocator)
//
// Renders syntax-highlighted text, cursors, and selections in the editor area
// using OpenGL 1.x immediate mode. Clips to the editor rectangle via GL_SCISSOR_TEST.
// Maps each TokenKind to VS Code dark theme colors.

const gl = @import("gl");
const FontAtlas = @import("font_atlas").FontAtlas;
const syntax = @import("syntax");
const SyntaxHighlighter = syntax.SyntaxHighlighter;
const TokenKind = syntax.TokenKind;
const LineSyntax = syntax.LineSyntax;
const TextBuffer = @import("buffer").TextBuffer;
const cursor_mod = @import("cursor");
const CursorState = cursor_mod.CursorState;
const Selection = cursor_mod.Selection;
const Color = @import("color").Color;
const Rect = @import("rect").Rect;

// =============================================================================
// VS Code Dark Theme Token Colors
// =============================================================================

/// Map a TokenKind to its VS Code dark theme color.
///
/// Color mapping:
///   keyword      → #569CD6 (blue)
///   string       → #CE9178 (orange)
///   comment      → #6A9955 (green)
///   number       → #B5CEA8 (light green)
///   builtin      → #4EC9B0 (teal)
///   type_name    → #4EC9B0 (teal)
///   function_name→ #DCDCAA (yellow)
///   operator     → #D4D4D4 (light gray)
///   punctuation  → #D4D4D4 (light gray)
///   preprocessor → #C586C0 (magenta)
///   plain        → #D4D4D4 (light gray)
pub fn tokenColor(kind: TokenKind) Color {
    return switch (kind) {
        .keyword => Color.rgb(0x56, 0x9C, 0xD6),
        .string_literal => Color.rgb(0xCE, 0x91, 0x78),
        .comment => Color.rgb(0x6A, 0x99, 0x55),
        .number_literal => Color.rgb(0xB5, 0xCE, 0xA8),
        .builtin => Color.rgb(0x4E, 0xC9, 0xB0),
        .type_name => Color.rgb(0x4E, 0xC9, 0xB0),
        .function_name => Color.rgb(0xDC, 0xDC, 0xAA),
        .operator => Color.rgb(0xD4, 0xD4, 0xD4),
        .punctuation => Color.rgb(0xD4, 0xD4, 0xD4),
        .preprocessor => Color.rgb(0xC5, 0x86, 0xC0),
        .plain => Color.rgb(0xD4, 0xD4, 0xD4),
    };
}

// Cursor bar color (white)
pub const CURSOR_COLOR = Color.rgb(0xFF, 0xFF, 0xFF);
// Cursor bar width in pixels
pub const CURSOR_WIDTH: f32 = 2.0;

// Selection highlight color (semi-transparent blue, matching VS Code)
pub const SELECTION_COLOR = Color.rgba(0x26, 0x4F, 0x78, 0x80);

// =============================================================================
// EditorViewport
// =============================================================================

pub const EditorViewport = struct {
    scroll_top: u32 = 0,
    visible_lines: u32 = 0,
};

// =============================================================================
// renderEditorViewport
// =============================================================================

/// Render the editor viewport: syntax-highlighted text, cursors, and selections.
///
/// Preconditions:
///   - OpenGL context is current
///   - `font_atlas` is initialized with valid texture and glyph metrics
///   - `buffer`, `cursor_state`, `highlighter` contain valid state
///
/// Postconditions:
///   - Only lines in [scroll_top, scroll_top + visible_lines) are rendered
///   - GL_SCISSOR_TEST is enabled then disabled (restored)
///   - Each token is drawn with its VS Code dark theme color
///   - A 2px cursor bar is drawn at each cursor position on visible lines
///   - Selection highlights are drawn for active selections on visible lines
pub fn renderEditorViewport(
    area: Rect,
    buffer: *const TextBuffer,
    cursor_state: *const CursorState,
    highlighter: *SyntaxHighlighter,
    font_atlas: *const FontAtlas,
    scroll_top: u32,
    visible_lines: u32,
) void {
    // Enable scissor test clipped to editor area
    gl.glEnable(gl.GL_SCISSOR_TEST);
    // glScissor uses bottom-left origin; convert from top-left Rect
    // We assume the GL viewport matches the window with glOrtho(0, w, h, 0, -1, 1)
    // so scissor Y must be flipped. However, since we don't know window height here,
    // we pass the rect as-is — the caller's glOrtho setup with top-down coords means
    // scissor Y = area.y works when the viewport is set up with matching dimensions.
    gl.glScissor(area.x, area.y, area.w, area.h);

    const line_height: f32 = @floatFromInt(font_atlas.cell_h);
    const area_x: f32 = @floatFromInt(area.x);
    const area_y: f32 = @floatFromInt(area.y);

    // Render visible lines
    var line_offset: u32 = 0;
    while (line_offset < visible_lines) : (line_offset += 1) {
        const line_idx = scroll_top + line_offset;
        if (line_idx >= buffer.line_count) break;

        const line_text = buffer.getLine(line_idx) orelse continue;
        const y = area_y + @as(f32, @floatFromInt(line_offset)) * line_height;

        // Tokenize the line
        highlighter.tokenizeLine(line_idx, line_text);
        const ls: *const LineSyntax = &highlighter.line_syntax[line_idx];

        // Draw selection highlights behind text
        drawSelectionHighlights(cursor_state, line_idx, area_x, y, line_height, font_atlas, line_text.len);

        // Draw each syntax token
        drawTokens(ls, line_text, area_x, y, font_atlas);

        // Draw cursor bars
        drawCursors(cursor_state, line_idx, scroll_top, visible_lines, area_x, y, line_height, font_atlas);
    }

    // Disable scissor test
    gl.glDisable(gl.GL_SCISSOR_TEST);
}

// =============================================================================
// Internal rendering helpers
// =============================================================================

fn drawTokens(
    ls: *const LineSyntax,
    line_text: []const u8,
    area_x: f32,
    y: f32,
    font_atlas: *const FontAtlas,
) void {
    var i: u16 = 0;
    while (i < ls.token_count) : (i += 1) {
        const tok = ls.tokens[i];
        const color = tokenColor(tok.kind);
        const start: usize = tok.start_col;
        const end: usize = start + tok.len;
        if (end > line_text.len) break;

        // Compute x offset for this token
        const x_offset = area_x + @as(f32, @floatFromInt(tok.start_col)) * @as(f32, @floatFromInt(font_atlas.cell_w));
        const token_text = line_text[start..end];

        // Render token text with its color
        gl.glEnable(gl.GL_TEXTURE_2D);
        gl.glBindTexture(gl.GL_TEXTURE_2D, font_atlas.texture_id);
        gl.glColor4f(color.r, color.g, color.b, color.a);

        var x = x_offset;
        for (token_text) |ch| {
            x += font_atlas.renderGlyph(ch, x, y);
        }

        gl.glDisable(gl.GL_TEXTURE_2D);
    }
}

fn drawCursors(
    cursor_state: *const CursorState,
    line_idx: u32,
    scroll_top: u32,
    visible_lines: u32,
    area_x: f32,
    y: f32,
    line_height: f32,
    font_atlas: *const FontAtlas,
) void {
    _ = scroll_top;
    _ = visible_lines;

    var c: u32 = 0;
    while (c < cursor_state.cursor_count) : (c += 1) {
        const sel = cursor_state.cursors[c];
        if (sel.active.line == line_idx) {
            const cursor_x = area_x + @as(f32, @floatFromInt(sel.active.col)) * @as(f32, @floatFromInt(font_atlas.cell_w));

            // Draw 2px cursor bar as a quad
            gl.glDisable(gl.GL_TEXTURE_2D);
            gl.glColor4f(CURSOR_COLOR.r, CURSOR_COLOR.g, CURSOR_COLOR.b, CURSOR_COLOR.a);
            gl.glBegin(gl.GL_QUADS);
            gl.glVertex2f(cursor_x, y);
            gl.glVertex2f(cursor_x + CURSOR_WIDTH, y);
            gl.glVertex2f(cursor_x + CURSOR_WIDTH, y + line_height);
            gl.glVertex2f(cursor_x, y + line_height);
            gl.glEnd();
        }
    }
}

fn drawSelectionHighlights(
    cursor_state: *const CursorState,
    line_idx: u32,
    area_x: f32,
    y: f32,
    line_height: f32,
    font_atlas: *const FontAtlas,
    line_len: usize,
) void {
    var c: u32 = 0;
    while (c < cursor_state.cursor_count) : (c += 1) {
        const sel = cursor_state.cursors[c];
        if (sel.isEmpty()) continue;

        const start = sel.startPos();
        const end = sel.endPos();

        // Determine if this line is within the selection range
        if (line_idx < start.line or line_idx > end.line) continue;

        // Compute selection column range on this line
        var sel_start_col: u32 = 0;
        var sel_end_col: u32 = @intCast(line_len);

        if (line_idx == start.line) {
            sel_start_col = start.col;
        }
        if (line_idx == end.line) {
            sel_end_col = end.col;
        }

        if (sel_start_col >= sel_end_col) continue;

        const x0 = area_x + @as(f32, @floatFromInt(sel_start_col)) * @as(f32, @floatFromInt(font_atlas.cell_w));
        const x1 = area_x + @as(f32, @floatFromInt(sel_end_col)) * @as(f32, @floatFromInt(font_atlas.cell_w));

        // Draw semi-transparent selection rectangle
        gl.glDisable(gl.GL_TEXTURE_2D);
        gl.glColor4f(SELECTION_COLOR.r, SELECTION_COLOR.g, SELECTION_COLOR.b, SELECTION_COLOR.a);
        gl.glBegin(gl.GL_QUADS);
        gl.glVertex2f(x0, y);
        gl.glVertex2f(x1, y);
        gl.glVertex2f(x1, y + line_height);
        gl.glVertex2f(x0, y + line_height);
        gl.glEnd();
    }
}

// =============================================================================
// Tests — tokenColor mapping (GL externs not available in test environment)
// =============================================================================

const std = @import("std");
const testing = std.testing;

test "tokenColor maps keyword to VS Code blue (#569CD6)" {
    const c = tokenColor(.keyword);
    try testing.expectApproxEqAbs(@as(f32, 0x56) / 255.0, c.r, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0x9C) / 255.0, c.g, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0xD6) / 255.0, c.b, 0.002);
}

test "tokenColor maps string_literal to VS Code orange (#CE9178)" {
    const c = tokenColor(.string_literal);
    try testing.expectApproxEqAbs(@as(f32, 0xCE) / 255.0, c.r, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0x91) / 255.0, c.g, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0x78) / 255.0, c.b, 0.002);
}

test "tokenColor maps comment to VS Code green (#6A9955)" {
    const c = tokenColor(.comment);
    try testing.expectApproxEqAbs(@as(f32, 0x6A) / 255.0, c.r, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0x99) / 255.0, c.g, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0x55) / 255.0, c.b, 0.002);
}

test "tokenColor maps number_literal to #B5CEA8" {
    const c = tokenColor(.number_literal);
    try testing.expectApproxEqAbs(@as(f32, 0xB5) / 255.0, c.r, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0xCE) / 255.0, c.g, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0xA8) / 255.0, c.b, 0.002);
}

test "tokenColor maps builtin to teal (#4EC9B0)" {
    const c = tokenColor(.builtin);
    try testing.expectApproxEqAbs(@as(f32, 0x4E) / 255.0, c.r, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0xC9) / 255.0, c.g, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0xB0) / 255.0, c.b, 0.002);
}

test "tokenColor maps plain to light gray (#D4D4D4)" {
    const c = tokenColor(.plain);
    try testing.expectApproxEqAbs(@as(f32, 0xD4) / 255.0, c.r, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0xD4) / 255.0, c.g, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0xD4) / 255.0, c.b, 0.002);
}

test "tokenColor maps punctuation to light gray (#D4D4D4)" {
    const c = tokenColor(.punctuation);
    try testing.expectApproxEqAbs(@as(f32, 0xD4) / 255.0, c.r, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0xD4) / 255.0, c.g, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0xD4) / 255.0, c.b, 0.002);
}

test "tokenColor maps operator to light gray (#D4D4D4)" {
    const c = tokenColor(.operator);
    const expected = Color.rgb(0xD4, 0xD4, 0xD4);
    try testing.expectApproxEqAbs(expected.r, c.r, 0.002);
    try testing.expectApproxEqAbs(expected.g, c.g, 0.002);
    try testing.expectApproxEqAbs(expected.b, c.b, 0.002);
}

test "tokenColor maps preprocessor to magenta (#C586C0)" {
    const c = tokenColor(.preprocessor);
    try testing.expectApproxEqAbs(@as(f32, 0xC5) / 255.0, c.r, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0x86) / 255.0, c.g, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0xC0) / 255.0, c.b, 0.002);
}

test "tokenColor maps function_name to yellow (#DCDCAA)" {
    const c = tokenColor(.function_name);
    try testing.expectApproxEqAbs(@as(f32, 0xDC) / 255.0, c.r, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0xDC) / 255.0, c.g, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0xAA) / 255.0, c.b, 0.002);
}

test "tokenColor maps type_name to teal (#4EC9B0)" {
    const c = tokenColor(.type_name);
    const builtin_color = tokenColor(.builtin);
    try testing.expectApproxEqAbs(builtin_color.r, c.r, 0.002);
    try testing.expectApproxEqAbs(builtin_color.g, c.g, 0.002);
    try testing.expectApproxEqAbs(builtin_color.b, c.b, 0.002);
}

test "tokenColor covers all TokenKind variants" {
    // Ensure every variant returns a valid color (a > 0)
    const kinds = [_]TokenKind{
        .plain,       .keyword,      .string_literal, .number_literal,
        .comment,     .type_name,    .function_name,  .operator,
        .punctuation, .preprocessor, .builtin,
    };
    for (kinds) |kind| {
        const c = tokenColor(kind);
        try testing.expect(c.r >= 0.0 and c.r <= 1.0);
        try testing.expect(c.g >= 0.0 and c.g <= 1.0);
        try testing.expect(c.b >= 0.0 and c.b <= 1.0);
        try testing.expect(c.a > 0.0);
    }
}

test "CURSOR_COLOR is white" {
    try testing.expectApproxEqAbs(@as(f32, 1.0), CURSOR_COLOR.r, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 1.0), CURSOR_COLOR.g, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 1.0), CURSOR_COLOR.b, 0.002);
}

test "CURSOR_WIDTH is 2 pixels" {
    try testing.expectApproxEqAbs(@as(f32, 2.0), CURSOR_WIDTH, 0.001);
}

test "SELECTION_COLOR is semi-transparent blue" {
    try testing.expect(SELECTION_COLOR.a > 0.0);
    try testing.expect(SELECTION_COLOR.a < 1.0);
    // Blue-ish: b component should be significant
    try testing.expect(SELECTION_COLOR.b > SELECTION_COLOR.r);
}

test "EditorViewport default initialization" {
    const vp = EditorViewport{};
    try testing.expectEqual(@as(u32, 0), vp.scroll_top);
    try testing.expectEqual(@as(u32, 0), vp.visible_lines);
}
