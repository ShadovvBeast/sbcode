// src/platform/http.zig — WinHTTP-based HTTP client (for extension marketplace, updates)
//
// Zero-allocation HTTP client using WinHTTP. All storage is stack-based.
// WinHttpCloseHandle is called on every code path (success and failure).

const std = @import("std");
const w32 = @import("win32");

// =============================================================================
// Constants
// =============================================================================

pub const MAX_RESPONSE_SIZE: u32 = 1024 * 1024; // 1 MB
pub const MAX_URL_LEN: u32 = 2048;

// =============================================================================
// Types
// =============================================================================

pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,

    /// Returns the WinHTTP method string as a null-terminated UTF-16 pointer.
    pub fn toWideString(self: HttpMethod) [*:0]const u16 {
        return switch (self) {
            .GET => w32.L("GET"),
            .POST => w32.L("POST"),
            .PUT => w32.L("PUT"),
            .DELETE => w32.L("DELETE"),
        };
    }
};

pub const HttpResponse = struct {
    body: [MAX_RESPONSE_SIZE]u8 = undefined,
    body_len: u32 = 0,
    status_code: u32 = 0,
    success: bool = false,
};

// =============================================================================
// HTTP request
// =============================================================================

/// Perform an HTTP request via WinHTTP.
///
/// Preconditions:
///   - `host` and `path` are valid null-terminated UTF-16 strings
///   - `port` is a valid port number (80, 443, etc.)
///   - For HTTPS: `use_tls` == true
///
/// Postconditions:
///   - If success: response.body[0..response.body_len] contains response body,
///     response.success == true
///   - If failure: response.success == false
///   - All WinHTTP handles (session, connection, request) are closed before return
///   - No heap allocation occurs
pub fn request(
    method: HttpMethod,
    host: [*:0]const u16,
    port: u16,
    path: [*:0]const u16,
    use_tls: bool,
    request_body: ?[]const u8,
) HttpResponse {
    var response = HttpResponse{};

    // Step 1: Open WinHTTP session
    const session = w32.WinHttpOpen(
        w32.L("SBCode/1.0"),
        w32.WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
        w32.WINHTTP_NO_PROXY_NAME,
        w32.WINHTTP_NO_PROXY_BYPASS,
        0,
    ) orelse return response;

    // Step 2: Connect to host
    const connection = w32.WinHttpConnect(
        session,
        host,
        port,
        0,
    ) orelse {
        _ = w32.WinHttpCloseHandle(session);
        return response;
    };

    // Step 3: Open request with method and optional TLS flag
    const flags: w32.DWORD = if (use_tls) w32.WINHTTP_FLAG_SECURE else 0;
    const req = w32.WinHttpOpenRequest(
        connection,
        method.toWideString(),
        path,
        null,
        null,
        null,
        flags,
    ) orelse {
        _ = w32.WinHttpCloseHandle(connection);
        _ = w32.WinHttpCloseHandle(session);
        return response;
    };

    // Step 4: Send request (with optional body for POST/PUT)
    const body_ptr: ?*anyopaque = if (request_body) |b| @ptrCast(@constCast(b.ptr)) else null;
    const body_len: w32.DWORD = if (request_body) |b| @intCast(b.len) else 0;
    if (w32.WinHttpSendRequest(req, null, 0, body_ptr, body_len, body_len, 0) == 0) {
        _ = w32.WinHttpCloseHandle(req);
        _ = w32.WinHttpCloseHandle(connection);
        _ = w32.WinHttpCloseHandle(session);
        return response;
    }

    // Step 5: Receive response
    if (w32.WinHttpReceiveResponse(req, null) == 0) {
        _ = w32.WinHttpCloseHandle(req);
        _ = w32.WinHttpCloseHandle(connection);
        _ = w32.WinHttpCloseHandle(session);
        return response;
    }

    // Step 6: Read response body in chunks
    var total_read: u32 = 0;
    while (total_read < MAX_RESPONSE_SIZE) {
        var chunk_read: w32.DWORD = 0;
        if (w32.WinHttpReadData(
            req,
            response.body[total_read..].ptr,
            MAX_RESPONSE_SIZE - total_read,
            &chunk_read,
        ) == 0) break;
        if (chunk_read == 0) break;
        total_read += chunk_read;
    }
    response.body_len = total_read;
    response.success = true;

    // Step 7: Close all handles — always
    _ = w32.WinHttpCloseHandle(req);
    _ = w32.WinHttpCloseHandle(connection);
    _ = w32.WinHttpCloseHandle(session);

    return response;
}

// =============================================================================
// Tests — struct initialization and constants only (WinHTTP externs unavailable
// in cross-compilation test environment)
// =============================================================================

test "MAX_RESPONSE_SIZE is 1 MB" {
    try std.testing.expectEqual(@as(u32, 1024 * 1024), MAX_RESPONSE_SIZE);
}

test "MAX_URL_LEN is 2048" {
    try std.testing.expectEqual(@as(u32, 2048), MAX_URL_LEN);
}

test "HttpResponse default initialization" {
    const r = HttpResponse{};
    try std.testing.expectEqual(false, r.success);
    try std.testing.expectEqual(@as(u32, 0), r.body_len);
    try std.testing.expectEqual(@as(u32, 0), r.status_code);
}

test "HttpMethod toWideString returns correct method strings" {
    // GET
    const get_str = HttpMethod.GET.toWideString();
    try std.testing.expectEqual(@as(u16, 'G'), get_str[0]);
    try std.testing.expectEqual(@as(u16, 'E'), get_str[1]);
    try std.testing.expectEqual(@as(u16, 'T'), get_str[2]);
    try std.testing.expectEqual(@as(u16, 0), get_str[3]);

    // POST
    const post_str = HttpMethod.POST.toWideString();
    try std.testing.expectEqual(@as(u16, 'P'), post_str[0]);
    try std.testing.expectEqual(@as(u16, 'O'), post_str[1]);
    try std.testing.expectEqual(@as(u16, 'S'), post_str[2]);
    try std.testing.expectEqual(@as(u16, 'T'), post_str[3]);
    try std.testing.expectEqual(@as(u16, 0), post_str[4]);

    // PUT
    const put_str = HttpMethod.PUT.toWideString();
    try std.testing.expectEqual(@as(u16, 'P'), put_str[0]);
    try std.testing.expectEqual(@as(u16, 'U'), put_str[1]);
    try std.testing.expectEqual(@as(u16, 'T'), put_str[2]);
    try std.testing.expectEqual(@as(u16, 0), put_str[3]);

    // DELETE
    const del_str = HttpMethod.DELETE.toWideString();
    try std.testing.expectEqual(@as(u16, 'D'), del_str[0]);
    try std.testing.expectEqual(@as(u16, 'E'), del_str[1]);
    try std.testing.expectEqual(@as(u16, 'L'), del_str[2]);
    try std.testing.expectEqual(@as(u16, 'E'), del_str[3]);
    try std.testing.expectEqual(@as(u16, 'T'), del_str[4]);
    try std.testing.expectEqual(@as(u16, 'E'), del_str[5]);
    try std.testing.expectEqual(@as(u16, 0), del_str[6]);
}

test "HttpMethod enum has all four methods" {
    const methods = [_]HttpMethod{ .GET, .POST, .PUT, .DELETE };
    try std.testing.expectEqual(@as(usize, 4), methods.len);
}

test "WinHTTP constants match expected values" {
    try std.testing.expectEqual(@as(w32.DWORD, 0x00800000), w32.WINHTTP_FLAG_SECURE);
    try std.testing.expectEqual(@as(w32.DWORD, 0), w32.WINHTTP_ACCESS_TYPE_DEFAULT_PROXY);
    try std.testing.expectEqual(@as(u16, 443), w32.INTERNET_DEFAULT_HTTPS_PORT);
    try std.testing.expectEqual(@as(u16, 80), w32.INTERNET_DEFAULT_HTTP_PORT);
}
