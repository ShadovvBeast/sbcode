// src/base/rect.zig — Layout rectangle

pub const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub fn contains(self: Rect, px: i32, py: i32) bool {
        return px >= self.x and px < self.x + self.w and
            py >= self.y and py < self.y + self.h;
    }

    pub fn intersects(self: Rect, other: Rect) bool {
        return self.x < other.x + other.w and self.x + self.w > other.x and
            self.y < other.y + other.h and self.y + self.h > other.y;
    }

    pub fn shrink(self: Rect, margin: i32) Rect {
        return .{
            .x = self.x + margin,
            .y = self.y + margin,
            .w = self.w - margin * 2,
            .h = self.h - margin * 2,
        };
    }
};

// --- Unit Tests ---

const testing = @import("std").testing;

test "Rect.contains - point inside rect" {
    const r = Rect{ .x = 10, .y = 20, .w = 100, .h = 50 };
    try testing.expect(r.contains(10, 20)); // top-left corner (inclusive)
    try testing.expect(r.contains(50, 40)); // center
    try testing.expect(r.contains(109, 69)); // just inside bottom-right
}

test "Rect.contains - point outside rect" {
    const r = Rect{ .x = 10, .y = 20, .w = 100, .h = 50 };
    try testing.expect(!r.contains(9, 20)); // left of rect
    try testing.expect(!r.contains(10, 19)); // above rect
    try testing.expect(!r.contains(110, 20)); // exclusive right edge
    try testing.expect(!r.contains(10, 70)); // exclusive bottom edge
}

test "Rect.contains - zero-size rect contains nothing" {
    const r = Rect{ .x = 5, .y = 5, .w = 0, .h = 0 };
    try testing.expect(!r.contains(5, 5));
}

test "Rect.intersects - overlapping rects" {
    const a = Rect{ .x = 0, .y = 0, .w = 100, .h = 100 };
    const b = Rect{ .x = 50, .y = 50, .w = 100, .h = 100 };
    try testing.expect(a.intersects(b));
    try testing.expect(b.intersects(a));
}

test "Rect.intersects - non-overlapping rects" {
    const a = Rect{ .x = 0, .y = 0, .w = 50, .h = 50 };
    const b = Rect{ .x = 50, .y = 0, .w = 50, .h = 50 }; // touching edge
    try testing.expect(!a.intersects(b)); // touching edges don't overlap
}

test "Rect.intersects - contained rect" {
    const outer = Rect{ .x = 0, .y = 0, .w = 100, .h = 100 };
    const inner = Rect{ .x = 10, .y = 10, .w = 20, .h = 20 };
    try testing.expect(outer.intersects(inner));
    try testing.expect(inner.intersects(outer));
}

test "Rect.shrink - basic shrink" {
    const r = Rect{ .x = 10, .y = 20, .w = 100, .h = 80 };
    const s = r.shrink(5);
    try testing.expectEqual(@as(i32, 15), s.x);
    try testing.expectEqual(@as(i32, 25), s.y);
    try testing.expectEqual(@as(i32, 90), s.w);
    try testing.expectEqual(@as(i32, 70), s.h);
}

test "Rect.shrink - zero margin returns same rect" {
    const r = Rect{ .x = 10, .y = 20, .w = 100, .h = 80 };
    const s = r.shrink(0);
    try testing.expectEqual(r.x, s.x);
    try testing.expectEqual(r.y, s.y);
    try testing.expectEqual(r.w, s.w);
    try testing.expectEqual(r.h, s.h);
}
