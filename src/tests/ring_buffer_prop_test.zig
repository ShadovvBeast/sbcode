// Property-based test for RingBuffer FIFO ordering
// **Validates: Requirements 3.1, 3.2, 3.3**
//
// Property 1: RingBuffer FIFO Ordering
// For any sequence of push and pop operations on a RingBuffer of arbitrary
// comptime capacity, items returned by pop shall appear in the same order
// they were pushed (FIFO), push shall return false only when the buffer is
// full, and pop shall return null only when the buffer is empty.

const std = @import("std");
const RingBuffer = @import("ring_buffer").RingBuffer;
const expect = std.testing.expect;

// --- Custom comptime LCG-based pseudo-random generator (zero dependencies) ---

const Lcg = struct {
    state: u64,

    const A: u64 = 6364136223846793005;
    const C: u64 = 1442695040888963407;

    fn init(seed: u64) Lcg {
        return .{ .state = seed };
    }

    fn next(self: *Lcg) u64 {
        self.state = self.state *% A +% C;
        return self.state;
    }

    /// Returns a value in [0, bound).
    fn bounded(self: *Lcg, bound: u64) u64 {
        return self.next() % bound;
    }
};

// --- Operation encoding ---

const Op = enum { push, pop };

fn generateOps(comptime max_ops: usize, rng: *Lcg) struct { ops: [max_ops]Op, vals: [max_ops]u32, count: usize } {
    var result: struct { ops: [max_ops]Op, vals: [max_ops]u32, count: usize } = undefined;
    const count = @as(usize, @intCast(rng.bounded(max_ops))) + 1;
    result.count = count;
    for (0..count) |i| {
        result.ops[i] = if (rng.bounded(2) == 0) .push else .pop;
        result.vals[i] = @as(u32, @truncate(rng.next()));
    }
    return result;
}

// --- Core property test logic ---
// Runs a random sequence of push/pop operations on a RingBuffer and verifies:
//   1. Items come out in FIFO order (tracked via a shadow queue)
//   2. push returns false ONLY when the buffer is full
//   3. pop returns null ONLY when the buffer is empty

fn runFifoPropertyTest(comptime capacity: usize, comptime max_ops: usize, rng: *Lcg) !void {
    var rb = RingBuffer(u32, capacity){};

    // Shadow FIFO queue to track expected order
    var shadow: [max_ops]u32 = undefined;
    var shadow_head: usize = 0;
    var shadow_len: usize = 0;

    const gen = generateOps(max_ops, rng);

    for (0..gen.count) |i| {
        switch (gen.ops[i]) {
            .push => {
                const val = gen.vals[i];
                const result = rb.push(val);
                if (shadow_len == capacity) {
                    // Buffer is full — push must return false
                    try expect(!result);
                    // Buffer unchanged: len stays the same
                    try expect(rb.len == shadow_len);
                } else {
                    // Buffer has space — push must return true
                    try expect(result);
                    shadow[shadow_head + shadow_len] = val;
                    shadow_len += 1;
                    try expect(rb.len == shadow_len);
                }
            },
            .pop => {
                const result = rb.pop();
                if (shadow_len == 0) {
                    // Buffer is empty — pop must return null
                    try expect(result == null);
                } else {
                    // Buffer has items — pop must return the oldest item (FIFO)
                    try expect(result != null);
                    try expect(result.? == shadow[shadow_head]);
                    shadow_head += 1;
                    shadow_len -= 1;
                    try expect(rb.len == shadow_len);
                }
            },
        }
    }
}

// --- Property tests across multiple seeds and capacities ---

test "Property 1: RingBuffer FIFO ordering — capacity 4" {
    comptime var seed: u64 = 0;
    inline while (seed < 50) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runFifoPropertyTest(4, 64, &rng);
    }
}

test "Property 1: RingBuffer FIFO ordering — capacity 1" {
    comptime var seed: u64 = 100;
    inline while (seed < 150) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runFifoPropertyTest(1, 32, &rng);
    }
}

test "Property 1: RingBuffer FIFO ordering — capacity 16" {
    comptime var seed: u64 = 200;
    inline while (seed < 250) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runFifoPropertyTest(16, 128, &rng);
    }
}

test "Property 1: RingBuffer FIFO ordering — capacity 64" {
    comptime var seed: u64 = 300;
    inline while (seed < 330) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runFifoPropertyTest(64, 256, &rng);
    }
}

test "Property 1: RingBuffer FIFO ordering — heavy push then drain" {
    // Specifically tests wrap-around: fill completely, drain completely, repeat
    comptime var seed: u64 = 500;
    inline while (seed < 520) : (seed += 1) {
        var rng = Lcg.init(seed);
        var rb = RingBuffer(u32, 8){};
        var shadow: [1024]u32 = undefined;
        var shadow_head: usize = 0;
        var shadow_len: usize = 0;

        // Multiple fill-drain cycles to exercise wrap-around
        for (0..4) |_| {
            // Fill
            for (0..8) |_| {
                const val = @as(u32, @truncate(rng.next()));
                const ok = rb.push(val);
                try expect(ok);
                shadow[shadow_head + shadow_len] = val;
                shadow_len += 1;
            }
            // Full — push must fail
            try expect(!rb.push(999));
            try expect(rb.len == 8);

            // Drain
            for (0..8) |_| {
                const item = rb.pop();
                try expect(item != null);
                try expect(item.? == shadow[shadow_head]);
                shadow_head += 1;
                shadow_len -= 1;
            }
            // Empty — pop must return null
            try expect(rb.pop() == null);
            try expect(rb.len == 0);
        }
    }
}
