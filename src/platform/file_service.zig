// src/platform/file_service.zig — Win32 file I/O (no std lib)
//
// Zero-allocation file read/write using Win32 CreateFileW, ReadFile, WriteFile.
// All storage is stack-based. CloseHandle is called on every code path.

const std = @import("std");
const w32 = @import("win32");

// =============================================================================
// Constants
// =============================================================================

pub const MAX_FILE_SIZE: u32 = 4 * 1024 * 1024; // 4 MB
pub const MAX_PATH_LEN: u32 = 512;

// Win32 file I/O constants
const GENERIC_READ: w32.DWORD = 0x80000000;
const GENERIC_WRITE: w32.DWORD = 0x40000000;
const OPEN_EXISTING: w32.DWORD = 3;
const CREATE_ALWAYS: w32.DWORD = 2;
const FILE_SHARE_READ: w32.DWORD = 1;
const FILE_ATTRIBUTE_NORMAL: w32.DWORD = 0x80;

// =============================================================================
// Result types
// =============================================================================

pub const ReadResult = struct {
    success: bool = false,
    bytes_read: u32 = 0,
};

// =============================================================================
// File operations
// =============================================================================

/// Read entire file into caller-provided stack buffer via Win32 CreateFileW/ReadFile.
///
/// Preconditions:
///   - `path` is a valid null-terminated UTF-16 file path
///   - `out_buf` points to a caller-owned buffer of MAX_FILE_SIZE bytes
///
/// Postconditions:
///   - If success: out_buf[0..result.bytes_read] contains file content, result.success == true
///   - If failure: result.success == false, result.bytes_read == 0
///   - CloseHandle is called on all code paths where a handle was opened
///   - No heap allocation occurs
pub fn readFile(path: [*:0]const u16, out_buf: *[MAX_FILE_SIZE]u8) ReadResult {
    var result = ReadResult{};

    const handle = w32.CreateFileW(
        path,
        GENERIC_READ,
        FILE_SHARE_READ,
        null,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        null,
    );

    // CreateFileW returns null (INVALID_HANDLE_VALUE mapped to optional) on failure
    if (handle == null) return result;

    var bytes_read: w32.DWORD = 0;
    const ok = w32.ReadFile(handle, out_buf, MAX_FILE_SIZE, &bytes_read, null);

    // CloseHandle before returning — always
    _ = w32.CloseHandle(handle);

    if (ok != 0) {
        result.bytes_read = bytes_read;
        result.success = true;
    }

    return result;
}

/// Write buffer to file via Win32 CreateFileW(CREATE_ALWAYS)/WriteFile.
///
/// Preconditions:
///   - `path` is a valid null-terminated UTF-16 file path
///   - `data.len` fits in a u32
///
/// Postconditions:
///   - If success: file on disk contains exactly `data` bytes, returns true
///   - If failure: returns false
///   - CloseHandle is called on all code paths where a handle was opened
///   - bytes_written is verified to equal data.len
pub fn writeFile(path: [*:0]const u16, data: []const u8) bool {
    const handle = w32.CreateFileW(
        path,
        GENERIC_WRITE,
        0, // no sharing
        null,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        null,
    );

    if (handle == null) return false;

    var bytes_written: w32.DWORD = 0;
    const ok = w32.WriteFile(handle, data.ptr, @intCast(data.len), &bytes_written, null);

    // CloseHandle before returning — always
    _ = w32.CloseHandle(handle);

    return ok != 0 and bytes_written == @as(w32.DWORD, @intCast(data.len));
}

// =============================================================================
// Tests — struct initialization and constants only (Win32 externs unavailable
// in cross-compilation test environment)
// =============================================================================

test "MAX_FILE_SIZE is 4 MB" {
    try std.testing.expectEqual(@as(u32, 4 * 1024 * 1024), MAX_FILE_SIZE);
}

test "MAX_PATH_LEN is 512" {
    try std.testing.expectEqual(@as(u32, 512), MAX_PATH_LEN);
}

test "ReadResult default initialization" {
    const r = ReadResult{};
    try std.testing.expectEqual(false, r.success);
    try std.testing.expectEqual(@as(u32, 0), r.bytes_read);
}

test "Win32 file I/O constants match expected values" {
    try std.testing.expectEqual(@as(w32.DWORD, 0x80000000), GENERIC_READ);
    try std.testing.expectEqual(@as(w32.DWORD, 0x40000000), GENERIC_WRITE);
    try std.testing.expectEqual(@as(w32.DWORD, 3), OPEN_EXISTING);
    try std.testing.expectEqual(@as(w32.DWORD, 2), CREATE_ALWAYS);
    try std.testing.expectEqual(@as(w32.DWORD, 0x80), FILE_ATTRIBUTE_NORMAL);
}
