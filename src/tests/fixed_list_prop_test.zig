// Property-based test for FixedList operations
// **Validates: Requirements 3.4, 3.5**
//
// Property 2: FixedList Operations Match Reference Model
// For any sequence of append and remove-by-index operations on a FixedList,
// the resulting contents shall match those of a simple reference list that
// performs the same operations, and get-by-index shall return the correct
// element or null for out-of-bounds indices. append returns false only when
// full, remove returns null only for out-of-bounds indices, and after any
// sequence of operations slice() matches the reference model.

const std = @import("std");
const FixedList = @import("fixed_list").FixedList;
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

const Op = enum { append, remove, get };

fn generateOps(comptime max_ops: usize, rng: *Lcg) struct { ops: [max_ops]Op, vals: [max_ops]u32, indices: [max_ops]usize, count: usize } {
    var result: struct { ops: [max_ops]Op, vals: [max_ops]u32, indices: [max_ops]usize, count: usize } = undefined;
    const count = @as(usize, @intCast(rng.bounded(max_ops))) + 1;
    result.count = count;
    for (0..count) |i| {
        const r = rng.bounded(3);
        result.ops[i] = if (r == 0) .append else if (r == 1) .remove else .get;
        result.vals[i] = @as(u32, @truncate(rng.next()));
        result.indices[i] = @as(usize, @intCast(rng.bounded(32)));
    }
    return result;
}

// --- Reference model: simple array-based list ---

fn ReferenceList(comptime capacity: usize) type {
    return struct {
        const Self = @This();
        items: [capacity]u32 = undefined,
        len: usize = 0,

        fn append(self: *Self, val: u32) bool {
            if (self.len >= capacity) return false;
            self.items[self.len] = val;
            self.len += 1;
            return true;
        }

        fn remove(self: *Self, index: usize) ?u32 {
            if (index >= self.len) return null;
            const item = self.items[index];
            var i = index;
            while (i < self.len - 1) : (i += 1) {
                self.items[i] = self.items[i + 1];
            }
            self.len -= 1;
            return item;
        }

        fn get(self: *const Self, index: usize) ?u32 {
            if (index >= self.len) return null;
            return self.items[index];
        }

        fn slice(self: *const Self) []const u32 {
            return self.items[0..self.len];
        }
    };
}

// --- Core property test logic ---
// Runs a random sequence of append/remove/get operations on a FixedList and
// a reference model, verifying they behave identically at every step:
//   1. append returns false only when full
//   2. remove returns null only for out-of-bounds indices
//   3. get returns null only for out-of-bounds indices
//   4. After any sequence of operations, slice() matches the reference model

fn runReferenceModelPropertyTest(comptime capacity: usize, comptime max_ops: usize, rng: *Lcg) !void {
    var fl = FixedList(u32, capacity){};
    var ref = ReferenceList(capacity){};

    const gen = generateOps(max_ops, rng);

    for (0..gen.count) |i| {
        switch (gen.ops[i]) {
            .append => {
                const val = gen.vals[i];
                const fl_result = fl.append(val);
                const ref_result = ref.append(val);
                // Both must agree on success/failure
                try expect(fl_result == ref_result);
                // Lengths must match
                try expect(fl.len == ref.len);
            },
            .remove => {
                const idx = gen.indices[i];
                const fl_result = fl.remove(idx);
                const ref_result = ref.remove(idx);
                // Both must return null for out-of-bounds, or same value
                if (ref_result) |ref_val| {
                    try expect(fl_result != null);
                    try expect(fl_result.? == ref_val);
                } else {
                    try expect(fl_result == null);
                }
                try expect(fl.len == ref.len);
            },
            .get => {
                const idx = gen.indices[i];
                const fl_result = fl.get(idx);
                const ref_result = ref.get(idx);
                // Both must return null for out-of-bounds, or same value
                if (ref_result) |ref_val| {
                    try expect(fl_result != null);
                    try expect(fl_result.? == ref_val);
                } else {
                    try expect(fl_result == null);
                }
            },
        }
    }

    // Final check: slice() must match the reference model
    const fl_slice = fl.slice();
    const ref_slice = ref.slice();
    try expect(fl_slice.len == ref_slice.len);
    for (0..fl_slice.len) |j| {
        try expect(fl_slice[j] == ref_slice[j]);
    }
}

// --- Property tests across multiple seeds and capacities ---

test "Property 2: FixedList operations match reference model — capacity 4" {
    comptime var seed: u64 = 0;
    inline while (seed < 50) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runReferenceModelPropertyTest(4, 64, &rng);
    }
}

test "Property 2: FixedList operations match reference model — capacity 1" {
    comptime var seed: u64 = 100;
    inline while (seed < 150) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runReferenceModelPropertyTest(1, 32, &rng);
    }
}

test "Property 2: FixedList operations match reference model — capacity 16" {
    comptime var seed: u64 = 200;
    inline while (seed < 250) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runReferenceModelPropertyTest(16, 128, &rng);
    }
}

test "Property 2: FixedList operations match reference model — capacity 64" {
    comptime var seed: u64 = 300;
    inline while (seed < 330) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runReferenceModelPropertyTest(64, 256, &rng);
    }
}

test "Property 2: FixedList operations — fill then remove all" {
    // Specifically tests filling to capacity, then removing every element
    comptime var seed: u64 = 500;
    inline while (seed < 520) : (seed += 1) {
        var rng = Lcg.init(seed);
        var fl = FixedList(u32, 8){};
        var ref = ReferenceList(8){};

        // Fill completely
        for (0..8) |_| {
            const val = @as(u32, @truncate(rng.next()));
            const fl_ok = fl.append(val);
            const ref_ok = ref.append(val);
            try expect(fl_ok == ref_ok);
            try expect(fl_ok);
        }
        // Full — append must fail
        try expect(!fl.append(999));
        try expect(!ref.append(999));
        try expect(fl.len == 8);

        // Remove all from front (index 0 each time)
        for (0..8) |_| {
            const fl_item = fl.remove(0);
            const ref_item = ref.remove(0);
            try expect(fl_item != null);
            try expect(ref_item != null);
            try expect(fl_item.? == ref_item.?);
        }
        // Empty — remove must return null
        try expect(fl.remove(0) == null);
        try expect(ref.remove(0) == null);
        try expect(fl.len == 0);

        // Verify slice is empty
        try expect(fl.slice().len == 0);
        try expect(ref.slice().len == 0);
    }
}
