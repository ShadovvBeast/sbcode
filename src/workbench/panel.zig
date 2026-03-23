// src/workbench/panel.zig — Panel rendering (VS Code style terminal/output/problems)
//
// Draws tab bar with underline-style active indicator, terminal content,
// and proper VS Code dark theme colors and separators.
// Zero allocators — all stack/comptime storage.

const gl = @import("gl");
const FontAtlas = @import("font_atlas").FontAtlas;
const Color = @import("color").Color;
const Rect = @import("rect").Rect;
const win32 = @import("win32");

// =============================================================================
// Constants
// =============================================================================

/// Panel background color (VS Code dark theme #1E1E1E).
const PANEL_BG = Color.rgb(0x1E, 0x1E, 0x1E);

/// Tab bar background.
const PANEL_TAB_BG = Color.rgb(0x25, 0x25, 0x25);

/// Active tab text color.
const TAB_ACTIVE_COLOR = Color.rgb(0xE7, 0xE7, 0xE7);

/// Inactive tab text color.
const TAB_INACTIVE_COLOR = Color.rgb(0x96, 0x96, 0x96);

/// Active tab underline indicator color.
const TAB_UNDERLINE_COLOR = Color.rgb(0xE7, 0xE7, 0xE7);

/// Separator line color.
const SEPARATOR_COLOR = Color.rgb(0x2B, 0x2B, 0x2B);

/// Terminal text color.
const TEXT_COLOR = Color.rgb(0xCC, 0xCC, 0xCC);

/// Dimmed text color.
const DIM_COLOR = Color.rgb(0x60, 0x60, 0x60);

/// Tab bar height.
const TAB_HEIGHT: i32 = 35;

/// Tab underline height.
const UNDERLINE_H: i32 = 1;

/// Text padding.
const PAD_X: i32 = 12;
const PAD_Y: i32 = 8;

/// Panel tab labels.
const TAB_LABELS = [_][]const u8{ "PROBLEMS", "OUTPUT", "TERMINAL" };

/// Maximum number of output lines stored.
pub const MAX_OUTPUT_LINES: usize = 128;

/// Maximum length per output line.
pub const MAX_LINE_LEN: usize = 256;

/// Diagnostic severity levels for the Problems panel.
pub const DiagnosticSeverity = enum(u8) { err, warning, info, hint };

/// A single diagnostic entry (error/warning from build output).
pub const DiagnosticEntry = struct {
    severity: DiagnosticSeverity = .err,
    line: u32 = 0,
    col: u32 = 0,
    message: [MAX_LINE_LEN]u8 = undefined,
    message_len: u16 = 0,
    file_path: [260]u8 = undefined,
    file_path_len: u16 = 0,
};

/// Maximum number of diagnostic entries.
pub const MAX_DIAGNOSTICS: usize = 64;

// =============================================================================
// Panel
// =============================================================================

pub const Panel = struct {
    active_tab: u8 = 2, // TERMINAL active by default (index 2)
    lines: [MAX_OUTPUT_LINES][MAX_LINE_LEN]u8 = undefined,
    line_lens: [MAX_OUTPUT_LINES]u16 = [_]u16{0} ** MAX_OUTPUT_LINES,
    line_count: u16 = 0,
    // Terminal process handles
    process_handle: ?win32.HANDLE = null,
    stdout_read: ?win32.HANDLE = null,
    stdin_write: ?win32.HANDLE = null,
    process_running: bool = false,

    // Diagnostics for Problems panel
    diagnostics: [MAX_DIAGNOSTICS]DiagnosticEntry = [_]DiagnosticEntry{.{}} ** MAX_DIAGNOSTICS,
    diagnostic_count: u16 = 0,

    /// Spawn a terminal shell process (cmd.exe) with pipe I/O.
    pub fn spawnTerminal(self: *Panel) void {
        if (self.process_running) return;

        var sa = win32.SECURITY_ATTRIBUTES{
            .nLength = @sizeOf(win32.SECURITY_ATTRIBUTES),
            .lpSecurityDescriptor = null,
            .bInheritHandle = 1,
        };

        var stdout_read: ?win32.HANDLE = null;
        var stdout_write: ?win32.HANDLE = null;
        var stdin_read: ?win32.HANDLE = null;
        var stdin_write: ?win32.HANDLE = null;

        // CreateProcess pipe setup for terminal I/O
        if (win32.CreatePipe(&stdout_read, &stdout_write, &sa, 0) == 0) return;
        if (win32.CreatePipe(&stdin_read, &stdin_write, &sa, 0) == 0) {
            win32.CloseHandle(stdout_read);
            win32.CloseHandle(stdout_write);
            return;
        }

        // Ensure our ends are not inherited
        _ = win32.SetHandleInformation(stdout_read, win32.HANDLE_FLAG_INHERIT, 0);
        _ = win32.SetHandleInformation(stdin_write, win32.HANDLE_FLAG_INHERIT, 0);

        var si: win32.STARTUPINFOW = @import("std").mem.zeroes(win32.STARTUPINFOW);
        si.cb = @sizeOf(win32.STARTUPINFOW);
        si.dwFlags = win32.STARTF_USESTDHANDLES;
        si.hStdInput = stdin_read;
        si.hStdOutput = stdout_write;
        si.hStdError = stdout_write;

        var pi: win32.PROCESS_INFORMATION = @import("std").mem.zeroes(win32.PROCESS_INFORMATION);

        // cmd.exe as UTF-16
        var cmd_line = [_]u16{ 'c', 'm', 'd', '.', 'e', 'x', 'e', 0 };

        const ok = win32.CreateProcessW(
            null,
            &cmd_line,
            null,
            null,
            1,
            win32.CREATE_NO_WINDOW,
            null,
            null,
            &si,
            &pi,
        );

        // Close child-side handles
        win32.CloseHandle(stdout_write);
        win32.CloseHandle(stdin_read);

        if (ok != 0) {
            self.process_handle = pi.hProcess;
            win32.CloseHandle(pi.hThread);
            self.stdout_read = stdout_read;
            self.stdin_write = stdin_write;
            self.process_running = true;
            self.appendLine("Terminal started (cmd.exe)");
        } else {
            win32.CloseHandle(stdout_read);
            win32.CloseHandle(stdin_write);
        }
    }

    /// Read available output from the terminal process.
    pub fn readTerminalOutput(self: *Panel) void {
        if (!self.process_running) return;
        const handle = self.stdout_read orelse return;

        var available: win32.DWORD = 0;
        if (win32.PeekNamedPipe(handle, null, 0, null, &available, null) == 0) return;
        if (available == 0) return;

        var buf: [MAX_LINE_LEN]u8 = undefined;
        const to_read: win32.DWORD = @intCast(@min(available, MAX_LINE_LEN));
        var bytes_read: win32.DWORD = 0;
        if (win32.ReadFile(handle, &buf, to_read, &bytes_read, null) != 0 and bytes_read > 0) {
            self.appendLine(buf[0..bytes_read]);
        }
    }

    /// Write input to the terminal process.
    pub fn writeTerminalInput(self: *Panel, data: []const u8) void {
        if (!self.process_running) return;
        const handle = self.stdin_write orelse return;
        var written: win32.DWORD = 0;
        _ = win32.WriteFile(handle, data.ptr, @intCast(data.len), &written, null);
    }

    /// Append a line of output to the panel.
    pub fn appendLine(self: *Panel, text: []const u8) void {
        if (self.line_count >= MAX_OUTPUT_LINES) {
            // Shift lines up to make room
            var i: u16 = 0;
            while (i + 1 < self.line_count) : (i += 1) {
                self.lines[i] = self.lines[i + 1];
                self.line_lens[i] = self.line_lens[i + 1];
            }
            self.line_count -= 1;
        }
        const idx = self.line_count;
        const copy_len: u16 = @intCast(@min(text.len, MAX_LINE_LEN));
        @memcpy(self.lines[idx][0..copy_len], text[0..copy_len]);
        self.line_lens[idx] = copy_len;
        self.line_count += 1;
    }

    /// Clear all output lines.
    pub fn clearLines(self: *Panel) void {
        self.line_count = 0;
    }

    /// Render the panel into the given region.
    pub fn render(self: *const Panel, region: Rect, font_atlas: *const FontAtlas) void {
        // Draw background
        renderQuad(region, PANEL_BG);

        if (region.w <= 0 or region.h <= 0) return;

        const cell_h = font_atlas.cell_h;
        const cell_w = font_atlas.cell_w;
        if (cell_h <= 0 or cell_w <= 0) return;

        // Top separator line
        renderQuad(Rect{ .x = region.x, .y = region.y, .w = region.w, .h = 1 }, SEPARATOR_COLOR);

        // Draw tab bar background
        const tab_bar_rect = Rect{
            .x = region.x,
            .y = region.y + 1,
            .w = region.w,
            .h = TAB_HEIGHT,
        };
        renderQuad(tab_bar_rect, PANEL_TAB_BG);

        // Draw tab labels with underline indicator on active tab
        var tab_x = region.x + PAD_X;
        for (TAB_LABELS, 0..) |label, i| {
            const is_active = (i == self.active_tab);
            const color = if (is_active) TAB_ACTIVE_COLOR else TAB_INACTIVE_COLOR;
            const text_y = tab_bar_rect.y + @divTrunc(TAB_HEIGHT - cell_h, 2);

            font_atlas.renderText(
                label,
                @floatFromInt(tab_x),
                @floatFromInt(text_y),
                color,
            );

            const label_w = @as(i32, @intCast(label.len)) * cell_w;

            // Active tab underline
            if (is_active) {
                renderQuad(Rect{
                    .x = tab_x,
                    .y = tab_bar_rect.y + TAB_HEIGHT - UNDERLINE_H,
                    .w = label_w,
                    .h = UNDERLINE_H,
                }, TAB_UNDERLINE_COLOR);
            }

            tab_x += label_w + PAD_X * 2;
        }

        // Bottom border of tab bar
        renderQuad(Rect{
            .x = region.x,
            .y = tab_bar_rect.y + TAB_HEIGHT,
            .w = region.w,
            .h = 1,
        }, SEPARATOR_COLOR);

        // Draw output lines from state
        const content_y = tab_bar_rect.y + TAB_HEIGHT + 1 + PAD_Y;
        if (self.line_count == 0) {
            font_atlas.renderText(
                "Terminal ready",
                @floatFromInt(region.x + PAD_X),
                @floatFromInt(content_y),
                DIM_COLOR,
            );
            return;
        }

        var i: u16 = 0;
        while (i < self.line_count) : (i += 1) {
            const y = content_y + @as(i32, i) * (cell_h + 2);
            if (y + cell_h > region.y + region.h) break;

            const line = self.lines[i][0..self.line_lens[i]];
            font_atlas.renderText(
                line,
                @floatFromInt(region.x + PAD_X),
                @floatFromInt(y),
                TEXT_COLOR,
            );
        }
    }
};

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

test "Panel default initialization" {
    const panel = Panel{};
    try testing.expectEqual(@as(u8, 2), panel.active_tab);
    try testing.expectEqual(@as(u16, 0), panel.line_count);
}

test "Panel background color is #1E1E1E" {
    try testing.expectApproxEqAbs(@as(f32, 0x1E) / 255.0, PANEL_BG.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0x1E) / 255.0, PANEL_BG.g, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0x1E) / 255.0, PANEL_BG.b, 0.001);
}

test "TAB_LABELS has 3 entries" {
    try testing.expectEqual(@as(usize, 3), TAB_LABELS.len);
}

test "Panel appendLine stores lines" {
    var panel = Panel{};
    panel.appendLine("hello");
    panel.appendLine("world");
    try testing.expectEqual(@as(u16, 2), panel.line_count);
    const mem = @import("std").mem;
    try testing.expect(mem.eql(u8, "hello", panel.lines[0][0..panel.line_lens[0]]));
    try testing.expect(mem.eql(u8, "world", panel.lines[1][0..panel.line_lens[1]]));
}

test "Panel clearLines resets count" {
    var panel = Panel{};
    panel.appendLine("test");
    try testing.expectEqual(@as(u16, 1), panel.line_count);
    panel.clearLines();
    try testing.expectEqual(@as(u16, 0), panel.line_count);
}

test "Panel appendLine shifts when full" {
    var panel = Panel{};
    var i: u16 = 0;
    while (i < MAX_OUTPUT_LINES + 5) : (i += 1) {
        panel.appendLine("x");
    }
    try testing.expectEqual(@as(u16, MAX_OUTPUT_LINES), panel.line_count);
}
