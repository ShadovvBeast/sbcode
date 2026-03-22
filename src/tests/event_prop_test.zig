// Property-based test for Event system fire-all-subscribers
// **Validates: Requirement 3.8**
//
// Property 4: Event System Fires All Subscribers
// For any set of N subscribers (where N <= max_listeners) registered on an
// Event, firing the event shall invoke all N callbacks exactly once with the
// provided data. subscribe returns false only when at max_listeners capacity.
// After unsubscribeAll, firing calls zero callbacks. Each callback receives
// the exact data passed to fire.

const std = @import("std");
const Event = @import("event").Event;
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

// --- Global state for tracking callback invocations ---

var g_call_count: u32 = 0;
var g_last_value: u32 = 0;

fn callback_inc(val: u32) void {
    g_call_count += 1;
    g_last_value = val;
}

// --- Core property test: N subscribers receive exactly N calls ---

fn runFireAllSubscribers(comptime max_listeners: usize, rng: *Lcg) !void {
    const TestEvent = Event(u32, max_listeners);
    var event = TestEvent{};

    // Pick a random subscriber count in [0, max_listeners]
    const n = @as(usize, @intCast(rng.bounded(max_listeners + 1)));

    // Subscribe N callbacks — all should succeed
    for (0..n) |_| {
        const ok = event.subscribe(callback_inc);
        try expect(ok);
    }
    try expect(event.count == n);

    // Reset global counter and fire
    g_call_count = 0;
    g_last_value = 0;
    const fire_val = @as(u32, @truncate(rng.next()));
    event.fire(fire_val);

    // Exactly N callbacks should have been invoked
    try expect(g_call_count == n);
    // If N > 0, the last value received must equal fire_val
    if (n > 0) {
        try expect(g_last_value == fire_val);
    }
}

// --- Core property test: subscribe returns false at capacity ---

fn runSubscribeAtCapacity(comptime max_listeners: usize, rng: *Lcg) !void {
    _ = rng;
    const TestEvent = Event(u32, max_listeners);
    var event = TestEvent{};

    // Fill to capacity
    for (0..max_listeners) |_| {
        const ok = event.subscribe(callback_inc);
        try expect(ok);
    }
    try expect(event.count == max_listeners);

    // Next subscribe must return false
    const overflow = event.subscribe(callback_inc);
    try expect(!overflow);
    try expect(event.count == max_listeners);

    // Fire should still call exactly max_listeners callbacks
    g_call_count = 0;
    event.fire(42);
    try expect(g_call_count == max_listeners);
}

// --- Core property test: unsubscribeAll then fire calls zero callbacks ---

fn runUnsubscribeAllThenFire(comptime max_listeners: usize, rng: *Lcg) !void {
    const TestEvent = Event(u32, max_listeners);
    var event = TestEvent{};

    // Subscribe a random number of listeners
    const n = @as(usize, @intCast(rng.bounded(max_listeners + 1)));
    for (0..n) |_| {
        _ = event.subscribe(callback_inc);
    }

    // Unsubscribe all
    event.unsubscribeAll();
    try expect(event.count == 0);

    // Fire should invoke zero callbacks
    g_call_count = 0;
    event.fire(999);
    try expect(g_call_count == 0);
}

// --- Core property test: resubscribe after unsubscribeAll works ---

fn runResubscribeAfterClear(comptime max_listeners: usize, rng: *Lcg) !void {
    const TestEvent = Event(u32, max_listeners);
    var event = TestEvent{};

    // Subscribe, fire, verify
    const n1 = @as(usize, @intCast(rng.bounded(max_listeners + 1)));
    for (0..n1) |_| {
        _ = event.subscribe(callback_inc);
    }
    g_call_count = 0;
    event.fire(1);
    try expect(g_call_count == n1);

    // Clear all
    event.unsubscribeAll();
    g_call_count = 0;
    event.fire(2);
    try expect(g_call_count == 0);

    // Resubscribe a different count
    const n2 = @as(usize, @intCast(rng.bounded(max_listeners + 1)));
    for (0..n2) |_| {
        const ok = event.subscribe(callback_inc);
        try expect(ok);
    }
    g_call_count = 0;
    const fire_val = @as(u32, @truncate(rng.next()));
    event.fire(fire_val);
    try expect(g_call_count == n2);
    if (n2 > 0) {
        try expect(g_last_value == fire_val);
    }
}

// --- Core property test: each callback receives exact data ---

// Use a separate global to track data correctness across multiple fires
var g_data_correct: bool = true;
var g_expected_value: u32 = 0;

fn callback_check_data(val: u32) void {
    if (val != g_expected_value) {
        g_data_correct = false;
    }
    g_call_count += 1;
}

fn runDataPassthrough(comptime max_listeners: usize, rng: *Lcg) !void {
    const TestEvent = Event(u32, max_listeners);
    var event = TestEvent{};

    const n = @as(usize, @intCast(rng.bounded(max_listeners + 1)));
    for (0..n) |_| {
        _ = event.subscribe(callback_check_data);
    }

    // Fire multiple times with different values
    const num_fires = @as(usize, @intCast(rng.bounded(8))) + 1;
    for (0..num_fires) |_| {
        const val = @as(u32, @truncate(rng.next()));
        g_call_count = 0;
        g_data_correct = true;
        g_expected_value = val;
        event.fire(val);
        try expect(g_call_count == n);
        try expect(g_data_correct);
    }
}

// --- Property tests across multiple seeds and capacities ---

test "Property 4: Event fires all N subscribers — capacity 4" {
    comptime var seed: u64 = 0;
    inline while (seed < 50) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runFireAllSubscribers(4, &rng);
    }
}

test "Property 4: Event fires all N subscribers — capacity 1" {
    comptime var seed: u64 = 100;
    inline while (seed < 150) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runFireAllSubscribers(1, &rng);
    }
}

test "Property 4: Event fires all N subscribers — capacity 16" {
    comptime var seed: u64 = 200;
    inline while (seed < 250) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runFireAllSubscribers(16, &rng);
    }
}

test "Property 4: Event subscribe returns false at capacity" {
    comptime var seed: u64 = 300;
    inline while (seed < 330) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runSubscribeAtCapacity(4, &rng);
    }
}

test "Property 4: Event subscribe returns false at capacity — capacity 1" {
    comptime var seed: u64 = 330;
    inline while (seed < 360) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runSubscribeAtCapacity(1, &rng);
    }
}

test "Property 4: Event unsubscribeAll then fire calls zero callbacks" {
    comptime var seed: u64 = 400;
    inline while (seed < 450) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runUnsubscribeAllThenFire(8, &rng);
    }
}

test "Property 4: Event resubscribe after unsubscribeAll" {
    comptime var seed: u64 = 500;
    inline while (seed < 550) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runResubscribeAfterClear(4, &rng);
    }
}

test "Property 4: Event each callback receives exact data" {
    comptime var seed: u64 = 600;
    inline while (seed < 650) : (seed += 1) {
        var rng = Lcg.init(seed);
        try runDataPassthrough(8, &rng);
    }
}
