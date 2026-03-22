// src/base/color.zig — RGBA color

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1.0,

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{
            .r = @as(f32, @floatFromInt(r)) / 255.0,
            .g = @as(f32, @floatFromInt(g)) / 255.0,
            .b = @as(f32, @floatFromInt(b)) / 255.0,
        };
    }

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{
            .r = @as(f32, @floatFromInt(r)) / 255.0,
            .g = @as(f32, @floatFromInt(g)) / 255.0,
            .b = @as(f32, @floatFromInt(b)) / 255.0,
            .a = @as(f32, @floatFromInt(a)) / 255.0,
        };
    }
};

// --- Unit Tests ---

const testing = @import("std").testing;

test "Color.rgb - black" {
    const c = Color.rgb(0, 0, 0);
    try testing.expectApproxEqAbs(@as(f32, 0.0), c.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0.0), c.g, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0.0), c.b, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), c.a, 0.001); // default alpha
}

test "Color.rgb - white" {
    const c = Color.rgb(255, 255, 255);
    try testing.expectApproxEqAbs(@as(f32, 1.0), c.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), c.g, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), c.b, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), c.a, 0.001);
}

test "Color.rgb - specific color" {
    const c = Color.rgb(128, 64, 32);
    try testing.expectApproxEqAbs(@as(f32, 128.0 / 255.0), c.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 64.0 / 255.0), c.g, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 32.0 / 255.0), c.b, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), c.a, 0.001);
}

test "Color.rgba - fully transparent" {
    const c = Color.rgba(255, 0, 0, 0);
    try testing.expectApproxEqAbs(@as(f32, 1.0), c.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0.0), c.g, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0.0), c.b, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0.0), c.a, 0.001);
}

test "Color.rgba - half transparent" {
    const c = Color.rgba(0, 255, 0, 128);
    try testing.expectApproxEqAbs(@as(f32, 0.0), c.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), c.g, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0.0), c.b, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 128.0 / 255.0), c.a, 0.001);
}

test "Color.rgba - fully opaque" {
    const c = Color.rgba(100, 150, 200, 255);
    try testing.expectApproxEqAbs(@as(f32, 100.0 / 255.0), c.r, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 150.0 / 255.0), c.g, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 200.0 / 255.0), c.b, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), c.a, 0.001);
}
