// src/base/uri.zig — URI representation (replaces VS Code's URI class)

const strings = @import("strings");
pub const FixedString = strings.FixedString;

pub const UriScheme = enum {
    file,
    untitled,
    vscode_settings,
    unknown,
};

pub const Uri = struct {
    scheme: UriScheme = .file,
    path: FixedString = .{},

    pub fn fromFilePath(path: []const u8) Uri {
        return .{ .scheme = .file, .path = FixedString.fromSlice(path) };
    }
};

// --- Unit Tests ---

const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;

test "Uri default initialization" {
    const uri = Uri{};
    try expect(uri.scheme == .file);
    try expect(uri.path.len == 0);
    try expect(uri.path.asSlice().len == 0);
}

test "Uri.fromFilePath sets scheme to file and stores path" {
    const uri = Uri.fromFilePath("/home/user/file.zig");
    try expect(uri.scheme == .file);
    try expect(mem.eql(u8, uri.path.asSlice(), "/home/user/file.zig"));
}

test "Uri.fromFilePath with empty path" {
    const uri = Uri.fromFilePath("");
    try expect(uri.scheme == .file);
    try expect(uri.path.len == 0);
}

test "Uri.fromFilePath with Windows-style path" {
    const uri = Uri.fromFilePath("C:\\Users\\dev\\project\\main.zig");
    try expect(uri.scheme == .file);
    try expect(mem.eql(u8, uri.path.asSlice(), "C:\\Users\\dev\\project\\main.zig"));
}

test "Uri custom scheme" {
    const uri = Uri{ .scheme = .untitled, .path = FixedString.fromSlice("Untitled-1") };
    try expect(uri.scheme == .untitled);
    try expect(mem.eql(u8, uri.path.asSlice(), "Untitled-1"));
}

test "Uri vscode_settings scheme" {
    const uri = Uri{ .scheme = .vscode_settings, .path = FixedString.fromSlice("settings.json") };
    try expect(uri.scheme == .vscode_settings);
    try expect(mem.eql(u8, uri.path.asSlice(), "settings.json"));
}

test "Uri unknown scheme" {
    const uri = Uri{ .scheme = .unknown };
    try expect(uri.scheme == .unknown);
    try expect(uri.path.len == 0);
}

test "UriScheme enum values are distinct" {
    try expect(@intFromEnum(UriScheme.file) != @intFromEnum(UriScheme.untitled));
    try expect(@intFromEnum(UriScheme.file) != @intFromEnum(UriScheme.vscode_settings));
    try expect(@intFromEnum(UriScheme.file) != @intFromEnum(UriScheme.unknown));
    try expect(@intFromEnum(UriScheme.untitled) != @intFromEnum(UriScheme.vscode_settings));
}
