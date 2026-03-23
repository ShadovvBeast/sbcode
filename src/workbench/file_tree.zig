// src/workbench/file_tree.zig — Shared rendering atoms for file tree UI
const gl = @import("gl");
const Color = @import("color").Color;

pub fn renderAlphaRect(x: i32, y: i32, w: i32, h: i32, color: Color) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(color.r, color.g, color.b, color.a);
    const x0: f32 = @floatFromInt(x);
    const y0: f32 = @floatFromInt(y);
    const x1: f32 = @floatFromInt(x + w);
    const y1: f32 = @floatFromInt(y + h);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(x0, y0);
    gl.glVertex2f(x1, y0);
    gl.glVertex2f(x1, y1);
    gl.glVertex2f(x0, y1);
    gl.glEnd();
}

pub fn renderSearchIcon(cx: f32, cy: f32, radius: f32, color: Color) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(color.r, color.g, color.b, color.a);
    gl.glLineWidth(1.5);
    gl.glBegin(gl.GL_LINE_LOOP);
    comptime var i: usize = 0;
    inline while (i < 12) : (i += 1) {
        const angle: f32 = @as(f32, @floatFromInt(i)) * (2.0 * 3.14159 / 12.0);
        gl.glVertex2f(cx + radius * @cos(angle), cy + radius * @sin(angle));
    }
    gl.glEnd();
    const hx = cx + radius * 0.707;
    const hy = cy + radius * 0.707;
    gl.glBegin(gl.GL_LINES);
    gl.glVertex2f(hx, hy);
    gl.glVertex2f(hx + radius * 0.6, hy + radius * 0.6);
    gl.glEnd();
    gl.glLineWidth(1.0);
}

pub fn renderFolderIcon(x: i32, y: i32, size: i32, color: Color) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    const s: f32 = @floatFromInt(size);
    const fx: f32 = @floatFromInt(x);
    const fy: f32 = @floatFromInt(y);
    const tab_w = s * 0.4;
    const tab_h = s * 0.2;
    gl.glColor4f(color.r * 0.85, color.g * 0.85, color.b * 0.85, color.a);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(fx, fy);
    gl.glVertex2f(fx + tab_w, fy);
    gl.glVertex2f(fx + tab_w + tab_h * 0.5, fy + tab_h);
    gl.glVertex2f(fx, fy + tab_h);
    gl.glEnd();
    gl.glColor4f(color.r, color.g, color.b, color.a);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(fx, fy + tab_h);
    gl.glVertex2f(fx + s * 0.9, fy + tab_h);
    gl.glVertex2f(fx + s * 0.9, fy + s);
    gl.glVertex2f(fx, fy + s);
    gl.glEnd();
    gl.glColor4f(1.0, 1.0, 1.0, color.a * 0.12);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(fx, fy + tab_h);
    gl.glVertex2f(fx + s * 0.9, fy + tab_h);
    gl.glVertex2f(fx + s * 0.9, fy + tab_h + 1.0);
    gl.glVertex2f(fx, fy + tab_h + 1.0);
    gl.glEnd();
}
pub fn renderFileIcon(x: i32, y: i32, size: i32, color: Color) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    const s: f32 = @floatFromInt(size);
    const fx: f32 = @floatFromInt(x);
    const fy: f32 = @floatFromInt(y);
    const fold = s * 0.25;
    const w = s * 0.7;
    gl.glColor4f(color.r, color.g, color.b, color.a);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(fx, fy);
    gl.glVertex2f(fx + w - fold, fy);
    gl.glVertex2f(fx + w - fold, fy + s);
    gl.glVertex2f(fx, fy + s);
    gl.glEnd();
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(fx + w - fold, fy + fold);
    gl.glVertex2f(fx + w, fy + fold);
    gl.glVertex2f(fx + w, fy + s);
    gl.glVertex2f(fx + w - fold, fy + s);
    gl.glEnd();
    gl.glColor4f(color.r * 0.7, color.g * 0.7, color.b * 0.7, color.a);
    gl.glBegin(gl.GL_TRIANGLES);
    gl.glVertex2f(fx + w - fold, fy);
    gl.glVertex2f(fx + w, fy + fold);
    gl.glVertex2f(fx + w - fold, fy + fold);
    gl.glEnd();
}

pub fn renderArrowUp(cx: f32, cy: f32, size: f32, color: Color) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(color.r, color.g, color.b, color.a);
    gl.glBegin(gl.GL_TRIANGLES);
    gl.glVertex2f(cx, cy - size);
    gl.glVertex2f(cx - size * 0.7, cy + size * 0.3);
    gl.glVertex2f(cx + size * 0.7, cy + size * 0.3);
    gl.glEnd();
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(cx - size * 0.2, cy + size * 0.3);
    gl.glVertex2f(cx + size * 0.2, cy + size * 0.3);
    gl.glVertex2f(cx + size * 0.2, cy + size);
    gl.glVertex2f(cx - size * 0.2, cy + size);
    gl.glEnd();
}

pub fn renderChevron(cx: f32, cy: f32, size: f32, expanded: bool, color: Color) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(color.r, color.g, color.b, color.a);
    gl.glBegin(gl.GL_TRIANGLES);
    if (expanded) {
        gl.glVertex2f(cx - size * 0.5, cy - size * 0.3);
        gl.glVertex2f(cx + size * 0.5, cy - size * 0.3);
        gl.glVertex2f(cx, cy + size * 0.4);
    } else {
        gl.glVertex2f(cx - size * 0.2, cy - size * 0.5);
        gl.glVertex2f(cx + size * 0.4, cy);
        gl.glVertex2f(cx - size * 0.2, cy + size * 0.5);
    }
    gl.glEnd();
}

pub fn renderIndentGuide(x: i32, y: i32, h: i32, color: Color) void {
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glColor4f(color.r, color.g, color.b, color.a);
    const fx: f32 = @floatFromInt(x);
    const fy: f32 = @floatFromInt(y);
    const fh: f32 = @floatFromInt(h);
    gl.glBegin(gl.GL_QUADS);
    gl.glVertex2f(fx, fy);
    gl.glVertex2f(fx + 1.0, fy);
    gl.glVertex2f(fx + 1.0, fy + fh);
    gl.glVertex2f(fx, fy + fh);
    gl.glEnd();
}
pub fn fileExtension(name: []const u8) []const u8 {
    var i: usize = name.len;
    while (i > 0) {
        i -= 1;
        if (name[i] == '.') return name[i..];
    }
    return "";
}

fn strEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

pub fn fileNameColor(name: []const u8, alpha: f32, selected: bool) Color {
    if (selected) return Color{ .r = 0.95, .g = 0.95, .b = 0.95, .a = alpha };
    const ext = fileExtension(name);
    if (ext.len == 0) return Color{ .r = 0.83, .g = 0.83, .b = 0.83, .a = alpha };
    if (strEql(ext, ".zig")) return Color{ .r = 0.95, .g = 0.65, .b = 0.25, .a = alpha };
    if (strEql(ext, ".json") or strEql(ext, ".toml") or strEql(ext, ".yml") or strEql(ext, ".yaml"))
        return Color{ .r = 0.60, .g = 0.85, .b = 0.45, .a = alpha };
    if (strEql(ext, ".md") or strEql(ext, ".txt") or strEql(ext, ".rst"))
        return Color{ .r = 0.55, .g = 0.75, .b = 0.95, .a = alpha };
    if (strEql(ext, ".py") or strEql(ext, ".sh") or strEql(ext, ".bat") or strEql(ext, ".ps1"))
        return Color{ .r = 0.70, .g = 0.55, .b = 0.90, .a = alpha };
    if (strEql(ext, ".ico") or strEql(ext, ".png") or strEql(ext, ".bmp") or strEql(ext, ".svg"))
        return Color{ .r = 0.90, .g = 0.55, .b = 0.70, .a = alpha };
    if (strEql(ext, ".c") or strEql(ext, ".h") or strEql(ext, ".cpp") or strEql(ext, ".hpp"))
        return Color{ .r = 0.45, .g = 0.70, .b = 0.95, .a = alpha };
    return Color{ .r = 0.83, .g = 0.83, .b = 0.83, .a = alpha };
}

pub const DIR_ICON_COLOR = Color{ .r = 0.86, .g = 0.74, .b = 0.42, .a = 1.0 };
pub const FILE_ICON_COLOR = Color{ .r = 0.55, .g = 0.65, .b = 0.80, .a = 1.0 };

pub fn formatCount(filtered: u16, total: u16, buf: *[32]u8) []const u8 {
    var pos: usize = 0;
    pos = writeU16(buf, pos, filtered);
    const of_str = " of ";
    @memcpy(buf[pos..][0..of_str.len], of_str);
    pos += of_str.len;
    pos = writeU16(buf, pos, total);
    const items_str = " items";
    @memcpy(buf[pos..][0..items_str.len], items_str);
    pos += items_str.len;
    return buf[0..pos];
}

pub fn writeU16(buf: *[32]u8, start: usize, val: u16) usize {
    if (val == 0) {
        buf[start] = '0';
        return start + 1;
    }
    var digits: [5]u8 = undefined;
    var dcount: usize = 0;
    var v = val;
    while (v > 0) {
        digits[dcount] = @intCast(v % 10 + '0');
        dcount += 1;
        v /= 10;
    }
    var pos = start;
    var i: usize = dcount;
    while (i > 0) {
        i -= 1;
        buf[pos] = digits[i];
        pos += 1;
    }
    return pos;
}
const testing = @import("std").testing;

test "fileExtension extracts extension" {
    try testing.expectEqualSlices(u8, ".zig", fileExtension("main.zig"));
    try testing.expectEqualSlices(u8, ".json", fileExtension("package.json"));
    try testing.expectEqualSlices(u8, "", fileExtension("Makefile"));
}

test "fileNameColor returns orange for zig" {
    const c = fileNameColor("test.zig", 1.0, false);
    try testing.expectApproxEqAbs(@as(f32, 0.95), c.r, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 0.65), c.g, 0.01);
}

test "fileNameColor returns white for selected" {
    const c = fileNameColor("test.zig", 1.0, true);
    try testing.expectApproxEqAbs(@as(f32, 0.95), c.r, 0.01);
}

test "formatCount formats correctly" {
    var buf: [32]u8 = undefined;
    const result = formatCount(5, 20, &buf);
    try testing.expectEqualSlices(u8, "5 of 20 items", result);
}

test "formatCount handles zero" {
    var buf: [32]u8 = undefined;
    const result = formatCount(0, 0, &buf);
    try testing.expectEqualSlices(u8, "0 of 0 items", result);
}

test "DIR_ICON_COLOR is golden" {
    try testing.expectApproxEqAbs(@as(f32, 0.86), DIR_ICON_COLOR.r, 0.01);
}