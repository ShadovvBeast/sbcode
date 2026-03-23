// src/workbench/status_bar.zig — Status bar rendering (VS Code style)
//
// Multi-section status bar with branch info, errors/warnings, line/col,
// spaces, encoding, language mode — matching VS Code dark theme.
// Zero allocators — all stack/comptime storage.

const gl = @import("gl");
const FontAtlas = @import("font_atlas").FontAtlas;
const Color = @import("color").Color;
const Rect = @import("rect").Rect;

// =============================================================================
// Constants
// =============================================================================

/// Status bar background color (VS Code dark theme #007ACC).
const STATUS_BAR_BG = Color.rgb(0x00, 0x7A, 0xCC);

/// Status bar text color.
const TEXT_COLOR = Color.rgb(0xFF, 0xFF, 0xFF);

/// Section separator color (slightly darker blue).
const SEPARATOR_COLOR = Color.rgb(0x00, 0x6B, 0xB3);

/// Text padding.
const PAD_X: i32 = 10;
const PAD_Y: i32 = 3;

/// Maximum language mode label length.
const MAX_LANG_LEN: usize = 32;

/// Maximum notification message length.
const MAX_NOTIFICATION_LEN: usize = 128;

/// Maximum branch name length.
const MAX_BRANCH_LEN: usize = 32;

// =============================================================================
// StatusBar
// =============================================================================

pub const StatusBar = struct {
    line: u32 = 1,
    col: u32 = 1,
    language_mode: [MAX_LANG_LEN]u8 = [_]u8{0} ** MAX_LANG_LEN,
    language_mode_len: u8 = 0,
    notification: [MAX_NOTIFICATION_LEN]u8 = [_]u8{0} ** MAX_NOTIFICATION_LEN,
    notification_len: u8 = 0,
    branch_name: [MAX_BRANCH_LEN]u8 = [_]u8{0} ** MAX_BRANCH_LEN,
    branch_name_len: u8 = 0,
    error_count: u16 = 0,
    warning_count: u16 = 0,
    tab_size: u8 = 4,
    use_spaces: bool = true,

    /// Set the language mode label.
    pub fn setLanguageMode(self: *StatusBar, mode: []const u8) void {
        const copy_len = @min(mode.len, MAX_LANG_LEN);
        @memcpy(self.language_mode[0..copy_len], mode[0..copy_len]);
        self.language_mode_len = @intCast(copy_len);
    }

    /// Set a notification message (displayed on the right side).
    pub fn setNotification(self: *StatusBar, msg: []const u8) void {
        const copy_len = @min(msg.len, MAX_NOTIFICATION_LEN);
        @memcpy(self.notification[0..copy_len], msg[0..copy_len]);
        self.notification_len = @intCast(copy_len);
    }

    /// Clear the notification message.
    pub fn clearNotification(self: *StatusBar) void {
        self.notification_len = 0;
    }

    /// Set the branch name.
    pub fn setBranch(self: *StatusBar, name: []const u8) void {
        const copy_len = @min(name.len, MAX_BRANCH_LEN);
        @memcpy(self.branch_name[0..copy_len], name[0..copy_len]);
        self.branch_name_len = @intCast(copy_len);
    }

    /// Notify that a file exceeds the maximum buffer size.
    pub fn notifyFileTooLarge(self: *StatusBar) void {
        self.setNotification("File too large (>4MB)");
    }

    /// Notify that a file read failed, including the Win32 error code.
    pub fn notifyFileReadError(self: *StatusBar, error_code: u32) void {
        var buf: [MAX_NOTIFICATION_LEN]u8 = undefined;
        const prefix = "File read failed (error: ";
        const suffix = ")";

        var pos: usize = 0;
        @memcpy(buf[pos..][0..prefix.len], prefix);
        pos += prefix.len;

        pos += writeU32(buf[pos..], error_code);

        @memcpy(buf[pos..][0..suffix.len], suffix);
        pos += suffix.len;

        self.setNotification(buf[0..pos]);
    }

    /// Notify that a buffer overflow occurred during an insert operation.
    pub fn notifyBufferOverflow(self: *StatusBar) void {
        self.setNotification("Buffer overflow \xe2\x80\x94 insert rejected");
    }

    /// Render the status bar into the given region.
    ///
    /// VS Code layout (left to right):
    ///   Left:  [branch] [errors] [warnings]
    ///   Right: [Ln X, Col Y] [Spaces: N] [UTF-8] [language] [bell]
    pub fn render(self: *const StatusBar, region: Rect, font_atlas: *const FontAtlas) void {
        // Draw background
        renderQuad(region, STATUS_BAR_BG);

        if (region.w <= 0 or region.h <= 0) return;

        const cell_w = font_atlas.cell_w;
        const cell_h = font_atlas.cell_h;
        if (cell_w <= 0) return;

        // DPI-scaled padding
        const pad_x: i32 = cell_w;
        const text_y = region.y + @divTrunc(region.h - cell_h, 2); // vertically centered

        // ---- LEFT SIDE ----
        var left_x = region.x + pad_x;

        // Branch name (with branch icon symbol)
        if (self.branch_name_len > 0) {
            font_atlas.renderText("*", @floatFromInt(left_x), @floatFromInt(text_y), TEXT_COLOR);
            left_x += cell_w + 3;
            font_atlas.renderText(
                self.branch_name[0..self.branch_name_len],
                @floatFromInt(left_x),
                @floatFromInt(text_y),
                TEXT_COLOR,
            );
            left_x += @as(i32, self.branch_name_len) * cell_w + pad_x;
        } else {
            // Default branch display
            font_atlas.renderText("* main", @floatFromInt(left_x), @floatFromInt(text_y), TEXT_COLOR);
            left_x += 6 * cell_w + pad_x;
        }

        // Error count
        var err_buf: [16]u8 = undefined;
        var err_len: usize = 0;
        err_buf[0] = 'x';
        err_len = 1;
        err_buf[err_len] = ' ';
        err_len += 1;
        err_len += writeU32(err_buf[err_len..], self.error_count);
        font_atlas.renderText(err_buf[0..err_len], @floatFromInt(left_x), @floatFromInt(text_y), TEXT_COLOR);
        left_x += @as(i32, @intCast(err_len)) * cell_w + pad_x;

        // Warning count
        var warn_buf: [16]u8 = undefined;
        var warn_len: usize = 0;
        warn_buf[0] = '!';
        warn_len = 1;
        warn_buf[warn_len] = ' ';
        warn_len += 1;
        warn_len += writeU32(warn_buf[warn_len..], self.warning_count);
        font_atlas.renderText(warn_buf[0..warn_len], @floatFromInt(left_x), @floatFromInt(text_y), TEXT_COLOR);

        // ---- RIGHT SIDE (rendered right-to-left) ----
        var right_x = region.x + region.w - pad_x;

        // Notification bell icon (rightmost)
        right_x -= cell_w;
        font_atlas.renderText("o", @floatFromInt(right_x), @floatFromInt(text_y), TEXT_COLOR);
        right_x -= pad_x;

        // Language mode
        if (self.language_mode_len > 0) {
            const lang_w = @as(i32, self.language_mode_len) * cell_w;
            right_x -= lang_w;
            font_atlas.renderText(
                self.language_mode[0..self.language_mode_len],
                @floatFromInt(right_x),
                @floatFromInt(text_y),
                TEXT_COLOR,
            );
            right_x -= pad_x;
        } else {
            // Default: "Plain Text"
            const default_lang = "Plain Text";
            const lang_w = @as(i32, @intCast(default_lang.len)) * cell_w;
            right_x -= lang_w;
            font_atlas.renderText(default_lang, @floatFromInt(right_x), @floatFromInt(text_y), TEXT_COLOR);
            right_x -= pad_x;
        }

        // Encoding: "UTF-8"
        const encoding = "UTF-8";
        const enc_w = @as(i32, @intCast(encoding.len)) * cell_w;
        right_x -= enc_w;
        font_atlas.renderText(encoding, @floatFromInt(right_x), @floatFromInt(text_y), TEXT_COLOR);
        right_x -= pad_x;

        // Spaces/Tab size: "Spaces: 4"
        var spaces_buf: [16]u8 = undefined;
        var sp_len: usize = 0;
        if (self.use_spaces) {
            const prefix = "Spaces: ";
            @memcpy(spaces_buf[0..prefix.len], prefix);
            sp_len = prefix.len;
        } else {
            const prefix = "Tab Size: ";
            @memcpy(spaces_buf[0..prefix.len], prefix);
            sp_len = prefix.len;
        }
        sp_len += writeU32(spaces_buf[sp_len..], self.tab_size);
        const sp_w = @as(i32, @intCast(sp_len)) * cell_w;
        right_x -= sp_w;
        font_atlas.renderText(spaces_buf[0..sp_len], @floatFromInt(right_x), @floatFromInt(text_y), TEXT_COLOR);
        right_x -= pad_x;

        // Line/Col: "Ln X, Col Y"
        var line_col_buf: [32]u8 = undefined;
        const line_col_len = formatLineCol(&line_col_buf, self.line, self.col);
        const lc_w = @as(i32, @intCast(line_col_len)) * cell_w;
        right_x -= lc_w;
        font_atlas.renderText(line_col_buf[0..line_col_len], @floatFromInt(right_x), @floatFromInt(text_y), TEXT_COLOR);

        // Notification overlay (centered, if present)
        if (self.notification_len > 0) {
            const notif_w = @as(i32, self.notification_len) * cell_w;
            const notif_x = region.x + @divTrunc(region.w - notif_w, 2);
            font_atlas.renderText(
                self.notification[0..self.notification_len],
                @floatFromInt(notif_x),
                @floatFromInt(text_y),
                TEXT_COLOR,
            );
        }
    }
};

// =============================================================================
// Formatting helpers
// =============================================================================

/// Format "Ln {line}, Col {col}" into the buffer. Returns the number of bytes written.
fn formatLineCol(buf: *[32]u8, line: u32, col: u32) usize {
    var pos: usize = 0;

    buf[pos] = 'L';
    pos += 1;
    buf[pos] = 'n';
    pos += 1;
    buf[pos] = ' ';
    pos += 1;

    pos += writeU32(buf[pos..], line);

    buf[pos] = ',';
    pos += 1;
    buf[pos] = ' ';
    pos += 1;
    buf[pos] = 'C';
    pos += 1;
    buf[pos] = 'o';
    pos += 1;
    buf[pos] = 'l';
    pos += 1;
    buf[pos] = ' ';
    pos += 1;

    pos += writeU32(buf[pos..], col);

    return pos;
}

/// Write a u32 as decimal digits into the buffer. Returns the number of bytes written.
fn writeU32(buf: []u8, value: u32) usize {
    if (value == 0) {
        buf[0] = '0';
        return 1;
    }

    var tmp: [10]u8 = undefined;
    var len: usize = 0;
    var v = value;
    while (v > 0) : (len += 1) {
        tmp[len] = @intCast((v % 10) + '0');
        v /= 10;
    }

    var i: usize = 0;
    while (i < len) : (i += 1) {
        buf[i] = tmp[len - 1 - i];
    }
    return len;
}

// =============================================================================
// GL rendering helper
// =============================================================================

fn renderQuad(region: Rect, color: Color) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(color.r, color.g, color.b, color.a);

    const x0: f32 = @floatFromInt(region.x);
    const y0: f32 = @floatFromInt(region.y);
    const x1: f32 = @floatFromInt(region.x + region.w);
    const y1: f32 = @floatFromInt(region.y + region.h);

    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(x0, y0);
    gl.glVertex2f(x1, y0);
    gl.glVertex2f(x1, y1);
    gl.glVertex2f(x0, y1);
    gl.glEnd();
}

// =============================================================================
// Tests
// =============================================================================

const testing = @import("std").testing;

test "StatusBar default initialization" {
    const sb = StatusBar{};
    try testing.expectEqual(@as(u32, 1), sb.line);
    try testing.expectEqual(@as(u32, 1), sb.col);
    try testing.expectEqual(@as(u8, 0), sb.language_mode_len);
    try testing.expectEqual(@as(u8, 0), sb.notification_len);
    try testing.expectEqual(@as(u8, 0), sb.branch_name_len);
    try testing.expectEqual(@as(u16, 0), sb.error_count);
    try testing.expectEqual(@as(u16, 0), sb.warning_count);
    try testing.expectEqual(@as(u8, 4), sb.tab_size);
    try testing.expectEqual(true, sb.use_spaces);
}

test "StatusBar.setLanguageMode sets mode" {
    var sb = StatusBar{};
    sb.setLanguageMode("Zig");
    try testing.expectEqual(@as(u8, 3), sb.language_mode_len);
    try testing.expect(testing.mem.eql(u8, "Zig", sb.language_mode[0..sb.language_mode_len]));
}

test "StatusBar.setNotification sets message" {
    var sb = StatusBar{};
    sb.setNotification("File saved");
    try testing.expectEqual(@as(u8, 10), sb.notification_len);
    try testing.expect(testing.mem.eql(u8, "File saved", sb.notification[0..sb.notification_len]));
}

test "StatusBar.clearNotification clears message" {
    var sb = StatusBar{};
    sb.setNotification("Error");
    try testing.expect(sb.notification_len > 0);
    sb.clearNotification();
    try testing.expectEqual(@as(u8, 0), sb.notification_len);
}

test "StatusBar.setBranch sets branch name" {
    var sb = StatusBar{};
    sb.setBranch("feature/ui");
    try testing.expectEqual(@as(u8, 10), sb.branch_name_len);
    try testing.expect(testing.mem.eql(u8, "feature/ui", sb.branch_name[0..sb.branch_name_len]));
}

test "StatusBar background color is #007ACC" {
    try testing.expectApproxEqAbs(@as(f32, 0x00) / 255.0, STATUS_BAR_BG.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0x7A) / 255.0, STATUS_BAR_BG.g, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0xCC) / 255.0, STATUS_BAR_BG.b, 0.001);
}

test "formatLineCol produces correct output" {
    var buf: [32]u8 = undefined;
    const len = formatLineCol(&buf, 42, 7);
    try testing.expect(testing.mem.eql(u8, "Ln 42, Col 7", buf[0..len]));
}

test "formatLineCol with line 1 col 1" {
    var buf: [32]u8 = undefined;
    const len = formatLineCol(&buf, 1, 1);
    try testing.expect(testing.mem.eql(u8, "Ln 1, Col 1", buf[0..len]));
}

test "writeU32 zero" {
    var buf: [10]u8 = undefined;
    const len = writeU32(&buf, 0);
    try testing.expectEqual(@as(usize, 1), len);
    try testing.expectEqual(@as(u8, '0'), buf[0]);
}

test "writeU32 multi-digit" {
    var buf: [10]u8 = undefined;
    const len = writeU32(&buf, 12345);
    try testing.expect(testing.mem.eql(u8, "12345", buf[0..len]));
}

test "StatusBar.notifyFileTooLarge sets correct message" {
    var sb = StatusBar{};
    sb.notifyFileTooLarge();
    try testing.expect(sb.notification_len > 0);
    try testing.expect(testing.mem.eql(u8, "File too large (>4MB)", sb.notification[0..sb.notification_len]));
}

test "StatusBar.notifyFileReadError formats error code" {
    var sb = StatusBar{};
    sb.notifyFileReadError(5);
    try testing.expect(sb.notification_len > 0);
    try testing.expect(testing.mem.eql(u8, "File read failed (error: 5)", sb.notification[0..sb.notification_len]));
}

test "StatusBar.notifyFileReadError formats large error code" {
    var sb = StatusBar{};
    sb.notifyFileReadError(1234);
    try testing.expect(testing.mem.eql(u8, "File read failed (error: 1234)", sb.notification[0..sb.notification_len]));
}

test "StatusBar.notifyFileReadError formats zero error code" {
    var sb = StatusBar{};
    sb.notifyFileReadError(0);
    try testing.expect(testing.mem.eql(u8, "File read failed (error: 0)", sb.notification[0..sb.notification_len]));
}

test "StatusBar.notifyBufferOverflow sets correct message" {
    var sb = StatusBar{};
    sb.notifyBufferOverflow();
    try testing.expect(sb.notification_len > 0);
    try testing.expect(testing.mem.eql(u8, "Buffer overflow \xe2\x80\x94 insert rejected", sb.notification[0..sb.notification_len]));
}

test "StatusBar notification can be cleared after error" {
    var sb = StatusBar{};
    sb.notifyFileTooLarge();
    try testing.expect(sb.notification_len > 0);
    sb.clearNotification();
    try testing.expectEqual(@as(u8, 0), sb.notification_len);
}
