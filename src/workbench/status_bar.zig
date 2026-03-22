// src/workbench/status_bar.zig — Status bar rendering stub
//
// Displays line/col info, language mode text, and a notification message area
// in the status bar region using GL immediate mode.
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

/// Text padding.
const PAD_X: i32 = 10;
const PAD_Y: i32 = 3;

/// Maximum language mode label length.
const MAX_LANG_LEN: usize = 32;

/// Maximum notification message length.
const MAX_NOTIFICATION_LEN: usize = 128;

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

    /// Notify that a file exceeds the maximum buffer size.
    pub fn notifyFileTooLarge(self: *StatusBar) void {
        self.setNotification("File too large (>4MB)");
    }

    /// Notify that a file read failed, including the Win32 error code.
    pub fn notifyFileReadError(self: *StatusBar, error_code: u32) void {
        // Build "File read failed (error: XXXX)" into a stack buffer
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
    /// Preconditions:
    ///   - `region` is the status_bar layout rectangle
    ///   - `font_atlas` is initialized with a valid texture
    ///
    /// Postconditions:
    ///   - Background is drawn for the entire status bar
    ///   - "Ln X, Col Y" text is rendered on the left
    ///   - Language mode is rendered in the center-right area
    ///   - Notification message (if any) is rendered on the right
    pub fn render(self: *const StatusBar, region: Rect, font_atlas: *const FontAtlas) void {
        // Draw background
        renderQuad(region, STATUS_BAR_BG);

        if (region.w <= 0 or region.h <= 0) return;

        const cell_w = font_atlas.cell_w;
        if (cell_w <= 0) return;

        // Format "Ln X, Col Y" into a stack buffer
        var line_col_buf: [32]u8 = undefined;
        const line_col_len = formatLineCol(&line_col_buf, self.line, self.col);

        // Render line/col on the left
        font_atlas.renderText(
            line_col_buf[0..line_col_len],
            @floatFromInt(region.x + PAD_X),
            @floatFromInt(region.y + PAD_Y),
            TEXT_COLOR,
        );

        // Render language mode in the center-right
        if (self.language_mode_len > 0) {
            const lang_x = region.x + region.w - @as(i32, self.language_mode_len) * cell_w - PAD_X * 2;
            font_atlas.renderText(
                self.language_mode[0..self.language_mode_len],
                @floatFromInt(lang_x),
                @floatFromInt(region.y + PAD_Y),
                TEXT_COLOR,
            );
        }

        // Render notification in the center
        if (self.notification_len > 0) {
            const notif_x = region.x + @divTrunc(region.w, 3);
            font_atlas.renderText(
                self.notification[0..self.notification_len],
                @floatFromInt(notif_x),
                @floatFromInt(region.y + PAD_Y),
                TEXT_COLOR,
            );
        }
    }
};

// =============================================================================
// Formatting helper
// =============================================================================

/// Format "Ln {line}, Col {col}" into the buffer. Returns the number of bytes written.
fn formatLineCol(buf: *[32]u8, line: u32, col: u32) usize {
    var pos: usize = 0;

    // "Ln "
    buf[pos] = 'L';
    pos += 1;
    buf[pos] = 'n';
    pos += 1;
    buf[pos] = ' ';
    pos += 1;

    // Line number
    pos += writeU32(buf[pos..], line);

    // ", Col "
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

    // Col number
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

    // Reverse into output buffer
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
