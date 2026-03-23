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

pub const OPENFILENAMEW = extern struct {
    lStructSize: DWORD,
    hwndOwner: ?HWND,
    hInstance: ?HINSTANCE,
    lpstrFilter: ?[*:0]const u16,
    lpstrCustomFilter: ?[*]u16,
    nMaxCustFilter: DWORD,
    nFilterIndex: DWORD,
    lpstrFile: [*]u16,
    nMaxFile: DWORD,
    lpstrFileTitle: ?[*]u16,
    nMaxFileTitle: DWORD,
    lpstrInitialDir: ?[*:0]const u16,
    lpstrTitle: ?[*:0]const u16,
    Flags: DWORD,
    nFileOffset: WORD,
    nFileExtension: WORD,
    lpstrDefExt: ?[*:0]const u16,
    lCustData: LPARAM,
    lpfnHook: ?*anyopaque,
    lpTemplateName: ?[*:0]const u16,
    pvReserved: ?*anyopaque,
    dwReserved: DWORD,
    FlagsEx: DWORD,
};

pub const OFN_FILEMUSTEXIST: DWORD = 0x00001000;
pub const OFN_PATHMUSTEXIST: DWORD = 0x00000800;
pub const OFN_NOCHANGEDIR: DWORD = 0x00000008;

pub const SECURITY_ATTRIBUTES = extern struct {
    nLength: DWORD,
    lpSecurityDescriptor: ?*anyopaque,
    bInheritHandle: BOOL,
};

pub const STARTUPINFOW = extern struct {
    cb: DWORD,
    lpReserved: ?[*:0]u16,
    lpDesktop: ?[*:0]u16,
    lpTitle: ?[*:0]u16,
    dwX: DWORD,
    dwY: DWORD,
    dwXSize: DWORD,
    dwYSize: DWORD,
    dwXCountChars: DWORD,
    dwYCountChars: DWORD,
    dwFillAttribute: DWORD,
    dwFlags: DWORD,
    wShowWindow: WORD,
    cbReserved2: WORD,
    lpReserved2: ?*u8,
    hStdInput: ?HANDLE,
    hStdOutput: ?HANDLE,
    hStdError: ?HANDLE,
};

pub const PROCESS_INFORMATION = extern struct {
    hProcess: ?HANDLE,
    hThread: ?HANDLE,
    dwProcessId: DWORD,
    dwThreadId: DWORD,
};

pub const STARTF_USESTDHANDLES: DWORD = 0x00000100;
pub const CREATE_NO_WINDOW: DWORD = 0x08000000;
pub const HANDLE_FLAG_INHERIT: DWORD = 0x00000001;

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
pub const HTLEFT: LRESULT = 10;
pub const HTRIGHT: LRESULT = 11;
pub const HTTOP: LRESULT = 12;
pub const HTTOPLEFT: LRESULT = 13;
pub const HTTOPRIGHT: LRESULT = 14;
pub const HTBOTTOM: LRESULT = 15;
pub const HTBOTTOMLEFT: LRESULT = 16;
pub const HTBOTTOMRIGHT: LRESULT = 17;

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
pub extern "user32" fn DrawIconEx(?HDC, i32, i32, ?HICON, i32, i32, UINT, ?*opaque {}, UINT) callconv(cc) BOOL;
pub const DI_NORMAL: UINT = 0x0003;
pub extern "user32" fn PostMessageW(HWND, UINT, WPARAM, LPARAM) callconv(cc) BOOL;
pub extern "user32" fn GetWindowRect(HWND, *RECT) callconv(cc) BOOL;
pub const HMONITOR = *opaque {};
pub extern "user32" fn MonitorFromWindow(HWND, DWORD) callconv(cc) ?HMONITOR;
pub extern "user32" fn GetMonitorInfoW(?HMONITOR, *MONITORINFO) callconv(cc) BOOL;
pub extern "user32" fn SetProcessDPIAware() callconv(cc) BOOL;
pub extern "user32" fn GetSystemMetrics(i32) callconv(cc) i32;

pub const SM_CXSCREEN: i32 = 0;
pub const SM_CYSCREEN: i32 = 1;

pub extern "user32" fn GetDpiForWindow(HWND) callconv(cc) UINT;

pub const MONITOR_DEFAULTTONEAREST: DWORD = 0x00000002;

pub const MONITORINFO = extern struct {
    cbSize: DWORD = @sizeOf(MONITORINFO),
    rcMonitor: RECT = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 },
    rcWork: RECT = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 },
    dwFlags: DWORD = 0,
};

pub const MINMAXINFO = extern struct {
    ptReserved: POINT = .{ .x = 0, .y = 0 },
    ptMaxSize: POINT = .{ .x = 0, .y = 0 },
    ptMaxPosition: POINT = .{ .x = 0, .y = 0 },
    ptMinTrackSize: POINT = .{ .x = 0, .y = 0 },
    ptMaxTrackSize: POINT = .{ .x = 0, .y = 0 },
};

pub const WM_GETMINMAXINFO: UINT = 0x0024;

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
pub extern "kernel32" fn GetCurrentDirectoryW(DWORD, [*]u16) callconv(cc) DWORD;
pub extern "kernel32" fn CreateFileW([*:0]const u16, DWORD, DWORD, ?*anyopaque, DWORD, DWORD, ?HANDLE) callconv(cc) ?HANDLE;
pub extern "kernel32" fn ReadFile(?HANDLE, [*]u8, DWORD, ?*DWORD, ?*anyopaque) callconv(cc) BOOL;
pub extern "kernel32" fn WriteFile(?HANDLE, [*]const u8, DWORD, ?*DWORD, ?*anyopaque) callconv(cc) BOOL;
pub extern "kernel32" fn CloseHandle(?HANDLE) callconv(cc) BOOL;
pub extern "kernel32" fn CreateProcessW(?[*:0]const u16, ?[*:0]u16, ?*anyopaque, ?*anyopaque, BOOL, DWORD, ?*anyopaque, ?[*:0]const u16, *STARTUPINFOW, *PROCESS_INFORMATION) callconv(cc) BOOL;
pub extern "kernel32" fn CreatePipe(*?HANDLE, *?HANDLE, ?*SECURITY_ATTRIBUTES, DWORD) callconv(cc) BOOL;
pub extern "kernel32" fn PeekNamedPipe(?HANDLE, ?[*]u8, DWORD, ?*DWORD, ?*DWORD, ?*DWORD) callconv(cc) BOOL;
pub extern "kernel32" fn TerminateProcess(?HANDLE, UINT) callconv(cc) BOOL;
pub extern "kernel32" fn SetHandleInformation(?HANDLE, DWORD, DWORD) callconv(cc) BOOL;

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
// Extern functions — comdlg32
// =============================================================================

pub extern "comdlg32" fn GetOpenFileNameW(*OPENFILENAMEW) callconv(cc) BOOL;
pub extern "comdlg32" fn GetSaveFileNameW(*OPENFILENAMEW) callconv(cc) BOOL;

// =============================================================================
// Clipboard constants and functions
// =============================================================================

pub const CF_UNICODETEXT: UINT = 13;

pub extern "user32" fn OpenClipboard(?HWND) callconv(cc) BOOL;
pub extern "user32" fn CloseClipboard() callconv(cc) BOOL;
pub extern "user32" fn EmptyClipboard() callconv(cc) BOOL;
pub extern "user32" fn GetClipboardData(UINT) callconv(cc) ?HANDLE;
pub extern "user32" fn SetClipboardData(UINT, ?HANDLE) callconv(cc) ?HANDLE;
pub extern "kernel32" fn GlobalAlloc(UINT, usize) callconv(cc) ?HANDLE;
pub extern "kernel32" fn GlobalLock(?HANDLE) callconv(cc) ?[*]u8;
pub extern "kernel32" fn GlobalUnlock(?HANDLE) callconv(cc) BOOL;
pub extern "kernel32" fn GlobalFree(?HANDLE) callconv(cc) ?HANDLE;
pub const GMEM_MOVEABLE: UINT = 0x0002;

// =============================================================================
// MessageBox constants and functions
// =============================================================================

pub const MB_YESNOCANCEL: UINT = 0x00000003;
pub const MB_ICONWARNING: UINT = 0x00000030;
pub const IDYES: i32 = 6;
pub const IDNO: i32 = 7;
pub const IDCANCEL: i32 = 2;

pub extern "user32" fn MessageBoxW(?HWND, [*:0]const u16, [*:0]const u16, UINT) callconv(cc) i32;

// =============================================================================
// ShowWindow constants
// =============================================================================

pub const SW_MINIMIZE: i32 = 6;
pub const SW_MAXIMIZE: i32 = 3;
pub const SW_RESTORE: i32 = 9;
pub const SC_CLOSE: WPARAM = 0xF060;
pub const SC_MINIMIZE: WPARAM = 0xF020;
pub const SC_MAXIMIZE: WPARAM = 0xF030;
pub const SC_RESTORE: WPARAM = 0xF120;
pub const WM_SYSCOMMAND: UINT = 0x0112;

pub extern "user32" fn IsZoomed(HWND) callconv(cc) BOOL;

// =============================================================================
// FindFirstFile / FindNextFile for directory listing
// =============================================================================

pub const FILETIME = extern struct {
    dwLowDateTime: DWORD,
    dwHighDateTime: DWORD,
};

pub const WIN32_FIND_DATAW = extern struct {
    dwFileAttributes: DWORD,
    ftCreationTime: FILETIME,
    ftLastAccessTime: FILETIME,
    ftLastWriteTime: FILETIME,
    nFileSizeHigh: DWORD,
    nFileSizeLow: DWORD,
    dwReserved0: DWORD,
    dwReserved1: DWORD,
    cFileName: [260]u16,
    cAlternateFileName: [14]u16,
};

pub const FILE_ATTRIBUTE_DIRECTORY: DWORD = 0x10;
pub const INVALID_HANDLE: usize = @as(usize, @bitCast(@as(isize, -1)));

pub extern "kernel32" fn FindFirstFileW([*:0]const u16, *WIN32_FIND_DATAW) callconv(cc) ?HANDLE;
pub extern "kernel32" fn FindNextFileW(?HANDLE, *WIN32_FIND_DATAW) callconv(cc) BOOL;
pub extern "kernel32" fn FindClose(?HANDLE) callconv(cc) BOOL;

// =============================================================================
// Additional window messages
// =============================================================================

pub const WM_RBUTTONDOWN: UINT = 0x0204;
pub const WM_LBUTTONDBLCLK: UINT = 0x0203;
pub const WM_DROPFILES: UINT = 0x0233;
pub const WM_NCLBUTTONDBLCLK: UINT = 0x00A3;

// OFN flags for Save dialog
pub const OFN_OVERWRITEPROMPT: DWORD = 0x00000002;

// =============================================================================
// Shell drag-and-drop APIs
// =============================================================================

pub extern "shell32" fn DragAcceptFiles(HWND, BOOL) callconv(cc) void;
pub extern "shell32" fn DragQueryFileW(?HANDLE, UINT, ?[*:0]u16, UINT) callconv(cc) UINT;
pub extern "shell32" fn DragFinish(?HANDLE) callconv(cc) void;

// =============================================================================
// File system watcher APIs
// =============================================================================

pub extern "kernel32" fn FindFirstChangeNotificationW([*:0]const u16, BOOL, DWORD) callconv(cc) ?HANDLE;
pub extern "kernel32" fn FindNextChangeNotification(?HANDLE) callconv(cc) BOOL;
pub extern "kernel32" fn FindCloseChangeNotification(?HANDLE) callconv(cc) BOOL;
pub extern "kernel32" fn ReadDirectoryChangesW(?HANDLE, [*]u8, DWORD, BOOL, DWORD, ?*DWORD, ?*anyopaque, ?*anyopaque) callconv(cc) BOOL;

pub const FILE_NOTIFY_CHANGE_FILE_NAME: DWORD = 0x00000001;
pub const FILE_NOTIFY_CHANGE_LAST_WRITE: DWORD = 0x00000010;

// =============================================================================
// Context menu APIs
// =============================================================================

pub extern "user32" fn CreatePopupMenu() callconv(cc) ?HMENU;
pub extern "user32" fn AppendMenuW(?HMENU, UINT, usize, ?[*:0]const u16) callconv(cc) BOOL;
pub extern "user32" fn TrackPopupMenu(?HMENU, UINT, i32, i32, i32, HWND, ?*const RECT) callconv(cc) BOOL;
pub extern "user32" fn DestroyMenu(?HMENU) callconv(cc) BOOL;

pub const HMENU = *opaque {};
pub const MF_STRING: UINT = 0x00000000;
pub const MF_SEPARATOR: UINT = 0x00000800;
pub const MF_GRAYED: UINT = 0x00000001;
pub const MF_POPUP: UINT = 0x00000010;
pub const MF_CHECKED: UINT = 0x00000008;
pub const TPM_RETURNCMD: UINT = 0x0100;
pub const TPM_LEFTALIGN: UINT = 0x0000;
pub const TPM_TOPALIGN: UINT = 0x0000;

pub extern "user32" fn ClientToScreen(HWND, *POINT) callconv(cc) BOOL;

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
