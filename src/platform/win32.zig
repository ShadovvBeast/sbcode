// src/platform/win32.zig — Core Win32 types and externs
//
// Hand-written Win32 API extern declarations. All Windows types, constants,
// and function bindings. No auto-generation, no third-party dependencies.

const std = @import("std");
const cc: std.builtin.CallingConvention = .c;

// =============================================================================
// Primitive type aliases
// =============================================================================

pub const LPARAM = isize;
pub const WPARAM = usize;
pub const LRESULT = isize;
pub const BOOL = i32;
pub const DWORD = u32;
pub const UINT = u32;
pub const LONG = i32;
pub const WORD = u16;

// =============================================================================
// Opaque handle types
// =============================================================================

pub const HWND = *opaque {};
pub const HDC = *opaque {};
pub const HGLRC = *opaque {};
pub const HINSTANCE = *opaque {};
pub const HFONT = *opaque {};
pub const HBITMAP = *opaque {};
pub const HICON = *opaque {};
pub const HANDLE = *opaque {};

// =============================================================================
// Callback types
// =============================================================================

pub const WNDPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(cc) LRESULT;

// =============================================================================
// Struct types (extern struct for ABI compatibility)
// =============================================================================

pub const WNDCLASSEXW = extern struct {
    cbSize: UINT,
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32,
    cbWndExtra: i32,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?*opaque {},
    hbrBackground: ?*opaque {},
    lpszMenuName: ?[*:0]const u16,
    lpszClassName: [*:0]const u16,
    hIconSm: ?HICON,
};

pub const MSG = extern struct {
    hwnd: ?HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
};

pub const POINT = extern struct {
    x: LONG,
    y: LONG,
};

pub const RECT = extern struct {
    left: LONG,
    top: LONG,
    right: LONG,
    bottom: LONG,
};

pub const LARGE_INTEGER = extern struct {
    QuadPart: i64,
};

pub const BITMAPINFOHEADER = extern struct {
    biSize: DWORD,
    biWidth: LONG,
    biHeight: LONG,
    biPlanes: WORD,
    biBitCount: WORD,
    biCompression: DWORD,
    biSizeImage: DWORD,
    biXPelsPerMeter: LONG,
    biYPelsPerMeter: LONG,
    biClrUsed: DWORD,
    biClrImportant: DWORD,
};

pub const RGBQUAD = extern struct {
    b: u8,
    g: u8,
    r: u8,
    reserved: u8,
};

pub const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]RGBQUAD,
};

pub const PIXELFORMATDESCRIPTOR = extern struct {
    nSize: WORD,
    nVersion: WORD,
    dwFlags: DWORD,
    iPixelType: u8,
    cColorBits: u8,
    cRedBits: u8,
    cRedShift: u8,
    cGreenBits: u8,
    cGreenShift: u8,
    cBlueBits: u8,
    cBlueShift: u8,
    cAlphaBits: u8,
    cAlphaShift: u8,
    cAccumBits: u8,
    cAccumRedBits: u8,
    cAccumGreenBits: u8,
    cAccumBlueBits: u8,
    cAccumAlphaBits: u8,
    cDepthBits: u8,
    cStencilBits: u8,
    cAuxBuffers: u8,
    iLayerType: u8,
    bReserved: u8,
    dwLayerMask: DWORD,
    dwVisibleMask: DWORD,
    dwDamageMask: DWORD,
};

// =============================================================================
// Window style constants
// =============================================================================

pub const WS_POPUP: DWORD = 0x80000000;
pub const WS_VISIBLE: DWORD = 0x10000000;
pub const WS_OVERLAPPEDWINDOW: DWORD = 0x00CF0000;
pub const WS_EX_APPWINDOW: DWORD = 0x00040000;

// =============================================================================
// Window message constants
// =============================================================================

pub const WM_DESTROY: UINT = 0x0002;
pub const WM_SIZE: UINT = 0x0005;
pub const WM_PAINT: UINT = 0x000F;
pub const WM_CLOSE: UINT = 0x0010;
pub const WM_QUIT: UINT = 0x0012;
pub const WM_NCHITTEST: UINT = 0x0084;
pub const WM_NCLBUTTONDOWN: UINT = 0x00A1;
pub const WM_KEYDOWN: UINT = 0x0100;
pub const WM_KEYUP: UINT = 0x0101;
pub const WM_CHAR: UINT = 0x0102;
pub const WM_MOUSEMOVE: UINT = 0x0200;
pub const WM_LBUTTONDOWN: UINT = 0x0201;
pub const WM_LBUTTONUP: UINT = 0x0202;
pub const WM_MOUSEWHEEL: UINT = 0x020A;

// =============================================================================
// File I/O constants
// =============================================================================

pub const GENERIC_READ: DWORD = 0x80000000;
pub const GENERIC_WRITE: DWORD = 0x40000000;
pub const CREATE_ALWAYS: DWORD = 2;
pub const OPEN_EXISTING: DWORD = 3;
pub const FILE_ATTRIBUTE_NORMAL: DWORD = 0x80;
pub const INVALID_HANDLE_VALUE: usize = @as(usize, @bitCast(@as(isize, -1)));

// =============================================================================
// PeekMessage constants
// =============================================================================

pub const PM_REMOVE: UINT = 0x0001;

// =============================================================================
// GDI constants
// =============================================================================

pub const DIB_RGB_COLORS: UINT = 0;
pub const TRANSPARENT: i32 = 1;
pub const BI_RGB: DWORD = 0;

// =============================================================================
// Virtual key constants
// =============================================================================

pub const VK_CONTROL: i32 = 0x11;
pub const VK_SHIFT: i32 = 0x10;
pub const VK_MENU: i32 = 0x12; // Alt key

// =============================================================================
// Hit-test result constants
// =============================================================================

pub const HTCAPTION: LRESULT = 2;
pub const HTCLIENT: LRESULT = 1;

// =============================================================================
// Pixel format descriptor flags
// =============================================================================

pub const PFD_DRAW_TO_WINDOW: DWORD = 0x00000004;
pub const PFD_SUPPORT_OPENGL: DWORD = 0x00000020;
pub const PFD_DOUBLEBUFFER: DWORD = 0x00000001;
pub const PFD_TYPE_RGBA: u8 = 0;
pub const PFD_MAIN_PLANE: u8 = 0;

// =============================================================================
// WinHTTP constants
// =============================================================================

pub const WINHTTP_ACCESS_TYPE_DEFAULT_PROXY: DWORD = 0;
pub const WINHTTP_NO_PROXY_NAME = null;
pub const WINHTTP_NO_PROXY_BYPASS = null;
pub const WINHTTP_FLAG_SECURE: DWORD = 0x00800000;
pub const INTERNET_DEFAULT_HTTPS_PORT: u16 = 443;
pub const INTERNET_DEFAULT_HTTP_PORT: u16 = 80;

// =============================================================================
// Comptime UTF-16 string literal helper
// =============================================================================

/// Converts an ASCII string literal to a null-terminated UTF-16 pointer at comptime.
/// Usage: `L("MyClassName")` returns `[*:0]const u16`.
pub fn L(comptime str: []const u8) *const [str.len:0]u16 {
    const buf = comptime blk: {
        var tmp: [str.len:0]u16 = undefined;
        for (str, 0..) |c, i| {
            tmp[i] = c;
        }
        break :blk tmp;
    };
    return &buf;
}

// =============================================================================
// Extern functions — user32
// =============================================================================

pub extern "user32" fn RegisterClassExW(*const WNDCLASSEXW) callconv(cc) u16;
pub extern "user32" fn CreateWindowExW(DWORD, [*:0]const u16, [*:0]const u16, DWORD, i32, i32, i32, i32, ?HWND, ?*opaque {}, HINSTANCE, ?*anyopaque) callconv(cc) ?HWND;
pub extern "user32" fn ShowWindow(HWND, i32) callconv(cc) BOOL;
pub extern "user32" fn DestroyWindow(HWND) callconv(cc) BOOL;
pub extern "user32" fn PeekMessageW(*MSG, ?HWND, UINT, UINT, UINT) callconv(cc) BOOL;
pub extern "user32" fn TranslateMessage(*const MSG) callconv(cc) BOOL;
pub extern "user32" fn DispatchMessageW(*const MSG) callconv(cc) LRESULT;
pub extern "user32" fn DefWindowProcW(HWND, UINT, WPARAM, LPARAM) callconv(cc) LRESULT;
pub extern "user32" fn PostQuitMessage(i32) callconv(cc) void;
pub extern "user32" fn GetClientRect(HWND, *RECT) callconv(cc) BOOL;
pub extern "user32" fn SetWindowPos(HWND, ?HWND, i32, i32, i32, i32, UINT) callconv(cc) BOOL;
pub extern "user32" fn GetCursorPos(*POINT) callconv(cc) BOOL;
pub extern "user32" fn ScreenToClient(HWND, *POINT) callconv(cc) BOOL;
pub extern "user32" fn GetDC(HWND) callconv(cc) ?HDC;
pub extern "user32" fn ReleaseDC(HWND, HDC) callconv(cc) i32;
pub extern "user32" fn GetKeyState(i32) callconv(cc) i16;
pub extern "user32" fn LoadImageW(?HINSTANCE, [*:0]const u16, UINT, i32, i32, UINT) callconv(cc) ?HICON;

// LoadImageW constants
pub const IMAGE_ICON: UINT = 1;
pub const LR_LOADFROMFILE: UINT = 0x0010;
pub const LR_DEFAULTSIZE: UINT = 0x0040;

// =============================================================================
// Extern functions — kernel32
// =============================================================================

pub extern "kernel32" fn GetModuleHandleW(?[*:0]const u16) callconv(cc) ?HINSTANCE;
pub extern "kernel32" fn QueryPerformanceCounter(*LARGE_INTEGER) callconv(cc) BOOL;
pub extern "kernel32" fn QueryPerformanceFrequency(*LARGE_INTEGER) callconv(cc) BOOL;
pub extern "kernel32" fn GetLastError() callconv(cc) DWORD;
pub extern "kernel32" fn CreateFileW([*:0]const u16, DWORD, DWORD, ?*anyopaque, DWORD, DWORD, ?*opaque {}) callconv(cc) ?*opaque {};
pub extern "kernel32" fn ReadFile(?*opaque {}, [*]u8, DWORD, ?*DWORD, ?*anyopaque) callconv(cc) BOOL;
pub extern "kernel32" fn WriteFile(?*opaque {}, [*]const u8, DWORD, ?*DWORD, ?*anyopaque) callconv(cc) BOOL;
pub extern "kernel32" fn CloseHandle(?*opaque {}) callconv(cc) BOOL;

// =============================================================================
// Extern functions — gdi32
// =============================================================================

pub extern "gdi32" fn CreateCompatibleDC(?HDC) callconv(cc) ?HDC;
pub extern "gdi32" fn CreateDIBSection(HDC, *const BITMAPINFO, UINT, *?*anyopaque, ?*opaque {}, DWORD) callconv(cc) ?HBITMAP;
pub extern "gdi32" fn SelectObject(HDC, *opaque {}) callconv(cc) ?*opaque {};
pub extern "gdi32" fn CreateFontW(i32, i32, i32, i32, i32, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, [*:0]const u16) callconv(cc) ?HFONT;
pub extern "gdi32" fn TextOutW(HDC, i32, i32, [*:0]const u16, i32) callconv(cc) BOOL;
pub extern "gdi32" fn DeleteDC(HDC) callconv(cc) BOOL;
pub extern "gdi32" fn DeleteObject(*opaque {}) callconv(cc) BOOL;
pub extern "gdi32" fn SetTextColor(HDC, DWORD) callconv(cc) DWORD;
pub extern "gdi32" fn SetBkMode(HDC, i32) callconv(cc) i32;
pub extern "gdi32" fn ChoosePixelFormat(HDC, *const PIXELFORMATDESCRIPTOR) callconv(cc) i32;
pub extern "gdi32" fn SetPixelFormat(HDC, i32, *const PIXELFORMATDESCRIPTOR) callconv(cc) BOOL;
pub extern "gdi32" fn SwapBuffers(HDC) callconv(cc) BOOL;

// =============================================================================
// Extern functions — winhttp
// =============================================================================

pub extern "winhttp" fn WinHttpOpen([*:0]const u16, DWORD, ?[*:0]const u16, ?[*:0]const u16, DWORD) callconv(cc) ?*opaque {};
pub extern "winhttp" fn WinHttpConnect(?*opaque {}, [*:0]const u16, u16, DWORD) callconv(cc) ?*opaque {};
pub extern "winhttp" fn WinHttpOpenRequest(?*opaque {}, [*:0]const u16, [*:0]const u16, ?[*:0]const u16, ?[*:0]const u16, ?*?[*:0]const u16, DWORD) callconv(cc) ?*opaque {};
pub extern "winhttp" fn WinHttpSendRequest(?*opaque {}, ?[*:0]const u16, DWORD, ?*anyopaque, DWORD, DWORD, usize) callconv(cc) BOOL;
pub extern "winhttp" fn WinHttpReceiveResponse(?*opaque {}, ?*anyopaque) callconv(cc) BOOL;
pub extern "winhttp" fn WinHttpReadData(?*opaque {}, [*]u8, DWORD, *DWORD) callconv(cc) BOOL;
pub extern "winhttp" fn WinHttpCloseHandle(?*opaque {}) callconv(cc) BOOL;

// =============================================================================
// Extern functions — bcrypt
// =============================================================================

pub extern "bcrypt" fn BCryptOpenAlgorithmProvider(*?*opaque {}, [*:0]const u16, ?[*:0]const u16, DWORD) callconv(cc) i32;
pub extern "bcrypt" fn BCryptHash(?*opaque {}, ?[*]u8, DWORD, [*]const u8, DWORD, [*]u8, DWORD) callconv(cc) i32;
pub extern "bcrypt" fn BCryptCloseAlgorithmProvider(?*opaque {}, DWORD) callconv(cc) i32;

// =============================================================================
// Extern functions — opengl32 (WGL)
// =============================================================================

pub extern "opengl32" fn wglCreateContext(HDC) callconv(cc) ?HGLRC;
pub extern "opengl32" fn wglMakeCurrent(HDC, ?HGLRC) callconv(cc) BOOL;
pub extern "opengl32" fn wglDeleteContext(HGLRC) callconv(cc) BOOL;

// =============================================================================
// Tests
// =============================================================================

test "L() converts ASCII to UTF-16" {
    const wide = L("Hello");
    try std.testing.expectEqual(@as(u16, 'H'), wide[0]);
    try std.testing.expectEqual(@as(u16, 'e'), wide[1]);
    try std.testing.expectEqual(@as(u16, 'l'), wide[2]);
    try std.testing.expectEqual(@as(u16, 'l'), wide[3]);
    try std.testing.expectEqual(@as(u16, 'o'), wide[4]);
    try std.testing.expectEqual(@as(u16, 0), wide[5]);
}

test "L() empty string" {
    const wide = L("");
    try std.testing.expectEqual(@as(u16, 0), wide[0]);
}

test "L() single character" {
    const wide = L("A");
    try std.testing.expectEqual(@as(u16, 0x41), wide[0]);
    try std.testing.expectEqual(@as(u16, 0), wide[1]);
}
