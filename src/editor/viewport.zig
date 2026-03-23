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
const Position = cursor_mod.Position;
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
// Cursor blink interval in seconds (toggled by workbench blink_timer)
pub const CURSOR_BLINK_INTERVAL: f64 = 0.53;

// Selection highlight color (semi-transparent blue, matching VS Code)
const SELECTION_BG = Color.rgba(0x26, 0x4F, 0x78, 0xCC);

// Indent guide line color (subtle vertical lines at tab stops)
const indent_guide_color = Color.rgba(0x40, 0x40, 0x40, 0x80);

// Word highlight color (highlight all occurrences of word under cursor)
const word_highlight_bg = Color.rgba(0x57, 0x57, 0x57, 0x40);

// Code folding gutter indicator color
const fold_indicator_color = Color.rgba(0x80, 0x80, 0x80, 0x60);

// Word wrap mode flag (soft line wrapping)
var word_wrap_enabled: bool = false;
pub const SELECTION_COLOR = Color.rgba(0x26, 0x4F, 0x78, 0x80);

// Line number gutter colors
const LINE_NUMBER_COLOR = Color.rgb(0x85, 0x85, 0x85);
const ACTIVE_LINE_NUMBER_COLOR = Color.rgb(0xC6, 0xC6, 0xC6);
const GUTTER_BG = Color.rgb(0x1E, 0x1E, 0x1E);

// Current line highlight
const CURRENT_LINE_BG = Color.rgba(0xFF, 0xFF, 0xFF, 0x0A);

// Scrollbar colors
const SCROLLBAR_TRACK_COLOR = Color.rgba(0x1E, 0x1E, 0x1E, 0x00);
const SCROLLBAR_THUMB_COLOR = Color.rgba(0x79, 0x79, 0x79, 0x66);

// Bracket matching highlight
const BRACKET_MATCH_BG = Color.rgba(0x00, 0x6E, 0xD1, 0x40);
const BRACKET_MATCH_BORDER = Color.rgba(0x00, 0x6E, 0xD1, 0x80);
const bracket_match_enabled = true;

// Gutter width in characters (line numbers)
pub const GUTTER_CHAR_WIDTH: u32 = 5;

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
    cursor_visible: bool,
) void {
    gl.glEnable(gl.GL_SCISSOR_TEST);
    gl.glScissor(area.x, area.y, area.w, area.h);

    const line_height: f32 = @floatFromInt(font_atlas.cell_h);
    const cell_w: f32 = @floatFromInt(font_atlas.cell_w);
    const area_x: f32 = @floatFromInt(area.x);
    const area_y: f32 = @floatFromInt(area.y);

    // Gutter width for line numbers
    const gutter_w: f32 = @as(f32, @floatFromInt(GUTTER_CHAR_WIDTH)) * cell_w;
    const text_x = area_x + gutter_w;

    // Get cursor line for current line highlight
    const cursor_line = cursor_state.primary().active.line;

    // Render visible lines
    var line_offset: u32 = 0;
    while (line_offset < visible_lines) : (line_offset += 1) {
        const line_idx = scroll_top + line_offset;
        if (line_idx >= buffer.line_count) break;

        const line_text = buffer.getLine(line_idx) orelse continue;
        const y = area_y + @as(f32, @floatFromInt(line_offset)) * line_height;

        // Current line highlight background
        if (line_idx == cursor_line) {
            drawRect(area_x, y, @floatFromInt(area.w), line_height, CURRENT_LINE_BG);
        }

        // Line number gutter
        drawLineNumber(line_idx + 1, line_idx == cursor_line, area_x, y, font_atlas);

        // Tokenize the line
        highlighter.tokenizeLine(line_idx, line_text);
        const ls: *const LineSyntax = &highlighter.line_syntax[line_idx];

        // Draw selection highlights behind text
        drawSelectionHighlights(cursor_state, line_idx, text_x, y, line_height, font_atlas, line_text.len);

        // Draw each syntax token
        drawTokens(ls, line_text, text_x, y, font_atlas);

        // Draw bracket matching highlight
        if (bracket_match_enabled)
            drawBracketMatch(buffer, cursor_state, line_idx, text_x, y, line_height, font_atlas);

        // Draw cursor bars
        if (cursor_visible) {
            drawCursors(cursor_state, line_idx, scroll_top, visible_lines, text_x, y, line_height, font_atlas);
        }
    }

    // Draw scrollbar
    drawScrollbar(area, buffer.line_count, scroll_top, visible_lines);

    gl.glDisable(gl.GL_SCISSOR_TEST);
}

// =============================================================================
// Internal rendering helpers
// =============================================================================

fn drawRect(x: f32, y: f32, w: f32, h: f32, color: Color) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(color.r, color.g, color.b, color.a);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(x, y);
    gl.glVertex2f(x + w, y);
    gl.glVertex2f(x + w, y + h);
    gl.glVertex2f(x, y + h);
    gl.glEnd();
}

fn drawLineNumber(line_num: u32, is_active: bool, area_x: f32, y: f32, font_atlas: *const FontAtlas) void {
    const color = if (is_active) ACTIVE_LINE_NUMBER_COLOR else LINE_NUMBER_COLOR;
    const cell_w: f32 = @floatFromInt(font_atlas.cell_w);

    // Format line number right-aligned in gutter (up to 4 digits + 1 space)
    var digits: [5]u8 = [_]u8{' '} ** 5;
    var n = line_num;
    var pos: usize = 3; // rightmost digit position (0-indexed, 4th char)
    while (n > 0) : (pos -|= 1) {
        digits[pos] = @intCast((n % 10) + '0');
        n /= 10;
        if (pos == 0) break;
    }

    var i: usize = 0;
    while (i < 4) : (i += 1) {
        const ch = digits[i];
        if (ch != ' ') {
            const x = area_x + @as(f32, @floatFromInt(i)) * cell_w;
            font_atlas.renderGlyphColored(ch, x, y, color);
        }
    }
}

fn drawScrollbar(area: Rect, total_lines: u32, scroll_top: u32, visible_lines: u32) void {
    if (total_lines == 0 or visible_lines >= total_lines) return;

    const scroll_track_w: f32 = 14.0;
    const area_x: f32 = @as(f32, @floatFromInt(area.x + area.w)) - scroll_track_w;
    const area_y: f32 = @floatFromInt(area.y);
    const area_h: f32 = @floatFromInt(area.h);

    // Draw track
    drawRect(area_x, area_y, scroll_track_w, area_h, SCROLLBAR_TRACK_COLOR);

    // Compute thumb size and position
    const ratio = @as(f32, @floatFromInt(visible_lines)) / @as(f32, @floatFromInt(total_lines));
    const thumb_h = @max(20.0, area_h * ratio);
    const scroll_range = @as(f32, @floatFromInt(total_lines - visible_lines));
    const thumb_y = if (scroll_range > 0)
        area_y + (@as(f32, @floatFromInt(scroll_top)) / scroll_range) * (area_h - thumb_h)
    else
        area_y;

    drawRect(area_x, thumb_y, scroll_track_w, thumb_h, SCROLLBAR_THUMB_COLOR);
}

fn drawBracketMatch(
    buffer: *const TextBuffer,
    cursor_state: *const CursorState,
    line_idx: u32,
    text_x: f32,
    y: f32,
    line_height: f32,
    font_atlas: *const FontAtlas,
) void {
    const cur = cursor_state.primary().active;
    const cur_line = cur.line;
    const cur_col = cur.col;

    // Only check bracket matching on cursor line
    if (line_idx != cur_line) {
        // Check if this line has the matching bracket
        const line_text = buffer.getLine(cur_line) orelse return;
        if (cur_col >= line_text.len) return;
        const ch = line_text[cur_col];
        const match_info = findMatchingBracket(buffer, cur_line, cur_col, ch) orelse return;
        if (match_info.line != line_idx) return;
        // Draw highlight on matching bracket
        const cell_w: f32 = @floatFromInt(font_atlas.cell_w);
        const mx = text_x + @as(f32, @floatFromInt(match_info.col)) * cell_w;
        drawRect(mx, y, cell_w, line_height, BRACKET_MATCH_BG);
        return;
    }

    // On cursor line, highlight bracket at cursor
    const line_text = buffer.getLine(cur_line) orelse return;
    if (cur_col >= line_text.len) return;
    const ch = line_text[cur_col];
    if (!isBracket(ch)) return;

    const cell_w: f32 = @floatFromInt(font_atlas.cell_w);
    const bx = text_x + @as(f32, @floatFromInt(cur_col)) * cell_w;
    drawRect(bx, y, cell_w, line_height, BRACKET_MATCH_BG);
}

fn isBracket(ch: u8) bool {
    return ch == '(' or ch == ')' or ch == '[' or ch == ']' or ch == '{' or ch == '}';
}

const BracketPair = struct { close: u8, dir: i32 };

fn findMatchingBracket(buffer: *const TextBuffer, line: u32, col: u32, ch: u8) ?Position {
    const open_close: BracketPair = switch (ch) {
        '(' => .{ .close = ')', .dir = 1 },
        '[' => .{ .close = ']', .dir = 1 },
        '{' => .{ .close = '}', .dir = 1 },
        ')' => .{ .close = '(', .dir = -1 },
        ']' => .{ .close = '[', .dir = -1 },
        '}' => .{ .close = '{', .dir = -1 },
        else => return null,
    };

    var depth: i32 = 0;
    var cur_line: i32 = @intCast(line);
    var cur_col: i32 = @intCast(col);

    // Move one step in direction first
    cur_col += open_close.dir;

    var iterations: u32 = 0;
    while (iterations < 5000) : (iterations += 1) {
        if (cur_line < 0 or cur_line >= @as(i32, @intCast(buffer.line_count))) break;
        const lt = buffer.getLine(@intCast(cur_line)) orelse break;
        if (cur_col < 0 or cur_col >= @as(i32, @intCast(lt.len))) {
            // Move to next/prev line
            cur_line += open_close.dir;
            if (cur_line < 0 or cur_line >= @as(i32, @intCast(buffer.line_count))) break;
            const next_lt = buffer.getLine(@intCast(cur_line)) orelse break;
            cur_col = if (open_close.dir > 0) 0 else @as(i32, @intCast(next_lt.len)) - 1;
            continue;
        }
        const c = lt[@intCast(cur_col)];
        if (c == ch) {
            depth += 1;
        } else if (c == open_close.close) {
            if (depth == 0) {
                return .{ .line = @intCast(cur_line), .col = @intCast(cur_col) };
            }
            depth -= 1;
        }
        cur_col += open_close.dir;
    }
    return null;
}

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
