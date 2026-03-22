// src/editor/cursor.zig — Multi-cursor and selection model (no allocator)
//
// Replaces VS Code's CursorState/Selection with a fixed-capacity multi-cursor
// model. All storage is stack/comptime sized. Zero allocator usage.

pub const Position = struct {
    line: u32,
    col: u32,
};

pub const Selection = struct {
    anchor: Position,
    active: Position, // cursor head

    pub fn isEmpty(self: Selection) bool {
        return self.anchor.line == self.active.line and self.anchor.col == self.active.col;
    }

    pub fn isForward(self: Selection) bool {
        if (self.anchor.line < self.active.line) return true;
        if (self.anchor.line == self.active.line) return self.anchor.col <= self.active.col;
        return false;
    }

    pub fn startPos(self: Selection) Position {
        return if (self.isForward()) self.anchor else self.active;
    }

    pub fn endPos(self: Selection) Position {
        return if (self.isForward()) self.active else self.anchor;
    }
};

pub const MAX_CURSORS = 64;

pub const CursorState = struct {
    cursors: [MAX_CURSORS]Selection = undefined,
    cursor_count: u32 = 1,

    pub fn primary(self: *const CursorState) Selection {
        return self.cursors[0];
    }

    pub fn setPrimary(self: *CursorState, pos: Position) void {
        self.cursors[0] = .{ .anchor = pos, .active = pos };
        self.cursor_count = 1;
    }

    pub fn addCursor(self: *CursorState, pos: Position) bool {
        if (self.cursor_count >= MAX_CURSORS) return false;
        self.cursors[self.cursor_count] = .{ .anchor = pos, .active = pos };
        self.cursor_count += 1;
        return true;
    }
};

// ============================================================================
// Unit tests
// ============================================================================

const std = @import("std");
const expect = std.testing.expect;

// --- Position tests ---

test "Position default values" {
    const pos = Position{ .line = 0, .col = 0 };
    try expect(pos.line == 0);
    try expect(pos.col == 0);
}

// --- Selection.isEmpty tests ---

test "Selection isEmpty when anchor equals active" {
    const sel = Selection{
        .anchor = .{ .line = 5, .col = 10 },
        .active = .{ .line = 5, .col = 10 },
    };
    try expect(sel.isEmpty());
}

test "Selection not isEmpty when anchor differs from active" {
    const sel = Selection{
        .anchor = .{ .line = 0, .col = 0 },
        .active = .{ .line = 0, .col = 5 },
    };
    try expect(!sel.isEmpty());
}

test "Selection not isEmpty when lines differ" {
    const sel = Selection{
        .anchor = .{ .line = 0, .col = 0 },
        .active = .{ .line = 1, .col = 0 },
    };
    try expect(!sel.isEmpty());
}

// --- Selection.isForward tests ---

test "Selection isForward when anchor line < active line" {
    const sel = Selection{
        .anchor = .{ .line = 0, .col = 5 },
        .active = .{ .line = 3, .col = 0 },
    };
    try expect(sel.isForward());
}

test "Selection isForward when same line and anchor col <= active col" {
    const sel = Selection{
        .anchor = .{ .line = 2, .col = 3 },
        .active = .{ .line = 2, .col = 10 },
    };
    try expect(sel.isForward());
}

test "Selection isForward when anchor equals active (empty selection)" {
    const sel = Selection{
        .anchor = .{ .line = 1, .col = 1 },
        .active = .{ .line = 1, .col = 1 },
    };
    try expect(sel.isForward());
}

test "Selection not isForward when anchor line > active line" {
    const sel = Selection{
        .anchor = .{ .line = 5, .col = 0 },
        .active = .{ .line = 2, .col = 0 },
    };
    try expect(!sel.isForward());
}

test "Selection not isForward when same line and anchor col > active col" {
    const sel = Selection{
        .anchor = .{ .line = 3, .col = 10 },
        .active = .{ .line = 3, .col = 2 },
    };
    try expect(!sel.isForward());
}

// --- Selection.startPos / endPos tests ---

test "Selection startPos and endPos for forward selection" {
    const sel = Selection{
        .anchor = .{ .line = 1, .col = 0 },
        .active = .{ .line = 3, .col = 5 },
    };
    const s = sel.startPos();
    const e = sel.endPos();
    try expect(s.line == 1 and s.col == 0);
    try expect(e.line == 3 and e.col == 5);
}

test "Selection startPos and endPos for backward selection" {
    const sel = Selection{
        .anchor = .{ .line = 5, .col = 10 },
        .active = .{ .line = 2, .col = 3 },
    };
    const s = sel.startPos();
    const e = sel.endPos();
    try expect(s.line == 2 and s.col == 3);
    try expect(e.line == 5 and e.col == 10);
}

test "Selection startPos and endPos for empty selection" {
    const sel = Selection{
        .anchor = .{ .line = 4, .col = 7 },
        .active = .{ .line = 4, .col = 7 },
    };
    const s = sel.startPos();
    const e = sel.endPos();
    try expect(s.line == 4 and s.col == 7);
    try expect(e.line == 4 and e.col == 7);
}

// --- CursorState tests ---

test "CursorState setPrimary sets first cursor and resets count" {
    var state = CursorState{};
    state.setPrimary(.{ .line = 10, .col = 5 });
    try expect(state.cursor_count == 1);
    const p = state.primary();
    try expect(p.anchor.line == 10 and p.anchor.col == 5);
    try expect(p.active.line == 10 and p.active.col == 5);
    try expect(p.isEmpty());
}

test "CursorState addCursor appends new cursor" {
    var state = CursorState{};
    state.setPrimary(.{ .line = 0, .col = 0 });
    try expect(state.addCursor(.{ .line = 5, .col = 3 }));
    try expect(state.cursor_count == 2);
    try expect(state.cursors[1].anchor.line == 5);
    try expect(state.cursors[1].anchor.col == 3);
}

test "CursorState addCursor returns false when full" {
    var state = CursorState{};
    state.setPrimary(.{ .line = 0, .col = 0 });
    var i: u32 = 1;
    while (i < MAX_CURSORS) : (i += 1) {
        try expect(state.addCursor(.{ .line = i, .col = 0 }));
    }
    try expect(state.cursor_count == MAX_CURSORS);
    // Should fail now
    try expect(!state.addCursor(.{ .line = 99, .col = 0 }));
    try expect(state.cursor_count == MAX_CURSORS);
}

test "CursorState setPrimary resets after multiple cursors" {
    var state = CursorState{};
    state.setPrimary(.{ .line = 0, .col = 0 });
    _ = state.addCursor(.{ .line = 1, .col = 0 });
    _ = state.addCursor(.{ .line = 2, .col = 0 });
    try expect(state.cursor_count == 3);
    state.setPrimary(.{ .line = 10, .col = 10 });
    try expect(state.cursor_count == 1);
    try expect(state.primary().anchor.line == 10);
}

test "CursorState primary returns first cursor" {
    var state = CursorState{};
    state.setPrimary(.{ .line = 7, .col = 3 });
    const p = state.primary();
    try expect(p.anchor.line == 7 and p.anchor.col == 3);
    try expect(p.active.line == 7 and p.active.col == 3);
}
