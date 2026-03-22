// src/base/json.zig — Stack-based JSON tokenizer and value access
// Zero-allocation JSON parser for config.json and settings files.
// Operates on a fixed token buffer with recursive descent parsing.

pub const MAX_TOKENS = 512;
pub const MAX_DEPTH = 32;

pub const TokenType = enum {
    object_start,
    object_end,
    array_start,
    array_end,
    string,
    number,
    bool_true,
    bool_false,
    null_val,
    colon,
    comma,
};

pub const Token = struct {
    kind: TokenType,
    start: usize, // byte offset into source
    len: usize,
};

pub const JsonParser = struct {
    tokens: [MAX_TOKENS]Token = undefined,
    token_count: usize = 0,
    source: []const u8 = &.{},

    /// Parse JSON source into token array. Returns false on malformed input.
    pub fn parse(self: *JsonParser, src: []const u8) bool {
        self.source = src;
        self.token_count = 0;
        var pos: usize = 0;
        if (!self.parseValue(&pos)) return false;
        self.skipWhitespace(&pos);
        // Ensure no trailing non-whitespace content
        return pos == src.len;
    }

    /// Lookup a string value by dot-separated key path (e.g., "editor.fontSize")
    pub fn getString(self: *const JsonParser, key_path: []const u8) ?[]const u8 {
        const tok_idx = self.findByKeyPath(key_path) orelse return null;
        const tok = self.tokens[tok_idx];
        if (tok.kind != .string) return null;
        // Return the string content without quotes
        return self.source[tok.start + 1 .. tok.start + tok.len - 1];
    }

    /// Lookup a numeric value by dot-separated key path
    pub fn getNumber(self: *const JsonParser, key_path: []const u8) ?f64 {
        const tok_idx = self.findByKeyPath(key_path) orelse return null;
        const tok = self.tokens[tok_idx];
        if (tok.kind != .number) return null;
        const num_str = self.source[tok.start .. tok.start + tok.len];
        return parseFloat(num_str);
    }

    /// Lookup a boolean value by dot-separated key path
    pub fn getBool(self: *const JsonParser, key_path: []const u8) ?bool {
        const tok_idx = self.findByKeyPath(key_path) orelse return null;
        const tok = self.tokens[tok_idx];
        return switch (tok.kind) {
            .bool_true => true,
            .bool_false => false,
            else => null,
        };
    }

    /// Serialize parsed JSON back into valid JSON text.
    /// Returns the serialized slice, or null if buffer too small.
    pub fn serialize(self: *const JsonParser, buf: []u8) ?[]const u8 {
        var out: usize = 0;
        var i: usize = 0;
        while (i < self.token_count) {
            const tok = self.tokens[i];
            switch (tok.kind) {
                .object_start => {
                    if (!appendChar(buf, &out, '{')) return null;
                },
                .object_end => {
                    if (!appendChar(buf, &out, '}')) return null;
                },
                .array_start => {
                    if (!appendChar(buf, &out, '[')) return null;
                },
                .array_end => {
                    if (!appendChar(buf, &out, ']')) return null;
                },
                .colon => {
                    if (!appendChar(buf, &out, ':')) return null;
                },
                .comma => {
                    if (!appendChar(buf, &out, ',')) return null;
                },
                .string, .number, .bool_true, .bool_false, .null_val => {
                    const slice = self.source[tok.start .. tok.start + tok.len];
                    if (!appendSlice(buf, &out, slice)) return null;
                },
            }
            i += 1;
        }
        return buf[0..out];
    }

    // ---- Internal parsing methods ----

    fn addToken(self: *JsonParser, kind: TokenType, start: usize, len: usize) bool {
        if (self.token_count >= MAX_TOKENS) return false;
        self.tokens[self.token_count] = .{ .kind = kind, .start = start, .len = len };
        self.token_count += 1;
        return true;
    }

    fn skipWhitespace(self: *const JsonParser, pos: *usize) void {
        while (pos.* < self.source.len) {
            const c = self.source[pos.*];
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                pos.* += 1;
            } else {
                break;
            }
        }
    }

    fn parseValue(self: *JsonParser, pos: *usize) bool {
        self.skipWhitespace(pos);
        if (pos.* >= self.source.len) return false;

        const c = self.source[pos.*];
        return switch (c) {
            '{' => self.parseObject(pos),
            '[' => self.parseArray(pos),
            '"' => self.parseString(pos),
            '-', '0'...'9' => self.parseNumber(pos),
            't' => self.parseLiteral(pos, "true", .bool_true),
            'f' => self.parseLiteral(pos, "false", .bool_false),
            'n' => self.parseLiteral(pos, "null", .null_val),
            else => false,
        };
    }

    fn parseObject(self: *JsonParser, pos: *usize) bool {
        if (pos.* >= self.source.len or self.source[pos.*] != '{') return false;
        if (!self.addToken(.object_start, pos.*, 1)) return false;
        pos.* += 1;

        self.skipWhitespace(pos);
        if (pos.* < self.source.len and self.source[pos.*] == '}') {
            if (!self.addToken(.object_end, pos.*, 1)) return false;
            pos.* += 1;
            return true;
        }

        while (true) {
            self.skipWhitespace(pos);
            // Expect string key
            if (pos.* >= self.source.len or self.source[pos.*] != '"') return false;
            if (!self.parseString(pos)) return false;

            // Expect colon
            self.skipWhitespace(pos);
            if (pos.* >= self.source.len or self.source[pos.*] != ':') return false;
            if (!self.addToken(.colon, pos.*, 1)) return false;
            pos.* += 1;

            // Expect value
            if (!self.parseValue(pos)) return false;

            self.skipWhitespace(pos);
            if (pos.* >= self.source.len) return false;

            if (self.source[pos.*] == ',') {
                if (!self.addToken(.comma, pos.*, 1)) return false;
                pos.* += 1;
            } else if (self.source[pos.*] == '}') {
                if (!self.addToken(.object_end, pos.*, 1)) return false;
                pos.* += 1;
                return true;
            } else {
                return false;
            }
        }
    }

    fn parseArray(self: *JsonParser, pos: *usize) bool {
        if (pos.* >= self.source.len or self.source[pos.*] != '[') return false;
        if (!self.addToken(.array_start, pos.*, 1)) return false;
        pos.* += 1;

        self.skipWhitespace(pos);
        if (pos.* < self.source.len and self.source[pos.*] == ']') {
            if (!self.addToken(.array_end, pos.*, 1)) return false;
            pos.* += 1;
            return true;
        }

        while (true) {
            if (!self.parseValue(pos)) return false;

            self.skipWhitespace(pos);
            if (pos.* >= self.source.len) return false;

            if (self.source[pos.*] == ',') {
                if (!self.addToken(.comma, pos.*, 1)) return false;
                pos.* += 1;
            } else if (self.source[pos.*] == ']') {
                if (!self.addToken(.array_end, pos.*, 1)) return false;
                pos.* += 1;
                return true;
            } else {
                return false;
            }
        }
    }

    fn parseString(self: *JsonParser, pos: *usize) bool {
        if (pos.* >= self.source.len or self.source[pos.*] != '"') return false;
        const start = pos.*;
        pos.* += 1; // skip opening quote

        while (pos.* < self.source.len) {
            const c = self.source[pos.*];
            if (c == '\\') {
                pos.* += 1; // skip backslash
                if (pos.* >= self.source.len) return false;
                const esc = self.source[pos.*];
                switch (esc) {
                    '"', '\\', '/', 'b', 'f', 'n', 'r', 't' => {
                        pos.* += 1;
                    },
                    'u' => {
                        // Expect 4 hex digits
                        pos.* += 1;
                        var j: usize = 0;
                        while (j < 4) : (j += 1) {
                            if (pos.* >= self.source.len) return false;
                            const h = self.source[pos.*];
                            if (!isHexDigit(h)) return false;
                            pos.* += 1;
                        }
                    },
                    else => return false,
                }
            } else if (c == '"') {
                pos.* += 1; // skip closing quote
                return self.addToken(.string, start, pos.* - start);
            } else if (c < 0x20) {
                // Control characters not allowed in strings
                return false;
            } else {
                pos.* += 1;
            }
        }
        return false; // unterminated string
    }

    fn parseNumber(self: *JsonParser, pos: *usize) bool {
        const start = pos.*;

        // Optional minus
        if (pos.* < self.source.len and self.source[pos.*] == '-') {
            pos.* += 1;
        }

        // Integer part
        if (pos.* >= self.source.len) return false;
        if (self.source[pos.*] == '0') {
            pos.* += 1;
        } else if (self.source[pos.*] >= '1' and self.source[pos.*] <= '9') {
            pos.* += 1;
            while (pos.* < self.source.len and self.source[pos.*] >= '0' and self.source[pos.*] <= '9') {
                pos.* += 1;
            }
        } else {
            return false;
        }

        // Fractional part
        if (pos.* < self.source.len and self.source[pos.*] == '.') {
            pos.* += 1;
            if (pos.* >= self.source.len or self.source[pos.*] < '0' or self.source[pos.*] > '9') return false;
            while (pos.* < self.source.len and self.source[pos.*] >= '0' and self.source[pos.*] <= '9') {
                pos.* += 1;
            }
        }

        // Exponent part
        if (pos.* < self.source.len and (self.source[pos.*] == 'e' or self.source[pos.*] == 'E')) {
            pos.* += 1;
            if (pos.* < self.source.len and (self.source[pos.*] == '+' or self.source[pos.*] == '-')) {
                pos.* += 1;
            }
            if (pos.* >= self.source.len or self.source[pos.*] < '0' or self.source[pos.*] > '9') return false;
            while (pos.* < self.source.len and self.source[pos.*] >= '0' and self.source[pos.*] <= '9') {
                pos.* += 1;
            }
        }

        if (pos.* == start) return false;
        return self.addToken(.number, start, pos.* - start);
    }

    fn parseLiteral(self: *JsonParser, pos: *usize, expected: []const u8, kind: TokenType) bool {
        const start = pos.*;
        if (pos.* + expected.len > self.source.len) return false;
        for (expected) |ch| {
            if (self.source[pos.*] != ch) return false;
            pos.* += 1;
        }
        return self.addToken(kind, start, expected.len);
    }

    // ---- Key-path lookup internals ----

    /// Find the token index of the value at the given dot-separated key path.
    /// Returns the token index of the value, or null if not found.
    fn findByKeyPath(self: *const JsonParser, key_path: []const u8) ?usize {
        // Start from the root, which must be an object
        if (self.token_count == 0) return null;
        if (self.tokens[0].kind != .object_start) return null;

        var current_obj_idx: usize = 0;
        var path_pos: usize = 0;

        while (path_pos <= key_path.len) {
            // Extract next segment
            const seg_start = path_pos;
            while (path_pos < key_path.len and key_path[path_pos] != '.') {
                path_pos += 1;
            }
            const segment = key_path[seg_start..path_pos];
            if (segment.len == 0) return null;

            // Skip the dot separator
            if (path_pos < key_path.len) {
                path_pos += 1;
            }

            // Search for the key in the current object
            const value_idx = self.findKeyInObject(current_obj_idx, segment) orelse return null;

            // If there are more segments, the value must be an object
            if (path_pos <= key_path.len and seg_start + segment.len < key_path.len) {
                if (self.tokens[value_idx].kind != .object_start) return null;
                current_obj_idx = value_idx;
            } else {
                return value_idx;
            }
        }
        return null;
    }

    /// Find a key within an object starting at obj_start_idx.
    /// Returns the token index of the value associated with the key.
    fn findKeyInObject(self: *const JsonParser, obj_start_idx: usize, key: []const u8) ?usize {
        if (obj_start_idx >= self.token_count) return null;
        if (self.tokens[obj_start_idx].kind != .object_start) return null;

        var i = obj_start_idx + 1;
        var depth: usize = 0;

        while (i < self.token_count) {
            const tok = self.tokens[i];

            if (depth == 0) {
                if (tok.kind == .object_end) return null; // end of this object

                // At depth 0, expect key (string), colon, value pattern
                if (tok.kind == .string) {
                    // Compare key content (without quotes)
                    const key_content = self.source[tok.start + 1 .. tok.start + tok.len - 1];
                    if (strEql(key_content, key)) {
                        // Next should be colon, then value
                        if (i + 2 < self.token_count and self.tokens[i + 1].kind == .colon) {
                            return i + 2;
                        }
                        return null;
                    }
                    // Skip past this key: colon, then skip the value
                    if (i + 2 >= self.token_count) return null;
                    if (self.tokens[i + 1].kind != .colon) return null;
                    i = i + 2;
                    // Now skip the value
                    i = self.skipValue(i) orelse return null;
                    // After skipping value, we might see comma or object_end
                    if (i < self.token_count and self.tokens[i].kind == .comma) {
                        i += 1;
                    }
                    continue;
                } else if (tok.kind == .comma) {
                    i += 1;
                    continue;
                } else {
                    return null;
                }
            } else {
                // Inside nested structure, just skip
                if (tok.kind == .object_start or tok.kind == .array_start) {
                    depth += 1;
                } else if (tok.kind == .object_end or tok.kind == .array_end) {
                    depth -= 1;
                }
                i += 1;
            }
        }
        return null;
    }

    /// Skip over a complete value starting at token index `idx`.
    /// Returns the index of the token after the value.
    fn skipValue(self: *const JsonParser, idx: usize) ?usize {
        if (idx >= self.token_count) return null;
        const tok = self.tokens[idx];
        switch (tok.kind) {
            .string, .number, .bool_true, .bool_false, .null_val => return idx + 1,
            .object_start => {
                var depth: usize = 1;
                var i = idx + 1;
                while (i < self.token_count) {
                    if (self.tokens[i].kind == .object_start) {
                        depth += 1;
                    } else if (self.tokens[i].kind == .object_end) {
                        depth -= 1;
                        if (depth == 0) return i + 1;
                    }
                    i += 1;
                }
                return null;
            },
            .array_start => {
                var depth: usize = 1;
                var i = idx + 1;
                while (i < self.token_count) {
                    if (self.tokens[i].kind == .array_start) {
                        depth += 1;
                    } else if (self.tokens[i].kind == .array_end) {
                        depth -= 1;
                        if (depth == 0) return i + 1;
                    }
                    i += 1;
                }
                return null;
            },
            else => return null,
        }
    }

    // ---- Helpers ----

    fn isHexDigit(c: u8) bool {
        return (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
    }

    fn strEql(a: []const u8, b: []const u8) bool {
        if (a.len != b.len) return false;
        for (a, b) |ca, cb| {
            if (ca != cb) return false;
        }
        return true;
    }

    fn appendChar(buf: []u8, out: *usize, c: u8) bool {
        if (out.* >= buf.len) return false;
        buf[out.*] = c;
        out.* += 1;
        return true;
    }

    fn appendSlice(buf: []u8, out: *usize, s: []const u8) bool {
        if (out.* + s.len > buf.len) return false;
        @memcpy(buf[out.*..][0..s.len], s);
        out.* += s.len;
        return true;
    }

    /// Simple float parser for JSON numbers (no allocator).
    fn parseFloat(s: []const u8) ?f64 {
        if (s.len == 0) return null;

        var i: usize = 0;
        var negative = false;
        if (s[i] == '-') {
            negative = true;
            i += 1;
        }
        if (i >= s.len) return null;

        // Integer part
        var int_part: f64 = 0;
        while (i < s.len and s[i] >= '0' and s[i] <= '9') {
            int_part = int_part * 10.0 + @as(f64, @floatFromInt(s[i] - '0'));
            i += 1;
        }

        // Fractional part
        var frac_part: f64 = 0;
        if (i < s.len and s[i] == '.') {
            i += 1;
            var divisor: f64 = 10.0;
            while (i < s.len and s[i] >= '0' and s[i] <= '9') {
                frac_part += @as(f64, @floatFromInt(s[i] - '0')) / divisor;
                divisor *= 10.0;
                i += 1;
            }
        }

        var result = int_part + frac_part;

        // Exponent part
        if (i < s.len and (s[i] == 'e' or s[i] == 'E')) {
            i += 1;
            var exp_negative = false;
            if (i < s.len and s[i] == '-') {
                exp_negative = true;
                i += 1;
            } else if (i < s.len and s[i] == '+') {
                i += 1;
            }
            var exp: i32 = 0;
            while (i < s.len and s[i] >= '0' and s[i] <= '9') {
                exp = exp * 10 + @as(i32, @intCast(s[i] - '0'));
                i += 1;
            }
            var multiplier: f64 = 1.0;
            var e: i32 = 0;
            while (e < exp) : (e += 1) {
                multiplier *= 10.0;
            }
            if (exp_negative) {
                result /= multiplier;
            } else {
                result *= multiplier;
            }
        }

        if (negative) result = -result;
        return result;
    }
};

// ---- Unit Tests ----

test "parse empty object" {
    var parser = JsonParser{};
    try std.testing.expect(parser.parse("{}"));
    try std.testing.expectEqual(@as(usize, 2), parser.token_count);
    try std.testing.expectEqual(TokenType.object_start, parser.tokens[0].kind);
    try std.testing.expectEqual(TokenType.object_end, parser.tokens[1].kind);
}

test "parse empty array" {
    var parser = JsonParser{};
    try std.testing.expect(parser.parse("[]"));
    try std.testing.expectEqual(@as(usize, 2), parser.token_count);
    try std.testing.expectEqual(TokenType.array_start, parser.tokens[0].kind);
    try std.testing.expectEqual(TokenType.array_end, parser.tokens[1].kind);
}

test "parse simple key-value" {
    var parser = JsonParser{};
    const input = "{\"name\":\"hello\"}";
    try std.testing.expect(parser.parse(input));
    const val = parser.getString("name");
    try std.testing.expect(val != null);
    try std.testing.expectEqualStrings("hello", val.?);
}

test "parse nested object key-path" {
    var parser = JsonParser{};
    const input = "{\"editor\":{\"fontSize\":14}}";
    try std.testing.expect(parser.parse(input));
    const val = parser.getNumber("editor.fontSize");
    try std.testing.expect(val != null);
    try std.testing.expectEqual(@as(f64, 14.0), val.?);
}

test "parse boolean values" {
    var parser = JsonParser{};
    const input = "{\"enabled\":true,\"debug\":false}";
    try std.testing.expect(parser.parse(input));
    try std.testing.expectEqual(@as(?bool, true), parser.getBool("enabled"));
    try std.testing.expectEqual(@as(?bool, false), parser.getBool("debug"));
}

test "parse null value" {
    var parser = JsonParser{};
    const input = "{\"value\":null}";
    try std.testing.expect(parser.parse(input));
    try std.testing.expectEqual(@as(?[]const u8, null), parser.getString("value"));
}

test "key-path not found returns null" {
    var parser = JsonParser{};
    const input = "{\"a\":1}";
    try std.testing.expect(parser.parse(input));
    try std.testing.expectEqual(@as(?f64, null), parser.getNumber("b"));
    try std.testing.expectEqual(@as(?f64, null), parser.getNumber("a.b"));
}

test "malformed input returns false" {
    var parser = JsonParser{};
    try std.testing.expect(!parser.parse("{"));
    try std.testing.expect(!parser.parse("{\"a\":}"));
    try std.testing.expect(!parser.parse("{\"a\""));
    try std.testing.expect(!parser.parse(""));
    try std.testing.expect(!parser.parse("{,}"));
}

test "parse array with values" {
    var parser = JsonParser{};
    const input = "[1,2,3]";
    try std.testing.expect(parser.parse(input));
    try std.testing.expectEqual(@as(usize, 6), parser.token_count); // [ 1 , 2 , 3 ]
}

test "parse negative number" {
    var parser = JsonParser{};
    const input = "{\"temp\":-42.5}";
    try std.testing.expect(parser.parse(input));
    const val = parser.getNumber("temp");
    try std.testing.expect(val != null);
    try std.testing.expectEqual(@as(f64, -42.5), val.?);
}

test "parse string with escapes" {
    var parser = JsonParser{};
    const input = "{\"msg\":\"hello\\nworld\"}";
    try std.testing.expect(parser.parse(input));
    const val = parser.getString("msg");
    try std.testing.expect(val != null);
    try std.testing.expectEqualStrings("hello\\nworld", val.?);
}

test "serialize round-trip" {
    var parser = JsonParser{};
    const input = "{\"a\":1,\"b\":true,\"c\":\"hello\"}";
    try std.testing.expect(parser.parse(input));

    var buf: [1024]u8 = undefined;
    const result = parser.serialize(&buf);
    try std.testing.expect(result != null);

    // Parse the serialized output
    var parser2 = JsonParser{};
    try std.testing.expect(parser2.parse(result.?));
    try std.testing.expectEqual(parser.token_count, parser2.token_count);
}

test "parse deeply nested object" {
    var parser = JsonParser{};
    const input = "{\"a\":{\"b\":{\"c\":42}}}";
    try std.testing.expect(parser.parse(input));
    const val = parser.getNumber("a.b.c");
    try std.testing.expect(val != null);
    try std.testing.expectEqual(@as(f64, 42.0), val.?);
}

test "parse with whitespace" {
    var parser = JsonParser{};
    const input = "  { \"key\" : \"value\" }  ";
    try std.testing.expect(parser.parse(input));
    const val = parser.getString("key");
    try std.testing.expect(val != null);
    try std.testing.expectEqualStrings("value", val.?);
}

test "trailing content returns false" {
    var parser = JsonParser{};
    try std.testing.expect(!parser.parse("{}extra"));
    try std.testing.expect(!parser.parse("[]1"));
}

test "parse number with exponent" {
    var parser = JsonParser{};
    const input = "{\"val\":1e2}";
    try std.testing.expect(parser.parse(input));
    const val = parser.getNumber("val");
    try std.testing.expect(val != null);
    try std.testing.expectEqual(@as(f64, 100.0), val.?);
}

test "multiple keys skip correctly" {
    var parser = JsonParser{};
    const input = "{\"x\":1,\"y\":2,\"z\":3}";
    try std.testing.expect(parser.parse(input));
    try std.testing.expectEqual(@as(?f64, 1.0), parser.getNumber("x"));
    try std.testing.expectEqual(@as(?f64, 2.0), parser.getNumber("y"));
    try std.testing.expectEqual(@as(?f64, 3.0), parser.getNumber("z"));
}

const std = @import("std");
