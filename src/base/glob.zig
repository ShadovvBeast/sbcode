// src/base/glob.zig — Glob pattern matching for file filters
//
// Implements glob_match with support for '*' and '?' wildcards.
// Used for file search filters and .gitignore-style patterns.
// Zero allocations — pure stack-based matching.

/// Match a glob pattern against a string.
/// Supports '*' (match any sequence) and '?' (match single char).
/// Returns true if the pattern matches the entire input string.
pub fn glob_match(pattern: []const u8, input: []const u8) bool {
    return matchImpl(pattern, input, 0, 0);
}

fn matchImpl(pattern: []const u8, input: []const u8, pi: usize, ii: usize) bool {
    var p = pi;
    var i = ii;

    while (p < pattern.len) {
        if (pattern[p] == '*') {
            p += 1;
            // Skip consecutive stars
            while (p < pattern.len and pattern[p] == '*') p += 1;
            if (p == pattern.len) return true;
            // Try matching rest of pattern at each position
            while (i <= input.len) {
                if (matchImpl(pattern, input, p, i)) return true;
                i += 1;
            }
            return false;
        } else if (pattern[p] == '?') {
            if (i >= input.len) return false;
            p += 1;
            i += 1;
        } else {
            if (i >= input.len or pattern[p] != input[i]) return false;
            p += 1;
            i += 1;
        }
    }
    return i == input.len;
}

/// Check if a filename matches any of a set of patterns.
/// Also supports wildcard_match as an alias.
pub fn wildcard_match(pattern: []const u8, input: []const u8) bool {
    return glob_match(pattern, input);
}

// =============================================================================
// Tests
// =============================================================================

const testing = @import("std").testing;

test "glob_match exact match" {
    try testing.expect(glob_match("hello", "hello"));
    try testing.expect(!glob_match("hello", "world"));
}

test "glob_match star wildcard" {
    try testing.expect(glob_match("*.zig", "main.zig"));
    try testing.expect(glob_match("src/*", "src/main.zig"));
    try testing.expect(glob_match("*", "anything"));
    try testing.expect(!glob_match("*.zig", "main.rs"));
}

test "glob_match question mark wildcard" {
    try testing.expect(glob_match("?.zig", "a.zig"));
    try testing.expect(!glob_match("?.zig", "ab.zig"));
}

test "glob_match complex patterns" {
    try testing.expect(glob_match("src/*.zig", "src/main.zig"));
    try testing.expect(glob_match("**/*.zig", "src/base/diff.zig"));
    try testing.expect(!glob_match("src/*.rs", "src/main.zig"));
}

test "glob_match empty strings" {
    try testing.expect(glob_match("", ""));
    try testing.expect(!glob_match("", "a"));
    try testing.expect(glob_match("*", ""));
}

test "wildcard_match is alias for glob_match" {
    try testing.expect(wildcard_match("*.txt", "readme.txt"));
}
