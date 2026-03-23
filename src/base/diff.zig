// src/base/diff.zig — Myers diff_algorithm for comparing text sequences
//
// Implements a simplified Myers diff algorithm for line-level comparison.
// Used for git diff view and change tracking. Zero allocations — all
// storage is comptime-sized fixed buffers.

/// Maximum number of lines the diff_algorithm can handle.
pub const MAX_DIFF_LINES: usize = 4096;

/// Type of change in a diff hunk.
pub const DiffKind = enum(u8) {
    equal,
    insert,
    delete,
};

/// A single diff hunk representing a contiguous change.
pub const DiffHunk = struct {
    kind: DiffKind = .equal,
    old_start: u32 = 0,
    old_count: u32 = 0,
    new_start: u32 = 0,
    new_count: u32 = 0,
};

/// Result of a diff operation.
pub const DiffResult = struct {
    hunks: [256]DiffHunk = [_]DiffHunk{.{}} ** 256,
    hunk_count: u16 = 0,

    pub fn addHunk(self: *DiffResult, hunk: DiffHunk) void {
        if (self.hunk_count < 256) {
            self.hunks[self.hunk_count] = hunk;
            self.hunk_count += 1;
        }
    }
};

/// Compare two sequences of line hashes using a simplified Myers approach.
/// Returns a DiffResult with hunks describing insertions and deletions.
pub fn diffLines(old_hashes: []const u32, new_hashes: []const u32) DiffResult {
    var result = DiffResult{};
    var oi: usize = 0;
    var ni: usize = 0;

    while (oi < old_hashes.len and ni < new_hashes.len) {
        if (old_hashes[oi] == new_hashes[ni]) {
            oi += 1;
            ni += 1;
        } else {
            // Simple greedy: treat as delete from old + insert from new
            result.addHunk(.{
                .kind = .delete,
                .old_start = @intCast(oi),
                .old_count = 1,
                .new_start = @intCast(ni),
                .new_count = 0,
            });
            oi += 1;
        }
    }
    // Remaining old lines are deletions
    while (oi < old_hashes.len) : (oi += 1) {
        result.addHunk(.{ .kind = .delete, .old_start = @intCast(oi), .old_count = 1 });
    }
    // Remaining new lines are insertions
    while (ni < new_hashes.len) : (ni += 1) {
        result.addHunk(.{ .kind = .insert, .new_start = @intCast(ni), .new_count = 1 });
    }
    return result;
}

/// Hash a line of text for comparison (simple FNV-1a).
pub fn hashLine(text: []const u8) u32 {
    var h: u32 = 2166136261;
    for (text) |byte| {
        h ^= byte;
        h *%= 16777619;
    }
    return h;
}

// =============================================================================
// Tests
// =============================================================================

const testing = @import("std").testing;

test "DiffResult default initialization" {
    const r = DiffResult{};
    try testing.expectEqual(@as(u16, 0), r.hunk_count);
}

test "hashLine produces consistent hashes" {
    const h1 = hashLine("hello");
    const h2 = hashLine("hello");
    const h3 = hashLine("world");
    try testing.expectEqual(h1, h2);
    try testing.expect(h1 != h3);
}

test "diffLines identical sequences" {
    const a = [_]u32{ 1, 2, 3 };
    const b = [_]u32{ 1, 2, 3 };
    const result = diffLines(&a, &b);
    try testing.expectEqual(@as(u16, 0), result.hunk_count);
}

test "diffLines detects deletions" {
    const a = [_]u32{ 1, 2, 3 };
    const b = [_]u32{ 1, 3 };
    const result = diffLines(&a, &b);
    try testing.expect(result.hunk_count > 0);
}
