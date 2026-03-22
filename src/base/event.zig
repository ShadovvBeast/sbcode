// src/base/event.zig — Comptime-typed event system (replaces VS Code's Emitter/Event)

pub fn Event(comptime T: type, comptime max_listeners: usize) type {
    return struct {
        const Self = @This();
        const Callback = *const fn (T) void;

        listeners: [max_listeners]?Callback = [_]?Callback{null} ** max_listeners,
        count: usize = 0,

        pub fn subscribe(self: *Self, cb: Callback) bool {
            if (self.count >= max_listeners) return false;
            self.listeners[self.count] = cb;
            self.count += 1;
            return true;
        }

        pub fn fire(self: *const Self, data: T) void {
            for (self.listeners[0..self.count]) |maybe_cb| {
                if (maybe_cb) |cb| cb(data);
            }
        }

        pub fn unsubscribeAll(self: *Self) void {
            for (&self.listeners) |*slot| slot.* = null;
            self.count = 0;
        }
    };
}

// Unit tests
const testing = @import("std").testing;

test "Event subscribe and fire" {
    const TestEvent = Event(u32, 4);
    var event = TestEvent{};

    var called_value: u32 = 0;
    const cb = struct {
        fn handler(val: u32) void {
            _ = val;
        }
    }.handler;
    _ = &called_value;

    try testing.expect(event.subscribe(cb));
    try testing.expectEqual(@as(usize, 1), event.count);

    event.fire(42);
}

test "Event subscribe returns false at capacity" {
    const TestEvent = Event(u32, 2);
    var event = TestEvent{};

    const cb = struct {
        fn handler(_: u32) void {}
    }.handler;

    try testing.expect(event.subscribe(cb));
    try testing.expect(event.subscribe(cb));
    try testing.expect(!event.subscribe(cb));
    try testing.expectEqual(@as(usize, 2), event.count);
}

test "Event unsubscribeAll clears all listeners" {
    const TestEvent = Event(u32, 4);
    var event = TestEvent{};

    const cb = struct {
        fn handler(_: u32) void {}
    }.handler;

    try testing.expect(event.subscribe(cb));
    try testing.expect(event.subscribe(cb));
    try testing.expectEqual(@as(usize, 2), event.count);

    event.unsubscribeAll();
    try testing.expectEqual(@as(usize, 0), event.count);
    for (event.listeners) |slot| {
        try testing.expect(slot == null);
    }
}

test "Event fire with no subscribers does nothing" {
    const TestEvent = Event(u32, 4);
    var event = TestEvent{};
    // Should not crash
    event.fire(99);
}

test "Event fire calls all subscribed callbacks" {
    // Use a global counter to verify all callbacks are invoked
    const S = struct {
        var counter: u32 = 0;
        fn inc(_: u32) void {
            counter += 1;
        }
    };
    S.counter = 0;

    const TestEvent = Event(u32, 4);
    var event = TestEvent{};

    try testing.expect(event.subscribe(S.inc));
    try testing.expect(event.subscribe(S.inc));
    try testing.expect(event.subscribe(S.inc));

    event.fire(1);
    try testing.expectEqual(@as(u32, 3), S.counter);
}

test "Event fire passes correct data to callbacks" {
    const S = struct {
        var received: u32 = 0;
        fn handler(val: u32) void {
            received = val;
        }
    };
    S.received = 0;

    const TestEvent = Event(u32, 2);
    var event = TestEvent{};

    try testing.expect(event.subscribe(S.handler));
    event.fire(12345);
    try testing.expectEqual(@as(u32, 12345), S.received);
}

test "Event resubscribe after unsubscribeAll" {
    const S = struct {
        var counter: u32 = 0;
        fn handler(_: u32) void {
            counter += 1;
        }
    };
    S.counter = 0;

    const TestEvent = Event(u32, 2);
    var event = TestEvent{};

    try testing.expect(event.subscribe(S.handler));
    event.fire(1);
    try testing.expectEqual(@as(u32, 1), S.counter);

    event.unsubscribeAll();
    event.fire(2);
    try testing.expectEqual(@as(u32, 1), S.counter); // no change

    try testing.expect(event.subscribe(S.handler));
    event.fire(3);
    try testing.expectEqual(@as(u32, 2), S.counter);
}
