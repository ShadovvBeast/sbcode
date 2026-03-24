// src/app.zig — Application lifecycle (window, GL context, font atlas, layout, timer)
//
// Pure Zig, zero dependencies, zero allocators, stack/comptime only.
// Top-level singleton managing the Win32 window, OpenGL context, font atlas,
// workbench layout, input state, and high-resolution timer.

const w32 = @import("win32");
const gl = @import("gl");
const FontAtlas = @import("font_atlas").FontAtlas;
const LayoutState = @import("layout").LayoutState;
const InputState = @import("input").InputState;
const Workbench = @import("workbench").Workbench;

// =============================================================================
// Constants
// =============================================================================

pub const DEFAULT_WIDTH: i32 = 1280;
pub const DEFAULT_HEIGHT: i32 = 720;
pub const CS_HREDRAW: u32 = 0x0002;
pub const CS_VREDRAW: u32 = 0x0001;
pub const CS_DBLCLKS: u32 = 0x0008;

// =============================================================================
// App
// =============================================================================

pub const App = struct {
    hwnd: ?w32.HWND = null,
    hdc: ?w32.HDC = null,
    hglrc: ?w32.HGLRC = null,
    font_atlas: FontAtlas = .{},
    layout: LayoutState = .{},
    input: InputState = .{},
    workbench: Workbench = .{},
    timer_freq: i64 = 0,
    timer_last: i64 = 0,
    delta_time: f64 = 0.0,
    running: bool = false,

    /// Process one frame: pump Win32 messages, compute delta time, reset input,
    /// set up GL projection, clear, and swap buffers.
    ///
    /// Preconditions:
    ///   - self.init() returned true (hwnd, hdc, hglrc are valid)
    ///   - self.running is true
    ///
    /// Postconditions:
    ///   - Per-frame input state has been reset and refilled from messages
    ///   - All pending Win32 messages have been dispatched
    ///   - self.delta_time reflects elapsed time since last tick
    ///   - One frame has been rendered (glClear + SwapBuffers)
    ///   - self.running is set to false if WM_QUIT was received
    pub fn tick(self: *App) void {
        // 1. Reset per-frame input state BEFORE pumping messages,
        //    so that WM_LBUTTONDOWN/WM_KEYDOWN etc. fill in fresh state
        //    that workbench.update() will see this frame.
        self.input.beginFrame();

        // 2. Pump all pending Win32 messages
        var msg: w32.MSG = undefined;
        while (w32.PeekMessageW(&msg, null, 0, 0, w32.PM_REMOVE) != 0) {
            if (msg.message == w32.WM_QUIT) {
                self.running = false;
                return;
            }
            _ = w32.TranslateMessage(&msg);
            _ = w32.DispatchMessageW(&msg);
        }

        // 3. Compute delta time via QueryPerformanceCounter
        var now: w32.LARGE_INTEGER = .{ .QuadPart = 0 };
        _ = w32.QueryPerformanceCounter(&now);
        if (self.timer_freq > 0) {
            self.delta_time = @as(f64, @floatFromInt(now.QuadPart - self.timer_last)) /
                @as(f64, @floatFromInt(self.timer_freq));
        }
        self.timer_last = now.QuadPart;

        // 4. Get current window dimensions for GL projection
        var rect: w32.RECT = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
        _ = w32.GetClientRect(self.hwnd.?, &rect);
        const width = rect.right - rect.left;
        const height = rect.bottom - rect.top;

        // 5. Set up GL projection and clear
        // VS Code dark theme background: #1E1E1E
        gl.glClearColor(0x1E.0 / 255.0, 0x1E.0 / 255.0, 0x1E.0 / 255.0, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        gl.glViewport(0, 0, width, height);

        gl.glMatrixMode(gl.GL_PROJECTION);
        gl.glLoadIdentity();
        gl.glOrtho(0, @floatFromInt(width), @floatFromInt(height), 0, -1, 1);

        gl.glMatrixMode(gl.GL_MODELVIEW);
        gl.glLoadIdentity();

        // 6. Update and render workbench
        self.workbench.update(&self.input, &self.layout, self.delta_time);
        self.workbench.render(&self.layout, &self.font_atlas);

        // 7. Swap buffers to present the frame
        _ = w32.SwapBuffers(self.hdc.?);
    }

    /// Initialize the application: register window class, create borderless WS_POPUP window,
    /// set up OpenGL context, initialize font atlas, layout, and timer.
    ///
    /// Returns true on success, false if wglCreateContext fails (PostQuitMessage called).
    pub fn init(self: *App) bool {
        // Enable DPI awareness for crisp rendering on high-DPI displays
        _ = w32.SetProcessDPIAware();

        // 1. Get module handle
        const hinstance = w32.GetModuleHandleW(null) orelse return false;

        // 2. Load application icon from sbcode.ico
        const icon = w32.LoadImageW(null, w32.L("src/sbcode.ico"), w32.IMAGE_ICON, 0, 0, w32.LR_LOADFROMFILE | w32.LR_DEFAULTSIZE);

        // 3. Register window class with windowProc callback
        const wc = w32.WNDCLASSEXW{
            .cbSize = @sizeOf(w32.WNDCLASSEXW),
            .style = CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS,
            .lpfnWndProc = windowProc,
            .cbClsExtra = 0,
            .cbWndExtra = 0,
            .hInstance = hinstance,
            .hIcon = icon,
            .hCursor = null,
            .hbrBackground = null,
            .lpszMenuName = null,
            .lpszClassName = w32.L("SBCode"),
            .hIconSm = icon,
        };
        _ = w32.RegisterClassExW(&wc);

        // 4. Compute window size: ~80% of screen, centered (VS Code default behavior)
        const screen_w = w32.GetSystemMetrics(w32.SM_CXSCREEN);
        const screen_h = w32.GetSystemMetrics(w32.SM_CYSCREEN);
        const win_w = if (screen_w > 0) @divTrunc(screen_w * 4, 5) else DEFAULT_WIDTH; // 80%
        const win_h = if (screen_h > 0) @divTrunc(screen_h * 4, 5) else DEFAULT_HEIGHT;
        const win_x = @divTrunc(screen_w - win_w, 2);
        const win_y = @divTrunc(screen_h - win_h, 2);

        self.hwnd = w32.CreateWindowExW(
            w32.WS_EX_APPWINDOW,
            w32.L("SBCode"),
            w32.L("SBCode"),
            w32.WS_POPUP | w32.WS_VISIBLE,
            win_x,
            win_y,
            win_w,
            win_h,
            null,
            null,
            hinstance,
            null,
        ) orelse return false;

        // 4. Get DC and set pixel format
        self.hdc = w32.GetDC(self.hwnd.?) orelse return false;

        var pfd: w32.PIXELFORMATDESCRIPTOR = .{
            .nSize = @sizeOf(w32.PIXELFORMATDESCRIPTOR),
            .nVersion = 1,
            .dwFlags = w32.PFD_DRAW_TO_WINDOW | w32.PFD_SUPPORT_OPENGL | w32.PFD_DOUBLEBUFFER,
            .iPixelType = w32.PFD_TYPE_RGBA,
            .cColorBits = 32,
            .cRedBits = 0,
            .cRedShift = 0,
            .cGreenBits = 0,
            .cGreenShift = 0,
            .cBlueBits = 0,
            .cBlueShift = 0,
            .cAlphaBits = 8,
            .cAlphaShift = 0,
            .cAccumBits = 0,
            .cAccumRedBits = 0,
            .cAccumGreenBits = 0,
            .cAccumBlueBits = 0,
            .cAccumAlphaBits = 0,
            .cDepthBits = 24,
            .cStencilBits = 8,
            .cAuxBuffers = 0,
            .iLayerType = w32.PFD_MAIN_PLANE,
            .bReserved = 0,
            .dwLayerMask = 0,
            .dwVisibleMask = 0,
            .dwDamageMask = 0,
        };

        const pixel_format = w32.ChoosePixelFormat(self.hdc.?, &pfd);
        if (pixel_format == 0) {
            w32.PostQuitMessage(1);
            return false;
        }
        _ = w32.SetPixelFormat(self.hdc.?, pixel_format, &pfd);

        // 5. Create OpenGL context — exit with PostQuitMessage if it fails
        self.hglrc = w32.wglCreateContext(self.hdc.?) orelse {
            w32.PostQuitMessage(1);
            return false;
        };
        _ = w32.wglMakeCurrent(self.hdc.?, self.hglrc);

        // 6. Enable GL_BLEND, GL_LINE_SMOOTH, set blend func
        gl.glEnable(gl.GL_BLEND);
        gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
        gl.glEnable(gl.GL_LINE_SMOOTH);

        // 7. Query DPI and compute scale factor for crisp, properly-sized UI
        const dpi = w32.GetDpiForWindow(self.hwnd.?);
        const dpi_scale: i32 = if (dpi >= 96) @intCast(dpi) else 96;

        // Scale font size: 16px base at 96 DPI
        const font_size = @divTrunc(16 * dpi_scale, 96);
        self.font_atlas.init(w32.L("Consolas"), font_size);

        // 7b. Rasterize app icon (sbcode.ico) into a GL texture for title bar rendering
        if (icon) |hicon| {
            self.workbench.icon_texture_id = rasterizeIconToTexture(hicon);
        }

        // 7c. Rasterize search icon (search.ico) into a GL texture for the search bar
        const search_icon = w32.LoadImageW(null, w32.L("src/search.ico"), w32.IMAGE_ICON, 0, 0, w32.LR_LOADFROMFILE | w32.LR_DEFAULTSIZE);
        if (search_icon) |sicon| {
            self.workbench.search_icon_texture_id = rasterizeIconToTexture(sicon);
        }

        // 7d. Rasterize folder icon (folder.ico) into a GL texture for activity bar
        const folder_icon = w32.LoadImageW(null, w32.L("src/folder.ico"), w32.IMAGE_ICON, 0, 0, w32.LR_LOADFROMFILE | w32.LR_DEFAULTSIZE);
        if (folder_icon) |ficon| {
            self.workbench.activity_bar.icon_textures[0] = rasterizeIconToTexture(ficon); // explorer
        }
        // Reuse search icon texture for activity bar search slot
        if (self.workbench.search_icon_texture_id != 0) {
            self.workbench.activity_bar.icon_textures[1] = self.workbench.search_icon_texture_id;
        }

        // 7e. Initialize file icon cache (system icons via SHGetFileInfoW)
        self.workbench.file_icon_cache.init();

        // 8. Scale layout dimensions for DPI, then recompute
        self.layout.title_bar_height = @divTrunc(30 * dpi_scale, 96);
        self.layout.activity_bar_width = @divTrunc(48 * dpi_scale, 96);
        self.layout.sidebar_width = @divTrunc(250 * dpi_scale, 96);
        self.layout.status_bar_height = @divTrunc(22 * dpi_scale, 96);
        self.layout.panel_height = @divTrunc(200 * dpi_scale, 96);
        self.layout.editor_tabs_height = @divTrunc(35 * dpi_scale, 96);
        self.layout.breadcrumbs_height = @divTrunc(22 * dpi_scale, 96);
        self.layout.minimap_width = @divTrunc(60 * dpi_scale, 96);
        self.layout.recompute(win_w, win_h);

        // 9. Initialize QueryPerformanceCounter timer
        var freq: w32.LARGE_INTEGER = .{ .QuadPart = 0 };
        _ = w32.QueryPerformanceFrequency(&freq);
        self.timer_freq = freq.QuadPart;

        var now: w32.LARGE_INTEGER = .{ .QuadPart = 0 };
        _ = w32.QueryPerformanceCounter(&now);
        self.timer_last = now.QuadPart;

        self.running = true;

        // Register default keybindings and commands
        self.workbench.registerDefaultKeybindings();
        self.workbench.registerDefaultCommands();

        // Store global pointer so windowProc can access this App instance
        setGlobalApp(self);

        // Store HWND for workbench window control operations
        const wb_mod = @import("workbench");
        wb_mod.setGlobalHwnd(self.hwnd.?);

        // Accept drag-and-drop files
        w32.DragAcceptFiles(self.hwnd.?, 1);

        return true;
    }
};

// =============================================================================
// Icon → GL texture helper
// =============================================================================

/// Rasterize an HICON into a 32×32 RGBA GL texture via GDI DIB section.
/// Returns the GL texture ID, or 0 on failure.
fn rasterizeIconToTexture(hicon: w32.HICON) gl.GLuint {
    const ICON_SZ = 32;
    const dc = w32.CreateCompatibleDC(null) orelse return 0;
    defer _ = w32.DeleteDC(dc);

    var bmi: w32.BITMAPINFO = .{
        .bmiHeader = .{
            .biSize = @sizeOf(w32.BITMAPINFOHEADER),
            .biWidth = ICON_SZ,
            .biHeight = -ICON_SZ,
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
    const bmp = w32.CreateDIBSection(dc, &bmi, w32.DIB_RGB_COLORS, &dib_bits, null, 0) orelse return 0;
    defer _ = w32.DeleteObject(@ptrCast(bmp));

    _ = w32.SelectObject(dc, @ptrCast(bmp));
    _ = w32.DrawIconEx(dc, 0, 0, hicon, ICON_SZ, ICON_SZ, 0, null, w32.DI_NORMAL);

    const bits = dib_bits orelse return 0;
    const src: [*]u8 = @ptrCast(bits);
    var rgba: [ICON_SZ * ICON_SZ * 4]u8 = undefined;
    var px: usize = 0;
    while (px < ICON_SZ * ICON_SZ) : (px += 1) {
        const off = px * 4;
        rgba[off + 0] = src[off + 2]; // R
        rgba[off + 1] = src[off + 1]; // G
        rgba[off + 2] = src[off + 0]; // B
        rgba[off + 3] = src[off + 3]; // A
    }

    var tex_id: gl.GLuint = 0;
    gl.glGenTextures(1, &tex_id);
    gl.glBindTexture(gl.GL_TEXTURE_2D, tex_id);
    gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, @intCast(gl.GL_RGBA), ICON_SZ, ICON_SZ, 0, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, @ptrCast(&rgba));
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);
    return tex_id;
}

// =============================================================================
// Global App pointer — set by init(), used by windowProc callback
// =============================================================================

var global_app: ?*App = null;

pub fn setGlobalApp(app: *App) void {
    global_app = app;
}

// =============================================================================
// Helper functions for extracting values from LPARAM/WPARAM
// =============================================================================

/// Extract low 16 bits (LOWORD macro equivalent).
inline fn loword(value: anytype) i16 {
    return @bitCast(@as(u16, @truncate(@as(usize, @bitCast(@as(isize, @intCast(value)))))));
}

/// Extract high 16 bits (HIWORD macro equivalent).
inline fn hiword(value: anytype) i16 {
    return @bitCast(@as(u16, @truncate(@as(usize, @bitCast(@as(isize, @intCast(value)))) >> 16)));
}

/// Check if a modifier key is currently held (high bit set in GetKeyState result).
inline fn isKeyDown(vk: i32) bool {
    return (w32.GetKeyState(vk) & @as(i16, -128)) != 0; // high bit = 0x8000
}

// =============================================================================
// Window procedure — handles all Win32 messages
// =============================================================================

fn windowProc(hwnd: w32.HWND, msg: w32.UINT, wparam: w32.WPARAM, lparam: w32.LPARAM) callconv(.c) w32.LRESULT {
    const app = global_app orelse return w32.DefWindowProcW(hwnd, msg, wparam, lparam);

    switch (msg) {
        // ----- Keyboard events -----
        w32.WM_KEYDOWN, w32.WM_KEYUP => {
            _ = app.input.pushKeyEvent(.{
                .vk = @truncate(wparam),
                .scancode = @truncate(@as(usize, @bitCast(@as(isize, lparam))) >> 16),
                .pressed = (msg == w32.WM_KEYDOWN),
                .ctrl = isKeyDown(w32.VK_CONTROL),
                .shift = isKeyDown(w32.VK_SHIFT),
                .alt = isKeyDown(w32.VK_MENU),
            });
            return 0;
        },

        w32.WM_CHAR => {
            // wparam contains the UTF-16 code unit; store as u8 for ASCII range
            const char: u8 = if (wparam <= 0xFF) @truncate(wparam) else '?';
            _ = app.input.pushTextInput(char);
            return 0;
        },

        // ----- Mouse events -----
        w32.WM_MOUSEMOVE => {
            const new_x: i32 = loword(lparam);
            const new_y: i32 = hiword(lparam);
            app.input.mouse_dx = new_x - app.input.mouse_x;
            app.input.mouse_dy = new_y - app.input.mouse_y;
            app.input.mouse_x = new_x;
            app.input.mouse_y = new_y;
            return 0;
        },

        w32.WM_LBUTTONDOWN => {
            app.input.left_button = true;
            app.input.left_button_pressed = true;
            return 0;
        },

        w32.WM_LBUTTONDBLCLK => {
            // Double-click: trigger word selection
            app.input.left_button = true;
            app.input.left_button_pressed = true;
            // Use the workbench's select_word at current cursor position
            const cur = app.workbench.cursor_state.primary().active;
            app.workbench.select_word(cur.line, cur.col);
            return 0;
        },

        w32.WM_LBUTTONUP => {
            app.input.left_button = false;
            app.input.left_button_released = true;
            return 0;
        },

        w32.WM_MOUSEWHEEL => {
            // Wheel delta is in the high word of wparam (GET_WHEEL_DELTA_WPARAM)
            app.input.scroll_delta = hiword(@as(isize, @bitCast(wparam)));
            return 0;
        },

        w32.WM_RBUTTONDOWN => {
            // Right-click: trigger context menu at cursor position
            app.input.right_button_pressed = true;
            return 0;
        },

        w32.WM_DROPFILES => {
            // Handle drag-and-drop files onto window
            const hdrop: ?w32.HANDLE = @ptrFromInt(wparam);
            var file_path: [260:0]u16 = [_:0]u16{0} ** 260;
            const path_ptr: ?[*:0]u16 = &file_path;
            const count = w32.DragQueryFileW(hdrop, 0, path_ptr, 260);
            if (count > 0) {
                app.workbench.openFile(@as([*:0]const u16, &file_path));
            }
            w32.DragFinish(hdrop);
            return 0;
        },

        w32.WM_NCLBUTTONDBLCLK => {
            // Double-click on title bar — maximize/restore handled by DefWindowProc
            return w32.DefWindowProcW(hwnd, msg, wparam, lparam);
        },

        // ----- Maximize constraints (keep WS_POPUP within work area) -----
        w32.WM_GETMINMAXINFO => {
            const mmi: *w32.MINMAXINFO = @ptrFromInt(@as(usize, @bitCast(lparam)));
            const monitor = w32.MonitorFromWindow(hwnd, w32.MONITOR_DEFAULTTONEAREST);
            var mi = w32.MONITORINFO{};
            mi.cbSize = @sizeOf(w32.MONITORINFO);
            if (w32.GetMonitorInfoW(monitor, &mi) != 0) {
                mmi.ptMaxPosition.x = mi.rcWork.left - mi.rcMonitor.left;
                mmi.ptMaxPosition.y = mi.rcWork.top - mi.rcMonitor.top;
                mmi.ptMaxSize.x = mi.rcWork.right - mi.rcWork.left;
                mmi.ptMaxSize.y = mi.rcWork.bottom - mi.rcWork.top;
            }
            return 0;
        },

        // ----- Layout -----
        w32.WM_SIZE => {
            const width: i32 = @as(i32, loword(lparam));
            const height: i32 = @as(i32, hiword(lparam));
            if (width > 0 and height > 0) {
                app.layout.recompute(width, height);
            }
            return 0;
        },

        // ----- Custom title bar drag and resize -----
        w32.WM_NCHITTEST => {
            const x: i32 = loword(lparam);
            const y: i32 = hiword(lparam);
            var pt = w32.POINT{ .x = x, .y = y };
            _ = w32.ScreenToClient(hwnd, &pt);

            // Edge resize zones (6px border)
            const border: i32 = 6;
            var window_rect: w32.RECT = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
            _ = w32.GetClientRect(hwnd, &window_rect);
            const w_width = window_rect.right;
            const w_height = window_rect.bottom;

            const on_left = pt.x < border;
            const on_right = pt.x >= w_width - border;
            const on_top = pt.y < border;
            const on_bottom = pt.y >= w_height - border;

            if (on_top and on_left) return w32.HTTOPLEFT;
            if (on_top and on_right) return w32.HTTOPRIGHT;
            if (on_bottom and on_left) return w32.HTBOTTOMLEFT;
            if (on_bottom and on_right) return w32.HTBOTTOMRIGHT;
            if (on_left) return w32.HTLEFT;
            if (on_right) return w32.HTRIGHT;
            if (on_top) return w32.HTTOP;
            if (on_bottom) return w32.HTBOTTOM;

            // Title bar drag zone (excluding window control buttons area on the right)
            const title_bar = app.layout.getRegion(.title_bar);
            if (title_bar.contains(pt.x, pt.y)) {
                // Menu bar labels: use cached cell_w from workbench (DPI-scaled)
                // Label chars: File(4)+Edit(4)+Selection(9)+View(4)+Go(2)+Run(3)+Terminal(8)+Help(4) = 38
                const cw = app.workbench.cell_w;
                const menu_pad: i32 = @max(cw, 10); // scale padding with font
                const menu_bar_end = cw + 38 * cw + 8 * menu_pad * 2; // left_margin + chars*cw + count*pad*2
                if (pt.x < menu_bar_end and app.workbench.menu_bar_visible) {
                    return w32.HTCLIENT; // Let menu bar clicks through as client area
                }
                // Reserve right area for close/min/max buttons (3 * scaled button width)
                const btn_area = app.layout.title_bar_height * 4; // ~4x title bar height for 3 buttons
                if (pt.x < title_bar.x + title_bar.w - btn_area) {
                    return w32.HTCAPTION;
                }
            }
            return w32.HTCLIENT;
        },

        // ----- Window lifecycle -----
        w32.WM_CLOSE => {
            // Check if buffer has unsaved changes — show custom GL dialog
            if (app.workbench.buffer.dirty) {
                app.workbench.showConfirmDialog(0); // 0 = close window action
                return 0;
            }
            _ = w32.DestroyWindow(hwnd);
            return 0;
        },

        w32.WM_DESTROY => {
            w32.PostQuitMessage(0);
            return 0;
        },

        else => {},
    }

    return w32.DefWindowProcW(hwnd, msg, wparam, lparam);
}

// =============================================================================
// Tests — minimal (Win32 externs not available in test environment)
// =============================================================================

const testing = @import("std").testing;

test "App default initialization" {
    const app = App{};
    try testing.expectEqual(@as(?w32.HWND, null), app.hwnd);
    try testing.expectEqual(@as(?w32.HDC, null), app.hdc);
    try testing.expectEqual(@as(?w32.HGLRC, null), app.hglrc);
    try testing.expectEqual(false, app.running);
    try testing.expectEqual(@as(i64, 0), app.timer_freq);
    try testing.expectEqual(@as(i64, 0), app.timer_last);
    try testing.expectEqual(@as(f64, 0.0), app.delta_time);
}

test "App.tick method exists and is callable" {
    // Verify tick is a valid method on App (can't actually call it without Win32)
    const tick_fn = @TypeOf(App.tick);
    // tick takes *App and returns void
    try testing.expect(tick_fn == *const fn (*App) void);
}

test "App constants are correct" {
    try testing.expectEqual(@as(i32, 1280), DEFAULT_WIDTH);
    try testing.expectEqual(@as(i32, 720), DEFAULT_HEIGHT);
    try testing.expectEqual(@as(u32, 0x0002), CS_HREDRAW);
    try testing.expectEqual(@as(u32, 0x0001), CS_VREDRAW);
}

test "loword extracts low 16 bits" {
    // 0x00030004 → low word = 4
    try testing.expectEqual(@as(i16, 4), loword(@as(isize, 0x00030004)));
    // Negative value: 0xFFFF → -1 as i16
    try testing.expectEqual(@as(i16, -1), loword(@as(isize, 0x0000FFFF)));
    try testing.expectEqual(@as(i16, 0), loword(@as(isize, 0)));
}

test "hiword extracts high 16 bits" {
    // 0x00030004 → high word = 3
    try testing.expectEqual(@as(i16, 3), hiword(@as(isize, 0x00030004)));
    try testing.expectEqual(@as(i16, 0), hiword(@as(isize, 0x00000004)));
    // 0xFFFF0000 → high word = -1 as i16
    try testing.expectEqual(@as(i16, -1), hiword(@as(isize, @bitCast(@as(usize, 0xFFFF0000)))));
}

test "setGlobalApp stores and clears pointer" {
    var app = App{};
    setGlobalApp(&app);
    try testing.expect(global_app != null);
    try testing.expectEqual(&app, global_app.?);

    // Reset for other tests
    global_app = null;
    try testing.expect(global_app == null);
}
